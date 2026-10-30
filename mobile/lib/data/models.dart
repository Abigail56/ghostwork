// Typed models mirroring the FastAPI schemas (and frontend/src/lib/types.ts).

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();
List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) item) =>
    ((value as List?) ?? const [])
        .map((e) => item(e as Map<String, dynamic>))
        .toList();

class User {
  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.notifyOnFailure,
    required this.notifyOnSuccess,
    required this.emailOnFailure,
    required this.pushOnFailure,
    required this.reduceMotion,
    required this.density,
    required this.createdAt,
    required this.passwordChangedAt,
    required this.termsVersion,
  });

  final String id;
  final String email;
  final String fullName;
  final bool notifyOnFailure;
  final bool notifyOnSuccess;
  final bool emailOnFailure;
  final bool pushOnFailure;
  final String reduceMotion; // system | reduce | full
  final String density; // comfortable | compact
  final DateTime createdAt;
  final DateTime? passwordChangedAt;
  final String? termsVersion;

  String get firstName => fullName.split(' ').first;
  String get initials => fullName
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'] as String,
    email: j['email'] as String,
    fullName: j['full_name'] as String,
    notifyOnFailure: j['notify_on_failure'] as bool? ?? true,
    notifyOnSuccess: j['notify_on_success'] as bool? ?? false,
    emailOnFailure: j['email_on_failure'] as bool? ?? false,
    pushOnFailure: j['push_on_failure'] as bool? ?? true,
    reduceMotion: j['reduce_motion'] as String? ?? 'system',
    density: j['density'] as String? ?? 'comfortable',
    createdAt: _date(j['created_at']) ?? DateTime.now(),
    passwordChangedAt: _date(j['password_changed_at']),
    termsVersion: j['terms_version'] as String?,
  );
}

class TokenResponse {
  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.expiresAt,
  });

  final String accessToken;
  final String? refreshToken;
  final User user;
  final DateTime expiresAt;

  factory TokenResponse.fromJson(Map<String, dynamic> j) => TokenResponse(
    accessToken: j['access_token'] as String,
    refreshToken: j['refresh_token'] as String?,
    user: User.fromJson(j['user'] as Map<String, dynamic>),
    expiresAt: _date(j['expires_at'])!,
  );
}

class PageOf<T> {
  PageOf({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  int get pages => total == 0 ? 1 : (total / pageSize).ceil();

  factory PageOf.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) item,
  ) => PageOf(
    items: _list(j['items'], item),
    total: j['total'] as int,
    page: j['page'] as int,
    pageSize: j['page_size'] as int,
  );
}

/* ---------------- Workflow definitions ---------------- */

class NodeDef {
  NodeDef({
    required this.id,
    required this.type,
    required this.name,
    required this.x,
    required this.y,
    required this.config,
  });

  final String id;
  final String type;
  final String name;
  final double x;
  final double y;
  final Map<String, dynamic> config;

  String get kind => type.startsWith('trigger.')
      ? 'trigger'
      : (type.startsWith('condition.') ? 'condition' : 'action');

  NodeDef copyWith({
    String? type,
    String? name,
    double? x,
    double? y,
    Map<String, dynamic>? config,
  }) => NodeDef(
    id: id,
    type: type ?? this.type,
    name: name ?? this.name,
    x: x ?? this.x,
    y: y ?? this.y,
    config: config ?? this.config,
  );

  factory NodeDef.fromJson(Map<String, dynamic> j) {
    final p = (j['position'] as Map?) ?? const {};
    return NodeDef(
      id: j['id'] as String,
      type: j['type'] as String,
      name: j['name'] as String,
      x: ((p['x'] as num?) ?? 0).toDouble(),
      y: ((p['y'] as num?) ?? 0).toDouble(),
      config: Map<String, dynamic>.from((j['config'] as Map?) ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'position': {'x': x.roundToDouble(), 'y': y.roundToDouble()},
    'config': config,
  };
}

class EdgeDef {
  EdgeDef({
    required this.id,
    required this.source,
    required this.target,
    this.handle = 'out',
  });

  final String id;
  final String source;
  final String target;
  final String handle;

  factory EdgeDef.fromJson(Map<String, dynamic> j) => EdgeDef(
    id: j['id'] as String,
    source: j['source'] as String,
    target: j['target'] as String,
    handle: j['source_handle'] as String? ?? 'out',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'target': target,
    'source_handle': handle,
  };
}

class Definition {
  Definition({required this.nodes, required this.edges});

  final List<NodeDef> nodes;
  final List<EdgeDef> edges;

  static Definition empty() => Definition(nodes: [], edges: []);

  factory Definition.fromJson(Map<String, dynamic>? j) => Definition(
    nodes: _list(j?['nodes'], NodeDef.fromJson),
    edges: _list(j?['edges'], EdgeDef.fromJson),
  );

  Map<String, dynamic> toJson() => {
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'edges': edges.map((e) => e.toJson()).toList(),
  };
}

class ValidationIssue {
  ValidationIssue({required this.message, this.nodeId, this.field});

  final String message;
  final String? nodeId;
  final String? field;

  factory ValidationIssue.fromJson(Map<String, dynamic> j) => ValidationIssue(
    message: j['message'] as String,
    nodeId: j['node_id'] as String?,
    field: j['field'] as String?,
  );
}

class LastExecution {
  LastExecution({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String status;
  final DateTime createdAt;

  factory LastExecution.fromJson(Map<String, dynamic> j) => LastExecution(
    id: j['id'] as String,
    status: j['status'] as String,
    createdAt: _date(j['created_at'])!,
  );
}

class WorkflowSummary {
  WorkflowSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.triggerType,
    required this.stepCount,
    required this.lastRunAt,
    required this.nextRunAt,
    required this.updatedAt,
    required this.lastExecution,
  });

  final String id;
  final String name;
  final String description;
  final String status;
  final String? triggerType;
  final int stepCount;
  final DateTime? lastRunAt;
  final DateTime? nextRunAt;
  final DateTime updatedAt;
  final LastExecution? lastExecution;

  factory WorkflowSummary.fromJson(Map<String, dynamic> j) => WorkflowSummary(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String? ?? '',
    status: j['status'] as String,
    triggerType: j['trigger_type'] as String?,
    stepCount: j['step_count'] as int? ?? 0,
    lastRunAt: _date(j['last_run_at']),
    nextRunAt: _date(j['next_run_at']),
    updatedAt: _date(j['updated_at'])!,
    lastExecution: j['last_execution'] == null
        ? null
        : LastExecution.fromJson(j['last_execution'] as Map<String, dynamic>),
  );
}

class Workflow extends WorkflowSummary {
  Workflow({
    required super.id,
    required super.name,
    required super.description,
    required super.status,
    required super.triggerType,
    required super.stepCount,
    required super.lastRunAt,
    required super.nextRunAt,
    required super.updatedAt,
    required super.lastExecution,
    required this.definition,
    required this.version,
    required this.webhookUrl,
    required this.webhookSigningEnabled,
    required this.validation,
  });

  final Definition definition;
  final int version;
  final String? webhookUrl;
  final bool webhookSigningEnabled;
  final List<ValidationIssue> validation;

  bool get isValid => validation.isEmpty;

  factory Workflow.fromJson(Map<String, dynamic> j) {
    final s = WorkflowSummary.fromJson(j);
    return Workflow(
      id: s.id,
      name: s.name,
      description: s.description,
      status: s.status,
      triggerType: s.triggerType,
      stepCount: s.stepCount,
      lastRunAt: s.lastRunAt,
      nextRunAt: s.nextRunAt,
      updatedAt: s.updatedAt,
      lastExecution: s.lastExecution,
      definition: Definition.fromJson(j['definition'] as Map<String, dynamic>?),
      version: j['version'] as int? ?? 1,
      webhookUrl: j['webhook_url'] as String?,
      webhookSigningEnabled: j['webhook_signing_enabled'] as bool? ?? false,
      validation: _list(j['validation'], ValidationIssue.fromJson),
    );
  }
}

/* ---------------- Executions ---------------- */

class ExecutionSummary {
  ExecutionSummary({
    required this.id,
    required this.workflowId,
    required this.workflowName,
    required this.status,
    required this.triggerType,
    required this.errorMessage,
    required this.createdAt,
    required this.startedAt,
    required this.finishedAt,
    required this.durationMs,
  });

  final String id;
  final String workflowId;
  final String workflowName;
  final String status;
  final String triggerType;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int? durationMs;

  bool get isActive => status == 'queued' || status == 'running';

  factory ExecutionSummary.fromJson(Map<String, dynamic> j) => ExecutionSummary(
    id: j['id'] as String,
    workflowId: j['workflow_id'] as String,
    workflowName: j['workflow_name'] as String,
    status: j['status'] as String,
    triggerType: j['trigger_type'] as String,
    errorMessage: j['error_message'] as String?,
    createdAt: _date(j['created_at'])!,
    startedAt: _date(j['started_at']),
    finishedAt: _date(j['finished_at']),
    durationMs: j['duration_ms'] as int?,
  );
}

class ExecutionStep {
  ExecutionStep({
    required this.id,
    required this.nodeId,
    required this.nodeName,
    required this.nodeType,
    required this.status,
    required this.attempts,
    required this.durationMs,
    required this.errorMessage,
    required this.output,
  });

  final String id;
  final String nodeId;
  final String nodeName;
  final String nodeType;
  final String status;
  final int attempts;
  final int? durationMs;
  final String? errorMessage;
  final Map<String, dynamic>? output;

  factory ExecutionStep.fromJson(Map<String, dynamic> j) => ExecutionStep(
    id: j['id'] as String? ?? j['node_id'] as String,
    nodeId: j['node_id'] as String,
    nodeName: j['node_name'] as String,
    nodeType: j['node_type'] as String,
    status: j['status'] as String,
    attempts: j['attempts'] as int? ?? 0,
    durationMs: j['duration_ms'] as int?,
    errorMessage: j['error_message'] as String?,
    output: j['output'] as Map<String, dynamic>?,
  );
}

class Execution extends ExecutionSummary {
  Execution({
    required super.id,
    required super.workflowId,
    required super.workflowName,
    required super.status,
    required super.triggerType,
    required super.errorMessage,
    required super.createdAt,
    required super.startedAt,
    required super.finishedAt,
    required super.durationMs,
    required this.steps,
    required this.triggerPayload,
    required this.definition,
    required this.workflowVersion,
  });

  final List<ExecutionStep> steps;
  final Map<String, dynamic> triggerPayload;
  final Definition definition;
  final int workflowVersion;

  factory Execution.fromJson(Map<String, dynamic> j) {
    final s = ExecutionSummary.fromJson(j);
    return Execution(
      id: s.id,
      workflowId: s.workflowId,
      workflowName: s.workflowName,
      status: s.status,
      triggerType: s.triggerType,
      errorMessage: s.errorMessage,
      createdAt: s.createdAt,
      startedAt: s.startedAt,
      finishedAt: s.finishedAt,
      durationMs: s.durationMs,
      steps: _list(j['steps'], ExecutionStep.fromJson),
      triggerPayload:
          (j['trigger_payload'] as Map<String, dynamic>?) ?? const {},
      definition: Definition.fromJson(
        j['definition_snapshot'] as Map<String, dynamic>?,
      ),
      workflowVersion: j['workflow_version'] as int? ?? 1,
    );
  }
}

/* ---------------- Dashboard, activity, notifications ---------------- */

class TrendPoint {
  TrendPoint({
    required this.date,
    required this.succeeded,
    required this.failed,
    required this.other,
  });

  final DateTime date;
  final int succeeded;
  final int failed;
  final int other;

  int get total => succeeded + failed + other;

  factory TrendPoint.fromJson(Map<String, dynamic> j) => TrendPoint(
    date: DateTime.parse(j['date'] as String),
    succeeded: j['succeeded'] as int,
    failed: j['failed'] as int,
    other: j['other'] as int,
  );
}

class Activity {
  Activity({required this.id, required this.message, required this.createdAt});

  final String id;
  final String message;
  final DateTime createdAt;

  factory Activity.fromJson(Map<String, dynamic> j) => Activity(
    id: j['id'] as String,
    message: j['message'] as String,
    createdAt: _date(j['created_at'])!,
  );
}

class AttentionItem {
  AttentionItem({
    required this.workflowId,
    required this.workflowName,
    required this.reason,
  });

  final String workflowId;
  final String workflowName;
  final String reason;

  factory AttentionItem.fromJson(Map<String, dynamic> j) => AttentionItem(
    workflowId: j['workflow_id'] as String,
    workflowName: j['workflow_name'] as String,
    reason: j['reason'] as String,
  );
}

class DashboardSummary {
  DashboardSummary({
    required this.totalWorkflows,
    required this.activeWorkflows,
    required this.totalExecutions,
    required this.executions30d,
    required this.successRate,
    required this.trend,
    required this.recent,
    required this.activity,
    required this.failures24h,
    required this.successes24h,
    required this.inProgress,
    required this.lastExecutionAt,
    required this.attention,
  });

  final int totalWorkflows;
  final int activeWorkflows;
  final int totalExecutions;
  final int executions30d;
  final double? successRate;
  final List<TrendPoint> trend;
  final List<ExecutionSummary> recent;
  final List<Activity> activity;
  final int failures24h;
  final int successes24h;
  final int inProgress;
  final DateTime? lastExecutionAt;
  final List<AttentionItem> attention;

  factory DashboardSummary.fromJson(Map<String, dynamic> j) {
    final h = j['health'] as Map<String, dynamic>;
    return DashboardSummary(
      totalWorkflows: j['total_workflows'] as int,
      activeWorkflows: j['active_workflows'] as int,
      totalExecutions: j['total_executions'] as int,
      executions30d: j['executions_30d'] as int? ?? 0,
      successRate: (j['success_rate_30d'] as num?)?.toDouble(),
      trend: _list(j['trend'], TrendPoint.fromJson),
      recent: _list(j['recent_executions'], ExecutionSummary.fromJson),
      activity: _list(j['recent_activity'], Activity.fromJson),
      failures24h: h['failures_24h'] as int,
      successes24h: h['successes_24h'] as int? ?? 0,
      inProgress: h['in_progress'] as int,
      lastExecutionAt: _date(h['last_execution_at']),
      attention: _list(h['attention'], AttentionItem.fromJson),
    );
  }
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.link,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final String? link;
  final bool read;
  final DateTime createdAt;

  /// Execution ID when the notification links to a run.
  String? get executionId =>
      RegExp(r'^/executions/([0-9a-f-]{36})$').firstMatch(link ?? '')?.group(1);

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    kind: j['kind'] as String,
    title: j['title'] as String,
    body: j['body'] as String? ?? '',
    link: j['link'] as String?,
    read: j['read_at'] != null,
    createdAt: _date(j['created_at'])!,
  );
}

class SessionInfo {
  SessionInfo({
    required this.id,
    required this.userAgent,
    required this.ipAddress,
    required this.createdAt,
    required this.lastUsedAt,
    required this.current,
  });

  final String id;
  final String? userAgent;
  final String? ipAddress;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final bool current;

  factory SessionInfo.fromJson(Map<String, dynamic> j) => SessionInfo(
    id: j['id'] as String,
    userAgent: j['user_agent'] as String?,
    ipAddress: j['ip_address'] as String?,
    createdAt: _date(j['created_at'])!,
    lastUsedAt: _date(j['last_used_at'])!,
    current: j['current'] as bool,
  );
}

/* ---------------- Catalog, templates, integrations ---------------- */

class NodeType {
  NodeType({
    required this.type,
    required this.kind,
    required this.label,
    required this.description,
    required this.integrationProvider,
    required this.defaultConfig,
  });

  final String type;
  final String kind;
  final String label;
  final String description;
  final String? integrationProvider;
  final Map<String, dynamic> defaultConfig;

  factory NodeType.fromJson(Map<String, dynamic> j) => NodeType(
    type: j['type'] as String,
    kind: j['kind'] as String,
    label: j['label'] as String,
    description: j['description'] as String,
    integrationProvider: j['integration_provider'] as String?,
    defaultConfig: Map<String, dynamic>.from(
      (j['default_config'] as Map?) ?? const {},
    ),
  );
}

class Template {
  Template({
    required this.slug,
    required this.name,
    required this.description,
    required this.category,
    required this.requires,
    required this.definition,
  });

  final String slug;
  final String name;
  final String description;
  final String category;
  final List<String> requires;
  final Definition definition;

  factory Template.fromJson(Map<String, dynamic> j) => Template(
    slug: j['slug'] as String,
    name: j['name'] as String,
    description: j['description'] as String,
    category: j['category'] as String,
    requires: ((j['requires'] as List?) ?? const []).cast<String>(),
    definition: Definition.fromJson(j['definition'] as Map<String, dynamic>?),
  );
}

class IntegrationProvider {
  IntegrationProvider({
    required this.key,
    required this.label,
    required this.available,
    required this.description,
    required this.verifiable,
  });

  final String key;
  final String label;
  final bool available;
  final String description;
  final bool verifiable;

  factory IntegrationProvider.fromJson(Map<String, dynamic> j) =>
      IntegrationProvider(
        key: j['key'] as String,
        label: j['label'] as String,
        available: j['available'] as bool,
        description: j['description'] as String,
        verifiable: j['verifiable'] as bool? ?? false,
      );
}

class Integration {
  Integration({
    required this.id,
    required this.provider,
    required this.name,
    required this.status,
    required this.lastError,
    required this.lastVerifiedAt,
    required this.createdAt,
    required this.details,
  });

  final String id;
  final String provider;
  final String name;
  final String status;
  final String? lastError;
  final DateTime? lastVerifiedAt;
  final DateTime createdAt;
  final Map<String, dynamic> details;

  factory Integration.fromJson(Map<String, dynamic> j) => Integration(
    id: j['id'] as String,
    provider: j['provider'] as String,
    name: j['name'] as String,
    status: j['status'] as String,
    lastError: j['last_error'] as String?,
    lastVerifiedAt: _date(j['last_verified_at']),
    createdAt: _date(j['created_at'])!,
    details: Map<String, dynamic>.from((j['details'] as Map?) ?? const {}),
  );
}
