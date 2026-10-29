import logging
import uuid
from datetime import timedelta

from celery.exceptions import SoftTimeLimitExceeded
from sqlalchemy import delete
from sqlmodel import Session, select

from app.core.config import settings
from app.db.session import engine
from app.models import FINISHED_EXECUTION_STATUSES, ExecutionStatus, ExecutionStep, Workflow, WorkflowExecution, WorkflowStatus
from app.models.base import utcnow
from app.services import execution_engine
from app.workers.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(name="ghostwork.run_execution")
def run_workflow_execution(execution_id: str) -> str | None:
    with Session(engine) as db:
        try:
            return execution_engine.run_execution(db, uuid.UUID(execution_id))
        except SoftTimeLimitExceeded:
            db.rollback()
            execution = db.get(WorkflowExecution, uuid.UUID(execution_id))
            if execution is None:
                return None
            steps = list(db.exec(select(ExecutionStep).where(ExecutionStep.execution_id == execution.id)))
            execution_engine.finish_execution(
                db,
                execution,
                steps,
                f"The run exceeded the {settings.EXECUTION_SOFT_TIME_LIMIT_SECONDS}-second time limit.",
            )
            return execution.status


@celery_app.task(name="ghostwork.dispatch_due_schedules")
def dispatch_due_schedules() -> int:
    """Queue runs for active scheduled workflows whose next run time has passed."""
    from fastapi import HTTPException

    from app.services import workflow_service
    from app.services.workflow_definition import parse_definition

    dispatched = 0
    with Session(engine) as db:
        due = db.exec(
            select(Workflow)
            .where(
                Workflow.status == WorkflowStatus.ACTIVE,
                Workflow.trigger_type == "trigger.schedule",
                Workflow.next_run_at.is_not(None),
                Workflow.next_run_at <= utcnow(),
            )
            .with_for_update(skip_locked=True)
            .limit(100)
        ).all()
        for workflow in due:
            trigger = next(n for n in parse_definition(workflow.definition).nodes if n.type == "trigger.schedule")
            workflow.next_run_at = workflow_service.next_run_from_now(trigger)
            db.add(workflow)
            db.commit()
            try:
                workflow_service.queue_execution(
                    db, workflow, "trigger.schedule", {"scheduled_at": utcnow().isoformat()}
                )
                dispatched += 1
            except HTTPException as exc:
                logger.warning("Scheduled run for workflow %s skipped: %s", workflow.id, exc.detail)
    return dispatched


@celery_app.task(name="ghostwork.reap_stale_executions")
def reap_stale_executions() -> int:
    """Fail runs whose worker disappeared (crash, deploy) so they don't stay 'running' forever."""
    cutoff = utcnow() - timedelta(seconds=settings.EXECUTION_SOFT_TIME_LIMIT_SECONDS * 3)
    reaped = 0
    with Session(engine) as db:
        stale = db.exec(
            select(WorkflowExecution).where(
                WorkflowExecution.status.in_([ExecutionStatus.RUNNING, ExecutionStatus.QUEUED]),
                WorkflowExecution.created_at < cutoff,
            )
        ).all()
        for execution in stale:
            steps = list(db.exec(select(ExecutionStep).where(ExecutionStep.execution_id == execution.id)))
            execution_engine.finish_execution(
                db, execution, steps, "The run stopped unexpectedly (worker unavailable) and was marked as failed."
            )
            reaped += 1
    return reaped


@celery_app.task(name="ghostwork.purge_old_executions")
def purge_old_executions() -> int:
    """Delete finished executions older than EXECUTION_RETENTION_DAYS (steps cascade)."""
    if settings.EXECUTION_RETENTION_DAYS <= 0:
        return 0
    cutoff = utcnow() - timedelta(days=settings.EXECUTION_RETENTION_DAYS)
    with Session(engine) as db:
        result = db.exec(
            delete(WorkflowExecution).where(
                WorkflowExecution.created_at < cutoff,
                WorkflowExecution.status.in_(FINISHED_EXECUTION_STATUSES),
            )
        )
        db.commit()
        return result.rowcount
