from datetime import timedelta

from sqlmodel import Session, select

from app.core import rate_limit
from app.core.config import settings
from app.core.security import hash_token
from app.db.session import engine
from app.models import PasswordResetToken, RefreshSession, User
from app.models.base import utcnow
from tests.conftest import PASSWORD, register

CSRF = {"X-GhostWork-CSRF": "1"}


def test_register_hashes_password_with_argon2(client):
    body = register(client)
    assert body["user"]["email"] == "ada@example.com"
    assert "hashed_password" not in body["user"]
    with Session(engine) as db:
        user = db.exec(select(User)).one()
        assert user.hashed_password.startswith("$argon2id$")
        assert PASSWORD not in user.hashed_password


def test_register_sets_httponly_refresh_cookie(client):
    response = client.post(
        "/api/v1/auth/register", json={"email": "a@example.com", "full_name": "A", "password": PASSWORD, "accept_terms": True}
    )
    cookie = response.headers["set-cookie"]
    assert "gw_refresh=" in cookie
    assert "HttpOnly" in cookie
    assert "Path=/api/v1/auth" in cookie
    assert "samesite=lax" in cookie.lower()
    assert response.json()["refresh_token"] is None


def test_register_rejects_duplicate_email_case_insensitive(client):
    register(client)
    response = client.post(
        "/api/v1/auth/register", json={"email": "ADA@example.com", "full_name": "Ada", "password": PASSWORD, "accept_terms": True}
    )
    assert response.status_code == 409


def test_register_validates_password(client):
    for password in ["short1", "lettersonlypassword", "1234567890123"]:
        response = client.post(
            "/api/v1/auth/register", json={"email": "b@example.com", "full_name": "B", "password": password, "accept_terms": True}
        )
        assert response.status_code == 422


def test_login_success_and_failure(client):
    register(client)
    ok = client.post("/api/v1/auth/login", json={"email": "Ada@Example.com", "password": PASSWORD})
    assert ok.status_code == 200
    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {ok.json()['access_token']}"})
    assert me.status_code == 200 and me.json()["full_name"] == "Ada Lovelace"

    bad = client.post("/api/v1/auth/login", json={"email": "ada@example.com", "password": "wrong-password-1"})
    assert bad.status_code == 401
    unknown = client.post("/api/v1/auth/login", json={"email": "nobody@example.com", "password": PASSWORD})
    assert unknown.status_code == 401
    assert bad.json()["detail"] == unknown.json()["detail"]


def test_protected_route_requires_token(client):
    assert client.get("/api/v1/auth/me").status_code == 401
    assert client.get("/api/v1/auth/me", headers={"Authorization": "Bearer nonsense"}).status_code == 401


def test_refresh_requires_csrf_header(client):
    register(client)
    assert client.post("/api/v1/auth/refresh").status_code == 403
    assert client.post("/api/v1/auth/refresh", headers={**CSRF, "Origin": "https://evil.example"}).status_code == 403
    ok = client.post("/api/v1/auth/refresh", headers={**CSRF, "Origin": "http://localhost:3000"})
    assert ok.status_code == 200


def test_refresh_rotates_token_and_detects_reuse(client):
    register(client)
    first = client.cookies.get("gw_refresh")
    rotated = client.post("/api/v1/auth/refresh", headers=CSRF)
    assert rotated.status_code == 200
    second = client.cookies.get("gw_refresh")
    assert second and second != first

    # Replaying the old token right away is treated as a concurrent refresh.
    client.cookies.set("gw_refresh", first, path="/api/v1/auth")
    assert client.post("/api/v1/auth/refresh", headers=CSRF).status_code == 409

    # After the grace window, replay is treated as theft and the session is revoked.
    with Session(engine) as db:
        session = db.exec(select(RefreshSession)).one()
        session.last_used_at = utcnow() - timedelta(minutes=5)
        db.add(session)
        db.commit()
    assert client.post("/api/v1/auth/refresh", headers=CSRF).status_code == 401
    client.cookies.set("gw_refresh", second, path="/api/v1/auth")
    assert client.post("/api/v1/auth/refresh", headers=CSRF).status_code == 401
    access = rotated.json()["access_token"]
    assert client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {access}"}).status_code == 401


def test_logout_revokes_session_and_access_token(client):
    body = register(client)
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    assert client.post("/api/v1/auth/logout", headers=CSRF).status_code == 200
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 401
    # The cookie is cleared on logout, so the browser is simply signed out.
    assert client.post("/api/v1/auth/refresh", headers=CSRF).status_code == 204


def test_revoked_cookie_cannot_refresh(client):
    register(client)
    token = client.cookies.get("gw_refresh")
    client.post("/api/v1/auth/logout", headers=CSRF)
    client.cookies.set("gw_refresh", token, path="/api/v1/auth")
    assert client.post("/api/v1/auth/refresh", headers=CSRF).status_code == 401


def test_mobile_clients_receive_refresh_token_in_body(client):
    register(client)
    client.cookies.clear()
    login = client.post("/api/v1/auth/login", json={"email": "ada@example.com", "password": PASSWORD, "client": "mobile"})
    token = login.json()["refresh_token"]
    assert token and "set-cookie" not in login.headers
    refreshed = client.post("/api/v1/auth/refresh", json={"refresh_token": token})
    assert refreshed.status_code == 200
    assert refreshed.json()["refresh_token"] not in (None, token)


def test_sessions_list_and_revoke(client):
    body = register(client)
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    other = client.post("/api/v1/auth/login", json={"email": "ada@example.com", "password": PASSWORD, "client": "mobile"})
    other_headers = {"Authorization": f"Bearer {other.json()['access_token']}"}
    sessions = client.get("/api/v1/auth/sessions", headers=headers).json()
    assert len(sessions) == 2
    assert sum(s["current"] for s in sessions) == 1
    assert client.post("/api/v1/auth/sessions/revoke-others", headers=headers).status_code == 200
    assert client.get("/api/v1/auth/me", headers=other_headers).status_code == 401
    assert client.get("/api/v1/auth/me", headers=headers).status_code == 200


def test_cannot_revoke_another_users_session(client):
    a = register(client)
    b = register(client, email="b@example.com")
    b_session = client.get("/api/v1/auth/sessions", headers={"Authorization": f"Bearer {b['access_token']}"}).json()[0]
    response = client.delete(
        f"/api/v1/auth/sessions/{b_session['id']}", headers={"Authorization": f"Bearer {a['access_token']}"}
    )
    assert response.status_code == 404


def test_change_password(client):
    body = register(client)
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    wrong = client.post(
        "/api/v1/auth/change-password",
        headers=headers,
        json={"current_password": "nope-nope-1", "new_password": "brand-new-pass-7"},
    )
    assert wrong.status_code == 400
    ok = client.post(
        "/api/v1/auth/change-password",
        headers=headers,
        json={"current_password": PASSWORD, "new_password": "brand-new-pass-7"},
    )
    assert ok.status_code == 200
    assert client.post("/api/v1/auth/login", json={"email": "ada@example.com", "password": "brand-new-pass-7"}).status_code == 200


def test_forgot_password_reports_unconfigured_email(client):
    register(client)
    response = client.post("/api/v1/auth/forgot-password", json={"email": "ada@example.com"})
    assert response.status_code == 202
    assert response.json()["email_delivery_configured"] is False
    with Session(engine) as db:
        assert db.exec(select(PasswordResetToken)).first() is None


def test_forgot_and_reset_password_with_email(client, monkeypatch):
    register(client)
    sent = []
    monkeypatch.setattr(settings, "SMTP_HOST", "mail.test")
    monkeypatch.setattr("app.services.auth_service.send_email", lambda cfg, to, subject, body: sent.append(body))
    response = client.post("/api/v1/auth/forgot-password", json={"email": "ada@example.com"})
    assert response.json()["email_delivery_configured"] is True
    unknown = client.post("/api/v1/auth/forgot-password", json={"email": "ghost@example.com"})
    assert unknown.json()["message"] == response.json()["message"]
    assert len(sent) == 1
    token = sent[0].split("token=")[1].split()[0]

    reset = client.post("/api/v1/auth/reset-password", json={"token": token, "password": "after-reset-pass-9"})
    assert reset.status_code == 200
    again = client.post("/api/v1/auth/reset-password", json={"token": token, "password": "after-reset-pass-9"})
    assert again.status_code == 400
    assert client.post("/api/v1/auth/login", json={"email": "ada@example.com", "password": "after-reset-pass-9"}).status_code == 200
    with Session(engine) as db:
        stored = db.exec(select(PasswordResetToken)).one()
        assert stored.token_hash == hash_token(token)


def test_login_rate_limited(client):
    register(client)
    rate_limit.set_backend(rate_limit.MemoryBackend())
    codes = [
        client.post("/api/v1/auth/login", json={"email": "ada@example.com", "password": "wrong-pass-123"}).status_code
        for _ in range(11)
    ]
    assert codes[:10] == [401] * 10
    assert codes[10] == 429


def test_update_profile_and_preferences(client, auth):
    response = client.patch(
        "/api/v1/users/me", headers=auth, json={"full_name": "  Ada   King ", "density": "compact", "notify_on_success": True}
    )
    assert response.status_code == 200
    body = response.json()
    assert body["full_name"] == "Ada King" and body["density"] == "compact" and body["notify_on_success"] is True
    assert client.patch("/api/v1/users/me", headers=auth, json={"density": "huge"}).status_code == 422


def test_register_requires_terms_acceptance(client):
    base = {"email": "t@example.com", "full_name": "T", "password": PASSWORD}
    assert client.post("/api/v1/auth/register", json=base).status_code == 422
    rejected = client.post("/api/v1/auth/register", json={**base, "accept_terms": False})
    assert rejected.status_code == 422 and "Terms of Service" in rejected.text
    ok = client.post("/api/v1/auth/register", json={**base, "accept_terms": True})
    assert ok.status_code == 201
    user = ok.json()["user"]
    assert user["terms_version"] == settings.TERMS_VERSION and user["terms_accepted_at"]
