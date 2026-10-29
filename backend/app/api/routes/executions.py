import uuid
from datetime import datetime
from typing import Literal

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import String, cast, func, or_
from sqlmodel import Session, select

from app.api.deps import CurrentUser, SessionDep
from app.models import ExecutionStatus, ExecutionStep, Workflow, WorkflowExecution
from app.models.base import utcnow
from app.schemas.common import Page
from app.schemas.workflow import ExecutionRead, ExecutionSummary, StepRead
from app.services import workflow_service

router = APIRouter(prefix="/executions", tags=["Executions"])


def escape_like(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def to_summary(execution: WorkflowExecution, workflow_name: str) -> ExecutionSummary:
    return ExecutionSummary(
        id=execution.id,
        workflow_id=execution.workflow_id,
        workflow_name=workflow_name,
        status=execution.status,
        trigger_type=execution.trigger_type,
        error_message=execution.error_message,
        created_at=execution.created_at,
        started_at=execution.started_at,
        finished_at=execution.finished_at,
        duration_ms=execution.duration_ms,
    )


def _get_owned(db: Session, owner_id: uuid.UUID, execution_id: uuid.UUID) -> tuple[WorkflowExecution, Workflow]:
    row = db.exec(
        select(WorkflowExecution, Workflow)
        .join(Workflow, Workflow.id == WorkflowExecution.workflow_id)
        .where(WorkflowExecution.id == execution_id, WorkflowExecution.owner_id == owner_id)
    ).first()
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Execution not found.")
    return row


@router.get("", response_model=Page[ExecutionSummary])
def list_executions(
    user: CurrentUser,
    db: SessionDep,
    q: str | None = Query(default=None, max_length=120, description="Workflow name or execution ID prefix"),
    status_filter: Literal["queued", "running", "succeeded", "failed", "cancelled"] | None = Query(
        default=None, alias="status"
    ),
    workflow_id: uuid.UUID | None = None,
    started_after: datetime | None = Query(default=None, alias="from"),
    started_before: datetime | None = Query(default=None, alias="to"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
):
    filters = [WorkflowExecution.owner_id == user.id]
    if q and q.strip():
        term = escape_like(q.strip().lower())
        filters.append(
            or_(
                Workflow.name.ilike(f"%{term}%", escape="\\"),
                cast(WorkflowExecution.id, String).like(f"{term}%", escape="\\"),
            )
        )
    if status_filter:
        filters.append(WorkflowExecution.status == status_filter)
    if workflow_id:
        filters.append(WorkflowExecution.workflow_id == workflow_id)
    if started_after:
        filters.append(WorkflowExecution.created_at >= started_after)
    if started_before:
        filters.append(WorkflowExecution.created_at < started_before)

    base = select(WorkflowExecution, Workflow.name).join(Workflow, Workflow.id == WorkflowExecution.workflow_id)
    total = db.exec(
        select(func.count())
        .select_from(WorkflowExecution)
        .join(Workflow, Workflow.id == WorkflowExecution.workflow_id)
        .where(*filters)
    ).one()
    rows = db.exec(
        base.where(*filters)
        .order_by(WorkflowExecution.created_at.desc(), WorkflowExecution.id)
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    return Page(items=[to_summary(e, name) for e, name in rows], total=total, page=page, page_size=page_size)


@router.get("/{execution_id}", response_model=ExecutionRead)
def get_execution(execution_id: uuid.UUID, user: CurrentUser, db: SessionDep):
    execution, workflow = _get_owned(db, user.id, execution_id)
    steps = db.exec(
        select(ExecutionStep).where(ExecutionStep.execution_id == execution.id).order_by(ExecutionStep.position)
    ).all()
    return ExecutionRead(
        **to_summary(execution, workflow.name).model_dump(),
        trigger_payload=execution.trigger_payload,
        definition_snapshot=execution.definition_snapshot,
        workflow_version=execution.workflow_version,
        steps=[StepRead.model_validate(s) for s in steps],
    )


@router.post("/{execution_id}/cancel", response_model=ExecutionSummary)
def cancel_execution(execution_id: uuid.UUID, user: CurrentUser, db: SessionDep):
    execution, workflow = _get_owned(db, user.id, execution_id)
    execution = db.exec(select(WorkflowExecution).where(WorkflowExecution.id == execution.id).with_for_update()).one()
    if execution.status not in (ExecutionStatus.QUEUED, ExecutionStatus.RUNNING):
        raise HTTPException(status.HTTP_409_CONFLICT, "Only queued or running executions can be cancelled.")
    was_queued = execution.status == ExecutionStatus.QUEUED
    execution.status = ExecutionStatus.CANCELLED
    execution.error_message = "Cancelled by user."
    if was_queued:
        # The worker will see the status and skip it; close it out now.
        now = utcnow()
        execution.finished_at = now
        for step in db.exec(select(ExecutionStep).where(ExecutionStep.execution_id == execution.id)):
            step.status = "skipped"
            db.add(step)
    # A running execution stops before its next step; the worker records the finish time.
    db.add(execution)
    db.commit()
    db.refresh(execution)
    return to_summary(execution, workflow.name)


@router.post("/{execution_id}/rerun", response_model=ExecutionSummary, status_code=status.HTTP_202_ACCEPTED)
def rerun_execution(execution_id: uuid.UUID, user: CurrentUser, db: SessionDep):
    """Run the workflow again (current version) with the same trigger data."""
    execution, workflow = _get_owned(db, user.id, execution_id)
    new = workflow_service.queue_execution(db, workflow, "manual", execution.trigger_payload)
    db.refresh(new)
    return to_summary(new, workflow.name)
