from sqlmodel import Session, select

from app.db.session import engine
from app.models import Integration
from tests.helpers import create_workflow, edge, http_workflow, node
from tests.test_executions import run


def connect_http_credential(client, headers, token="s3cret-token-value"):
    response = client.post(
        "/api/v1/integrations",
        headers=headers,
        json={"provider": "http_auth", "name": "My API", "config": {"scheme": "bearer", "token": token}},
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_integration_secrets_are_encrypted_and_never_returned(client, auth):
    created = connect_http_credential(client, auth)
    assert "s3cret-token-value" not in str(created)
    listing = client.get("/api/v1/integrations", headers=auth)
    assert "s3cret-token-value" not in listing.text
    with Session(engine) as db:
        stored = db.exec(select(Integration)).one()
        assert "s3cret-token-value" not in stored.encrypted_secrets
        assert "s3cret-token-value" not in str(stored.public_config)


def test_http_credential_is_applied_but_not_logged(client, auth, http_server):
    server, base = http_server
    credential = connect_http_credential(client, auth)
    definition = http_workflow(base, path="/x")
    definition["nodes"][1]["config"].update(method="POST", body="{}", credential_integration_id=credential["id"])
    workflow = create_workflow(client, auth, definition)
    execution = run(client, auth, workflow["id"])
    assert execution["status"] == "succeeded"
    assert server.received[0]["headers"]["Authorization"] == "Bearer s3cret-token-value"
    detail = client.get(f"/api/v1/executions/{execution['id']}", headers=auth).text
    assert "s3cret-token-value" not in detail


def test_cannot_use_another_users_integration(client, auth, other_auth, http_server):
    _, base = http_server
    credential = connect_http_credential(client, other_auth)
    definition = http_workflow(base)
    definition["nodes"][1]["config"]["credential_integration_id"] = credential["id"]
    workflow = create_workflow(client, auth, definition)
    assert any(i["field"] == "credential_integration_id" for i in workflow["validation"])
    assert client.delete(f"/api/v1/integrations/{credential['id']}", headers=auth).status_code == 404


def test_slack_requires_webhook_url(client, auth):
    bad = client.post("/api/v1/integrations", headers=auth,
                      json={"provider": "slack", "name": "Slack", "config": {"webhook_url": "https://evil.example/x"}})
    assert bad.status_code == 400
    unknown = client.post("/api/v1/integrations", headers=auth, json={"provider": "github", "name": "x", "config": {}})
    assert unknown.status_code == 400


def test_smtp_integration_and_email_action(client, auth, monkeypatch):
    sent = []
    monkeypatch.setattr("app.services.integrations.verify_smtp", lambda config: None)
    monkeypatch.setattr("app.services.integrations._guard_host", lambda host, port: None)
    monkeypatch.setattr(
        "app.services.execution_engine.send_email",
        lambda config, to, subject, body: sent.append((config.password, to, subject, body)) or "<id@test>",
    )
    created = client.post("/api/v1/integrations", headers=auth, json={
        "provider": "smtp", "name": "Mail", "config": {"host": "smtp.example.com", "port": 587, "username": "bot",
                                                        "password": "mail-pass-1", "sender": "bot@example.com"}})
    assert created.status_code == 201 and "mail-pass-1" not in created.text
    definition = {
        "nodes": [node("t", "trigger.manual"),
                  node("mail", "action.email", config={"integration_id": created.json()["id"], "to": ["{{ trigger.payload.to }}"],
                                                       "subject": "Hello {{ trigger.payload.name }}", "body": "Body"})],
        "edges": [edge("t", "mail")],
    }
    workflow = create_workflow(client, auth, definition)
    execution = run(client, auth, workflow["id"], {"to": "ada@example.com", "name": "Ada"})
    assert execution["status"] == "succeeded", execution
    assert sent == [("mail-pass-1", ["ada@example.com"], "Hello Ada", "Body")]


def test_providers_mark_planned(client):
    providers = {p["key"]: p for p in client.get("/api/v1/integrations/providers").json()}
    assert providers["smtp"]["available"] and providers["slack"]["available"]
    assert not providers["github"]["available"] and not providers["google"]["available"]


def test_dashboard_reflects_real_data(client, auth, http_server):
    _, base = http_server
    empty = client.get("/api/v1/dashboard/summary", headers=auth).json()
    assert empty["total_workflows"] == 0 and empty["total_executions"] == 0
    assert empty["success_rate_30d"] is None and len(empty["trend"]) == 14

    ok = create_workflow(client, auth, http_workflow(base))
    bad = create_workflow(client, auth, http_workflow(base, path="/status/400"))
    run(client, auth, ok["id"])
    run(client, auth, ok["id"])
    run(client, auth, ok["id"])
    run(client, auth, bad["id"])
    bad_wf = client.get(f"/api/v1/workflows/{bad['id']}", headers=auth).json()
    client.post(f"/api/v1/workflows/{bad_wf['id']}/status", headers=auth, json={"status": "active"})

    summary = client.get("/api/v1/dashboard/summary", headers=auth).json()
    assert summary["total_workflows"] == 2 and summary["active_workflows"] == 1
    assert summary["total_executions"] == 4 and summary["success_rate_30d"] == 75.0
    assert summary["trend"][-1]["succeeded"] == 3 and summary["trend"][-1]["failed"] == 1
    assert summary["health"]["failures_24h"] == 1
    assert summary["health"]["attention"][0]["workflow_id"] == bad["id"]
    assert len(summary["recent_executions"]) == 4
    assert summary["recent_activity"]


def test_notifications(client, auth, http_server):
    _, base = http_server
    workflow = create_workflow(client, auth, http_workflow(base, path="/status/400"))
    run(client, auth, workflow["id"])
    listing = client.get("/api/v1/notifications", headers=auth).json()
    assert listing["unread"] == 1
    nid = listing["items"][0]["id"]
    assert client.post(f"/api/v1/notifications/{nid}/read", headers=auth).status_code == 200
    assert client.get("/api/v1/notifications", headers=auth).json()["unread"] == 0
