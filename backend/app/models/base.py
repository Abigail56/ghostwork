from datetime import UTC, datetime

from sqlalchemy import DateTime
from sqlmodel import Field


def utcnow() -> datetime:
    return datetime.now(UTC)


def created_at_field(index: bool = False):
    return Field(default_factory=utcnow, sa_type=DateTime(timezone=True), nullable=False, index=index)


def optional_timestamp_field(index: bool = False):
    return Field(default=None, sa_type=DateTime(timezone=True), nullable=True, index=index)
