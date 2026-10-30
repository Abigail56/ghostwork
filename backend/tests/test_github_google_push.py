import json
import uuid
from types import SimpleNamespace

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from sqlmodel import Session, select

from app.core.config import settings
from app.db.session import engine
from app.models import Integration, PushSubscription
from app.services import net_guard, push
from tests.helpers import create_workflow, edge, node
from tests.test_executions import run

KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048).private_bytes(
    serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()
).decode()
SERVICE_ACCOUNT = json.dumps({
    "type": "service_account", "client_email": "bot@demo.iam.gserviceaccount.com", "private_key": KEY,
    "project_id": "demo", "token_uri": "https://evil.example/steal",
})


def fake_api(monkeypatch, routes):
    """Replace outbound HTTP; records calls. `routes` maps a substring of the URL to (status, body)."""
    calls = []

    def request(method, url, **kwargs):
        calls.append({"method": method, "url": url, **kwargs})
        for fragment, (status, body) in routes.items():
            if fragment in url:
                host = url.split("/")[2]
                assert host in kwargs["allowed_hosts"]
                return SimpleNamespace(status_code=status, body=body, headers={}, truncated=False, url=url)
        raise AssertionError(f"unexpected request: {url}")

    monkeypatch.setattr(net_guard, "safe_request", request)
    return calls


def connect(client, auth, provider, config):
    response = client.post("/api/v1/integrations", headers=auth, json={"provider": provider, "name": provider, "config": config})
    assert response.status_code == 201, response.text
    return response.json()


def flow(type_, config):
    return {"nodes": [node("t", "trigger.manual"), node("a", type_, config=config)], "edges": [edge("t", "a")]}


def test_github_connect_keeps_the_token_secret(client, auth, monkeypatch):
    fake_api(monkeypatch, {"/user": (200, {"login": "ada"})})
    created = connect(client, auth, "github", {"token": "ghp_secret"})
    assert created["details"]["account"] == "ada" and "ghp_secret" not in json.dumps(created)
    with Session(engine) as db:
        assert "ghp_secret" not in db.exec(select(Integration)).one().encrypted_secrets


def test_github_rejects_a_bad_token(client, auth, monkeypatch):
    fake_api(monkeypatch, {"/user": (401, {"message": "Bad credentials"})})
    response = client.post("/api/v1/integrations", headers=auth, json={"provider": "github", "name": "g", "config": {"token": "x"}})
    assert response.status_code == 400 and "Bad credentials" in response.text


def test_github_issue_step(client, auth, monkeypatch):
    calls = fake_api(monkeypatch, {
        "/user": (200, {"login": "ada"}),
        "/repos/ada/app/issues": (201, {"number": 7, "html_url": "https://github.com/ada/app/issues/7"}),
    })
    integration = connect(client, auth, "github", {"token": "ghp_secret"})
    workflow = create_workflow(client, auth, flow("action.github_issue", {
        "integration_id": integration["id"], "repository": "ada/app", "title": "Broken: {{ trigger.payload.what }}", "labels": ["bug"],
    }))
    assert workflow["validation"] == []
    execution = run(client, auth, workflow["id"], {"what": "login"})
    assert execution["status"] == "succeeded", execution
    assert execution["steps"][1]["output"]["number"] == 7
    assert "ghp_secret" not in json.dumps(execution)
    call = calls[-1]
    assert call["headers"]["Authorization"] == "Bearer ghp_secret"
    assert json.loads(call["content"]) == {"title": "Broken: login", "body": "", "labels": ["bug"]}


def test_github_issue_rejects_path_tricks_from_templates(client, auth, monkeypatch):
    fake_api(monkeypatch, {"/user": (200, {"login": "ada"})})
    integration = connect(client, auth, "github", {"token": "t"})
    workflow = create_workflow(client, auth, flow("action.github_issue", {
        "integration_id": integration["id"], "repository": "{{ trigger.payload.repo }}", "title": "x",
    }))
    execution = run(client, auth, workflow["id"], {"repo": "../../user/keys"})
    assert execution["status"] == "failed" and "owner/name" in execution["error_message"]


def test_google_ignores_token_uri_in_the_key_file(client, auth, monkeypatch):
    calls = fake_api(monkeypatch, {"oauth2.googleapis.com/token": (200, {"access_token": "ya29"})})
    created = connect(client, auth, "google", {"service_account_json": SERVICE_ACCOUNT})
    assert created["details"]["service_account"] == "bot@demo.iam.gserviceaccount.com"
    assert "PRIVATE KEY" not in json.dumps(created)
    assert calls[0]["url"] == "https://oauth2.googleapis.com/token"


def test_google_rejects_other_json(client, auth):
    response = client.post("/api/v1/integrations", headers=auth, json={"provider": "google", "name": "g", "config": {"service_account_json": '{"a": 1}'}})
    assert response.status_code == 400 and "service-account" in response.text


def test_sheets_append_and_read_steps(client, auth, monkeypatch):
    calls = fake_api(monkeypatch, {
        "oauth2.googleapis.com/token": (200, {"access_token": "ya29"}),
        ":append": (200, {"updates": {"updatedRange": "Sheet1!A2:B2"}}),
        "/values/Sheet1": (200, {"range": "Sheet1!A1:B2", "values": [["a", "b"], ["c", "d"]]}),
    })
    integration = connect(client, auth, "google", {"service_account_json": SERVICE_ACCOUNT})
    append = create_workflow(client, auth, flow("action.sheets_append", {
        "integration_id": integration["id"], "spreadsheet_id": "abc", "values": ["{{ trigger.payload.n }}", "x"],
    }))
    assert append["validation"] == []
    result = run(client, auth, append["id"], {"n": 5})
    assert result["status"] == "succeeded", result
    assert result["steps"][1]["output"] == {"appended": ["5", "x"], "range": "Sheet1!A2:B2"}
    assert json.loads(calls[-1]["content"]) == {"values": [["5", "x"]]}

    read = create_workflow(client, auth, flow("action.sheets_read", {"integration_id": integration["id"], "spreadsheet_id": "abc"}))
    output = run(client, auth, read["id"])["steps"][1]["output"]
    assert output["row_count"] == 2 and output["rows"][1] == ["c", "d"]


def test_github_style_webhook_signature(client, auth):
    import hashlib
    import hmac

    workflow = create_workflow(client, auth, {
        "nodes": [node("h", "trigger.webhook"), node("a", "action.transform", config={"fields": [{"key": "x", "value": "1"}]})],
        "edges": [edge("h", "a")],
    })
    client.post(f"/api/v1/workflows/{workflow['id']}/status", headers=auth, json={"status": "active"})
    secret = client.post(f"/api/v1/workflows/{workflow['id']}/webhook/secret", headers=auth).json()["secret"]
    path = workflow["webhook_url"].split("localhost:8000")[1]
    signature = "sha256=" + hmac.new(secret.encode(), b"{}", hashlib.sha256).hexdigest()
    headers = {"Content-Type": "application/json", "X-Hub-Signature-256": signature}
    assert client.post(path, content=b"{}", headers=headers).status_code == 202


WEB_SUB = {"kind": "webpush", "endpoint": "https://fcm.googleapis.com/fcm/send/abc", "keys": {"p256dh": "k", "auth": "a"}}


def test_push_needs_server_configuration(client, auth, monkeypatch):
    monkeypatch.setattr(settings, "VAPID_PRIVATE_KEY", "")
    monkeypatch.setattr(settings, "VAPID_PUBLIC_KEY", "")
    assert client.get("/api/v1/push/config").json() == {"web_push_public_key": None, "fcm_enabled": False}
    assert client.post("/api/v1/push/subscriptions", headers=auth, json=WEB_SUB).status_code == 409


def test_push_rejects_endpoints_that_are_not_push_services(client, auth, monkeypatch):
    monkeypatch.setattr(settings, "VAPID_PRIVATE_KEY", "x")
    monkeypatch.setattr(settings, "VAPID_PUBLIC_KEY", "y")
    for endpoint in ["http://127.0.0.1/x", "https://evil.example/x", "https://169.254.169.254/x", "https://googleapis.com.evil.example/x"]:
        response = client.post("/api/v1/push/subscriptions", headers=auth, json={**WEB_SUB, "endpoint": endpoint})
        assert response.status_code == 400, endpoint


def test_failed_run_pushes_and_dead_devices_are_removed(client, auth, monkeypatch):
    monkeypatch.setattr(settings, "VAPID_PRIVATE_KEY", "x")
    monkeypatch.setattr(settings, "VAPID_PUBLIC_KEY", "y")
    sent = []

    def fake_webpush(subscription_info, data, **kwargs):
        sent.append(json.loads(data))

    monkeypatch.setattr(push, "webpush", fake_webpush)
    assert client.post("/api/v1/push/subscriptions", headers=auth, json=WEB_SUB).status_code == 201
    assert client.post("/api/v1/push/test", headers=auth).status_code == 200
    assert sent[-1]["title"] == "GhostWork test notification"

    monkeypatch.setattr(settings, "ALLOW_PRIVATE_NETWORK_REQUESTS", False)
    workflow = create_workflow(client, auth, flow("action.http_request", {"url": "http://127.0.0.1/"}))
    assert run(client, auth, workflow["id"])["status"] == "failed"
    assert sent[-1]["title"].endswith("failed") and sent[-1]["link"].startswith("/executions/")

    def gone(subscription_info, data, **kwargs):
        raise push.WebPushException("gone", response=SimpleNamespace(status_code=410))

    monkeypatch.setattr(push, "webpush", gone)
    assert client.post("/api/v1/push/test", headers=auth).status_code == 409
    with Session(engine) as db:
        assert db.exec(select(PushSubscription)).first() is None


def test_push_respects_the_preference(client, auth, monkeypatch):
    monkeypatch.setattr(settings, "VAPID_PRIVATE_KEY", "x")
    monkeypatch.setattr(settings, "VAPID_PUBLIC_KEY", "y")
    sent = []
    monkeypatch.setattr(push, "webpush", lambda subscription_info, data, **k: sent.append(data))
    client.post("/api/v1/push/subscriptions", headers=auth, json=WEB_SUB)
    client.patch("/api/v1/users/me", headers=auth, json={"push_on_failure": False})
    workflow = create_workflow(client, auth, flow("action.http_request", {"url": "http://127.0.0.1/"}))
    run(client, auth, workflow["id"])
    assert sent == []


def test_web_push_payload_is_really_encrypted_for_the_browser(monkeypatch):
    """Runs pywebpush for real and decrypts what would go to the push service, as a browser would."""
    import base64
    import os

    import http_ece
    import pywebpush
    from cryptography.hazmat.primitives.asymmetric import ec

    b64 = lambda raw: base64.urlsafe_b64encode(raw).decode().rstrip("=")
    vapid = ec.generate_private_key(ec.SECP256R1())
    monkeypatch.setattr(settings, "VAPID_PRIVATE_KEY", b64(vapid.private_numbers().private_value.to_bytes(32, "big")))
    monkeypatch.setattr(settings, "VAPID_PUBLIC_KEY", "unused")
    browser = ec.generate_private_key(ec.SECP256R1())
    auth_secret = os.urandom(16)
    browser_public = browser.public_key().public_bytes(serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
    sent = {}

    def fake_post(url, data=None, headers=None, timeout=None):
        sent.update(url=url, data=data, headers=headers)
        return SimpleNamespace(status_code=201, text="", headers={})

    monkeypatch.setattr(pywebpush.requests, "post", fake_post)
    sub = PushSubscription(
        user_id=uuid.uuid4(),
        kind="webpush",
        endpoint="https://fcm.googleapis.com/fcm/send/device",
        keys={"p256dh": b64(browser_public), "auth": b64(auth_secret)},
    )
    assert push._send_web_push(sub, {"title": "Run failed", "body": "Step 2"}) is True
    assert b"Run failed" not in sent["data"]
    assert sent["headers"]["Authorization"].startswith("vapid t=")
    decrypted = http_ece.decrypt(sent["data"], private_key=browser, auth_secret=auth_secret, version="aes128gcm")
    assert json.loads(decrypted) == {"title": "Run failed", "body": "Step 2"}


def test_a_failed_delivery_is_not_counted_as_sent(client, auth, monkeypatch):
    monkeypatch.setattr(settings, "VAPID_PRIVATE_KEY", "x")
    monkeypatch.setattr(settings, "VAPID_PUBLIC_KEY", "y")

    def rejected(**_):
        raise push.WebPushException("rate limited", response=SimpleNamespace(status_code=429))

    monkeypatch.setattr(push, "webpush", rejected)
    assert client.post(
        "/api/v1/push/subscriptions",
        json={"kind": "webpush", "endpoint": "https://fcm.googleapis.com/fcm/send/a", "keys": {"p256dh": "k", "auth": "a"}},
        headers=auth,
    ).status_code == 201
    assert client.post("/api/v1/push/test", headers=auth).status_code == 409
    with Session(engine) as db:
        assert db.exec(select(PushSubscription).where(PushSubscription.endpoint.endswith("/a"))).first() is not None
