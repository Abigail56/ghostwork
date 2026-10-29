"""Password hashing, access tokens, opaque refresh tokens and secret encryption."""

import hashlib
import json
import secrets
import uuid
from datetime import UTC, datetime, timedelta

import jwt
from cryptography.fernet import Fernet, InvalidToken
from pwdlib import PasswordHash
from pwdlib.hashers.argon2 import Argon2Hasher

from app.core.config import settings

_password_hash = PasswordHash((Argon2Hasher(),))

# Used to equalize timing when the account does not exist.
_DUMMY_HASH = _password_hash.hash("ghostwork-timing-equalizer")


def hash_password(password: str) -> str:
    return _password_hash.hash(password)


def verify_password(password: str, hashed: str | None) -> bool:
    if hashed is None:
        _password_hash.verify(password, _DUMMY_HASH)
        return False
    try:
        return _password_hash.verify(password, hashed)
    except Exception:
        return False


def verify_and_update_password(password: str, hashed: str) -> tuple[bool, str | None]:
    """Verify, and return a fresh hash when the stored one uses outdated parameters."""
    try:
        return _password_hash.verify_and_update(password, hashed)
    except Exception:
        return False, None


def create_access_token(user_id: uuid.UUID, session_id: uuid.UUID) -> tuple[str, datetime]:
    now = datetime.now(UTC)
    expires = now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": str(user_id),
        "sid": str(session_id),
        "type": "access",
        "iat": now,
        "exp": expires,
        "jti": secrets.token_hex(8),
    }
    token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return token, expires


def decode_access_token(token: str) -> dict | None:
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
            options={"require": ["exp", "sub", "sid", "type"]},
        )
    except jwt.PyJWTError:
        return None
    if payload.get("type") != "access":
        return None
    return payload


def generate_opaque_token() -> str:
    return secrets.token_urlsafe(48)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


class SecretBoxError(Exception):
    pass


def _fernet() -> Fernet:
    if not settings.INTEGRATION_ENCRYPTION_KEY:
        raise SecretBoxError("Integration encryption is not configured on the server.")
    try:
        return Fernet(settings.INTEGRATION_ENCRYPTION_KEY.encode())
    except ValueError as exc:
        raise SecretBoxError("INTEGRATION_ENCRYPTION_KEY is not a valid Fernet key.") from exc


def encrypt_secrets(data: dict) -> str:
    return _fernet().encrypt(json.dumps(data).encode()).decode()


def decrypt_secrets(token: str) -> dict:
    try:
        return json.loads(_fernet().decrypt(token.encode()))
    except InvalidToken as exc:
        raise SecretBoxError("Stored credentials could not be decrypted.") from exc
