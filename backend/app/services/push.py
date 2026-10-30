"""Push notifications: Web Push (browsers, VAPID) and Firebase Cloud Messaging (Android, iOS)."""

import json
import logging
import uuid
from urllib.parse import urlsplit

from pywebpush import WebPushException, webpush
from sqlmodel import Session, select

from app.core.config import settings
from app.models import PushSubscription
from app.services import net_guard
from app.services.external_apis import FCM_SCOPE, ExternalApiError, google_access_token, parse_service_account

logger = logging.getLogger(__name__)

# Subscription endpoints come from the client, so only real push services are accepted (SSRF guard).
_WEB_PUSH_SUFFIXES = (".googleapis.com", ".mozilla.com", ".push.apple.com", ".notify.windows.com")


def web_push_enabled() -> bool:
    return bool(settings.VAPID_PRIVATE_KEY and settings.VAPID_PUBLIC_KEY)


def fcm_enabled() -> bool:
    return bool(settings.FCM_SERVICE_ACCOUNT_FILE)


def valid_web_push_endpoint(endpoint: str) -> bool:
    parts = urlsplit(endpoint)
    host = parts.hostname or ""
    return parts.scheme == "https" and any(host.endswith(s) for s in _WEB_PUSH_SUFFIXES)


def _send_web_push(sub: PushSubscription, payload: dict) -> bool:
    """Returns False when the subscription no longer exists; raises when delivery failed."""
    try:
        webpush(
            subscription_info={"endpoint": sub.endpoint, "keys": sub.keys},
            data=json.dumps(payload),
            vapid_private_key=settings.VAPID_PRIVATE_KEY,
            vapid_claims={"sub": settings.VAPID_SUBJECT},
            timeout=10,
        )
    except WebPushException as exc:
        status = exc.response.status_code if exc.response is not None else None
        if status in (404, 410):
            return False
        raise ExternalApiError(f"Web push failed with status {status}") from exc
    return True


def _send_fcm(sub: PushSubscription, payload: dict) -> bool:
    with open(settings.FCM_SERVICE_ACCOUNT_FILE) as handle:
        info = parse_service_account(handle.read())
    token = google_access_token(info, FCM_SCOPE)
    message = {
        "message": {
            "token": sub.endpoint,
            "notification": {"title": payload["title"], "body": payload["body"]},
            "data": {"link": payload.get("link") or ""},
        }
    }
    response = net_guard.safe_request(
        "POST",
        f"https://fcm.googleapis.com/v1/projects/{info.get('project_id')}/messages:send",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        content=json.dumps(message),
        timeout=10,
        allowed_hosts={"fcm.googleapis.com"},
    )
    if response.status_code == 404:
        return False
    if response.status_code >= 400:
        raise ExternalApiError(f"FCM push failed with status {response.status_code}")
    return True


def send_push(db: Session, user_id: uuid.UUID, title: str, body: str = "", link: str | None = None) -> int:
    """Best effort: a push failure must never affect the run that triggered it. Returns devices reached."""
    subs = db.exec(select(PushSubscription).where(PushSubscription.user_id == user_id)).all()
    payload = {"title": title[:160], "body": body[:300], "link": link}
    sent = 0
    for sub in subs:
        try:
            if sub.kind == "webpush":
                alive = web_push_enabled() and _send_web_push(sub, payload)
                configured = web_push_enabled()
            else:
                configured = fcm_enabled()
                alive = configured and _send_fcm(sub, payload)
        except (ExternalApiError, net_guard.BlockedDestination, net_guard.RequestFailed, OSError, ValueError) as exc:
            logger.warning("Push delivery error: %s: %s", type(exc).__name__, exc)
            continue
        if not configured:
            continue
        if alive:
            sent += 1
        else:
            db.delete(sub)
    return sent
