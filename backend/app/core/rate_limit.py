"""Fixed-window rate limiting backed by Redis (in-memory backend for tests)."""

import logging
import threading
import time
from dataclasses import dataclass

import redis
from fastapi import HTTPException, Request, status

from app.core.config import settings

logger = logging.getLogger(__name__)


class RateLimitBackend:
    def hit(self, key: str, window_seconds: int) -> int:
        raise NotImplementedError


class RedisBackend(RateLimitBackend):
    def __init__(self, url: str):
        self._client = redis.Redis.from_url(url, socket_timeout=1, socket_connect_timeout=1)

    def hit(self, key: str, window_seconds: int) -> int:
        pipe = self._client.pipeline()
        pipe.incr(key)
        pipe.expire(key, window_seconds, nx=True)
        count, _ = pipe.execute()
        return int(count)


class MemoryBackend(RateLimitBackend):
    def __init__(self):
        self._lock = threading.Lock()
        self._data: dict[str, tuple[int, float]] = {}

    def hit(self, key: str, window_seconds: int) -> int:
        now = time.monotonic()
        with self._lock:
            count, expires = self._data.get(key, (0, now + window_seconds))
            if now > expires:
                count, expires = 0, now + window_seconds
            count += 1
            self._data[key] = (count, expires)
            return count

    def reset(self) -> None:
        with self._lock:
            self._data.clear()


_backend: RateLimitBackend | None = None


def get_backend() -> RateLimitBackend:
    global _backend
    if _backend is None:
        _backend = RedisBackend(settings.REDIS_URL)
    return _backend


def set_backend(backend: RateLimitBackend) -> None:
    global _backend
    _backend = backend


def client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


@dataclass(frozen=True)
class RateLimit:
    """FastAPI dependency: `Depends(RateLimit("login", 10, 60))` limits per client IP."""

    scope: str
    limit: int
    window_seconds: int

    def __call__(self, request: Request) -> None:
        check_rate_limit(f"{self.scope}:{client_ip(request)}", self.limit, self.window_seconds)


def check_rate_limit(key: str, limit: int, window_seconds: int) -> None:
    if not settings.RATE_LIMIT_ENABLED:
        return
    try:
        count = get_backend().hit(f"ghostwork:rl:{key}", window_seconds)
    except redis.RedisError:
        # Availability over strictness: log and allow if the limiter store is down.
        logger.warning("Rate limiter unavailable; allowing request for %s", key.split(":")[0])
        return
    if count > limit:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please wait a moment and try again.",
            headers={"Retry-After": str(window_seconds)},
        )
