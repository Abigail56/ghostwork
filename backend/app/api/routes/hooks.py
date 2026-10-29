import json

from fastapi import APIRouter, HTTPException, Request, status
from sqlmodel import select

from app.api.deps import SessionDep
from app.core.config import settings
from app.core.rate_limit import check_rate_limit
from app.models import Workflow, WorkflowStatus
from app.services import workflow_service

router = APIRouter(prefix="/hooks", tags=["Webhooks"])

# Forwarded to the workflow as trigger.payload.headers; credentials are never stored.
_FORWARDED_HEADERS = {"content-type", "user-agent", "x-github-event", "x-request-id", "x-event-type"}


@router.post("/{token}", status_code=status.HTTP_202_ACCEPTED)
async def receive_webhook(token: str, request: Request, db: SessionDep):
    if len(token) > 64:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown webhook.")
    check_rate_limit(f"webhook:{token}", 60, 60)
    body_bytes = await request.body()
    if len(body_bytes) > settings.WEBHOOK_MAX_PAYLOAD_BYTES:
        raise HTTPException(status.HTTP_413_CONTENT_TOO_LARGE, "Payload too large.")

    workflow = db.exec(select(Workflow).where(Workflow.webhook_token == token)).first()
    if workflow is None or workflow.trigger_type != "trigger.webhook":
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown webhook.")
    if workflow.status != WorkflowStatus.ACTIVE:
        raise HTTPException(status.HTTP_409_CONFLICT, "This workflow is not active.")

    text = body_bytes.decode("utf-8", errors="replace")
    body: object = text
    if "json" in request.headers.get("content-type", "") and text:
        try:
            body = json.loads(text)
        except ValueError:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Body is not valid JSON.")
    elif "x-www-form-urlencoded" in request.headers.get("content-type", ""):
        body = dict((await request.form()).items())
    payload = {
        "body": body,
        "query": dict(request.query_params),
        "headers": {k: v for k, v in request.headers.items() if k.lower() in _FORWARDED_HEADERS},
    }
    execution = workflow_service.queue_execution(db, workflow, "trigger.webhook", payload)
    return {"execution_id": str(execution.id), "status": "queued"}
