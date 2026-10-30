import uuid
from datetime import datetime

from sqlalchemy import Column, ForeignKey, Text, Uuid
from sqlalchemy.dialects.postgresql import JSONB
from sqlmodel import Field, SQLModel

from app.models.base import created_at_field, optional_timestamp_field


class Integration(SQLModel, table=True):
    """A connected service. Secrets live only in `encrypted_secrets` (Fernet)."""

    __tablename__ = "integrations"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    owner_id: uuid.UUID = Field(
        sa_column=Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    )
    provider: str = Field(max_length=32, index=True)
    name: str = Field(max_length=80)
    # Non-secret settings that are safe to return to the owner (host, port, sender...).
    public_config: dict = Field(default_factory=dict, sa_column=Column(JSONB, nullable=False))
    encrypted_secrets: str = Field(sa_column=Column(Text, nullable=False))
    status: str = Field(default="connected", max_length=16)  # connected | error
    last_error: str | None = Field(default=None, max_length=500)
    last_verified_at: datetime | None = optional_timestamp_field()
    created_at: datetime = created_at_field()
    updated_at: datetime = created_at_field()


class Notification(SQLModel, table=True):
    __tablename__ = "notifications"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(
        sa_column=Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    )
    kind: str = Field(max_length=32)  # execution_failed | execution_succeeded | security
    title: str = Field(max_length=160)
    body: str = Field(default="", max_length=500)
    link: str | None = Field(default=None, max_length=200)
    read_at: datetime | None = optional_timestamp_field()
    created_at: datetime = created_at_field(index=True)


class PushSubscription(SQLModel, table=True):
    """A device that receives push notifications: a Web Push endpoint or an FCM token."""

    __tablename__ = "push_subscriptions"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(
        sa_column=Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    )
    kind: str = Field(max_length=16)  # webpush | fcm
    endpoint: str = Field(sa_column=Column(Text, unique=True, nullable=False))
    keys: dict = Field(default_factory=dict, sa_column=Column(JSONB, nullable=False))
    created_at: datetime = created_at_field()


class ActivityEvent(SQLModel, table=True):
    """Audit trail of things a user did (shown as recent activity)."""

    __tablename__ = "activity_events"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    user_id: uuid.UUID = Field(
        sa_column=Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    )
    workflow_id: uuid.UUID | None = Field(
        default=None, sa_column=Column(Uuid, ForeignKey("workflows.id", ondelete="SET NULL"), nullable=True)
    )
    kind: str = Field(max_length=40)
    message: str = Field(max_length=300)
    details: dict = Field(default_factory=dict, sa_column=Column(JSONB, nullable=False))
    created_at: datetime = created_at_field(index=True)
