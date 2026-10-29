"""Minimal, safe template interpolation: `{{ trigger.payload.name }}`.

Only dotted path lookups are supported - no expressions, filters or code execution.
"""

import json
import re
from typing import Any

TEMPLATE_PATTERN = re.compile(r"\{\{\s*([A-Za-z_][A-Za-z0-9_\-]*(?:\.[A-Za-z0-9_\-]+)*)\s*\}\}")
ROOTS = {"trigger", "steps", "execution", "workflow"}

_MISSING = object()


def lookup(context: dict, path: str) -> Any:
    current: Any = context
    for segment in path.split("."):
        if isinstance(current, dict):
            current = current.get(segment, _MISSING)
        elif isinstance(current, list) and segment.isdigit():
            index = int(segment)
            current = current[index] if index < len(current) else _MISSING
        else:
            return None
        if current is _MISSING:
            return None
    return current


def _stringify(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, (dict, list)):
        return json.dumps(value, separators=(",", ":"))
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def render(template: str, context: dict) -> str:
    return TEMPLATE_PATTERN.sub(lambda m: _stringify(lookup(context, m.group(1))), template)


def render_value(template: str, context: dict) -> Any:
    """Like render(), but a template that is exactly one expression keeps its type."""
    match = TEMPLATE_PATTERN.fullmatch(template.strip())
    if match:
        return lookup(context, match.group(1))
    return render(template, context)


def referenced_paths(template: str) -> list[str]:
    return [m.group(1) for m in TEMPLATE_PATTERN.finditer(template)]


def invalid_roots(template: str) -> list[str]:
    return [p for p in referenced_paths(template) if p.split(".")[0] not in ROOTS]
