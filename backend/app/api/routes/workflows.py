import secrets
import uuid
from typing import Literal

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import func, or_
from sqlalchemy.dialects.postgresql import distinct_on
from sqlmodel import Session, select

from app.api.deps import CurrentUser, SessionDep
from app.api.routes.executions import escape_like, to_summary
from app.core.config import settings
from app.models import Workflow, WorkflowExecution, WorkflowStatus
from app.models.base import utcnow
from app.schemas.common import Message, Page
from app.schemas.workflow import (
    ExecutionSummary,
    LastExecution,
    RunRequest,
    StatusChange,
    ValidationResponse,
    WorkflowCreate,
    WorkflowRead,
    WorkflowSummary,
    WorkflowUpdate,
)
from app.services import workflow_service
from app.services.activity import record_activity

router = APIRouter(prefix="/workflows", tags=["Workflows"])

SortKey = Literal["updated", "-updated", "name", "-name", "created", "-created", "last_run", "-last_run"]
_SORT_COLUMNS = {
    "updated": Workflow.updated_at,
    "name": func.lower(Workflow.name),
    "created": Workflow.created_at,
    "last_run": Workflow.last_run_at,
}


def _last_executions(db: Session, workflow_ids: list[uuid.UUID]) -> dict[uuid.UUID, LastExecution]:
    if not workflow_ids:
        return {}
    rows = db.exec(
        select(WorkflowExecution)
        .where(WorkflowExecution.workflow_id.in_(workflow_ids))
        .ext(distinct_on(WorkflowExecution.workflow_id))
        .order_by(WorkflowExecution.workflow_id, WorkflowExecution.created_at.desc())
    ).all()
    return {
        r.workflow_id: LastExecution(id=r.id, status=r.status, created_at=r.created_at, finished_at=r.finished_at)
        for r in rows
    }


def _summary(workflow: Workflow, last: LastExecution | None) -> WorkflowSummary:
    return WorkflowSummary(
        id=workflow.id,
        name=workflow.name,
        description=workflow.description,
        status=workflow.status,
        trigger_type=workflow.trigger_type,
        step_count=len(workflow.definition.get("nodes", [])),
        last_run_at=workflow.last_run_at,
        next_run_at=workflow.next_run_at,
        created_at=workflow.created_at,
        updated_at=workflow.updated_at,
        last_execution=last,
    )


def _read(db: Session, workflow: Workflow) -> WorkflowRead:
    result = workflow_service.validate_for_owner(db, workflow)
    last = _last_executions(db, [workflow.id]).get(workflow.id)
    webhook_url = (
        f"{settings.API_PUBLIC_URL.rstrip('/')}/api/v1/hooks/{workflow.webhook_token}"
        if workflow.trigger_type == "trigger.webhook" and workflow.webhook_token
        else None
    )
    return WorkflowRead(
        **_summary(workflow, last).model_dump(),
        definition=workflow.definition,
        version=workflow.version,
        webhook_url=webhook_url,
        validation=[i.as_dict() for i in result.issues],
    )


@router.get("", response_model=Page[WorkflowSummary])
def list_workflows(
    user: CurrentUser,
    db: SessionDep,
    q: str | None = Query(default=None, max_length=120),
    status_filter: Literal["draft", "active", "paused"] | None = Query(default=None, alias="status"),
    sort: SortKey = "-updated",
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
):
    filters = [Workflow.owner_id == user.id]
    if q and q.strip():
        pattern = f"%{escape_like(q.strip())}%"
        filters.append(or_(Workflow.name.ilike(pattern, escape="\\"), Workflow.description.ilike(pattern, escape="\\")))
    if status_filter:
        filters.append(Workflow.status == status_filter)
    total = db.exec(select(func.count()).select_from(Workflow).where(*filters)).one()
    column = _SORT_COLUMNS[sort.lstrip("-")]
    order = column.desc().nulls_last() if sort.startswith("-") else column.asc().nulls_last()
    rows = db.exec(
        select(Workflow).where(*filters).order_by(order, Workflow.id).offset((page - 1) * page_size).limit(page_size)
    ).all()
    last = _last_executions(db, [w.id for w in rows])
    return Page(items=[_summary(w, last.get(w.id)) for w in rows], total=total, page=page, page_size=page_size)


@router.post("", response_model=WorkflowRead, status_code=status.HTTP_201_CREATED)
def create_workflow(payload: WorkflowCreate, user: CurrentUser, db: SessionDep):
    workflow = Workflow(owner_id=user.id, name=payload.name, description=payload.description, version=0)
    workflow_service.apply_definition(db, workflow, payload.definition or {"nodes": [], "edges": []})
    db.add(workflow)
    db.flush()
    record_activity(db, user.id, "workflow.created", f"{workflow.name} created", workflow.id)
    db.commit()
    db.refresh(workflow)
    return _read(db, workflow)


@router.get("/{workflow_id}", response_model=WorkflowRead)
def get_workflow(workflow_id: uuid.UUID, user: CurrentUser, db: SessionDep):
    return _read(db, workflow_service.get_owned_workflow(db, user.id, workflow_id))


@router.patch("/{workflow_id}", response_model=WorkflowRead)
def update_workflow(workflow_id: uuid.UUID, payload: WorkflowUpdate, user: CurrentUser, db: SessionDep):
    workflow = workflow_service.get_owned_workflow(db, user.id, workflow_id, lock=True)
    if payload.expected_version is not None and payload.expected_version != workflow.version:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "This workflow was changed somewhere else. Reload to get the latest version.",
        )
    if payload.name is not None:
        workflow.name = payload.name
    if payload.description is not None:
        workflow.description = payload.description
    if payload.definition is not None:
        workflow_service.apply_definition(db, workflow, payload.definition)
    else:
        workflow.version += 1
    workflow.updated_at = utcnow()
    db.add(workflow)
    record_activity(db, user.id, "workflow.updated", f"{workflow.name} updated", workflow.id)
    db.commit()
    db.refresh(workflow)
    return _read(db, workflow)


@router.delete("/{workflow_id}", response_model=Message)
def delete_workflow(workflow_id: uuid.UUID, user: CurrentUser, db: SessionDep):
    workflow = workflow_service.get_owned_workflow(db, user.id, workflow_id, lock=True)
    record_activity(db, user.id, "workflow.deleted", f"{workflow.name} deleted")
    db.delete(workflow)
    db.commit()
    return Message(message="Workflow deleted.")


@router.post("/{workflow_id}/duplicate", response_model=WorkflowRead, status_code=status.HTTP_201_CREATED)
def duplicate_workflow(workflow_id: uuid.UUID, user: CurrentUser, db: SessionDep):
    source = workflow_service.get_owned_workflow(db, user.id, workflow_id)
    copy = Workflow(owner_id=user.id, name=f"{source.name} (copy)"[:120], description=source.description, version=0)
    workflow_service.apply_definition(db, copy, source.definition)
    db.add(copy)
    db.flush()
    record_activity(db, user.id, "workflow.created", f"{copy.name} created from {source.name}", copy.id)
    db.commit()
    db.refresh(copy)
    return _read(db, copy)


@router.post("/{workflow_id}/status", response_model=WorkflowRead)
def change_status(workflow_id: uuid.UUID, payload: StatusChange, user: CurrentUser, db: SessionDep):
    workflow = workflow_service.get_owned_workflow(db, user.id, workflow_id, lock=True)
    workflow_service.set_status(db, workflow, WorkflowStatus(payload.status))
    db.commit()
    db.refresh(workflow)
    return _read(db, workflow)


@router.post("/{workflow_id}/validate", response_model=ValidationResponse)
def validate_workflow(workflow_id: uuid.UUID, user: CurrentUser, db: SessionDep):
    workflow = workflow_service.get_owned_workflow(db, user.id, workflow_id)
    result = workflow_service.validate_for_owner(db, workflow)
    return ValidationResponse(valid=result.valid, issues=[i.as_dict() for i in result.issues])


@router.post("/{workflow_id}/run", response_model=ExecutionSummary, status_code=status.HTTP_202_ACCEPTED)
def run_workflow(workflow_id: uuid.UUID, payload: RunRequest, user: CurrentUser, db: SessionDep):
    workflow = workflow_service.get_owned_workflow(db, user.id, workflow_id)
    execution = workflow_service.queue_execution(db, workflow, "manual", payload.payload)
    db.refresh(execution)
    return to_summary(execution, workflow.name)


@router.post("/{workflow_id}/webhook/rotate", response_model=WorkflowRead)
def rotate_webhook(workflow_id: uuid.UUID, user: CurrentUser, db: SessionDep):
    workflow = workflow_service.get_owned_workflow(db, user.id, workflow_id, lock=True)
    if workflow.trigger_type != "trigger.webhook":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "This workflow doesn't use a webhook trigger.")
    workflow.webhook_token = secrets.token_urlsafe(24)
    workflow.updated_at = utcnow()
    db.add(workflow)
    record_activity(db, user.id, "workflow.webhook_rotated", f"Webhook URL regenerated for {workflow.name}", workflow.id)
    db.commit()
    db.refresh(workflow)
    return _read(db, workflow)
