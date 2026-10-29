import uuid
from typing import Annotated

from fastapi import APIRouter, Cookie, Depends, HTTPException, Request, Response, status
from fastapi.responses import JSONResponse

from app.api.deps import AuthDep, CurrentUser, SessionDep, require_csrf
from app.core.config import settings
from app.core.rate_limit import RateLimit, client_ip
from app.schemas.auth import (
    ChangePasswordRequest,
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    ResetPasswordRequest,
    SessionRead,
    TokenResponse,
    UserRead,
)
from app.schemas.common import Message
from app.services import auth_service
from app.services.auth_service import AuthError, IssuedTokens

router = APIRouter(prefix="/auth", tags=["Authentication"])

COOKIE_PATH = "/api/v1/auth"
RefreshCookie = Annotated[str | None, Cookie(alias=settings.REFRESH_COOKIE_NAME)]


def _set_refresh_cookie(response: Response, token: str) -> None:
    response.set_cookie(
        key=settings.REFRESH_COOKIE_NAME,
        value=token,
        max_age=settings.REFRESH_TOKEN_EXPIRE_DAYS * 86400,
        httponly=True,
        secure=settings.COOKIE_SECURE,
        samesite=settings.COOKIE_SAMESITE,
        domain=settings.COOKIE_DOMAIN,
        path=COOKIE_PATH,
    )


def _clear_refresh_cookie(response: Response) -> None:
    response.delete_cookie(
        key=settings.REFRESH_COOKIE_NAME,
        path=COOKIE_PATH,
        domain=settings.COOKIE_DOMAIN,
        secure=settings.COOKIE_SECURE,
        httponly=True,
        samesite=settings.COOKIE_SAMESITE,
    )


def _token_response(response: Response, user, issued: IssuedTokens, client: str) -> TokenResponse:
    body = TokenResponse(
        access_token=issued.access_token,
        expires_at=issued.access_expires_at,
        user=UserRead.model_validate(user),
    )
    if client == "mobile":
        body.refresh_token = issued.refresh_token
    else:
        _set_refresh_cookie(response, issued.refresh_token)
    response.headers["Cache-Control"] = "no-store"
    return body


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(RateLimit("register", 5, 3600))],
)
def register(payload: RegisterRequest, request: Request, response: Response, db: SessionDep):
    try:
        user = auth_service.register_user(db, payload.email, payload.full_name, payload.password)
    except AuthError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, exc.message)
    issued = auth_service.start_session(db, user, request.headers.get("user-agent"), client_ip(request))
    db.commit()
    db.refresh(user)
    return _token_response(response, user, issued, payload.client)


@router.post("/login", response_model=TokenResponse, dependencies=[Depends(RateLimit("login", 10, 300))])
def login(payload: LoginRequest, request: Request, response: Response, db: SessionDep):
    try:
        user = auth_service.authenticate(db, payload.email, payload.password)
    except AuthError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, exc.message)
    issued = auth_service.start_session(db, user, request.headers.get("user-agent"), client_ip(request))
    db.commit()
    db.refresh(user)
    return _token_response(response, user, issued, payload.client)


@router.post(
    "/refresh",
    response_model=TokenResponse,
    dependencies=[Depends(RateLimit("refresh", 60, 60))],
    responses={
        204: {"description": "No refresh cookie: the browser is not signed in."},
        409: {"description": "Concurrent refresh; retry once."},
    },
)
def refresh(
    request: Request,
    response: Response,
    db: SessionDep,
    refresh_cookie: RefreshCookie = None,
    payload: RefreshRequest | None = None,
):
    body_token = payload.refresh_token if payload else None
    if body_token:
        token, client = body_token, "mobile"
    else:
        # Cookie-authenticated: guard against cross-site requests.
        require_csrf(request, request.headers.get("X-GhostWork-CSRF"))
        token, client = refresh_cookie, "web"
    if not token:
        # No session at all is a normal state for a browser, not an error.
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    try:
        user, issued = auth_service.rotate_session(
            db, token, request.headers.get("user-agent"), client_ip(request)
        )
    except AuthError as exc:
        if exc.code == "refresh_race":
            raise HTTPException(status.HTTP_409_CONFLICT, exc.message)
        failure = JSONResponse({"detail": exc.message}, status_code=status.HTTP_401_UNAUTHORIZED)
        if client == "web":
            _clear_refresh_cookie(failure)
        return failure
    db.commit()
    return _token_response(response, user, issued, client)


@router.post("/logout", response_model=Message)
def logout(
    request: Request,
    response: Response,
    db: SessionDep,
    refresh_cookie: RefreshCookie = None,
    payload: RefreshRequest | None = None,
):
    token = payload.refresh_token if payload and payload.refresh_token else None
    if token is None:
        require_csrf(request, request.headers.get("X-GhostWork-CSRF"))
        token = refresh_cookie
    if token:
        auth_service.revoke_by_token(db, token)
        db.commit()
    _clear_refresh_cookie(response)
    return Message(message="Signed out.")


@router.get("/me", response_model=UserRead)
def me(user: CurrentUser):
    return user


@router.post(
    "/forgot-password",
    response_model=ForgotPasswordResponse,
    status_code=status.HTTP_202_ACCEPTED,
    dependencies=[Depends(RateLimit("forgot", 5, 900))],
)
def forgot_password(payload: ForgotPasswordRequest, db: SessionDep):
    auth_service.request_password_reset(db, payload.email)
    db.commit()
    configured = settings.platform_email_enabled
    message = (
        "If an account exists for that email, we've sent a link to reset the password."
        if configured
        else "Password recovery email is not configured on this GhostWork server. Contact your administrator."
    )
    return ForgotPasswordResponse(message=message, email_delivery_configured=configured)


@router.post("/reset-password", response_model=Message, dependencies=[Depends(RateLimit("reset", 10, 900))])
def reset_password(payload: ResetPasswordRequest, db: SessionDep):
    try:
        auth_service.reset_password(db, payload.token, payload.password)
    except AuthError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, exc.message)
    db.commit()
    return Message(message="Your password has been reset. Sign in with your new password.")


@router.post("/change-password", response_model=Message, dependencies=[Depends(RateLimit("change_pw", 10, 900))])
def change_password(payload: ChangePasswordRequest, context: AuthDep, db: SessionDep):
    try:
        auth_service.change_password(
            db, context.user, payload.current_password, payload.new_password, context.session_id
        )
    except AuthError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, exc.message)
    db.commit()
    return Message(message="Password updated. Your other sessions have been signed out.")


@router.get("/sessions", response_model=list[SessionRead])
def list_sessions(context: AuthDep, db: SessionDep):
    return [
        SessionRead(
            id=s.id,
            user_agent=s.user_agent,
            ip_address=s.ip_address,
            created_at=s.created_at,
            last_used_at=s.last_used_at,
            expires_at=s.expires_at,
            current=s.id == context.session_id,
        )
        for s in auth_service.list_active_sessions(db, context.user.id)
    ]


@router.delete("/sessions/{session_id}", response_model=Message)
def revoke_session(session_id: uuid.UUID, context: AuthDep, db: SessionDep):
    if not auth_service.revoke_session(db, context.user.id, session_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Session not found.")
    db.commit()
    return Message(message="Session signed out.")


@router.post("/sessions/revoke-others", response_model=Message)
def revoke_other_sessions(context: AuthDep, db: SessionDep):
    count = auth_service.revoke_all_sessions(db, context.user.id, except_session_id=context.session_id)
    db.commit()
    return Message(message=f"Signed out of {count} other session{'s' if count != 1 else ''}.")
