"""Accounts, refresh sessions (rotating, revocable) and password recovery."""

import logging
import uuid
from dataclasses import dataclass
from datetime import timedelta

from sqlmodel import Session, select, update

from app.core.config import settings
from app.core.security import (
    create_access_token,
    generate_opaque_token,
    hash_password,
    hash_token,
    verify_and_update_password,
    verify_password,
)
from app.models import PasswordResetToken, RefreshSession, User
from app.models.base import utcnow
from app.services.activity import notify, record_activity
from app.services.mailer import MailError, platform_smtp_config, send_email

logger = logging.getLogger(__name__)

# A rotated token presented again within this window is treated as a concurrent
# refresh (e.g. two tabs), not theft: the client should retry with the new cookie.
REFRESH_REUSE_GRACE_SECONDS = 20


class AuthError(Exception):
    def __init__(self, message: str, code: str = "invalid"):
        super().__init__(message)
        self.message = message
        self.code = code


@dataclass
class IssuedTokens:
    access_token: str
    access_expires_at: object
    refresh_token: str
    session: RefreshSession


def register_user(db: Session, email: str, full_name: str, password: str) -> User:
    if db.exec(select(User).where(User.email == email)).first() is not None:
        raise AuthError("An account with this email already exists.", code="email_taken")
    user = User(email=email, full_name=full_name, hashed_password=hash_password(password))
    db.add(user)
    db.flush()
    record_activity(db, user.id, "account.created", "Account created")
    return user


def authenticate(db: Session, email: str, password: str) -> User:
    user = db.exec(select(User).where(User.email == email)).first()
    if user is None:
        verify_password(password, None)
        raise AuthError("Incorrect email or password.", code="invalid_credentials")
    valid, new_hash = verify_and_update_password(password, user.hashed_password)
    if not valid:
        raise AuthError("Incorrect email or password.", code="invalid_credentials")
    if not user.is_active:
        raise AuthError("This account has been disabled.", code="inactive")
    if new_hash:
        user.hashed_password = new_hash
        db.add(user)
    return user


def start_session(db: Session, user: User, user_agent: str | None, ip: str | None) -> IssuedTokens:
    refresh_token = generate_opaque_token()
    now = utcnow()
    refresh_session = RefreshSession(
        user_id=user.id,
        token_hash=hash_token(refresh_token),
        user_agent=(user_agent or "")[:300] or None,
        ip_address=ip,
        created_at=now,
        last_used_at=now,
        expires_at=now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )
    db.add(refresh_session)
    db.flush()
    access_token, expires = create_access_token(user.id, refresh_session.id)
    return IssuedTokens(access_token, expires, refresh_token, refresh_session)


def rotate_session(db: Session, refresh_token: str, user_agent: str | None, ip: str | None) -> tuple[User, IssuedTokens]:
    token_hash = hash_token(refresh_token)
    now = utcnow()
    refresh_session = db.exec(
        select(RefreshSession).where(RefreshSession.token_hash == token_hash).with_for_update()
    ).first()

    if refresh_session is None:
        reused = db.exec(
            select(RefreshSession).where(RefreshSession.previous_token_hash == token_hash).with_for_update()
        ).first()
        if reused is not None and reused.revoked_at is None:
            if (now - reused.last_used_at).total_seconds() <= REFRESH_REUSE_GRACE_SECONDS:
                raise AuthError("Session was just refreshed. Retry.", code="refresh_race")
            # An old token came back after rotation: assume it was stolen.
            reused.revoked_at = now
            db.add(reused)
            notify(
                db,
                reused.user_id,
                "security",
                "A session was signed out for your protection",
                "An expired sign-in token was reused, so GhostWork ended that session.",
                "/settings?tab=sessions",
            )
            db.commit()
            logger.warning("Refresh token reuse detected; session %s revoked", reused.id)
        raise AuthError("Your session has ended. Please sign in again.", code="invalid_session")

    if refresh_session.revoked_at is not None or refresh_session.expires_at <= now:
        raise AuthError("Your session has ended. Please sign in again.", code="invalid_session")

    user = db.get(User, refresh_session.user_id)
    if user is None or not user.is_active:
        raise AuthError("Your session has ended. Please sign in again.", code="invalid_session")

    new_token = generate_opaque_token()
    refresh_session.previous_token_hash = token_hash
    refresh_session.token_hash = hash_token(new_token)
    refresh_session.last_used_at = now
    if user_agent:
        refresh_session.user_agent = user_agent[:300]
    if ip:
        refresh_session.ip_address = ip
    db.add(refresh_session)
    access_token, expires = create_access_token(user.id, refresh_session.id)
    return user, IssuedTokens(access_token, expires, new_token, refresh_session)


def revoke_by_token(db: Session, refresh_token: str) -> None:
    refresh_session = db.exec(
        select(RefreshSession).where(RefreshSession.token_hash == hash_token(refresh_token))
    ).first()
    if refresh_session and refresh_session.revoked_at is None:
        refresh_session.revoked_at = utcnow()
        db.add(refresh_session)


def revoke_session(db: Session, user_id: uuid.UUID, session_id: uuid.UUID) -> bool:
    refresh_session = db.get(RefreshSession, session_id)
    if refresh_session is None or refresh_session.user_id != user_id:
        return False
    if refresh_session.revoked_at is None:
        refresh_session.revoked_at = utcnow()
        db.add(refresh_session)
    return True


def revoke_all_sessions(db: Session, user_id: uuid.UUID, except_session_id: uuid.UUID | None = None) -> int:
    statement = (
        update(RefreshSession)
        .where(RefreshSession.user_id == user_id, RefreshSession.revoked_at.is_(None))
        .values(revoked_at=utcnow())
    )
    if except_session_id is not None:
        statement = statement.where(RefreshSession.id != except_session_id)
    return db.exec(statement).rowcount


def list_active_sessions(db: Session, user_id: uuid.UUID) -> list[RefreshSession]:
    return list(
        db.exec(
            select(RefreshSession)
            .where(
                RefreshSession.user_id == user_id,
                RefreshSession.revoked_at.is_(None),
                RefreshSession.expires_at > utcnow(),
            )
            .order_by(RefreshSession.last_used_at.desc())
        )
    )


def change_password(db: Session, user: User, current: str, new: str, keep_session_id: uuid.UUID) -> None:
    if not verify_password(current, user.hashed_password):
        raise AuthError("Your current password is incorrect.", code="invalid_password")
    if current == new:
        raise AuthError("Choose a password you haven't used for this account.", code="same_password")
    user.hashed_password = hash_password(new)
    user.password_changed_at = utcnow()
    user.updated_at = utcnow()
    db.add(user)
    revoke_all_sessions(db, user.id, except_session_id=keep_session_id)
    record_activity(db, user.id, "security.password_changed", "Password changed; other sessions signed out")


def request_password_reset(db: Session, email: str) -> None:
    """Create a reset token and email it. Silent when the account does not exist."""
    user = db.exec(select(User).where(User.email == email)).first()
    if user is None or not user.is_active:
        return
    smtp = platform_smtp_config()
    if smtp is None:
        logger.info("Password reset requested but platform email is not configured.")
        return
    token = generate_opaque_token()
    now = utcnow()
    db.exec(
        update(PasswordResetToken)
        .where(PasswordResetToken.user_id == user.id, PasswordResetToken.used_at.is_(None))
        .values(used_at=now)
    )
    db.add(
        PasswordResetToken(
            user_id=user.id,
            token_hash=hash_token(token),
            created_at=now,
            expires_at=now + timedelta(minutes=settings.PASSWORD_RESET_EXPIRE_MINUTES),
        )
    )
    db.commit()
    link = f"{settings.FRONTEND_URL.rstrip('/')}/reset-password?token={token}"
    body = (
        f"Hi {user.full_name},\n\n"
        "Someone asked to reset the password for your GhostWork account.\n"
        f"Use this link within {settings.PASSWORD_RESET_EXPIRE_MINUTES} minutes:\n\n{link}\n\n"
        "If this wasn't you, you can ignore this email; your password won't change.\n"
    )
    try:
        send_email(smtp, [user.email], "Reset your GhostWork password", body)
    except MailError as exc:
        logger.error("Password reset email failed: %s", exc)


def reset_password(db: Session, token: str, new_password: str) -> None:
    now = utcnow()
    record = db.exec(
        select(PasswordResetToken).where(PasswordResetToken.token_hash == hash_token(token)).with_for_update()
    ).first()
    if record is None or record.used_at is not None or record.expires_at <= now:
        raise AuthError("This reset link is invalid or has expired. Request a new one.", code="invalid_token")
    user = db.get(User, record.user_id)
    if user is None or not user.is_active:
        raise AuthError("This reset link is invalid or has expired. Request a new one.", code="invalid_token")
    record.used_at = now
    user.hashed_password = hash_password(new_password)
    user.password_changed_at = now
    user.updated_at = now
    db.add(record)
    db.add(user)
    revoke_all_sessions(db, user.id)
    record_activity(db, user.id, "security.password_reset", "Password reset via email link; all sessions signed out")
