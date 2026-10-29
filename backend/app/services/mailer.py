"""Outbound email over SMTP. Used for platform mail and the user-configured email action."""

import smtplib
import ssl
from dataclasses import dataclass
from email.message import EmailMessage
from email.utils import make_msgid

from app.core.config import settings


class MailError(Exception):
    pass


@dataclass
class SmtpConfig:
    host: str
    port: int
    username: str | None
    password: str | None
    use_tls: bool
    sender: str


def platform_smtp_config() -> SmtpConfig | None:
    if not settings.platform_email_enabled:
        return None
    return SmtpConfig(
        host=settings.SMTP_HOST,
        port=settings.SMTP_PORT,
        username=settings.SMTP_USERNAME,
        password=settings.SMTP_PASSWORD,
        use_tls=settings.SMTP_USE_TLS,
        sender=settings.SMTP_FROM,
    )


def _connect(config: SmtpConfig, timeout: float) -> smtplib.SMTP:
    if config.port == 465:
        server: smtplib.SMTP = smtplib.SMTP_SSL(
            config.host, config.port, timeout=timeout, context=ssl.create_default_context()
        )
    else:
        server = smtplib.SMTP(config.host, config.port, timeout=timeout)
        server.ehlo()
        if config.use_tls:
            server.starttls(context=ssl.create_default_context())
            server.ehlo()
    if config.username:
        server.login(config.username, config.password or "")
    return server


def verify_smtp(config: SmtpConfig, timeout: float = 10) -> None:
    """Connect and authenticate without sending anything."""
    try:
        server = _connect(config, timeout)
        server.noop()
        server.quit()
    except (smtplib.SMTPException, OSError) as exc:
        raise MailError(_describe(exc)) from exc


def send_email(config: SmtpConfig, to: list[str], subject: str, body: str, timeout: float = 15) -> str:
    message = EmailMessage()
    message["From"] = config.sender
    message["To"] = ", ".join(to)
    message["Subject"] = subject
    message["Message-ID"] = make_msgid(domain="ghostwork.local")
    message.set_content(body)
    try:
        server = _connect(config, timeout)
        server.send_message(message)
        server.quit()
    except (smtplib.SMTPException, OSError) as exc:
        raise MailError(_describe(exc)) from exc
    return message["Message-ID"]


def _describe(exc: Exception) -> str:
    if isinstance(exc, smtplib.SMTPAuthenticationError):
        return "The mail server rejected the username or password."
    if isinstance(exc, smtplib.SMTPRecipientsRefused):
        return "The mail server refused one or more recipients."
    if isinstance(exc, (TimeoutError, ConnectionRefusedError, OSError)) and not isinstance(exc, smtplib.SMTPException):
        return "Could not connect to the mail server."
    return "The mail server returned an error while sending."
