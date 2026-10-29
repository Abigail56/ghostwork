import uuid

from sqlmodel import Session

from app.models import ActivityEvent, Notification


def record_activity(
    db: Session,
    user_id: uuid.UUID,
    kind: str,
    message: str,
    workflow_id: uuid.UUID | None = None,
    details: dict | None = None,
) -> None:
    """Add an activity event to the current transaction (caller commits)."""
    db.add(
        ActivityEvent(
            user_id=user_id, kind=kind, message=message[:300], workflow_id=workflow_id, details=details or {}
        )
    )


def notify(db: Session, user_id: uuid.UUID, kind: str, title: str, body: str = "", link: str | None = None) -> None:
    db.add(Notification(user_id=user_id, kind=kind, title=title[:160], body=body[:500], link=link))
