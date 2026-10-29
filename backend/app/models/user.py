import uuid
from datetime import datetime

from sqlalchemy import Column, ForeignKey, String, Uuid
from sqlmodel import Field, SQLModel

from app.models.base import created_at_field, optional_timestamp_field


class User(SQLModel, table=True):
    __tablename__ = "users"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    email: str = Field(sa_column=Column(String(320), unique=True, index=True, nullable=False))
    full_name: str = Field(max_length=120)
    hashed_password: str = Field(max_length=255)
    is_active: bool = Field(default=True)

    # Notification preferences
    notify_on_failure: bool = Field(default=True)
    notify_on_success: bool = Field(default=False)
    email_on_failure: bool = Field(default=False)

    # Appearance preferences
    reduce_motion: str = Field(default="system", max_length=10)  # system | reduce | full
    density: str = Field(default="comfortable", max_length=12)  # comfortable | compact

    password_changed_at: datetime | None = optional_timestamp_field()
    created_at: datetime = created_at_field()
    updated_at: datetime = created_at_field()


class RefreshSession(SQLModel, table=True):
    """A device sign-in. Each refresh rotates the token; the family is revoked on reuse."""

    __tablename__ = "refresh_sessions"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(
        sa_column=Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    )
    token_hash: str = Field(sa_column=Column(String(64), unique=True, index=True, nullable=False))
    previous_token_hash: str | None = Field(default=None, max_length=64, index=True)
    user_agent: str | None = Field(default=None, max_length=300)
    ip_address: str | None = Field(default=None, max_length=64)
    created_at: datetime = created_at_field()
    last_used_at: datetime = created_at_field()
    expires_at: datetime = created_at_field()
    revoked_at: datetime | None = optional_timestamp_field()


class PasswordResetToken(SQLModel, table=True):
    __tablename__ = "password_reset_tokens"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(
        sa_column=Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    )
    token_hash: str = Field(sa_column=Column(String(64), unique=True, index=True, nullable=False))
    created_at: datetime = created_at_field()
    expires_at: datetime = created_at_field()
    used_at: datetime | None = optional_timestamp_field()
