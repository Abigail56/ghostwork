import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import Column, ForeignKey, Index, String, Uuid
from sqlalchemy.dialects.postgresql import JSONB
from sqlmodel import Field, SQLModel

from app.models.base import created_at_field, optional_timestamp_field


class WorkflowStatus(StrEnum):
    DRAFT = "draft"
    ACTIVE = "active"
    PAUSED = "paused"


class Workflow(SQLModel, table=True):
    __tablename__ = "workflows"
    __table_args__ = (
        Index("ix_workflows_owner_updated", "owner_id", "updated_at"),
        Index("ix_workflows_schedule_due", "status", "next_run_at"),
    )

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    owner_id: uuid.UUID = Field(
        sa_column=Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    )
    name: str = Field(max_length=120)
    description: str = Field(default="", max_length=1000)
    status: str = Field(default=WorkflowStatus.DRAFT, max_length=16, index=True)
    # {"nodes": [...], "edges": [...]} - validated by app.services.workflow_definition
    definition: dict = Field(default_factory=lambda: {"nodes": [], "edges": []}, sa_column=Column(JSONB, nullable=False))
    trigger_type: str | None = Field(default=None, max_length=32)
    # Secret path segment for webhook triggers.
    webhook_token: str | None = Field(
        default=None, sa_column=Column(String(64), unique=True, index=True, nullable=True)
    )
    next_run_at: datetime | None = optional_timestamp_field()
    last_run_at: datetime | None = optional_timestamp_field()
    version: int = Field(default=1)
    created_at: datetime = created_at_field()
    updated_at: datetime = created_at_field()
