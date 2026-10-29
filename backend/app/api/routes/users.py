import logging

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlmodel import select

from app.api.deps import CurrentUser, SessionDep
from app.api.routes.auth import _clear_refresh_cookie
from app.core.rate_limit import RateLimit
from app.core.security import verify_password
from app.models import User
from app.models.base import utcnow
from app.schemas.auth import ChangeEmailRequest, DeleteAccountRequest, UserRead, UserUpdate
from app.services.activity import record_activity
from app.services.mailer import MailError, platform_smtp_config, send_email

router = APIRouter(prefix="/users", tags=["Users"])
logger = logging.getLogger(__name__)


@router.patch("/me", response_model=UserRead)
def update_me(payload: UserUpdate, user: CurrentUser, db: SessionDep):
    changes = payload.model_dump(exclude_unset=True, exclude_none=True)
    for key, value in changes.items():
        setattr(user, key, value)
    if changes:
        user.updated_at = utcnow()
        db.add(user)
        if "full_name" in changes:
            record_activity(db, user.id, "account.profile_updated", "Profile updated")
        db.commit()
        db.refresh(user)
    return user


@router.post("/me/email", response_model=UserRead, dependencies=[Depends(RateLimit("change_email", 5, 900))])
def change_email(payload: ChangeEmailRequest, user: CurrentUser, db: SessionDep):
    if not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Your password is incorrect.")
    if payload.new_email == user.email:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "That's already your email address.")
    if db.exec(select(User).where(User.email == payload.new_email)).first() is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "An account with this email already exists.")
    old_email = user.email
    user.email = payload.new_email
    user.updated_at = utcnow()
    db.add(user)
    record_activity(db, user.id, "account.email_changed", f"Email changed from {old_email} to {payload.new_email}")
    db.commit()
    db.refresh(user)
    smtp = platform_smtp_config()
    if smtp is not None:
        try:
            send_email(
                smtp,
                [old_email],
                "Your GhostWork email address was changed",
                f"The email for your GhostWork account was changed to {payload.new_email}.\n\n"
                "If you didn't do this, reset your password and contact your administrator.\n",
            )
        except MailError as exc:
            logger.warning("Email-change notice not sent: %s", exc)
    return user


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT, dependencies=[Depends(RateLimit("delete_account", 5, 900))])
def delete_me(payload: DeleteAccountRequest, user: CurrentUser, db: SessionDep):
    """Permanently delete the account and everything it owns (cascades)."""
    if not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Your password is incorrect.")
    db.delete(user)
    db.commit()
    result = Response(status_code=status.HTTP_204_NO_CONTENT)
    _clear_refresh_cookie(result)
    return result
