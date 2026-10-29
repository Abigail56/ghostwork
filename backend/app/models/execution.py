import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import Column, ForeignKey, Index, Text, Uuid
from sqlalchemy.dialects.postgresql import JSONB
from sqlmodel import Field, SQLModel

from app.models.base import created_at_field, optional_timestamp_field


class ExecutionStatus(StrEnum):
    QUEUED = "queued"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    FAILED = "failed"
    CANCELLED = "cancelled"


ACTIVE_EXECUTION_STATUSES = (ExecutionStatus.QUEUED, ExecutionStatus.RUNNING)
FINISHED_EXECUTION_STATUSES = (ExecutionStatus.SUCCEEDED, ExecutionStatus.FAILED, ExecutionStatus.CANCELLED)


class StepStatus(StrEnum):
    PENDING = "pending"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    FAILED = "failed"
    SKIPPED = "skipped"


class WorkflowExecution(SQLModel, table=True):
    __tablename__ = "workflow_executions"
    __table_args__ = (
        Index("ix_executions_owner_created", "owner_id", "created_at"),
        Index("ix_executions_workflow_created", "workflow_id", "created_at"),
    )

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    workflow_id: uuid.UUID = Field(
        sa_column=Column(Uuid, ForeignKey("workflows.id", ondelete="CASCADE"), nullable=False)
    )
    owner_id: uuid.UUID = Field(
        sa_column=Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    )
    status: str = Field(default=ExecutionStatus.QUEUED, max_length=16, index=True)
    trigger_type: str = Field(max_length=32)
    trigger_payload: dict = Field(default_factory=dict, sa_column=Column(JSONB, nullable=False))
    # The definition as it was when the run was queued; later edits don't change history.
    definition_snapshot: dict = Field(default_factory=dict, sa_column=Column(JSONB, nullable=False))
    workflow_version: int = Field(default=1)
    error_message: str | None = Field(default=None, sa_column=Column(Text, nullable=True))
    created_at: datetime = created_at_field()
    started_at: datetime | None = optional_timestamp_field()
    finished_at: datetime | None = optional_timestamp_field()
    duration_ms: int | None = Field(default=None)


class ExecutionStep(SQLModel, table=True):
    __tablename__ = "execution_steps"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    execution_id: uuid.UUID = Field(
        sa_column=Column(Uuid, ForeignKey("workflow_executions.id", ondelete="CASCADE"), index=True, nullable=False)
    )
    node_id: str = Field(max_length=64)
    node_type: str = Field(max_length=48)
    node_name: str = Field(max_length=120)
    position: int = Field(default=0)
    status: str = Field(default=StepStatus.PENDING, max_length=16)
    attempts: int = Field(default=0)
    output: dict | None = Field(default=None, sa_column=Column(JSONB, nullable=True))
    error_message: str | None = Field(default=None, sa_column=Column(Text, nullable=True))
    started_at: datetime | None = optional_timestamp_field()
    finished_at: datetime | None = optional_timestamp_field()
    duration_ms: int | None = Field(default=None)
