"""GitHub and Google API calls. Hosts are fixed, so credentials can only reach these services."""

import json
import time
from urllib.parse import quote, urlencode

import jwt

from app.services import net_guard

GITHUB_HOST = "api.github.com"
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
SHEETS_SCOPE = "https://www.googleapis.com/auth/spreadsheets"
FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"


class ExternalApiError(Exception):
    pass


def _error_message(body: object, fallback: str) -> str:
    if isinstance(body, dict):
        message = body.get("message") or body.get("error_description")
        error = body.get("error")
        if isinstance(error, dict):
            message = message or error.get("message")
        if isinstance(message, str):
            return message[:300]
    return fallback


def github_request(token: str, method: str, path: str, payload: dict | None = None) -> object:
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if payload is not None:
        headers["Content-Type"] = "application/json"
    try:
        response = net_guard.safe_request(
            method,
            f"https://{GITHUB_HOST}{path}",
            headers=headers,
            content=json.dumps(payload) if payload is not None else None,
            timeout=15,
            allowed_hosts={GITHUB_HOST},
        )
    except (net_guard.BlockedDestination, net_guard.RequestFailed) as exc:
        raise ExternalApiError(str(exc))
    if response.status_code >= 400:
        raise ExternalApiError(f"GitHub returned HTTP {response.status_code}: {_error_message(response.body, 'request failed')}")
    return response.body


def parse_service_account(raw: str) -> dict:
    try:
        info = json.loads(raw)
    except ValueError:
        raise ExternalApiError("That isn't valid JSON. Paste the whole service-account key file.")
    if not isinstance(info, dict) or info.get("type") != "service_account" or not info.get("client_email") or not info.get("private_key"):
        raise ExternalApiError("That isn't a Google service-account key file.")
    return info


def google_access_token(info: dict, scope: str) -> str:
    now = int(time.time())
    claims = {"iss": info["client_email"], "scope": scope, "aud": GOOGLE_TOKEN_URL, "iat": now, "exp": now + 3600}
    try:
        assertion = jwt.encode(claims, info["private_key"], algorithm="RS256")
    except Exception:
        raise ExternalApiError("The service-account private key couldn't be read.")
    try:
        # The token URL is fixed: a token_uri inside the key file is deliberately ignored.
        response = net_guard.safe_request(
            "POST",
            GOOGLE_TOKEN_URL,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            content=urlencode({"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion}),
            timeout=15,
            allowed_hosts={"oauth2.googleapis.com"},
        )
    except (net_guard.BlockedDestination, net_guard.RequestFailed) as exc:
        raise ExternalApiError(str(exc))
    token = response.body.get("access_token") if isinstance(response.body, dict) else None
    if response.status_code >= 400 or not token:
        raise ExternalApiError(f"Google rejected the service account: {_error_message(response.body, 'sign-in failed')}")
    return token


def sheets_request(info: dict, method: str, spreadsheet_id: str, path: str, payload: dict | None = None) -> object:
    token = google_access_token(info, SHEETS_SCOPE)
    headers = {"Authorization": f"Bearer {token}"}
    if payload is not None:
        headers["Content-Type"] = "application/json"
    try:
        response = net_guard.safe_request(
            method,
            f"https://sheets.googleapis.com/v4/spreadsheets/{quote(spreadsheet_id, safe='')}{path}",
            headers=headers,
            content=json.dumps(payload) if payload is not None else None,
            timeout=15,
            allowed_hosts={"sheets.googleapis.com"},
        )
    except (net_guard.BlockedDestination, net_guard.RequestFailed) as exc:
        raise ExternalApiError(str(exc))
    if response.status_code >= 400:
        hint = " Share the spreadsheet with the service account's email." if response.status_code == 403 else ""
        raise ExternalApiError(f"Google Sheets returned HTTP {response.status_code}: {_error_message(response.body, 'request failed')}.{hint}")
    return response.body
