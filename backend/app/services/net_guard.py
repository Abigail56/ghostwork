"""Outbound HTTP with server-side request forgery (SSRF) protection.

Every destination is resolved, every resolved address is checked against blocked
ranges, and the connection is pinned to the checked address so DNS cannot be
re-pointed between the check and the request. Redirects are followed manually and
re-checked.
"""

import ipaddress
import json
import socket
from dataclasses import dataclass
from urllib.parse import urljoin, urlsplit, urlunsplit

import httpx

from app.core.config import settings

ALLOWED_SCHEMES = {"http", "https"}
MAX_REDIRECTS = 3
_EXTRA_BLOCKED = [
    ipaddress.ip_network("100.64.0.0/10"),  # carrier-grade NAT
    ipaddress.ip_network("192.0.0.0/24"),
    ipaddress.ip_network("198.18.0.0/15"),
    ipaddress.ip_network("64:ff9b::/96"),
]
_DROP_RESPONSE_HEADERS = {"set-cookie", "authorization", "proxy-authenticate", "www-authenticate"}


class BlockedDestination(Exception):
    pass


class RequestFailed(Exception):
    pass


def _is_blocked(ip: ipaddress._BaseAddress) -> bool:
    if isinstance(ip, ipaddress.IPv6Address) and ip.ipv4_mapped is not None:
        ip = ip.ipv4_mapped
    return (
        ip.is_private
        or ip.is_loopback
        or ip.is_link_local
        or ip.is_multicast
        or ip.is_reserved
        or ip.is_unspecified
        or any(ip in net for net in _EXTRA_BLOCKED if net.version == ip.version)
    )


def validate_url_shape(url: str) -> None:
    """Static checks usable at save time (no DNS)."""
    parts = urlsplit(url)
    if parts.scheme not in ALLOWED_SCHEMES:
        raise BlockedDestination("Only http and https URLs are allowed.")
    if not parts.hostname:
        raise BlockedDestination("The URL must include a host name.")
    if parts.username or parts.password:
        raise BlockedDestination("Credentials in URLs are not allowed. Use an HTTP credential integration.")
    try:
        parts.port
    except ValueError:
        raise BlockedDestination("The URL has an invalid port.")


def resolve_safe(host: str, port: int) -> str:
    """Resolve `host` and return one address that is allowed, or raise."""
    try:
        infos = socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)
    except socket.gaierror:
        raise RequestFailed(f"Could not resolve host '{host}'.")
    addresses = []
    for info in infos:
        ip = ipaddress.ip_address(info[4][0].split("%")[0])
        if _is_blocked(ip) and not settings.ALLOW_PRIVATE_NETWORK_REQUESTS:
            raise BlockedDestination(
                f"Requests to private or internal network addresses are blocked ('{host}')."
            )
        addresses.append(ip)
    if not addresses:
        raise RequestFailed(f"Could not resolve host '{host}'.")
    return str(addresses[0])


@dataclass
class SafeResponse:
    status_code: int
    headers: dict[str, str]
    body: object
    truncated: bool
    url: str


def safe_request(
    method: str,
    url: str,
    *,
    headers: dict[str, str] | None = None,
    content: str | bytes | None = None,
    timeout: float = 15,
    max_bytes: int | None = None,
    allowed_hosts: set[str] | None = None,
) -> SafeResponse:
    max_bytes = max_bytes or settings.HTTP_ACTION_MAX_RESPONSE_BYTES
    timeout = min(timeout, settings.HTTP_ACTION_MAX_TIMEOUT_SECONDS)
    current_url, current_method, current_content = url, method.upper(), content

    with httpx.Client(timeout=timeout, follow_redirects=False, trust_env=False) as client:
        for _ in range(MAX_REDIRECTS + 1):
            validate_url_shape(current_url)
            parts = urlsplit(current_url)
            host = parts.hostname
            if allowed_hosts is not None and host not in allowed_hosts:
                raise BlockedDestination(f"Requests to '{host}' are not allowed for this action.")
            port = parts.port or (443 if parts.scheme == "https" else 80)
            ip = resolve_safe(host, port)
            ip_host = f"[{ip}]" if ":" in ip else ip
            netloc = f"{ip_host}:{parts.port}" if parts.port else ip_host
            pinned_url = urlunsplit((parts.scheme, netloc, parts.path or "/", parts.query, ""))
            request_headers = {"User-Agent": "GhostWork/1.0", **(headers or {})}
            request_headers["Host"] = parts.netloc.rsplit("@", 1)[-1]
            extensions = {"sni_hostname": host} if parts.scheme == "https" else {}
            try:
                request = client.build_request(
                    current_method, pinned_url, headers=request_headers, content=current_content, extensions=extensions
                )
                response = client.send(request, stream=True)
            except httpx.TimeoutException:
                raise RequestFailed(f"The request timed out after {timeout:g} seconds.")
            except httpx.HTTPError as exc:
                raise RequestFailed(f"Could not connect: {type(exc).__name__}.")

            try:
                if response.is_redirect and "location" in response.headers:
                    current_url = urljoin(current_url, response.headers["location"])
                    if response.status_code in (301, 302, 303) and current_method != "HEAD":
                        current_method, current_content = "GET", None
                    continue
                chunks, size, truncated = [], 0, False
                for chunk in response.iter_bytes():
                    size += len(chunk)
                    if size > max_bytes:
                        chunks.append(chunk[: max_bytes - (size - len(chunk))])
                        truncated = True
                        break
                    chunks.append(chunk)
                raw = b"".join(chunks)
            finally:
                response.close()

            text = raw.decode(response.encoding or "utf-8", errors="replace")
            body = text
            if "json" in response.headers.get("content-type", "") and not truncated:
                try:
                    body = json.loads(text)
                except ValueError:
                    body = text
            filtered = {
                k.lower(): v for k, v in response.headers.items() if k.lower() not in _DROP_RESPONSE_HEADERS
            }
            return SafeResponse(response.status_code, filtered, body, truncated, current_url)
    raise RequestFailed(f"Too many redirects (more than {MAX_REDIRECTS}).")
