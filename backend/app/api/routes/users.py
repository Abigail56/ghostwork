from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.models.base import utcnow
from app.schemas.auth import UserRead, UserUpdate
from app.services.activity import record_activity

router = APIRouter(prefix="/users", tags=["Users"])


@router.patch("/me", response_model=UserRead)
def update_me(payload: UserUpdate, user: CurrentUser, db: SessionDep):
    changes = payload.model_dump(exclude_unset=True, exclude_none=True)
    for key, value in changes.items():
        setattr(user, key, value)
    if changes:
        user.updated_at = utcnow()
        db.add(user)
        if "full_name" in changes:
            record_activity(db, user.id, "account.profile_updated", "Profile updated")
        db.commit()
        db.refresh(user)
    return user
