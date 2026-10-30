import 'dart:convert';

const userJson = {
  'id': 'u1',
  'email': 'ada@example.com',
  'full_name': 'Ada Lovelace',
  'notify_on_failure': true,
  'notify_on_success': false,
  'email_on_failure': false,
  'reduce_motion': 'system',
  'density': 'comfortable',
  'created_at': '2026-10-29T10:00:00Z',
  'password_changed_at': null,
};

Map<String, dynamic> tokenJson(String access, String refresh) => {
      'access_token': access,
      'token_type': 'bearer',
      'expires_at': '2030-01-01T00:00:00Z',
      'user': userJson,
      'refresh_token': refresh,
    };

const executionJson = {
  'id': '11111111-2222-3333-4444-555555555555',
  'workflow_id': 'w1',
  'workflow_name': 'Nightly sync',
  'status': 'failed',
  'trigger_type': 'trigger.schedule',
  'error_message': "Step 'Fetch' failed: The server responded with HTTP 500.",
  'created_at': '2026-10-30T08:00:00Z',
  'started_at': '2026-10-30T08:00:01Z',
  'finished_at': '2026-10-30T08:00:02Z',
  'duration_ms': 1234,
};

final executionDetailJson = {
  ...executionJson,
  'trigger_payload': {'scheduled_at': '2026-10-30T08:00:00Z'},
  'definition_snapshot': {'nodes': [], 'edges': []},
  'workflow_version': 3,
  'steps': [
    {'id': 's1', 'node_id': 't', 'node_type': 'trigger.schedule', 'node_name': 'Every hour', 'position': 0, 'status': 'succeeded', 'attempts': 1, 'output': {'type': 'trigger.schedule'}, 'error_message': null, 'started_at': null, 'finished_at': null, 'duration_ms': 3},
    {'id': 's2', 'node_id': 'f', 'node_type': 'action.http_request', 'node_name': 'Fetch', 'position': 1, 'status': 'failed', 'attempts': 2, 'output': null, 'error_message': 'The server responded with HTTP 500.', 'started_at': null, 'finished_at': null, 'duration_ms': 900},
    {'id': 's3', 'node_id': 'm', 'node_type': 'action.email', 'node_name': 'Email team', 'position': 2, 'status': 'skipped', 'attempts': 0, 'output': null, 'error_message': null, 'started_at': null, 'finished_at': null, 'duration_ms': null},
  ],
};

final dashboardJson = {
  'total_workflows': 4,
  'active_workflows': 2,
  'total_executions': 37,
  'executions_30d': 37,
  'success_rate_30d': 91.9,
  'trend': [
    {'date': '2026-10-30', 'succeeded': 2, 'failed': 1, 'other': 0},
  ],
  'recent_executions': [executionJson],
  'recent_activity': [
    {'id': 'a1', 'kind': 'workflow.activated', 'message': 'Nightly sync activated', 'workflow_id': 'w1', 'created_at': '2026-10-30T08:00:00Z'},
  ],
  'health': {'failures_24h': 1, 'successes_24h': 9, 'in_progress': 0, 'last_execution_at': null, 'attention': [{'workflow_id': 'w1', 'workflow_name': 'Nightly sync', 'reason': 'Last run failed'}]},
};

String encode(Object value) => jsonEncode(value);

const notificationJson = {
  'id': 'n1',
  'kind': 'execution_failed',
  'title': 'Nightly sync failed',
  'body': '',
  'link': '/executions/11111111-2222-3333-4444-555555555555',
  'read_at': null,
  'created_at': '2026-10-30T08:00:00Z',
};

final workflowSummaryJson = {
  'id': 'w1',
  'name': 'Nightly sync',
  'description': 'Pulls orders every night',
  'status': 'active',
  'trigger_type': 'trigger.schedule',
  'step_count': 3,
  'last_run_at': '2026-10-30T08:00:00Z',
  'next_run_at': null,
  'created_at': '2026-10-01T08:00:00Z',
  'updated_at': '2026-10-30T08:00:00Z',
  'last_execution': {'id': '11111111-2222-3333-4444-555555555555', 'status': 'failed', 'created_at': '2026-10-30T08:00:00Z', 'finished_at': null},
};

final workflowJson = {
  ...workflowSummaryJson,
  'version': 4,
  'webhook_url': null,
  'webhook_signing_enabled': false,
  // JSONB returns keys in a different order than the app writes them.
  'definition': {
    'edges': [
      {'source': 'check', 'target': 'fetch', 'source_handle': 'true', 'id': 'e1'},
    ],
    'nodes': [
      {'config': {'unit': 'hours', 'every': 1}, 'id': 'start', 'name': 'Every hour', 'type': 'trigger.schedule', 'position': {'y': 0, 'x': 0}},
      {'config': {'left': '{{ trigger.payload.x }}', 'operator': 'equals', 'right': '1'}, 'id': 'check', 'name': 'Check', 'type': 'condition.if', 'position': {'y': 170, 'x': 0}},
      {'config': {'method': 'GET', 'url': 'https://api.example.com/orders'}, 'id': 'fetch', 'name': 'Fetch orders', 'type': 'action.http_request', 'position': {'y': 340, 'x': -120}},
    ],
  },
  'validation': [
    {'message': 'Connect the true or false branch of this condition.', 'node_id': 'check', 'field': null},
  ],
};

const nodeTypesJson = [
  {'type': 'trigger.manual', 'kind': 'trigger', 'label': 'Manual trigger', 'description': 'Run on demand from GhostWork.', 'integration_provider': null, 'outputs': ['out'], 'default_config': {}},
  {'type': 'action.transform', 'kind': 'action', 'label': 'Transform data', 'description': 'Build a new object from earlier data.', 'integration_provider': null, 'outputs': ['out'], 'default_config': {'fields': []}},
  {'type': 'condition.if', 'kind': 'condition', 'label': 'Condition', 'description': 'Continue down the true or false branch.', 'integration_provider': null, 'outputs': ['true', 'false'], 'default_config': {'left': '', 'operator': 'equals', 'right': ''}},
];
