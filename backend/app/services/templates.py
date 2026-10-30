"""Built-in workflow templates. Every template uses only implemented node types."""

from dataclasses import dataclass


@dataclass(frozen=True)
class Template:
    slug: str
    name: str
    description: str
    category: str
    requires: tuple[str, ...]
    definition: dict


def _node(id: str, type: str, name: str, x: float, y: float, config: dict | None = None) -> dict:
    return {"id": id, "type": type, "name": name, "position": {"x": x, "y": y}, "config": config or {}}


def _edge(source: str, target: str, handle: str = "out") -> dict:
    return {"id": f"e-{source}-{target}-{handle}", "source": source, "target": target, "source_handle": handle}


TEMPLATES: list[Template] = [
    Template(
        slug="endpoint-monitor",
        name="HTTP endpoint monitor",
        description="Check a URL every 15 minutes and email you when it responds with an error status.",
        category="Monitoring",
        requires=("smtp",),
        definition={
            "nodes": [
                _node("schedule", "trigger.schedule", "Every 15 minutes", 0, 0, {"every": 15, "unit": "minutes"}),
                _node(
                    "check",
                    "action.http_request",
                    "Check endpoint",
                    0,
                    170,
                    {"method": "GET", "url": "https://example.com", "timeout_seconds": 10, "retries": 1, "fail_on_error_status": False},
                ),
                _node(
                    "is_down",
                    "condition.if",
                    "Is it failing?",
                    0,
                    340,
                    {"left": "{{ steps.check.status_code }}", "operator": "greater_than", "right": "399"},
                ),
                _node(
                    "alert",
                    "action.email",
                    "Email alert",
                    -160,
                    520,
                    {
                        "to": ["you@example.com"],
                        "subject": "Endpoint check failed ({{ steps.check.status_code }})",
                        "body": "GhostWork checked the endpoint at {{ execution.started_at }} and got HTTP {{ steps.check.status_code }}.",
                    },
                ),
            ],
            "edges": [_edge("schedule", "check"), _edge("check", "is_down"), _edge("is_down", "alert", "true")],
        },
    ),
    Template(
        slug="scheduled-data-pull",
        name="Scheduled data retrieval",
        description="Fetch JSON from an API every day and reshape it into the fields you need.",
        category="Data",
        requires=(),
        definition={
            "nodes": [
                _node("daily", "trigger.schedule", "Every day", 0, 0, {"every": 1, "unit": "days"}),
                _node(
                    "fetch",
                    "action.http_request",
                    "Fetch data",
                    0,
                    170,
                    {"method": "GET", "url": "https://api.github.com/repos/python/cpython", "timeout_seconds": 15, "retries": 2},
                ),
                _node(
                    "shape",
                    "action.transform",
                    "Keep key fields",
                    0,
                    340,
                    {
                        "fields": [
                            {"key": "name", "value": "{{ steps.fetch.body.full_name }}"},
                            {"key": "stars", "value": "{{ steps.fetch.body.stargazers_count }}"},
                            {"key": "open_issues", "value": "{{ steps.fetch.body.open_issues_count }}"},
                        ]
                    },
                ),
            ],
            "edges": [_edge("daily", "fetch"), _edge("fetch", "shape")],
        },
    ),
    Template(
        slug="webhook-router",
        name="Webhook-triggered processing",
        description="Receive a webhook, normalize its payload and forward high-priority events to another API.",
        category="Webhooks",
        requires=(),
        definition={
            "nodes": [
                _node("hook", "trigger.webhook", "Incoming webhook", 0, 0),
                _node(
                    "normalize",
                    "action.transform",
                    "Normalize event",
                    0,
                    170,
                    {
                        "fields": [
                            {"key": "event", "value": "{{ trigger.payload.body.event }}"},
                            {"key": "priority", "value": "{{ trigger.payload.body.priority }}"},
                            {"key": "received_at", "value": "{{ execution.started_at }}"},
                        ]
                    },
                ),
                _node(
                    "urgent",
                    "condition.if",
                    "High priority?",
                    0,
                    340,
                    {"left": "{{ steps.normalize.priority }}", "operator": "equals", "right": "high"},
                ),
                _node(
                    "forward",
                    "action.http_request",
                    "Forward event",
                    -160,
                    520,
                    {
                        "method": "POST",
                        "url": "https://httpbin.org/post",
                        "body": '{"event": "{{ steps.normalize.event }}", "received_at": "{{ steps.normalize.received_at }}"}',
                    },
                ),
            ],
            "edges": [_edge("hook", "normalize"), _edge("normalize", "urgent"), _edge("urgent", "forward", "true")],
        },
    ),
    Template(
        slug="weekly-email-digest",
        name="Scheduled email notification",
        description="Send a reminder email on a fixed schedule.",
        category="Notifications",
        requires=("smtp",),
        definition={
            "nodes": [
                _node("weekly", "trigger.schedule", "Every 7 days", 0, 0, {"every": 7, "unit": "days"}),
                _node(
                    "send",
                    "action.email",
                    "Send reminder",
                    0,
                    170,
                    {
                        "to": ["team@example.com"],
                        "subject": "Weekly reminder",
                        "body": "This is your weekly reminder from GhostWork ({{ workflow.name }}).",
                    },
                ),
            ],
            "edges": [_edge("weekly", "send")],
        },
    ),
    Template(
        slug="webhook-to-slack",
        name="Webhook to Slack",
        description="Post a Slack message whenever a webhook is received.",
        category="Notifications",
        requires=("slack",),
        definition={
            "nodes": [
                _node("hook", "trigger.webhook", "Incoming webhook", 0, 0),
                _node(
                    "post",
                    "action.slack",
                    "Post to Slack",
                    0,
                    170,
                    {"text": "New event received: {{ trigger.payload.body }}"},
                ),
            ],
            "edges": [_edge("hook", "post")],
        },
    ),
]

TEMPLATES.extend(
    [
        Template(
            slug="webhook-to-github-issue",
            name="Webhook to GitHub issue",
            description="Open a GitHub issue whenever a webhook reports a problem.",
            category="Developer tools",
            requires=("github",),
            definition={
                "nodes": [
                    _node("hook", "trigger.webhook", "Incoming webhook", 0, 0),
                    _node(
                        "issue",
                        "action.github_issue",
                        "Create issue",
                        0,
                        170,
                        {
                            "repository": "owner/repository",
                            "title": "{{ trigger.payload.body.title }}",
                            "body": "Reported by GhostWork at {{ execution.started_at }}.",
                            "labels": ["bug"],
                        },
                    ),
                ],
                "edges": [_edge("hook", "issue")],
            },
        ),
        Template(
            slug="webhook-to-sheet",
            name="Log webhooks to Google Sheets",
            description="Add a spreadsheet row for every webhook received.",
            category="Data",
            requires=("google",),
            definition={
                "nodes": [
                    _node("hook", "trigger.webhook", "Incoming webhook", 0, 0),
                    _node(
                        "row",
                        "action.sheets_append",
                        "Add row",
                        0,
                        170,
                        {
                            "spreadsheet_id": "your-spreadsheet-id",
                            "sheet_range": "Sheet1",
                            "values": ["{{ execution.started_at }}", "{{ trigger.payload.body.event }}"],
                        },
                    ),
                ],
                "edges": [_edge("hook", "row")],
            },
        ),
    ]
)

TEMPLATES_BY_SLUG = {t.slug: t for t in TEMPLATES}
