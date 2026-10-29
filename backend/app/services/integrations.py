"""Supported integration providers. Secrets are encrypted at rest and never returned."""

import uuid
from dataclasses import dataclass
from typing import Callable, Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, ValidationError, field_validator
from sqlmodel import Session, select

from app.core.security import decrypt_secrets, encrypt_secrets
from app.models import Integration
from app.models.base import utcnow
from app.services import net_guard
from app.services.mailer import MailError, SmtpConfig, verify_smtp


class IntegrationError(Exception):
    pass


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class SmtpInput(_Strict):
    host: str = Field(min_length=1, max_length=255, pattern=r"^[A-Za-z0-9.\-]+$")
    port: int = Field(default=587, ge=1, le=65535)
    username: str | None = Field(default=None, max_length=255)
    password: str | None = Field(default=None, max_length=500)
    use_tls: bool = True
    sender: EmailStr


class SlackInput(_Strict):
    webhook_url: str = Field(max_length=500)

    @field_validator("webhook_url")
    @classmethod
    def _slack_url(cls, value: str) -> str:
        if not value.startswith("https://hooks.slack.com/services/"):
            raise ValueError("Use a Slack incoming webhook URL (https://hooks.slack.com/services/...).")
        return value


class HttpAuthInput(_Strict):
    scheme: Literal["bearer", "header"] = "bearer"
    header_name: str = Field(default="Authorization", max_length=100, pattern=r"^[A-Za-z0-9\-_]+$")
    token: str = Field(min_length=1, max_length=4000)


@dataclass(frozen=True)
class Provider:
    key: str
    label: str
    input_model: type[_Strict]
    secret_fields: tuple[str, ...]
    verify: Callable[[dict, dict], None] | None


def _smtp_config(public: dict, secrets: dict) -> SmtpConfig:
    return SmtpConfig(
        host=public["host"],
        port=public["port"],
        username=public.get("username"),
        password=secrets.get("password"),
        use_tls=public.get("use_tls", True),
        sender=public["sender"],
    )


def _guard_host(host: str, port: int) -> None:
    try:
        net_guard.resolve_safe(host, port)
    except (net_guard.BlockedDestination, net_guard.RequestFailed) as exc:
        raise IntegrationError(str(exc))


def _verify_smtp(public: dict, secrets: dict) -> None:
    _guard_host(public["host"], public["port"])
    try:
        verify_smtp(_smtp_config(public, secrets))
    except MailError as exc:
        raise IntegrationError(str(exc))


PROVIDERS: dict[str, Provider] = {
    "smtp": Provider("smtp", "Email (SMTP)", SmtpInput, ("password",), _verify_smtp),
    # Slack has no side-effect-free check for incoming webhooks; the URL shape is validated.
    "slack": Provider("slack", "Slack", SlackInput, ("webhook_url",), None),
    "http_auth": Provider("http_auth", "HTTP credential", HttpAuthInput, ("token",), None),
}


def split_config(provider: Provider, raw: dict) -> tuple[dict, dict]:
    try:
        parsed = provider.input_model.model_validate(raw).model_dump(mode="json")
    except ValidationError as exc:
        message = "; ".join(e["msg"].removeprefix("Value error, ") for e in exc.errors())
        raise IntegrationError(message)
    secrets = {k: parsed.pop(k) for k in provider.secret_fields if k in parsed}
    return parsed, secrets


def public_view(integration: Integration) -> dict:
    view = dict(integration.public_config)
    if integration.provider == "slack":
        view["webhook"] = "hooks.slack.com/services/••••"
    if integration.provider == "http_auth":
        view["token"] = "••••••••"
    return view


def create_integration(db: Session, owner_id: uuid.UUID, provider_key: str, name: str, raw: dict) -> Integration:
    provider = PROVIDERS.get(provider_key)
    if provider is None:
        raise IntegrationError("This integration is not available yet.")
    public, secrets = split_config(provider, raw)
    if provider_key == "smtp":
        public["has_password"] = bool(secrets.get("password"))
    now = utcnow()
    integration = Integration(
        owner_id=owner_id,
        provider=provider_key,
        name=name,
        public_config=public,
        encrypted_secrets=encrypt_secrets(secrets),
        created_at=now,
        updated_at=now,
    )
    if provider.verify is not None:
        try:
            provider.verify(public, secrets)
        except IntegrationError as exc:
            raise IntegrationError(f"Connection check failed: {exc}")
        integration.last_verified_at = now
    db.add(integration)
    return integration


def test_integration(db: Session, integration: Integration) -> None:
    provider = PROVIDERS[integration.provider]
    if provider.verify is None:
        raise IntegrationError("This integration can't be checked without sending a message.")
    try:
        provider.verify(integration.public_config, decrypt_secrets(integration.encrypted_secrets))
        integration.status, integration.last_error = "connected", None
        integration.last_verified_at = utcnow()
    except IntegrationError as exc:
        integration.status, integration.last_error = "error", str(exc)[:500]
        raise
    finally:
        integration.updated_at = utcnow()
        db.add(integration)


def owner_integrations(db: Session, owner_id: uuid.UUID) -> dict[uuid.UUID, str]:
    rows = db.exec(select(Integration.id, Integration.provider).where(Integration.owner_id == owner_id))
    return {row[0]: row[1] for row in rows}


def load_for_execution(db: Session, owner_id: uuid.UUID, integration_id: uuid.UUID, provider: str) -> tuple[dict, dict]:
    integration = db.get(Integration, integration_id)
    if integration is None or integration.owner_id != owner_id or integration.provider != provider:
        raise IntegrationError("The integration used by this step is no longer connected.")
    return integration.public_config, decrypt_secrets(integration.encrypted_secrets)


def smtp_from(public: dict, secrets: dict) -> SmtpConfig:
    return _smtp_config(public, secrets)
