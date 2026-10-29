import hashlib
import hmac
import json
from datetime import timedelta

from sqlalchemy import func
from sqlmodel import Session, select

from app.db.session import engine
from app.models import ActivityEvent, Workflow, WorkflowExecution
from app.models.base import utcnow
from tests.conftest import PASSWORD, register
from tests.helpers import create_workflow, edge, node


def _webhook_workflow(client, auth):
    definition = {
        "nodes": [node("hook", "trigger.webhook"),
                  node("t", "action.transform", config={"fields": [{"key": "x", "value": "{{ trigger.payload.body.x }}"}]})],
        "edges": [edge("hook", "t")],
    }
    workflow = create_workflow(client, auth, definition)
    client.post(f"/api/v1/workflows/{workflow['id']}/status", headers=auth, json={"status": "active"})
    return workflow, workflow["webhook_url"].split("localhost:8000")[1]


def test_signed_webhooks(client, auth):
    workflow, path = _webhook_workflow(client, auth)
    secret = client.post(f"/api/v1/workflows/{workflow['id']}/webhook/secret", headers=auth).json()["secret"]
    assert client.get(f"/api/v1/workflows/{workflow['id']}", headers=auth).json()["webhook_signing_enabled"] is True
    with Session(engine) as db:
        assert secret not in (db.get(Workflow, workflow["id"]).webhook_secret_encrypted or "")

    body = json.dumps({"x": 1}).encode()
    assert client.post(path, content=body, headers={"Content-Type": "application/json"}).status_code == 401
    bad = {"Content-Type": "application/json", "X-GhostWork-Signature": "sha256=" + "0" * 64}
    assert client.post(path, content=body, headers=bad).status_code == 401
    signature = "sha256=" + hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    good = client.post(path, content=body, headers={"Content-Type": "application/json", "X-GhostWork-Signature": signature})
    assert good.status_code == 202

    removed = client.delete(f"/api/v1/workflows/{workflow['id']}/webhook/secret", headers=auth).json()
    assert removed["webhook_signing_enabled"] is False
    assert client.post(path, content=body, headers={"Content-Type": "application/json"}).status_code == 202


def test_signing_secret_is_owner_only(client, auth, other_auth):
    workflow, _ = _webhook_workflow(client, auth)
    assert client.post(f"/api/v1/workflows/{workflow['id']}/webhook/secret", headers=other_auth).status_code == 404


def test_change_email(client, auth):
    register(client, email="taken@example.com", name="Taken")
    wrong = client.post("/api/v1/users/me/email", headers=auth, json={"new_email": "new@example.com", "password": "nope-nope-1"})
    assert wrong.status_code == 400
    taken = client.post("/api/v1/users/me/email", headers=auth, json={"new_email": "TAKEN@example.com", "password": PASSWORD})
    assert taken.status_code == 409
    ok = client.post("/api/v1/users/me/email", headers=auth, json={"new_email": "New@Example.com", "password": PASSWORD})
    assert ok.status_code == 200 and ok.json()["email"] == "new@example.com"
    assert client.post("/api/v1/auth/login", json={"email": "new@example.com", "password": PASSWORD}).status_code == 200


def test_delete_account_removes_everything(client, auth, other_auth):
    create_workflow(client, auth, {"nodes": [node("t", "trigger.manual")], "edges": []})
    create_workflow(client, other_auth, {"nodes": [node("t", "trigger.manual")], "edges": []})
    assert client.request("DELETE", "/api/v1/users/me", headers=auth, json={"password": "wrong-pass-1"}).status_code == 400
    response = client.request("DELETE", "/api/v1/users/me", headers=auth, json={"password": PASSWORD})
    assert response.status_code == 204
    assert client.get("/api/v1/auth/me", headers=auth).status_code == 401
    assert client.post("/api/v1/auth/login", json={"email": "ada@example.com", "password": PASSWORD}).status_code == 401
    with Session(engine) as db:
        assert db.exec(select(func.count()).select_from(Workflow)).one() == 1  # only the other user's
        assert db.exec(select(func.count()).select_from(ActivityEvent)).one() >= 1
    assert client.get("/api/v1/workflows", headers=other_auth).json()["total"] == 1


def test_purge_old_executions(client, auth, monkeypatch):
    from app.workers.tasks import purge_old_executions

    workflow = create_workflow(client, auth, {
        "nodes": [node("t", "trigger.manual"), node("a", "action.transform", config={"fields": [{"key": "x", "value": "1"}]})],
        "edges": [edge("t", "a")],
    })
    for _ in range(3):
        client.post(f"/api/v1/workflows/{workflow['id']}/run", headers=auth, json={})
    with Session(engine) as db:
        rows = db.exec(select(WorkflowExecution)).all()
        rows[0].created_at = utcnow() - timedelta(days=200)
        rows[1].created_at = utcnow() - timedelta(days=200)
        rows[1].status = "running"  # active runs are never purged
        for r in rows:
            db.add(r)
        db.commit()
    assert purge_old_executions.run() == 1
    assert client.get("/api/v1/executions", headers=auth).json()["total"] == 2
