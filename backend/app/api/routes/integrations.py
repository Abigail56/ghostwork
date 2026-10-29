import uuid

from fastapi import APIRouter, HTTPException, status
from sqlmodel import select

from app.api.deps import CurrentUser, SessionDep
from app.core.security import SecretBoxError
from app.models import Integration
from app.schemas.common import Message
from app.schemas.integration import IntegrationCreate, IntegrationRead, ProviderRead
from app.services import integrations as service
from app.services.activity import record_activity

router = APIRouter(prefix="/integrations", tags=["Integrations"])

_DESCRIPTIONS = {
    "smtp": "Send email from workflows through any SMTP server you control.",
    "slack": "Post messages to a Slack channel with an incoming webhook.",
    "http_auth": "Store an API token once and attach it to HTTP request steps.",
}
PLANNED = [
    ProviderRead(key="google", label="Google Workspace", available=False, verifiable=False,
                 description="Sheets, Gmail and Drive actions. Planned."),
    ProviderRead(key="github", label="GitHub", available=False, verifiable=False,
                 description="Issue, pull request and repository events. Planned."),
]


def _read(integration: Integration) -> IntegrationRead:
    return IntegrationRead(
        id=integration.id,
        provider=integration.provider,
        name=integration.name,
        status=integration.status,
        last_error=integration.last_error,
        last_verified_at=integration.last_verified_at,
        created_at=integration.created_at,
        details=service.public_view(integration),
    )


def _get_owned(db, owner_id: uuid.UUID, integration_id: uuid.UUID) -> Integration:
    integration = db.get(Integration, integration_id)
    if integration is None or integration.owner_id != owner_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Integration not found.")
    return integration


@router.get("/providers", response_model=list[ProviderRead])
def providers():
    available = [
        ProviderRead(key=p.key, label=p.label, available=True, description=_DESCRIPTIONS[p.key],
                     verifiable=p.verify is not None)
        for p in service.PROVIDERS.values()
    ]
    return available + PLANNED


@router.get("", response_model=list[IntegrationRead])
def list_integrations(user: CurrentUser, db: SessionDep):
    rows = db.exec(select(Integration).where(Integration.owner_id == user.id).order_by(Integration.created_at)).all()
    return [_read(i) for i in rows]


@router.post("", response_model=IntegrationRead, status_code=status.HTTP_201_CREATED)
def connect(payload: IntegrationCreate, user: CurrentUser, db: SessionDep):
    try:
        integration = service.create_integration(db, user.id, payload.provider, payload.name.strip(), payload.config)
    except (service.IntegrationError, SecretBoxError) as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc))
    db.flush()
    record_activity(db, user.id, "integration.connected", f"{integration.name} connected")
    db.commit()
    db.refresh(integration)
    return _read(integration)


@router.post("/{integration_id}/test", response_model=IntegrationRead)
def test(integration_id: uuid.UUID, user: CurrentUser, db: SessionDep):
    integration = _get_owned(db, user.id, integration_id)
    try:
        service.test_integration(db, integration)
    except (service.IntegrationError, SecretBoxError) as exc:
        db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Connection check failed: {exc}")
    db.commit()
    db.refresh(integration)
    return _read(integration)


@router.delete("/{integration_id}", response_model=Message)
def disconnect(integration_id: uuid.UUID, user: CurrentUser, db: SessionDep):
    integration = _get_owned(db, user.id, integration_id)
    record_activity(db, user.id, "integration.disconnected", f"{integration.name} disconnected")
    db.delete(integration)
    db.commit()
    return Message(message="Integration disconnected. Steps that used it will need a new connection.")
