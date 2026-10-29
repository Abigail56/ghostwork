import uuid

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import func, update
from sqlmodel import select

from app.api.deps import CurrentUser, SessionDep
from app.models import ActivityEvent, Notification
from app.models.base import utcnow
from app.schemas.common import Message, Page
from app.schemas.integration import ActivityRead, NotificationList, NotificationRead

router = APIRouter(tags=["Notifications"])


@router.get("/notifications", response_model=NotificationList)
def list_notifications(user: CurrentUser, db: SessionDep, limit: int = Query(default=20, ge=1, le=50)):
    rows = db.exec(
        select(Notification).where(Notification.user_id == user.id).order_by(Notification.created_at.desc()).limit(limit)
    ).all()
    unread = db.exec(
        select(func.count()).select_from(Notification).where(Notification.user_id == user.id, Notification.read_at.is_(None))
    ).one()
    return NotificationList(items=[NotificationRead.model_validate(n, from_attributes=True) for n in rows], unread=unread)


@router.post("/notifications/{notification_id}/read", response_model=Message)
def mark_read(notification_id: uuid.UUID, user: CurrentUser, db: SessionDep):
    notification = db.get(Notification, notification_id)
    if notification is None or notification.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Notification not found.")
    if notification.read_at is None:
        notification.read_at = utcnow()
        db.add(notification)
        db.commit()
    return Message(message="Marked as read.")


@router.post("/notifications/read-all", response_model=Message)
def mark_all_read(user: CurrentUser, db: SessionDep):
    db.exec(
        update(Notification)
        .where(Notification.user_id == user.id, Notification.read_at.is_(None))
        .values(read_at=utcnow())
    )
    db.commit()
    return Message(message="All notifications marked as read.")


@router.get("/activity", response_model=Page[ActivityRead])
def list_activity(
    user: CurrentUser,
    db: SessionDep,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
):
    total = db.exec(select(func.count()).select_from(ActivityEvent).where(ActivityEvent.user_id == user.id)).one()
    rows = db.exec(
        select(ActivityEvent)
        .where(ActivityEvent.user_id == user.id)
        .order_by(ActivityEvent.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    return Page(items=[ActivityRead.model_validate(a, from_attributes=True) for a in rows], total=total, page=page, page_size=page_size)
