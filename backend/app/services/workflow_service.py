"""Workflow lifecycle: ownership-scoped lookups, saving, activation and queuing runs."""

import logging
import secrets
import uuid
from datetime import timedelta

from fastapi import HTTPException, status
from sqlalchemy import func
from sqlmodel import Session, select

from app.core.config import settings
from app.models import (
    ACTIVE_EXECUTION_STATUSES,
    ExecutionStatus,
    Workflow,
    WorkflowExecution,
    WorkflowStatus,
)
from app.models.base import utcnow
from app.services import execution_engine
from app.services.activity import record_activity
from app.services.integrations import owner_integrations
from app.services.workflow_definition import (
    DefinitionError,
    ScheduleTriggerConfig,
    ValidationResult,
    config_of,
    parse_definition,
    validate_definition,
)

logger = logging.getLogger(__name__)


def get_owned_workflow(db: Session, owner_id: uuid.UUID, workflow_id: uuid.UUID, lock: bool = False) -> Workflow:
    statement = select(Workflow).where(Workflow.id == workflow_id, Workflow.owner_id == owner_id)
    if lock:
        statement = statement.with_for_update()
    workflow = db.exec(statement).first()
    if workflow is None:
        # 404 (not 403) so other users' workflow IDs can't be probed.
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Workflow not found.")
    return workflow


def definition_issues_http(exc: DefinitionError) -> HTTPException:
    return HTTPException(
        status.HTTP_422_UNPROCESSABLE_CONTENT,
        {"message": "The workflow definition is invalid.", "issues": [i.as_dict() for i in exc.issues]},
    )


def validate_for_owner(db: Session, workflow: Workflow) -> ValidationResult:
    return validate_definition(workflow.definition, owner_integrations(db, workflow.owner_id))


def apply_definition(db: Session, workflow: Workflow, raw: dict) -> None:
    """Store a structurally valid definition. Active workflows must stay fully valid."""
    try:
        definition = parse_definition(raw)
    except DefinitionError as exc:
        raise definition_issues_http(exc)
    stored = definition.model_dump(mode="json")
    trigger = next((n for n in definition.nodes if n.type.startswith("trigger.")), None)
    if workflow.status == WorkflowStatus.ACTIVE:
        result = validate_definition(stored, owner_integrations(db, workflow.owner_id))
        if not result.valid:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT,
                {
                    "message": "Active workflows must stay valid. Pause it to save unfinished changes.",
                    "issues": [i.as_dict() for i in result.issues],
                },
            )
    previous_trigger = workflow.trigger_type
    workflow.definition = stored
    workflow.trigger_type = trigger.type if trigger else None
    workflow.version += 1
    workflow.updated_at = utcnow()
    if workflow.trigger_type == "trigger.webhook" and not workflow.webhook_token:
        workflow.webhook_token = secrets.token_urlsafe(24)
    if workflow.status == WorkflowStatus.ACTIVE:
        if workflow.trigger_type == "trigger.schedule":
            if previous_trigger != "trigger.schedule" or workflow.next_run_at is None:
                workflow.next_run_at = next_run_from_now(trigger)
            else:
                workflow.next_run_at = min(workflow.next_run_at, next_run_from_now(trigger))
        else:
            workflow.next_run_at = None


def next_run_from_now(trigger_node) -> object:
    config = config_of(trigger_node)
    assert isinstance(config, ScheduleTriggerConfig)
    return utcnow() + timedelta(minutes=config.interval_minutes)


def set_status(db: Session, workflow: Workflow, new_status: WorkflowStatus) -> None:
    if new_status == WorkflowStatus.ACTIVE:
        result = validate_for_owner(db, workflow)
        if not result.valid:
            raise HTTPException(
                status.HTTP_422_UNPROCESSABLE_CONTENT,
                {"message": "Fix the workflow before activating it.", "issues": [i.as_dict() for i in result.issues]},
            )
        workflow.next_run_at = (
            next_run_from_now(result.trigger) if workflow.trigger_type == "trigger.schedule" else None
        )
        if workflow.trigger_type == "trigger.webhook" and not workflow.webhook_token:
            workflow.webhook_token = secrets.token_urlsafe(24)
    else:
        workflow.next_run_at = None
    workflow.status = new_status
    workflow.updated_at = utcnow()
    db.add(workflow)
    verb = {"active": "activated", "paused": "paused", "draft": "moved to draft"}[new_status]
    record_activity(db, workflow.owner_id, f"workflow.{verb.split()[0]}", f"{workflow.name} {verb}", workflow.id)


def active_execution_count(db: Session, owner_id: uuid.UUID) -> int:
    return db.exec(
        select(func.count())
        .select_from(WorkflowExecution)
        .where(WorkflowExecution.owner_id == owner_id, WorkflowExecution.status.in_(ACTIVE_EXECUTION_STATUSES))
    ).one()


def queue_execution(db: Session, workflow: Workflow, trigger_type: str, payload: dict) -> WorkflowExecution:
    """Validate, record and enqueue a run. Commits."""
    result = validate_for_owner(db, workflow)
    if not result.valid:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            {"message": "Fix the workflow before running it.", "issues": [i.as_dict() for i in result.issues]},
        )
    if active_execution_count(db, workflow.owner_id) >= settings.MAX_CONCURRENT_EXECUTIONS_PER_USER:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            f"You already have {settings.MAX_CONCURRENT_EXECUTIONS_PER_USER} runs in progress. "
            "Wait for one to finish and try again.",
        )
    execution = WorkflowExecution(
        workflow_id=workflow.id,
        owner_id=workflow.owner_id,
        trigger_type=trigger_type,
        trigger_payload=payload,
        definition_snapshot=workflow.definition,
        workflow_version=workflow.version,
    )
    db.add(execution)
    db.flush()
    execution_engine.create_steps(db, execution)
    db.commit()
    dispatch(db, execution)
    return execution


def dispatch(db: Session, execution: WorkflowExecution) -> None:
    from app.workers.tasks import run_workflow_execution

    try:
        run_workflow_execution.delay(str(execution.id))
    except Exception:
        logger.exception("Could not queue execution %s", execution.id)
        db.refresh(execution)
        if execution.status == ExecutionStatus.QUEUED:
            execution.status = ExecutionStatus.FAILED
            execution.error_message = "The run could not be queued because the task queue is unavailable."
            execution.finished_at = utcnow()
            db.add(execution)
            db.commit()
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "The task queue is unavailable, so the run couldn't start. Try again shortly.",
        )
