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
  'trend': [],
  'recent_executions': [executionJson],
  'recent_activity': [],
  'health': {'failures_24h': 1, 'successes_24h': 9, 'in_progress': 0, 'last_execution_at': null, 'attention': [{'workflow_id': 'w1', 'workflow_name': 'Nightly sync', 'reason': 'Last run failed'}]},
};

String encode(Object value) => jsonEncode(value);
