import os
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# Must be set before the app (and its settings) are imported.
_base = os.environ.get("TEST_DATABASE_URL")
if not _base:
    from dotenv import dotenv_values

    _url = dotenv_values(os.path.join(os.path.dirname(__file__), "..", ".env")).get("DATABASE_URL", "")
    _base = _url.rsplit("/", 1)[0] + "/ghostwork_test"
os.environ["DATABASE_URL"] = _base
os.environ["ENVIRONMENT"] = "test"
os.environ["CELERY_TASK_ALWAYS_EAGER"] = "true"
os.environ["SMTP_HOST"] = ""
# Pin limits so local .env overrides don't change test expectations.
os.environ["LOGIN_RATE_LIMIT_PER_5_MIN"] = "10"
os.environ["REGISTER_RATE_LIMIT_PER_HOUR"] = "50"
os.environ["ALLOW_PRIVATE_NETWORK_REQUESTS"] = "false"
os.environ.setdefault("INTEGRATION_ENCRYPTION_KEY", "kQhQ3dGcJYx5nHq3qQ2kD8yq8VYwU7b1b9h7cXz0M1s=")

import pytest  # noqa: E402
from alembic import command  # noqa: E402
from alembic.config import Config  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import text  # noqa: E402

from app.core import rate_limit  # noqa: E402
from app.core.config import settings  # noqa: E402
from app.db.session import engine  # noqa: E402
from app.main import app  # noqa: E402

PASSWORD = "correct-horse-42"


@pytest.fixture(scope="session", autouse=True)
def migrated_database():
    config = Config(os.path.join(os.path.dirname(__file__), "..", "alembic.ini"))
    config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)
    command.downgrade(config, "base")
    command.upgrade(config, "head")
    yield


@pytest.fixture(autouse=True)
def clean_tables():
    rate_limit.set_backend(rate_limit.MemoryBackend())
    yield
    with engine.begin() as conn:
        conn.execute(
            text(
                "TRUNCATE users, refresh_sessions, password_reset_tokens, workflows, workflow_executions, "
                "execution_steps, integrations, notifications, activity_events CASCADE"
            )
        )


@pytest.fixture
def client():
    with TestClient(app, base_url="http://localhost:8000") as c:
        yield c


def register(client, email="ada@example.com", name="Ada Lovelace", password=PASSWORD):
    response = client.post("/api/v1/auth/register", json={"email": email, "full_name": name, "password": password})
    assert response.status_code == 201, response.text
    return response.json()


@pytest.fixture
def auth(client):
    """Registered user; returns headers for authenticated requests."""
    body = register(client)
    return {"Authorization": f"Bearer {body['access_token']}"}


@pytest.fixture
def other_auth(client):
    body = register(client, email="mallory@example.com", name="Mallory")
    return {"Authorization": f"Bearer {body['access_token']}"}


class _Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, code: int, body: bytes, content_type="application/json"):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/status/"):
            self._send(int(self.path.split("/")[2]), b'{"error": true}')
        elif self.path == "/redirect-internal":
            self.send_response(302)
            self.send_header("Location", "http://169.254.169.254/latest/meta-data")
            self.send_header("Content-Length", "0")
            self.end_headers()
        else:
            self._send(200, b'{"name": "ghost", "count": 3, "items": [1, 2]}')

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        received = self.rfile.read(length)
        self.server.received.append({"headers": dict(self.headers), "body": received.decode()})
        self._send(201, b'{"ok": true}')


@pytest.fixture
def http_server(monkeypatch):
    """A local HTTP server. Private-network requests are allowed only for this test."""
    server = ThreadingHTTPServer(("127.0.0.1", 0), _Handler)
    server.received = []
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    monkeypatch.setattr(settings, "ALLOW_PRIVATE_NETWORK_REQUESTS", True)
    yield server, f"http://127.0.0.1:{server.server_address[1]}"
    server.shutdown()
    server.server_close()
