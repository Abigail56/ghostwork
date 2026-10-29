import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class WorkflowCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    description: str = Field(default="", max_length=1000)
    definition: dict | None = None

    @field_validator("name")
    @classmethod
    def _strip(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Name is required.")
        return value


class WorkflowUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=1000)
    definition: dict | None = None
    # Optimistic concurrency: reject the save if someone else saved in between.
    expected_version: int | None = None

    @field_validator("name")
    @classmethod
    def _strip(cls, value: str | None) -> str | None:
        if value is None:
            return value
        value = value.strip()
        if not value:
            raise ValueError("Name is required.")
        return value


class LastExecution(BaseModel):
    id: uuid.UUID
    status: str
    created_at: datetime
    finished_at: datetime | None


class WorkflowSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    description: str
    status: Literal["draft", "active", "paused"]
    trigger_type: str | None
    step_count: int
    last_run_at: datetime | None
    next_run_at: datetime | None
    created_at: datetime
    updated_at: datetime
    last_execution: LastExecution | None = None


class ValidationIssue(BaseModel):
    message: str
    node_id: str | None = None
    field: str | None = None


class WorkflowRead(WorkflowSummary):
    definition: dict
    version: int
    webhook_url: str | None = None
    webhook_signing_enabled: bool = False
    validation: list[ValidationIssue] = []


class WebhookSecretResponse(BaseModel):
    secret: str
    header: str = "X-GhostWork-Signature"
    algorithm: str = "HMAC-SHA256 of the raw body, hex, prefixed with sha256="


class StatusChange(BaseModel):
    status: Literal["active", "paused", "draft"]


class ValidationResponse(BaseModel):
    valid: bool
    issues: list[ValidationIssue]


class RunRequest(BaseModel):
    payload: dict = Field(default_factory=dict, description="Optional test data available as trigger.payload.")


class StepRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    node_id: str
    node_type: str
    node_name: str
    position: int
    status: str
    attempts: int
    output: dict | None
    error_message: str | None
    started_at: datetime | None
    finished_at: datetime | None
    duration_ms: int | None


class ExecutionSummary(BaseModel):
    id: uuid.UUID
    workflow_id: uuid.UUID
    workflow_name: str
    status: str
    trigger_type: str
    error_message: str | None
    created_at: datetime
    started_at: datetime | None
    finished_at: datetime | None
    duration_ms: int | None


class ExecutionRead(ExecutionSummary):
    trigger_payload: dict
    definition_snapshot: dict
    workflow_version: int
    steps: list[StepRead]


class NodeTypeRead(BaseModel):
    type: str
    kind: str
    label: str
    description: str
    integration_provider: str | None
    outputs: list[str]
    default_config: dict


class TemplateRead(BaseModel):
    slug: str
    name: str
    description: str
    category: str
    requires: list[str]
    definition: dict


class TemplateUse(BaseModel):
    name: str | None = Field(default=None, max_length=120)
