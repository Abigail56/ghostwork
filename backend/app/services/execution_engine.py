"""Runs a queued workflow execution step by step and records every outcome."""

import json
import logging
import re
import time
import uuid
from collections import defaultdict
from datetime import datetime
from urllib.parse import quote

from sqlmodel import Session, select

from app.core.config import settings
from app.core.security import SecretBoxError
from app.models import ExecutionStatus, ExecutionStep, StepStatus, User, Workflow, WorkflowExecution
from app.models.base import utcnow
from app.services import integrations as integration_service
from app.services import external_apis, net_guard, templating
from app.services.activity import notify
from app.services.mailer import MailError, platform_smtp_config, send_email
from app.services.push import send_push
from app.services.workflow_definition import (
    NODE_TYPES,
    UNARY_OPERATORS,
    ConditionConfig,
    DefinitionError,
    EmailConfig,
    GitHubIssueConfig,
    SheetsAppendConfig,
    SheetsReadConfig,
    HttpRequestConfig,
    NodeDef,
    SlackConfig,
    TransformConfig,
    config_of,
    parse_definition,
    topological_order,
)

logger = logging.getLogger(__name__)

MAX_STORED_OUTPUT_BYTES = 64_000


class StepFailed(Exception):
    pass


class ExecutionCancelled(Exception):
    pass


def _ms_between(start: datetime, end: datetime) -> int:
    return int((end - start).total_seconds() * 1000)


def _compact_output(output: object) -> dict:
    """Keep stored outputs bounded so a large API response can't bloat the database."""
    encoded = json.dumps(output, default=str)
    if len(encoded) <= MAX_STORED_OUTPUT_BYTES:
        return output if isinstance(output, dict) else {"value": output}
    return {"truncated": True, "preview": encoded[:MAX_STORED_OUTPUT_BYTES]}


# --- Step handlers ---------------------------------------------------------------


def _run_http(db: Session, execution: WorkflowExecution, config: HttpRequestConfig, ctx: dict, record_attempt) -> dict:
    url = templating.render(config.url, ctx).strip()
    headers = {h.key: templating.render(h.value, ctx) for h in config.headers}
    if config.credential_integration_id:
        try:
            public, secrets = integration_service.load_for_execution(
                db, execution.owner_id, config.credential_integration_id, "http_auth"
            )
        except (integration_service.IntegrationError, SecretBoxError) as exc:
            raise StepFailed(str(exc))
        if public.get("scheme") == "bearer":
            headers["Authorization"] = f"Bearer {secrets['token']}"
        else:
            headers[public.get("header_name", "Authorization")] = secrets["token"]
    body = templating.render(config.body, ctx) if config.method != "GET" and config.body else None
    if body is not None and not any(k.lower() == "content-type" for k in headers):
        try:
            json.loads(body)
            headers["Content-Type"] = "application/json"
        except ValueError:
            headers["Content-Type"] = "text/plain; charset=utf-8"

    last_error = "Request failed."
    for attempt in range(config.retries + 1):
        record_attempt(attempt + 1)
        try:
            response = net_guard.safe_request(
                config.method, url, headers=headers, content=body, timeout=config.timeout_seconds
            )
        except net_guard.BlockedDestination as exc:
            raise StepFailed(str(exc))  # never retry a blocked destination
        except net_guard.RequestFailed as exc:
            last_error = str(exc)
        else:
            output = {
                "status_code": response.status_code,
                "ok": response.status_code < 400,
                "headers": response.headers,
                "body": response.body,
                "truncated": response.truncated,
            }
            if response.status_code >= 400 and config.fail_on_error_status:
                last_error = f"The server responded with HTTP {response.status_code}."
                if response.status_code < 500 and response.status_code != 429:
                    raise StepFailed(last_error)
            else:
                return output
        if attempt < config.retries:
            time.sleep(min(2**attempt, 8))
    raise StepFailed(last_error)


def _run_transform(config: TransformConfig, ctx: dict) -> dict:
    return {item.key: templating.render_value(item.value, ctx) for item in config.fields}


def _run_email(db: Session, execution: WorkflowExecution, config: EmailConfig, ctx: dict) -> dict:
    try:
        public, secrets = integration_service.load_for_execution(db, execution.owner_id, config.integration_id, "smtp")
    except (integration_service.IntegrationError, SecretBoxError) as exc:
        raise StepFailed(str(exc))
    recipients = [templating.render(r, ctx).strip() for r in config.to]
    recipients = [r for r in recipients if r]
    if not recipients:
        raise StepFailed("No recipients after filling in the template values.")
    try:
        integration_service._guard_host(public["host"], public["port"])
        message_id = send_email(
            integration_service.smtp_from(public, secrets),
            recipients,
            templating.render(config.subject, ctx)[:300],
            templating.render(config.body, ctx),
        )
    except (MailError, integration_service.IntegrationError) as exc:
        raise StepFailed(str(exc))
    return {"sent": True, "recipients": recipients, "message_id": message_id}


def _run_slack(db: Session, execution: WorkflowExecution, config: SlackConfig, ctx: dict) -> dict:
    try:
        _, secrets = integration_service.load_for_execution(db, execution.owner_id, config.integration_id, "slack")
    except (integration_service.IntegrationError, SecretBoxError) as exc:
        raise StepFailed(str(exc))
    try:
        response = net_guard.safe_request(
            "POST",
            secrets["webhook_url"],
            headers={"Content-Type": "application/json"},
            content=json.dumps({"text": templating.render(config.text, ctx)}),
            timeout=10,
            allowed_hosts={"hooks.slack.com"},
        )
    except (net_guard.BlockedDestination, net_guard.RequestFailed) as exc:
        raise StepFailed(str(exc))
    if response.status_code >= 400:
        raise StepFailed(f"Slack rejected the message (HTTP {response.status_code}).")
    return {"sent": True, "status_code": response.status_code}


def _run_github_issue(db: Session, execution: WorkflowExecution, config: GitHubIssueConfig, ctx: dict) -> dict:
    try:
        _, secrets = integration_service.load_for_execution(db, execution.owner_id, config.integration_id, "github")
    except (integration_service.IntegrationError, SecretBoxError) as exc:
        raise StepFailed(str(exc))
    repository = templating.render(config.repository, ctx).strip()
    if not re.fullmatch(r"[\w.-]+/[\w.-]+", repository):
        raise StepFailed(f"'{repository}' isn't a repository in owner/name form.")
    payload: dict = {"title": templating.render(config.title, ctx)[:500], "body": templating.render(config.body, ctx)}
    labels = [label for label in (templating.render(item, ctx).strip() for item in config.labels) if label]
    if labels:
        payload["labels"] = labels
    try:
        issue = external_apis.github_request(secrets["token"], "POST", f"/repos/{repository}/issues", payload)
    except external_apis.ExternalApiError as exc:
        raise StepFailed(str(exc))
    return {"number": issue.get("number"), "url": issue.get("html_url"), "repository": repository}


def _sheets_info(db: Session, execution: WorkflowExecution, integration_id) -> dict:
    try:
        _, secrets = integration_service.load_for_execution(db, execution.owner_id, integration_id, "google")
        return external_apis.parse_service_account(secrets["service_account_json"])
    except (integration_service.IntegrationError, SecretBoxError, external_apis.ExternalApiError) as exc:
        raise StepFailed(str(exc))


def _run_sheets_append(db: Session, execution: WorkflowExecution, config: SheetsAppendConfig, ctx: dict) -> dict:
    info = _sheets_info(db, execution, config.integration_id)
    row = [templating._stringify(templating.render_value(value, ctx)) for value in config.values]
    sheet_range = quote(templating.render(config.sheet_range, ctx), safe="")
    try:
        result = external_apis.sheets_request(
            info,
            "POST",
            templating.render(config.spreadsheet_id, ctx).strip(),
            f"/values/{sheet_range}:append?valueInputOption=USER_ENTERED",
            {"values": [row]},
        )
    except external_apis.ExternalApiError as exc:
        raise StepFailed(str(exc))
    updates = result.get("updates", {}) if isinstance(result, dict) else {}
    return {"appended": row, "range": updates.get("updatedRange")}


def _run_sheets_read(db: Session, execution: WorkflowExecution, config: SheetsReadConfig, ctx: dict) -> dict:
    info = _sheets_info(db, execution, config.integration_id)
    sheet_range = quote(templating.render(config.sheet_range, ctx), safe="")
    try:
        result = external_apis.sheets_request(info, "GET", templating.render(config.spreadsheet_id, ctx).strip(), f"/values/{sheet_range}")
    except external_apis.ExternalApiError as exc:
        raise StepFailed(str(exc))
    rows = result.get("values", []) if isinstance(result, dict) else []
    return {"rows": rows, "row_count": len(rows), "range": result.get("range") if isinstance(result, dict) else None}


def _to_number(value: object) -> float | None:
    try:
        return float(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return None


def evaluate_condition(config: ConditionConfig, ctx: dict) -> bool:
    left = templating.render_value(config.left, ctx)
    right = templating.render_value(config.right, ctx) if config.operator not in UNARY_OPERATORS else None
    if config.operator == "is_empty":
        return left in (None, "", [], {})
    if config.operator == "is_not_empty":
        return left not in (None, "", [], {})
    left_s = templating._stringify(left)
    right_s = templating._stringify(right)
    if config.operator == "equals":
        return left_s == right_s
    if config.operator == "not_equals":
        return left_s != right_s
    if config.operator == "contains":
        return right_s in left if isinstance(left, list) else right_s in left_s
    if config.operator == "not_contains":
        return right_s not in left if isinstance(left, list) else right_s not in left_s
    ln, rn = _to_number(left), _to_number(right)
    if ln is None or rn is None:
        raise StepFailed(f"Can't compare '{left_s}' and '{right_s}' as numbers.")
    return ln > rn if config.operator == "greater_than" else ln < rn


# --- Orchestration -------------------------------------------------------------


def create_steps(db: Session, execution: WorkflowExecution) -> None:
    """Create a pending step row per node so progress is visible before the worker starts."""
    definition = parse_definition(execution.definition_snapshot)
    order = topological_order(definition) or definition.nodes
    for position, node in enumerate(order):
        db.add(
            ExecutionStep(
                execution_id=execution.id,
                node_id=node.id,
                node_type=node.type,
                node_name=node.name,
                position=position,
            )
        )


def _check_cancelled(db: Session, execution: WorkflowExecution) -> None:
    db.refresh(execution, attribute_names=["status"])
    if execution.status == ExecutionStatus.CANCELLED:
        raise ExecutionCancelled()


def run_execution(db: Session, execution_id: uuid.UUID) -> str | None:
    execution = db.exec(
        select(WorkflowExecution).where(WorkflowExecution.id == execution_id).with_for_update()
    ).first()
    if execution is None or execution.status != ExecutionStatus.QUEUED:
        return execution.status if execution else None  # already handled (idempotent)

    execution.status = ExecutionStatus.RUNNING
    execution.started_at = utcnow()
    db.add(execution)
    db.commit()

    steps = {
        s.node_id: s
        for s in db.exec(select(ExecutionStep).where(ExecutionStep.execution_id == execution.id))
    }
    failure: str | None = None
    cancelled = False
    try:
        definition = parse_definition(execution.definition_snapshot)
        order = topological_order(definition)
        if order is None:
            raise DefinitionError([])
        context = {
            "trigger": {"type": execution.trigger_type, "payload": execution.trigger_payload},
            "steps": {},
            "execution": {"id": str(execution.id), "started_at": execution.started_at.isoformat()},
            "workflow": {"id": str(execution.workflow_id)},
        }
        workflow = db.get(Workflow, execution.workflow_id)
        if workflow:
            context["workflow"]["name"] = workflow.name

        incoming = defaultdict(list)
        for edge in definition.edges:
            incoming[edge.target].append(edge)
        fired: set[tuple[str, str]] = set()  # (source node, handle) that produced output

        for node in order:
            _check_cancelled(db, execution)
            step = steps.get(node.id)
            if step is None:
                continue
            kind = NODE_TYPES[node.type].kind
            if kind != "trigger" and not any((e.source, e.source_handle) in fired for e in incoming[node.id]):
                step.status = StepStatus.SKIPPED
                db.add(step)
                db.commit()
                continue
            _run_step(db, execution, node, step, context, fired)
    except StepFailed as exc:
        failure = str(exc)
    except ExecutionCancelled:
        cancelled = True
    except DefinitionError:
        failure = "The workflow definition is no longer valid."
    except Exception:
        logger.exception("Unexpected error in execution %s", execution.id)
        failure = "An internal error stopped this run. The GhostWork team has been notified in the server logs."

    finish_execution(db, execution, steps.values(), failure, cancelled)
    return execution.status


def _run_step(db, execution, node: NodeDef, step: ExecutionStep, context: dict, fired: set) -> None:
    step.status = StepStatus.RUNNING
    step.started_at = utcnow()
    step.attempts = 1
    db.add(step)
    db.commit()

    def record_attempt(n: int) -> None:
        if n != step.attempts:
            step.attempts = n
            db.add(step)
            db.commit()

    try:
        config = config_of(node)
        handles = ["out"]
        if NODE_TYPES[node.type].kind == "trigger":
            output = {"type": execution.trigger_type, "payload": execution.trigger_payload}
        elif isinstance(config, HttpRequestConfig):
            output = _run_http(db, execution, config, context, record_attempt)
        elif isinstance(config, TransformConfig):
            output = _run_transform(config, context)
        elif isinstance(config, EmailConfig):
            output = _run_email(db, execution, config, context)
        elif isinstance(config, SlackConfig):
            output = _run_slack(db, execution, config, context)
        elif isinstance(config, GitHubIssueConfig):
            output = _run_github_issue(db, execution, config, context)
        elif isinstance(config, SheetsAppendConfig):
            output = _run_sheets_append(db, execution, config, context)
        elif isinstance(config, SheetsReadConfig):
            output = _run_sheets_read(db, execution, config, context)
        elif isinstance(config, ConditionConfig):
            result = evaluate_condition(config, context)
            output = {"result": result}
            handles = ["true" if result else "false"]
        else:  # pragma: no cover - catalog and handlers are kept in sync by tests
            raise StepFailed(f"Step type '{node.type}' can't run.")
    except StepFailed as exc:
        step.status = StepStatus.FAILED
        step.error_message = str(exc)[:2000]
        step.finished_at = utcnow()
        step.duration_ms = _ms_between(step.started_at, step.finished_at)
        db.add(step)
        db.commit()
        raise StepFailed(f"Step '{node.name}' failed: {exc}")

    context["steps"][node.id] = output
    for handle in handles:
        fired.add((node.id, handle))
    step.status = StepStatus.SUCCEEDED
    step.output = _compact_output(output)
    step.finished_at = utcnow()
    step.duration_ms = _ms_between(step.started_at, step.finished_at)
    db.add(step)
    db.commit()


def finish_execution(db: Session, execution: WorkflowExecution, steps, failure: str | None, cancelled: bool = False) -> None:
    now = utcnow()
    for step in steps:
        if step.status in (StepStatus.PENDING, StepStatus.RUNNING):
            step.status = StepStatus.SKIPPED if step.status == StepStatus.PENDING else StepStatus.FAILED
            if step.status == StepStatus.FAILED:
                step.error_message = step.error_message or "Stopped before this step finished."
                step.finished_at = now
            db.add(step)
    if cancelled:
        execution.status = ExecutionStatus.CANCELLED
        execution.error_message = execution.error_message or "Cancelled by user."
    elif failure:
        execution.status = ExecutionStatus.FAILED
        execution.error_message = failure[:2000]
    else:
        execution.status = ExecutionStatus.SUCCEEDED
    execution.finished_at = now
    if execution.started_at:
        execution.duration_ms = _ms_between(execution.started_at, now)
    db.add(execution)
    workflow = db.get(Workflow, execution.workflow_id)
    if workflow:
        workflow.last_run_at = now
        db.add(workflow)
    _notify_owner(db, execution, workflow)
    db.commit()


def _notify_owner(db: Session, execution: WorkflowExecution, workflow: Workflow | None) -> None:
    user = db.get(User, execution.owner_id)
    if user is None:
        return
    name = workflow.name if workflow else "A workflow"
    link = f"/executions/{execution.id}"
    if execution.status == ExecutionStatus.FAILED:
        if user.notify_on_failure:
            notify(db, user.id, "execution_failed", f"{name} failed", execution.error_message or "", link)
        if user.push_on_failure:
            send_push(db, user.id, f"{name} failed", execution.error_message or "", link)
        smtp = platform_smtp_config()
        if user.email_on_failure and smtp is not None:
            try:
                send_email(
                    smtp,
                    [user.email],
                    f"GhostWork: {name} failed",
                    f"{name} failed.\n\n{execution.error_message}\n\n"
                    f"Details: {settings.FRONTEND_URL.rstrip('/')}{link}\n",
                )
            except MailError as exc:
                logger.warning("Failure notification email not sent: %s", exc)
    elif execution.status == ExecutionStatus.SUCCEEDED and user.notify_on_success:
        notify(db, user.id, "execution_succeeded", f"{name} succeeded", "", link)
