"""Workflow definition schema, node catalog and validation.

A definition is a directed acyclic graph:

    {"nodes": [{"id", "type", "name", "position": {"x", "y"}, "config": {...}}],
     "edges": [{"id", "source", "target", "source_handle": "out" | "true" | "false"}]}

Parsing (`parse_definition`) is the structural check applied on every save. Full
validation (`validate_definition`) is required before activation or execution.
"""

import re
import uuid
from collections import defaultdict, deque
from dataclasses import dataclass, field
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator

from app.core.config import settings
from app.services import templating
from app.services.net_guard import BlockedDestination, validate_url_shape

NODE_ID = r"^[A-Za-z0-9_\-]{1,64}$"
FIELD_KEY = r"^[A-Za-z_][A-Za-z0-9_]{0,63}$"
TEMPLATE_MAX = 10_000


# --- Node configuration models ------------------------------------------------


class _Config(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ManualTriggerConfig(_Config):
    pass


class ScheduleTriggerConfig(_Config):
    every: int = Field(default=1, ge=1, le=10_000)
    unit: Literal["minutes", "hours", "days"] = "hours"

    @property
    def interval_minutes(self) -> int:
        return self.every * {"minutes": 1, "hours": 60, "days": 1440}[self.unit]


class WebhookTriggerConfig(_Config):
    pass


class HeaderPair(_Config):
    key: str = Field(min_length=1, max_length=100, pattern=r"^[A-Za-z0-9\-_]+$")
    value: str = Field(max_length=2000)


_SENSITIVE_HEADERS = {"authorization", "cookie", "proxy-authorization", "x-api-key", "api-key"}


class HttpRequestConfig(_Config):
    method: Literal["GET", "POST", "PUT", "PATCH", "DELETE"] = "GET"
    url: str = Field(default="", max_length=2000)
    headers: list[HeaderPair] = Field(default_factory=list, max_length=20)
    body: str = Field(default="", max_length=TEMPLATE_MAX)
    timeout_seconds: int = Field(default=15, ge=1, le=30)
    retries: int = Field(default=0, ge=0, le=3)
    fail_on_error_status: bool = True
    credential_integration_id: uuid.UUID | None = None

    @field_validator("headers")
    @classmethod
    def _no_secret_headers(cls, value: list[HeaderPair]) -> list[HeaderPair]:
        for header in value:
            if header.key.lower() in _SENSITIVE_HEADERS:
                raise ValueError(
                    f"Don't put '{header.key}' in plain headers. Connect an HTTP credential integration instead."
                )
        return value


class TransformField(_Config):
    key: str = Field(pattern=FIELD_KEY)
    value: str = Field(default="", max_length=TEMPLATE_MAX)


class TransformConfig(_Config):
    fields: list[TransformField] = Field(default_factory=list, max_length=30)


class EmailConfig(_Config):
    integration_id: uuid.UUID | None = None
    to: list[str] = Field(default_factory=list, max_length=10)
    subject: str = Field(default="", max_length=300)
    body: str = Field(default="", max_length=TEMPLATE_MAX)


class SlackConfig(_Config):
    integration_id: uuid.UUID | None = None
    text: str = Field(default="", max_length=3000)


class GitHubIssueConfig(_Config):
    integration_id: uuid.UUID | None = None
    repository: str = Field(default="", max_length=200)
    title: str = Field(default="", max_length=500)
    body: str = Field(default="", max_length=TEMPLATE_MAX)
    labels: list[str] = Field(default_factory=list, max_length=20)


class SheetsAppendConfig(_Config):
    integration_id: uuid.UUID | None = None
    spreadsheet_id: str = Field(default="", max_length=200)
    sheet_range: str = Field(default="Sheet1", max_length=200)
    values: list[str] = Field(default_factory=list, max_length=50)


class SheetsReadConfig(_Config):
    integration_id: uuid.UUID | None = None
    spreadsheet_id: str = Field(default="", max_length=200)
    sheet_range: str = Field(default="Sheet1", max_length=200)


Operator = Literal[
    "equals", "not_equals", "contains", "not_contains", "greater_than", "less_than", "is_empty", "is_not_empty"
]
UNARY_OPERATORS = {"is_empty", "is_not_empty"}


class ConditionConfig(_Config):
    left: str = Field(default="", max_length=1000)
    operator: Operator = "equals"
    right: str = Field(default="", max_length=1000)


# --- Catalog ----------------------------------------------------------------------


@dataclass(frozen=True)
class NodeType:
    type: str
    kind: Literal["trigger", "action", "condition"]
    label: str
    description: str
    config_model: type[_Config]
    integration_provider: str | None = None
    outputs: tuple[str, ...] = ("out",)


NODE_TYPES: dict[str, NodeType] = {
    n.type: n
    for n in [
        NodeType("trigger.manual", "trigger", "Manual trigger", "Run on demand from GhostWork.", ManualTriggerConfig),
        NodeType(
            "trigger.schedule", "trigger", "Schedule", "Run on a repeating interval while active.", ScheduleTriggerConfig
        ),
        NodeType(
            "trigger.webhook", "trigger", "Webhook", "Run when a unique URL receives an HTTP POST.", WebhookTriggerConfig
        ),
        NodeType("action.http_request", "action", "HTTP request", "Call an external HTTP API.", HttpRequestConfig),
        NodeType("action.transform", "action", "Transform data", "Build a new object from earlier data.", TransformConfig),
        NodeType(
            "action.email", "action", "Send email", "Send an email through your SMTP integration.", EmailConfig, "smtp"
        ),
        NodeType(
            "action.slack", "action", "Slack message", "Post to Slack with an incoming webhook.", SlackConfig, "slack"
        ),
        NodeType(
            "action.github_issue", "action", "GitHub issue", "Create an issue in a GitHub repository.", GitHubIssueConfig, "github"
        ),
        NodeType(
            "action.sheets_append", "action", "Append to sheet", "Add a row to a Google Sheet.", SheetsAppendConfig, "google"
        ),
        NodeType("action.sheets_read", "action", "Read sheet", "Read rows from a Google Sheet.", SheetsReadConfig, "google"),
        NodeType(
            "condition.if",
            "condition",
            "Condition",
            "Continue down the true or false branch.",
            ConditionConfig,
            outputs=("true", "false"),
        ),
    ]
}


# --- Structure ------------------------------------------------------------------


class Position(BaseModel):
    x: float = 0
    y: float = 0


class NodeDef(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: Annotated[str, Field(pattern=NODE_ID)]
    type: str
    name: str = Field(min_length=1, max_length=80)
    position: Position = Field(default_factory=Position)
    config: dict = Field(default_factory=dict)

    @field_validator("type")
    @classmethod
    def _known_type(cls, value: str) -> str:
        if value not in NODE_TYPES:
            raise ValueError(f"Unsupported node type '{value}'.")
        return value


class EdgeDef(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: Annotated[str, Field(pattern=NODE_ID)]
    source: str
    target: str
    source_handle: str = "out"


class WorkflowDefinition(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nodes: list[NodeDef] = Field(default_factory=list)
    edges: list[EdgeDef] = Field(default_factory=list)


class DefinitionError(Exception):
    def __init__(self, issues: list["Issue"]):
        super().__init__("; ".join(i.message for i in issues))
        self.issues = issues


@dataclass
class Issue:
    message: str
    node_id: str | None = None
    field: str | None = None

    def as_dict(self) -> dict:
        return {"message": self.message, "node_id": self.node_id, "field": self.field}


def _pydantic_issues(exc: ValidationError, node_id: str | None = None, prefix: str = "") -> list[Issue]:
    issues = []
    for err in exc.errors():
        loc = ".".join(str(p) for p in err["loc"])
        message = err["msg"].removeprefix("Value error, ")
        issues.append(Issue(message=f"{prefix}{message}" if not loc else f"{prefix}{loc}: {message}", node_id=node_id, field=loc or None))
    return issues


def parse_definition(raw: dict) -> WorkflowDefinition:
    """Structural validation applied on every save. Raises DefinitionError."""
    try:
        definition = WorkflowDefinition.model_validate(raw)
    except ValidationError as exc:
        raise DefinitionError(_pydantic_issues(exc))

    issues: list[Issue] = []
    if len(definition.nodes) > settings.MAX_WORKFLOW_NODES:
        issues.append(Issue(f"A workflow can have at most {settings.MAX_WORKFLOW_NODES} steps."))
    if len(definition.edges) > settings.MAX_WORKFLOW_NODES * 3:
        issues.append(Issue("Too many connections."))

    ids = [n.id for n in definition.nodes]
    if len(ids) != len(set(ids)):
        issues.append(Issue("Step IDs must be unique."))
    for node in definition.nodes:
        try:
            NODE_TYPES[node.type].config_model.model_validate(node.config)
        except ValidationError as exc:
            issues.extend(_pydantic_issues(exc, node.id))

    node_by_id = {n.id: n for n in definition.nodes}
    edge_ids = set()
    for edge in definition.edges:
        if edge.id in edge_ids:
            issues.append(Issue("Connection IDs must be unique."))
        edge_ids.add(edge.id)
        if edge.source not in node_by_id or edge.target not in node_by_id:
            issues.append(Issue("A connection points to a step that doesn't exist."))
            continue
        if edge.source == edge.target:
            issues.append(Issue("A step can't connect to itself.", edge.source))
        allowed = NODE_TYPES[node_by_id[edge.source].type].outputs
        if edge.source_handle not in allowed:
            issues.append(Issue(f"Invalid output '{edge.source_handle}'.", edge.source))
    if issues:
        raise DefinitionError(issues)
    return definition


def config_of(node: NodeDef):
    return NODE_TYPES[node.type].config_model.model_validate(node.config)


def topological_order(definition: WorkflowDefinition) -> list[NodeDef] | None:
    incoming = defaultdict(int)
    outgoing = defaultdict(list)
    for edge in definition.edges:
        incoming[edge.target] += 1
        outgoing[edge.source].append(edge.target)
    order_index = {n.id: i for i, n in enumerate(definition.nodes)}
    queue = deque(sorted((n.id for n in definition.nodes if incoming[n.id] == 0), key=order_index.get))
    node_by_id = {n.id: n for n in definition.nodes}
    ordered = []
    while queue:
        current = queue.popleft()
        ordered.append(node_by_id[current])
        for target in sorted(set(outgoing[current]), key=order_index.get):
            incoming[target] -= outgoing[current].count(target)
            if incoming[target] == 0:
                queue.append(target)
    return ordered if len(ordered) == len(definition.nodes) else None


@dataclass
class ValidationResult:
    definition: WorkflowDefinition | None
    issues: list[Issue] = field(default_factory=list)

    @property
    def valid(self) -> bool:
        return not self.issues

    @property
    def trigger(self) -> NodeDef | None:
        if self.definition is None:
            return None
        return next((n for n in self.definition.nodes if NODE_TYPES[n.type].kind == "trigger"), None)


def _check_templates(node: NodeDef, field_name: str, value: str, issues: list[Issue], known_steps: set[str]) -> None:
    for path in templating.referenced_paths(value):
        root = path.split(".")[0]
        if root not in templating.ROOTS:
            issues.append(Issue(f"Unknown reference '{{{{ {path} }}}}'. Use trigger, steps, execution or workflow.", node.id, field_name))
        elif root == "steps":
            parts = path.split(".")
            if len(parts) < 2 or parts[1] not in known_steps:
                issues.append(Issue(f"'{{{{ {path} }}}}' refers to a step that doesn't run before this one.", node.id, field_name))


def validate_definition(raw: dict, integrations: dict[uuid.UUID, str] | None = None) -> ValidationResult:
    """Full validation. `integrations` maps the owner's integration IDs to providers."""
    try:
        definition = parse_definition(raw)
    except DefinitionError as exc:
        return ValidationResult(None, exc.issues)

    issues: list[Issue] = []
    nodes = definition.nodes
    if not nodes:
        return ValidationResult(definition, [Issue("Add a trigger to start the workflow.")])

    triggers = [n for n in nodes if NODE_TYPES[n.type].kind == "trigger"]
    if not triggers:
        issues.append(Issue("Add a trigger to start the workflow."))
    elif len(triggers) > 1:
        for t in triggers[1:]:
            issues.append(Issue("A workflow can have only one trigger.", t.id))
    if len(nodes) == len(triggers):
        issues.append(Issue("Add at least one action after the trigger."))

    for edge in definition.edges:
        if any(edge.target == t.id for t in triggers):
            issues.append(Issue("Triggers can't have incoming connections.", edge.target))

    order = topological_order(definition)
    if order is None:
        issues.append(Issue("Connections form a loop. Workflows must flow in one direction."))
        return ValidationResult(definition, issues)

    # Reachability from the trigger, and which steps run before each node.
    outgoing = defaultdict(list)
    for edge in definition.edges:
        outgoing[edge.source].append(edge.target)
    reachable: set[str] = set()
    if triggers:
        stack = [triggers[0].id]
        while stack:
            current = stack.pop()
            if current in reachable:
                continue
            reachable.add(current)
            stack.extend(outgoing[current])
    for node in nodes:
        if node.id not in reachable and NODE_TYPES[node.type].kind != "trigger":
            issues.append(Issue(f"'{node.name}' isn't connected to the trigger.", node.id))

    incoming = defaultdict(list)
    for edge in definition.edges:
        incoming[edge.target].append(edge.source)
    ancestors: dict[str, set[str]] = {}
    for node in order:
        result: set[str] = set()
        for parent in incoming[node.id]:
            result.add(parent)
            result |= ancestors[parent]
        ancestors[node.id] = result

    integrations = integrations or {}
    for node in nodes:
        spec = NODE_TYPES[node.type]
        config = config_of(node)
        before = ancestors.get(node.id, set())

        if spec.kind == "condition":
            handles = {e.source_handle for e in definition.edges if e.source == node.id}
            if not handles:
                issues.append(Issue("Connect the true or false branch of this condition.", node.id))
        if isinstance(config, HttpRequestConfig):
            if not config.url.strip():
                issues.append(Issue("Enter the URL to call.", node.id, "url"))
            elif not re.match(r"^https?://", config.url.strip()):
                issues.append(Issue("The URL must start with http:// or https://.", node.id, "url"))
            elif not templating.referenced_paths(config.url):
                try:
                    validate_url_shape(config.url.strip())
                except BlockedDestination as exc:
                    issues.append(Issue(str(exc), node.id, "url"))
            _check_templates(node, "url", config.url, issues, before)
            _check_templates(node, "body", config.body, issues, before)
            for header in config.headers:
                _check_templates(node, "headers", header.value, issues, before)
            if config.credential_integration_id and integrations.get(config.credential_integration_id) != "http_auth":
                issues.append(Issue("Choose one of your HTTP credentials.", node.id, "credential_integration_id"))
        elif isinstance(config, TransformConfig):
            if not config.fields:
                issues.append(Issue("Add at least one field to build.", node.id, "fields"))
            keys = [f.key for f in config.fields]
            if len(keys) != len(set(keys)):
                issues.append(Issue("Field names must be unique.", node.id, "fields"))
            for item in config.fields:
                _check_templates(node, "fields", item.value, issues, before)
        elif isinstance(config, EmailConfig):
            if config.integration_id is None or integrations.get(config.integration_id) != "smtp":
                issues.append(Issue("Choose a connected email (SMTP) integration.", node.id, "integration_id"))
            if not config.to:
                issues.append(Issue("Add at least one recipient.", node.id, "to"))
            for recipient in config.to:
                if not templating.referenced_paths(recipient) and not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", recipient):
                    issues.append(Issue(f"'{recipient}' is not a valid email address.", node.id, "to"))
                _check_templates(node, "to", recipient, issues, before)
            if not config.subject.strip():
                issues.append(Issue("Enter a subject.", node.id, "subject"))
            _check_templates(node, "subject", config.subject, issues, before)
            _check_templates(node, "body", config.body, issues, before)
        elif isinstance(config, SlackConfig):
            if config.integration_id is None or integrations.get(config.integration_id) != "slack":
                issues.append(Issue("Choose a connected Slack integration.", node.id, "integration_id"))
            if not config.text.strip():
                issues.append(Issue("Enter the message text.", node.id, "text"))
            _check_templates(node, "text", config.text, issues, before)
        elif isinstance(config, GitHubIssueConfig):
            if config.integration_id is None or integrations.get(config.integration_id) != "github":
                issues.append(Issue("Choose a connected GitHub integration.", node.id, "integration_id"))
            if not templating.referenced_paths(config.repository) and not re.fullmatch(r"[\w.-]+/[\w.-]+", config.repository):
                issues.append(Issue("Enter the repository as owner/name.", node.id, "repository"))
            if not config.title.strip():
                issues.append(Issue("Enter the issue title.", node.id, "title"))
            for field_name, value in (("repository", config.repository), ("title", config.title), ("body", config.body)):
                _check_templates(node, field_name, value, issues, before)
            for label in config.labels:
                _check_templates(node, "labels", label, issues, before)
        elif isinstance(config, (SheetsAppendConfig, SheetsReadConfig)):
            if config.integration_id is None or integrations.get(config.integration_id) != "google":
                issues.append(Issue("Choose a connected Google Sheets integration.", node.id, "integration_id"))
            if not config.spreadsheet_id.strip():
                issues.append(Issue("Enter the spreadsheet ID from its URL.", node.id, "spreadsheet_id"))
            if not config.sheet_range.strip():
                issues.append(Issue("Enter the sheet or range, such as Sheet1.", node.id, "sheet_range"))
            if isinstance(config, SheetsAppendConfig):
                if not config.values:
                    issues.append(Issue("Add at least one column value.", node.id, "values"))
                for value in config.values:
                    _check_templates(node, "values", value, issues, before)
        elif isinstance(config, ConditionConfig):
            if not config.left.strip():
                issues.append(Issue("Choose a value to compare.", node.id, "left"))
            _check_templates(node, "left", config.left, issues, before)
            _check_templates(node, "right", config.right, issues, before)
        elif isinstance(config, ScheduleTriggerConfig):
            if config.interval_minutes < 5:
                issues.append(Issue("Schedules must run at most every 5 minutes.", node.id, "every"))

    return ValidationResult(definition, issues)


def node_catalog() -> list[dict]:
    return [
        {
            "type": n.type,
            "kind": n.kind,
            "label": n.label,
            "description": n.description,
            "integration_provider": n.integration_provider,
            "outputs": list(n.outputs),
            "default_config": n.config_model().model_dump(mode="json"),
        }
        for n in NODE_TYPES.values()
    ]
