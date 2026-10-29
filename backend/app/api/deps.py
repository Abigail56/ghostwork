import uuid
from dataclasses import dataclass
from typing import Annotated
from urllib.parse import urlsplit

from fastapi import Depends, Header, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlmodel import Session

from app.core.config import settings
from app.core.security import decode_access_token
from app.db.session import get_session
from app.models import RefreshSession, User
from app.models.base import utcnow

SessionDep = Annotated[Session, Depends(get_session)]

_bearer = HTTPBearer(auto_error=False)

CSRF_HEADER = "X-GhostWork-CSRF"


@dataclass
class AuthContext:
    user: User
    session_id: uuid.UUID


def _unauthorized(detail: str = "Not authenticated.") -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_auth_context(
    db: SessionDep,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> AuthContext:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _unauthorized()
    payload = decode_access_token(credentials.credentials)
    if payload is None:
        raise _unauthorized("Your session has expired. Please sign in again.")
    try:
        user_id = uuid.UUID(payload["sub"])
        session_id = uuid.UUID(payload["sid"])
    except ValueError:
        raise _unauthorized()
    # Checking the session makes revocation take effect immediately, not at token expiry.
    refresh_session = db.get(RefreshSession, session_id)
    if (
        refresh_session is None
        or refresh_session.user_id != user_id
        or refresh_session.revoked_at is not None
        or refresh_session.expires_at <= utcnow()
    ):
        raise _unauthorized("Your session has ended. Please sign in again.")
    user = db.get(User, user_id)
    if user is None or not user.is_active:
        raise _unauthorized()
    return AuthContext(user=user, session_id=session_id)


AuthDep = Annotated[AuthContext, Depends(get_auth_context)]


def get_current_user(context: AuthDep) -> User:
    return context.user


CurrentUser = Annotated[User, Depends(get_current_user)]


def require_csrf(
    request: Request,
    csrf: Annotated[str | None, Header(alias=CSRF_HEADER)] = None,
) -> None:
    """CSRF guard for endpoints authenticated by the refresh cookie.

    A custom header cannot be sent cross-origin without a CORS preflight, which only
    our configured origins pass. We also reject requests whose Origin is not allowed.
    """
    if csrf != "1":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Missing CSRF header.")
    origin = request.headers.get("origin")
    if origin is not None:
        allowed = {o.rstrip("/") for o in settings.CORS_ORIGINS}
        parts = urlsplit(origin)
        if f"{parts.scheme}://{parts.netloc}" not in allowed:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Origin not allowed.")
