from datetime import timedelta

from fastapi import APIRouter
from pydantic import BaseModel
from sqlalchemy import Date, case, cast, func
from sqlalchemy.dialects.postgresql import distinct_on
from sqlmodel import select

from app.api.deps import CurrentUser, SessionDep
from app.api.routes.executions import to_summary
from app.models import ActivityEvent, ExecutionStatus, Workflow, WorkflowExecution, WorkflowStatus
from app.models.base import utcnow
from app.schemas.integration import ActivityRead
from app.schemas.workflow import ExecutionSummary

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])

TREND_DAYS = 14


class TrendPoint(BaseModel):
    date: str
    succeeded: int
    failed: int
    other: int


class AttentionItem(BaseModel):
    workflow_id: str
    workflow_name: str
    reason: str


class Health(BaseModel):
    failures_24h: int
    successes_24h: int
    in_progress: int
    last_execution_at: str | None
    attention: list[AttentionItem]


class DashboardSummary(BaseModel):
    total_workflows: int
    active_workflows: int
    total_executions: int
    executions_30d: int
    # succeeded / (succeeded + failed) over 30 days; null when there were no finished runs.
    success_rate_30d: float | None
    trend: list[TrendPoint]
    recent_executions: list[ExecutionSummary]
    recent_activity: list[ActivityRead]
    health: Health


@router.get("/summary", response_model=DashboardSummary)
def summary(user: CurrentUser, db: SessionDep):
    now = utcnow()
    owner = WorkflowExecution.owner_id == user.id

    total_workflows, active_workflows = db.exec(
        select(
            func.count(),
            func.count().filter(Workflow.status == WorkflowStatus.ACTIVE),
        ).where(Workflow.owner_id == user.id)
    ).one()

    total_executions = db.exec(select(func.count()).select_from(WorkflowExecution).where(owner)).one()
    since_30 = now - timedelta(days=30)
    executions_30d, succeeded_30d, failed_30d = db.exec(
        select(
            func.count(),
            func.count().filter(WorkflowExecution.status == ExecutionStatus.SUCCEEDED),
            func.count().filter(WorkflowExecution.status == ExecutionStatus.FAILED),
        ).where(owner, WorkflowExecution.created_at >= since_30)
    ).one()
    finished = succeeded_30d + failed_30d
    success_rate = round(succeeded_30d / finished * 100, 1) if finished else None

    start = (now - timedelta(days=TREND_DAYS - 1)).date()
    day = cast(func.timezone("UTC", WorkflowExecution.created_at), Date)
    rows = db.exec(
        select(
            day,
            func.sum(case((WorkflowExecution.status == ExecutionStatus.SUCCEEDED, 1), else_=0)),
            func.sum(case((WorkflowExecution.status == ExecutionStatus.FAILED, 1), else_=0)),
            func.count(),
        )
        .where(owner, day >= start)
        .group_by(day)
    ).all()
    by_day = {r[0]: r for r in rows}
    trend = []
    for offset in range(TREND_DAYS):
        d = start + timedelta(days=offset)
        r = by_day.get(d)
        s, f, total = (int(r[1]), int(r[2]), int(r[3])) if r else (0, 0, 0)
        trend.append(TrendPoint(date=d.isoformat(), succeeded=s, failed=f, other=total - s - f))

    recent = db.exec(
        select(WorkflowExecution, Workflow.name)
        .join(Workflow, Workflow.id == WorkflowExecution.workflow_id)
        .where(owner)
        .order_by(WorkflowExecution.created_at.desc())
        .limit(6)
    ).all()

    activity = db.exec(
        select(ActivityEvent).where(ActivityEvent.user_id == user.id).order_by(ActivityEvent.created_at.desc()).limit(8)
    ).all()

    since_24 = now - timedelta(hours=24)
    failures_24h, successes_24h = db.exec(
        select(
            func.count().filter(WorkflowExecution.status == ExecutionStatus.FAILED),
            func.count().filter(WorkflowExecution.status == ExecutionStatus.SUCCEEDED),
        ).where(owner, WorkflowExecution.created_at >= since_24)
    ).one()
    in_progress = db.exec(
        select(func.count())
        .select_from(WorkflowExecution)
        .where(owner, WorkflowExecution.status.in_([ExecutionStatus.QUEUED, ExecutionStatus.RUNNING]))
    ).one()
    last_at = db.exec(select(func.max(WorkflowExecution.created_at)).where(owner)).one()

    # Active workflows whose most recent run failed.
    latest = (
        select(WorkflowExecution.workflow_id, WorkflowExecution.status)
        .where(owner)
        .ext(distinct_on(WorkflowExecution.workflow_id))
        .order_by(WorkflowExecution.workflow_id, WorkflowExecution.created_at.desc())
        .subquery()
    )
    failing = db.exec(
        select(Workflow.id, Workflow.name)
        .join(latest, latest.c.workflow_id == Workflow.id)
        .where(Workflow.owner_id == user.id, Workflow.status == WorkflowStatus.ACTIVE, latest.c.status == "failed")
        .limit(5)
    ).all()
    attention = [AttentionItem(workflow_id=str(i), workflow_name=n, reason="Last run failed") for i, n in failing]

    return DashboardSummary(
        total_workflows=total_workflows,
        active_workflows=active_workflows,
        total_executions=total_executions,
        executions_30d=executions_30d,
        success_rate_30d=success_rate,
        trend=trend,
        recent_executions=[to_summary(e, n) for e, n in recent],
        recent_activity=[ActivityRead.model_validate(a, from_attributes=True) for a in activity],
        health=Health(
            failures_24h=failures_24h,
            successes_24h=successes_24h,
            in_progress=in_progress,
            last_execution_at=last_at.isoformat() if last_at else None,
            attention=attention,
        ),
    )
