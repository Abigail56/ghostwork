import json

from sqlmodel import Session, select

from app.core.config import settings
from app.db.session import engine
from app.models import Notification
from tests.helpers import create_workflow, edge, http_workflow, node


def run(client, headers, workflow_id, payload=None):
    response = client.post(f"/api/v1/workflows/{workflow_id}/run", headers=headers, json={"payload": payload or {}})
    assert response.status_code == 202, response.text
    return client.get(f"/api/v1/executions/{response.json()['id']}", headers=headers).json()


def test_successful_http_transform_execution(client, auth, http_server):
    _, base = http_server
    definition = http_workflow(
        base,
        extra_nodes=[node("shape", "action.transform", "Shape", {"fields": [
            {"key": "who", "value": "{{ steps.fetch.body.name }}"},
            {"key": "count", "value": "{{ steps.fetch.body.count }}"},
            {"key": "greeting", "value": "Hi {{ trigger.payload.user }}"},
        ]})],
        extra_edges=[edge("fetch", "shape")],
    )
    workflow = create_workflow(client, auth, definition)
    execution = run(client, auth, workflow["id"], {"user": "Ada"})
    assert execution["status"] == "succeeded", execution
    assert execution["duration_ms"] is not None
    steps = {s["node_id"]: s for s in execution["steps"]}
    assert steps["fetch"]["output"]["status_code"] == 200
    assert steps["shape"]["output"] == {"who": "ghost", "count": 3, "greeting": "Hi Ada"}
    assert all(s["status"] == "succeeded" for s in execution["steps"])


def test_failed_execution_records_error_and_skips_rest(client, auth, http_server):
    _, base = http_server
    definition = http_workflow(
        base, path="/status/404",
        extra_nodes=[node("after", "action.transform", "After", {"fields": [{"key": "x", "value": "1"}]})],
        extra_edges=[edge("fetch", "after")],
    )
    workflow = create_workflow(client, auth, definition)
    execution = run(client, auth, workflow["id"])
    assert execution["status"] == "failed"
    assert "HTTP 404" in execution["error_message"]
    steps = {s["node_id"]: s for s in execution["steps"]}
    assert steps["fetch"]["status"] == "failed"
    assert steps["after"]["status"] == "skipped"
    with Session(engine) as db:
        notification = db.exec(select(Notification)).one()
        assert notification.kind == "execution_failed"


def test_retries_on_server_errors(client, auth, http_server):
    _, base = http_server
    workflow = create_workflow(client, auth, http_workflow(base, path="/status/503", retries=1))
    execution = run(client, auth, workflow["id"])
    assert execution["status"] == "failed"
    assert execution["steps"][1]["attempts"] == 2


def test_condition_branches(client, auth, http_server):
    server, base = http_server
    definition = {
        "nodes": [
            node("t", "trigger.manual"),
            node("check", "condition.if", "Check", {"left": "{{ trigger.payload.priority }}", "operator": "equals", "right": "high"}),
            node("yes", "action.http_request", "Yes", {"method": "POST", "url": f"{base}/yes", "body": '{"p": "{{ trigger.payload.priority }}"}'}),
            node("no", "action.transform", "No", {"fields": [{"key": "skipped", "value": "true"}]}),
        ],
        "edges": [edge("t", "check"), edge("check", "yes", "true"), edge("check", "no", "false")],
    }
    workflow = create_workflow(client, auth, definition)
    high = {s["node_id"]: s["status"] for s in run(client, auth, workflow["id"], {"priority": "high"})["steps"]}
    assert high == {"t": "succeeded", "check": "succeeded", "yes": "succeeded", "no": "skipped"}
    assert json.loads(server.received[0]["body"]) == {"p": "high"}
    assert server.received[0]["headers"]["Content-Type"] == "application/json"
    low = {s["node_id"]: s["status"] for s in run(client, auth, workflow["id"], {"priority": "low"})["steps"]}
    assert low == {"t": "succeeded", "check": "succeeded", "yes": "skipped", "no": "succeeded"}


def test_ssrf_protection_blocks_internal_destinations(client, auth, monkeypatch):
    monkeypatch.setattr(settings, "ALLOW_PRIVATE_NETWORK_REQUESTS", False)
    for url in ["http://127.0.0.1:8000/", "http://169.254.169.254/latest/meta-data", "http://localhost/",
                "http://[::1]/", "http://10.0.0.5/", "http://0.0.0.0/"]:
        workflow = create_workflow(client, auth, http_workflow("", path=url))
        execution = run(client, auth, workflow["id"])
        assert execution["status"] == "failed", url
        assert "blocked" in execution["error_message"].lower(), (url, execution["error_message"])


def test_ssrf_redirect_to_internal_is_blocked(client, auth, http_server, monkeypatch):
    _, base = http_server
    from app.services import net_guard

    real = net_guard.resolve_safe

    def resolve(host, port):  # allow the test server, block everything else private
        if host == "127.0.0.1":
            return host
        monkeypatch.setattr(settings, "ALLOW_PRIVATE_NETWORK_REQUESTS", False)
        return real(host, port)

    monkeypatch.setattr(net_guard, "resolve_safe", resolve)
    workflow = create_workflow(client, auth, http_workflow(base, path="/redirect-internal"))
    execution = run(client, auth, workflow["id"])
    assert execution["status"] == "failed"
    assert "blocked" in execution["error_message"].lower()


def test_execution_history_filters_and_ownership(client, auth, other_auth, http_server):
    _, base = http_server
    ok = create_workflow(client, auth, http_workflow(base), name="Good one")
    bad = create_workflow(client, auth, http_workflow(base, path="/status/400"), name="Bad one")
    run(client, auth, ok["id"])
    run(client, auth, ok["id"])
    failed = run(client, auth, bad["id"])

    everything = client.get("/api/v1/executions", headers=auth).json()
    assert everything["total"] == 3
    assert client.get("/api/v1/executions", headers=auth, params={"status": "failed"}).json()["total"] == 1
    assert client.get("/api/v1/executions", headers=auth, params={"workflow_id": ok["id"]}).json()["total"] == 2
    assert client.get("/api/v1/executions", headers=auth, params={"q": "good"}).json()["total"] == 2
    assert client.get("/api/v1/executions", headers=auth, params={"q": failed["id"][:8]}).json()["total"] == 1
    page = client.get("/api/v1/executions", headers=auth, params={"page": 2, "page_size": 2}).json()
    assert len(page["items"]) == 1

    assert client.get("/api/v1/executions", headers=other_auth).json()["total"] == 0
    assert client.get(f"/api/v1/executions/{failed['id']}", headers=other_auth).status_code == 404
    assert client.post(f"/api/v1/executions/{failed['id']}/rerun", headers=other_auth).status_code == 404

    rerun = client.post(f"/api/v1/executions/{failed['id']}/rerun", headers=auth)
    assert rerun.status_code == 202


def test_cannot_run_invalid_workflow(client, auth):
    workflow = create_workflow(client, auth, {"nodes": [node("t", "trigger.manual")], "edges": []})
    response = client.post(f"/api/v1/workflows/{workflow['id']}/run", headers=auth, json={})
    assert response.status_code == 422


def test_concurrency_limit(client, auth, monkeypatch, http_server):
    _, base = http_server
    workflow = create_workflow(client, auth, http_workflow(base))
    monkeypatch.setattr(settings, "MAX_CONCURRENT_EXECUTIONS_PER_USER", 0)
    response = client.post(f"/api/v1/workflows/{workflow['id']}/run", headers=auth, json={})
    assert response.status_code == 429


def test_queue_unavailable_marks_failed(client, auth, monkeypatch, http_server):
    _, base = http_server
    workflow = create_workflow(client, auth, http_workflow(base))

    def broken(*args, **kwargs):
        raise ConnectionError("broker down")

    monkeypatch.setattr("app.workers.tasks.run_workflow_execution.delay", broken)
    response = client.post(f"/api/v1/workflows/{workflow['id']}/run", headers=auth, json={})
    assert response.status_code == 503
    latest = client.get("/api/v1/executions", headers=auth).json()["items"][0]
    assert latest["status"] == "failed" and "queue" in latest["error_message"]


def test_cancel_queued_execution(client, auth, monkeypatch, http_server):
    _, base = http_server
    workflow = create_workflow(client, auth, http_workflow(base))
    monkeypatch.setattr("app.workers.tasks.run_workflow_execution.delay", lambda *a, **k: None)
    queued = client.post(f"/api/v1/workflows/{workflow['id']}/run", headers=auth, json={}).json()
    assert queued["status"] == "queued"
    cancelled = client.post(f"/api/v1/executions/{queued['id']}/cancel", headers=auth).json()
    assert cancelled["status"] == "cancelled"
    from app.workers.tasks import run_workflow_execution

    assert run_workflow_execution.run(queued["id"]) == "cancelled"  # worker skips it
    assert client.post(f"/api/v1/executions/{queued['id']}/cancel", headers=auth).status_code == 409


def test_webhook_trigger(client, auth, http_server):
    _, base = http_server
    definition = {
        "nodes": [node("hook", "trigger.webhook"),
                  node("shape", "action.transform", config={"fields": [{"key": "event", "value": "{{ trigger.payload.body.event }}"}]})],
        "edges": [edge("hook", "shape")],
    }
    workflow = create_workflow(client, auth, definition)
    url = workflow["webhook_url"]
    path = url.split("localhost:8000")[1]
    assert client.post(path, json={"event": "x"}).status_code == 409  # not active yet
    client.post(f"/api/v1/workflows/{workflow['id']}/status", headers=auth, json={"status": "active"})
    response = client.post(path, json={"event": "signup"}, headers={"Authorization": "Bearer secret"})
    assert response.status_code == 202
    execution = client.get(f"/api/v1/executions/{response.json()['execution_id']}", headers=auth).json()
    assert execution["status"] == "succeeded"
    assert execution["steps"][1]["output"] == {"event": "signup"}
    assert "authorization" not in execution["trigger_payload"]["headers"]
    assert client.post("/api/v1/hooks/not-a-real-token", json={}).status_code == 404
    big = client.post(path, content=b"x" * (settings.WEBHOOK_MAX_PAYLOAD_BYTES + 1))
    assert big.status_code == 413


def test_scheduler_dispatches_due_workflows(client, auth):
    from datetime import timedelta

    from app.models import Workflow
    from app.models.base import utcnow
    from app.workers.tasks import dispatch_due_schedules

    definition = {
        "nodes": [node("t", "trigger.schedule", config={"every": 1, "unit": "hours"}),
                  node("a", "action.transform", config={"fields": [{"key": "x", "value": "1"}]})],
        "edges": [edge("t", "a")],
    }
    workflow = create_workflow(client, auth, definition)
    client.post(f"/api/v1/workflows/{workflow['id']}/status", headers=auth, json={"status": "active"})
    assert dispatch_due_schedules.run() == 0
    with Session(engine) as db:
        stored = db.get(Workflow, workflow["id"])
        stored.next_run_at = utcnow() - timedelta(seconds=1)
        db.add(stored)
        db.commit()
    assert dispatch_due_schedules.run() == 1
    executions = client.get("/api/v1/executions", headers=auth).json()["items"]
    assert executions[0]["trigger_type"] == "trigger.schedule" and executions[0]["status"] == "succeeded"


def test_reaper_fails_stale_runs(client, auth, monkeypatch, http_server):
    from datetime import timedelta

    from app.models import WorkflowExecution
    from app.models.base import utcnow
    from app.workers.tasks import reap_stale_executions

    _, base = http_server
    workflow = create_workflow(client, auth, http_workflow(base))
    monkeypatch.setattr("app.workers.tasks.run_workflow_execution.delay", lambda *a, **k: None)
    queued = client.post(f"/api/v1/workflows/{workflow['id']}/run", headers=auth, json={}).json()
    with Session(engine) as db:
        execution = db.get(WorkflowExecution, queued["id"])
        execution.created_at = utcnow() - timedelta(hours=1)
        db.add(execution)
        db.commit()
    assert reap_stale_executions.run() == 1
    assert client.get(f"/api/v1/executions/{queued['id']}", headers=auth).json()["status"] == "failed"
