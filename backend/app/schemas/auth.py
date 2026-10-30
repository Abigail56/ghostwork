import re
import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


def validate_password_strength(value: str) -> str:
    if len(value) < 10:
        raise ValueError("Password must be at least 10 characters.")
    if len(value) > 128:
        raise ValueError("Password must be at most 128 characters.")
    if not re.search(r"[A-Za-z]", value) or not re.search(r"\d", value):
        raise ValueError("Password must contain at least one letter and one number.")
    if len(set(value)) < 5:
        raise ValueError("Password is too repetitive.")
    return value


def _normalize_email(value: str) -> str:
    return value.strip().lower()


class RegisterRequest(BaseModel):
    email: EmailStr
    full_name: str = Field(min_length=1, max_length=120)
    password: str
    accept_terms: bool = Field(description="Must be true: the user accepts the current Terms of Service.")
    client: Literal["web", "mobile"] = "web"

    @field_validator("accept_terms")
    @classmethod
    def _terms(cls, value: bool) -> bool:
        if value is not True:
            raise ValueError("You must accept the Terms of Service to create an account.")
        return value

    @field_validator("email")
    @classmethod
    def _email(cls, value: str) -> str:
        return _normalize_email(value)

    @field_validator("full_name")
    @classmethod
    def _strip_name(cls, value: str) -> str:
        value = " ".join(value.split())
        if not value:
            raise ValueError("Name is required.")
        return value

    @field_validator("password")
    @classmethod
    def _password(cls, value: str) -> str:
        return validate_password_strength(value)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)
    client: Literal["web", "mobile"] = "web"

    @field_validator("email")
    @classmethod
    def _email(cls, value: str) -> str:
        return _normalize_email(value)


class RefreshRequest(BaseModel):
    # Only mobile clients send the token in the body; browsers use the HttpOnly cookie.
    refresh_token: str | None = None


class ForgotPasswordRequest(BaseModel):
    email: EmailStr

    @field_validator("email")
    @classmethod
    def _email(cls, value: str) -> str:
        return _normalize_email(value)


class ForgotPasswordResponse(BaseModel):
    message: str
    email_delivery_configured: bool


class ResetPasswordRequest(BaseModel):
    token: str = Field(min_length=20, max_length=200)
    password: str

    @field_validator("password")
    @classmethod
    def _password(cls, value: str) -> str:
        return validate_password_strength(value)


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str

    @field_validator("new_password")
    @classmethod
    def _password(cls, value: str) -> str:
        return validate_password_strength(value)


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    full_name: str
    notify_on_failure: bool
    notify_on_success: bool
    email_on_failure: bool
    push_on_failure: bool
    reduce_motion: Literal["system", "reduce", "full"]
    density: Literal["comfortable", "compact"]
    created_at: datetime
    password_changed_at: datetime | None
    terms_version: str | None = None
    terms_accepted_at: datetime | None = None


class UserUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=120)
    notify_on_failure: bool | None = None
    notify_on_success: bool | None = None
    email_on_failure: bool | None = None
    push_on_failure: bool | None = None
    reduce_motion: Literal["system", "reduce", "full"] | None = None
    density: Literal["comfortable", "compact"] | None = None

    @field_validator("full_name")
    @classmethod
    def _strip_name(cls, value: str | None) -> str | None:
        if value is None:
            return value
        value = " ".join(value.split())
        if not value:
            raise ValueError("Name is required.")
        return value


class TokenResponse(BaseModel):
    access_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_at: datetime
    user: UserRead
    refresh_token: str | None = Field(
        default=None, description="Returned only to mobile clients (client='mobile')."
    )


class SessionRead(BaseModel):
    id: uuid.UUID
    user_agent: str | None
    ip_address: str | None
    created_at: datetime
    last_used_at: datetime
    expires_at: datetime
    current: bool


class ChangeEmailRequest(BaseModel):
    new_email: EmailStr
    password: str = Field(min_length=1, max_length=128)

    @field_validator("new_email")
    @classmethod
    def _email(cls, value: str) -> str:
        return _normalize_email(value)


class DeleteAccountRequest(BaseModel):
    password: str = Field(min_length=1, max_length=128)
