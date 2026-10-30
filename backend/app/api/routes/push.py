from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlmodel import select

from app.api.deps import CurrentUser, SessionDep
from app.core.config import settings
from app.core.rate_limit import RateLimit
from app.models import PushSubscription
from app.schemas.common import Message
from app.services import push

router = APIRouter(prefix="/push", tags=["Push notifications"])


class PushConfig(BaseModel):
    web_push_public_key: str | None
    fcm_enabled: bool


class SubscriptionCreate(BaseModel):
    kind: Literal["webpush", "fcm"]
    endpoint: str = Field(min_length=1, max_length=1000, description="Web Push endpoint URL or FCM device token.")
    keys: dict[str, str] = Field(default_factory=dict, description="Web Push p256dh and auth keys.")


class SubscriptionDelete(BaseModel):
    endpoint: str = Field(min_length=1, max_length=1000)


@router.get("/config", response_model=PushConfig)
def config():
    return PushConfig(
        web_push_public_key=settings.VAPID_PUBLIC_KEY if push.web_push_enabled() else None,
        fcm_enabled=push.fcm_enabled(),
    )


@router.post("/subscriptions", response_model=Message, status_code=status.HTTP_201_CREATED)
def subscribe(payload: SubscriptionCreate, user: CurrentUser, db: SessionDep):
    if payload.kind == "webpush":
        if not push.web_push_enabled():
            raise HTTPException(status.HTTP_409_CONFLICT, "Browser push isn't configured on this server.")
        if not push.valid_web_push_endpoint(payload.endpoint) or not {"p256dh", "auth"} <= payload.keys.keys():
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "That isn't a valid push subscription.")
    elif not push.fcm_enabled():
        raise HTTPException(status.HTTP_409_CONFLICT, "Mobile push isn't configured on this server.")
    existing = db.exec(select(PushSubscription).where(PushSubscription.endpoint == payload.endpoint)).first()
    if existing is not None:
        # A device belongs to whoever signed in on it last.
        existing.user_id, existing.kind, existing.keys = user.id, payload.kind, payload.keys
        db.add(existing)
    else:
        db.add(PushSubscription(user_id=user.id, kind=payload.kind, endpoint=payload.endpoint, keys=payload.keys))
    db.commit()
    return Message(message="This device will receive push notifications.")


@router.delete("/subscriptions", response_model=Message)
def unsubscribe(payload: SubscriptionDelete, user: CurrentUser, db: SessionDep):
    existing = db.exec(
        select(PushSubscription).where(PushSubscription.endpoint == payload.endpoint, PushSubscription.user_id == user.id)
    ).first()
    if existing is not None:
        db.delete(existing)
        db.commit()
    return Message(message="Push notifications turned off for this device.")


@router.post("/test", response_model=Message, dependencies=[Depends(RateLimit("push_test", 10, 300))])
def send_test(user: CurrentUser, db: SessionDep):
    sent = push.send_push(db, user.id, "GhostWork test notification", "Push notifications are working.", "/settings?tab=notifications")
    db.commit()
    if sent == 0:
        raise HTTPException(status.HTTP_409_CONFLICT, "No device could be reached. Turn on push for this device first.")
    return Message(message=f"Sent to {sent} device{'s' if sent != 1 else ''}.")
