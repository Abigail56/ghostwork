// Typed models mirroring the FastAPI response schemas.

DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String).toLocal();

class User {
  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.notifyOnFailure,
    required this.notifyOnSuccess,
    required this.emailOnFailure,
  });

  final String id;
  final String email;
  final String fullName;
  final bool notifyOnFailure;
  final bool notifyOnSuccess;
  final bool emailOnFailure;

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as String,
        email: j['email'] as String,
        fullName: j['full_name'] as String,
        notifyOnFailure: j['notify_on_failure'] as bool? ?? true,
        notifyOnSuccess: j['notify_on_success'] as bool? ?? false,
        emailOnFailure: j['email_on_failure'] as bool? ?? false,
      );
}

class TokenResponse {
  TokenResponse({required this.accessToken, required this.refreshToken, required this.user, required this.expiresAt});

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
  PageOf({required this.items, required this.total, required this.page, required this.pageSize});

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < total;

  factory PageOf.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) item) => PageOf(
        items: (j['items'] as List).map((e) => item(e as Map<String, dynamic>)).toList(),
        total: j['total'] as int,
        page: j['page'] as int,
        pageSize: j['page_size'] as int,
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
    required this.lastExecutionStatus,
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
  final String? lastExecutionStatus;

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
        lastExecutionStatus: (j['last_execution'] as Map<String, dynamic>?)?['status'] as String?,
      );
}

class WorkflowDetail extends WorkflowSummary {
  WorkflowDetail({
    required super.id,
    required super.name,
    required super.description,
    required super.status,
    required super.triggerType,
    required super.stepCount,
    required super.lastRunAt,
    required super.nextRunAt,
    required super.updatedAt,
    required super.lastExecutionStatus,
    required this.validation,
    required this.webhookUrl,
    required this.stepNames,
  });

  final List<String> validation;
  final String? webhookUrl;
  final List<String> stepNames;

  bool get isValid => validation.isEmpty;

  factory WorkflowDetail.fromJson(Map<String, dynamic> j) {
    final s = WorkflowSummary.fromJson(j);
    final nodes = ((j['definition'] as Map<String, dynamic>?)?['nodes'] as List?) ?? const [];
    return WorkflowDetail(
      id: s.id,
      name: s.name,
      description: s.description,
      status: s.status,
      triggerType: s.triggerType,
      stepCount: s.stepCount,
      lastRunAt: s.lastRunAt,
      nextRunAt: s.nextRunAt,
      updatedAt: s.updatedAt,
      lastExecutionStatus: s.lastExecutionStatus,
      validation: ((j['validation'] as List?) ?? const []).map((e) => (e as Map)['message'] as String).toList(),
      webhookUrl: j['webhook_url'] as String?,
      stepNames: nodes.map((n) => (n as Map)['name'] as String).toList(),
    );
  }
}

class ExecutionSummary {
  ExecutionSummary({
    required this.id,
    required this.workflowId,
    required this.workflowName,
    required this.status,
    required this.triggerType,
    required this.errorMessage,
    required this.createdAt,
    required this.durationMs,
  });

  final String id;
  final String workflowId;
  final String workflowName;
  final String status;
  final String triggerType;
  final String? errorMessage;
  final DateTime createdAt;
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
        durationMs: j['duration_ms'] as int?,
      );
}

class ExecutionStep {
  ExecutionStep({
    required this.nodeName,
    required this.nodeType,
    required this.status,
    required this.attempts,
    required this.durationMs,
    required this.errorMessage,
    required this.output,
  });

  final String nodeName;
  final String nodeType;
  final String status;
  final int attempts;
  final int? durationMs;
  final String? errorMessage;
  final Map<String, dynamic>? output;

  factory ExecutionStep.fromJson(Map<String, dynamic> j) => ExecutionStep(
        nodeName: j['node_name'] as String,
        nodeType: j['node_type'] as String,
        status: j['status'] as String,
        attempts: j['attempts'] as int? ?? 0,
        durationMs: j['duration_ms'] as int?,
        errorMessage: j['error_message'] as String?,
        output: j['output'] as Map<String, dynamic>?,
      );
}

class ExecutionDetail extends ExecutionSummary {
  ExecutionDetail({
    required super.id,
    required super.workflowId,
    required super.workflowName,
    required super.status,
    required super.triggerType,
    required super.errorMessage,
    required super.createdAt,
    required super.durationMs,
    required this.steps,
    required this.triggerPayload,
  });

  final List<ExecutionStep> steps;
  final Map<String, dynamic> triggerPayload;

  factory ExecutionDetail.fromJson(Map<String, dynamic> j) {
    final s = ExecutionSummary.fromJson(j);
    return ExecutionDetail(
      id: s.id,
      workflowId: s.workflowId,
      workflowName: s.workflowName,
      status: s.status,
      triggerType: s.triggerType,
      errorMessage: s.errorMessage,
      createdAt: s.createdAt,
      durationMs: s.durationMs,
      steps: ((j['steps'] as List?) ?? const []).map((e) => ExecutionStep.fromJson(e as Map<String, dynamic>)).toList(),
      triggerPayload: (j['trigger_payload'] as Map<String, dynamic>?) ?? const {},
    );
  }
}

class DashboardSummary {
  DashboardSummary({
    required this.totalWorkflows,
    required this.activeWorkflows,
    required this.totalExecutions,
    required this.successRate,
    required this.failures24h,
    required this.inProgress,
    required this.attention,
    required this.recent,
  });

  final int totalWorkflows;
  final int activeWorkflows;
  final int totalExecutions;
  final double? successRate;
  final int failures24h;
  final int inProgress;
  final List<String> attention;
  final List<ExecutionSummary> recent;

  factory DashboardSummary.fromJson(Map<String, dynamic> j) {
    final health = j['health'] as Map<String, dynamic>;
    return DashboardSummary(
      totalWorkflows: j['total_workflows'] as int,
      activeWorkflows: j['active_workflows'] as int,
      totalExecutions: j['total_executions'] as int,
      successRate: (j['success_rate_30d'] as num?)?.toDouble(),
      failures24h: health['failures_24h'] as int,
      inProgress: health['in_progress'] as int,
      attention: (health['attention'] as List).map((a) => (a as Map)['workflow_name'] as String).toList(),
      recent: (j['recent_executions'] as List).map((e) => ExecutionSummary.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class AppNotification {
  AppNotification({required this.id, required this.kind, required this.title, required this.body, required this.link, required this.read, required this.createdAt});

  final String id;
  final String kind;
  final String title;
  final String body;
  final String? link;
  final bool read;
  final DateTime createdAt;

  /// Execution ID when the notification links to a run.
  String? get executionId {
    final match = RegExp(r'^/executions/([0-9a-f-]{36})$').firstMatch(link ?? '');
    return match?.group(1);
  }

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
  SessionInfo({required this.id, required this.userAgent, required this.lastUsedAt, required this.current});

  final String id;
  final String? userAgent;
  final DateTime lastUsedAt;
  final bool current;

  factory SessionInfo.fromJson(Map<String, dynamic> j) => SessionInfo(
        id: j['id'] as String,
        userAgent: j['user_agent'] as String?,
        lastUsedAt: _date(j['last_used_at'])!,
        current: j['current'] as bool,
      );
}
