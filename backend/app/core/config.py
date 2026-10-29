from functools import lru_cache
from typing import Literal

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    APP_NAME: str = "GhostWork API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    ENVIRONMENT: Literal["development", "test", "production"] = "development"

    # Database
    DATABASE_URL: str = (
        "postgresql+psycopg://ghostwork:ghostwork_dev_password"
        "@localhost:5432/ghostwork"
    )

    # Authentication
    JWT_SECRET_KEY: str = ""
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    PASSWORD_RESET_EXPIRE_MINUTES: int = 30

    # Refresh-session cookie. Secure is forced on in production.
    REFRESH_COOKIE_NAME: str = "gw_refresh"
    COOKIE_SECURE: bool = False
    COOKIE_SAMESITE: Literal["lax", "strict", "none"] = "lax"
    COOKIE_DOMAIN: str | None = None

    # Version of the Terms of Service users accept at registration (bump when they change).
    TERMS_VERSION: str = "2026-10-30"

    # Frontend
    FRONTEND_URL: str = "http://localhost:3000"
    # Public base URL of this API (used to build webhook URLs).
    API_PUBLIC_URL: str = "http://localhost:8000"
    CORS_ORIGINS: list[str] = ["http://localhost:3000", "http://127.0.0.1:3000"]

    # Redis and background workers
    REDIS_URL: str = "redis://localhost:6379/0"
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/2"
    # Run Celery tasks inline (tests only).
    CELERY_TASK_ALWAYS_EAGER: bool = False

    # Rate limiting (requests per client IP per window)
    RATE_LIMIT_ENABLED: bool = True
    REGISTER_RATE_LIMIT_PER_HOUR: int = 5
    LOGIN_RATE_LIMIT_PER_5_MIN: int = 10

    # Integration credential encryption (Fernet key, urlsafe base64, 32 bytes).
    INTEGRATION_ENCRYPTION_KEY: str = ""

    # Platform email (password reset, failure notifications). Optional.
    SMTP_HOST: str | None = None
    SMTP_PORT: int = 587
    SMTP_USERNAME: str | None = None
    SMTP_PASSWORD: str | None = None
    SMTP_USE_TLS: bool = True
    SMTP_FROM: str = "GhostWork <no-reply@ghostwork.local>"

    # Workflow execution limits
    MAX_WORKFLOW_NODES: int = 50
    MAX_CONCURRENT_EXECUTIONS_PER_USER: int = 5
    EXECUTION_SOFT_TIME_LIMIT_SECONDS: int = 120
    HTTP_ACTION_MAX_TIMEOUT_SECONDS: int = 30
    HTTP_ACTION_MAX_RESPONSE_BYTES: int = 1_000_000
    WEBHOOK_MAX_PAYLOAD_BYTES: int = 256_000
    # Finished executions older than this are deleted by the beat scheduler (0 = keep forever).
    EXECUTION_RETENTION_DAYS: int = 90
    # Only for local development against services on your own machine.
    ALLOW_PRIVATE_NETWORK_REQUESTS: bool = False

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    @field_validator("COOKIE_DOMAIN", "SMTP_HOST", "SMTP_USERNAME", "SMTP_PASSWORD", mode="before")
    @classmethod
    def _blank_to_none(cls, value):
        return value or None

    @model_validator(mode="after")
    def _check_production(self):
        if len(self.JWT_SECRET_KEY) < 32:
            raise ValueError("JWT_SECRET_KEY must be set to at least 32 characters.")
        if self.ENVIRONMENT == "production":
            self.COOKIE_SECURE = True
            self.DEBUG = False
            if not self.INTEGRATION_ENCRYPTION_KEY:
                raise ValueError("INTEGRATION_ENCRYPTION_KEY is required in production.")
            if self.ALLOW_PRIVATE_NETWORK_REQUESTS:
                raise ValueError("ALLOW_PRIVATE_NETWORK_REQUESTS cannot be enabled in production.")
        return self

    @property
    def platform_email_enabled(self) -> bool:
        return bool(self.SMTP_HOST)


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
