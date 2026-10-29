import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class IntegrationCreate(BaseModel):
    provider: str = Field(max_length=32)
    name: str = Field(min_length=1, max_length=80)
    config: dict


class IntegrationRead(BaseModel):
    id: uuid.UUID
    provider: str
    name: str
    status: str
    last_error: str | None
    last_verified_at: datetime | None
    created_at: datetime
    details: dict


class ProviderRead(BaseModel):
    key: str
    label: str
    available: bool
    description: str
    verifiable: bool


class NotificationRead(BaseModel):
    id: uuid.UUID
    kind: str
    title: str
    body: str
    link: str | None
    read_at: datetime | None
    created_at: datetime


class NotificationList(BaseModel):
    items: list[NotificationRead]
    unread: int


class ActivityRead(BaseModel):
    id: uuid.UUID
    kind: str
    message: str
    workflow_id: uuid.UUID | None
    created_at: datetime
