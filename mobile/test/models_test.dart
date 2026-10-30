import 'package:flutter_test/flutter_test.dart';
import 'package:ghostwork_mobile/data/models.dart';

import 'fixtures.dart';

void main() {
  test('parses token response with mobile refresh token', () {
    final t = TokenResponse.fromJson(tokenJson('a1', 'r1'));
    expect(t.accessToken, 'a1');
    expect(t.refreshToken, 'r1');
    expect(t.user.fullName, 'Ada Lovelace');
  });

  test('parses execution detail with steps', () {
    final e = ExecutionDetail.fromJson(executionDetailJson);
    expect(e.status, 'failed');
    expect(e.isActive, isFalse);
    expect(e.steps.map((s) => s.status), ['succeeded', 'failed', 'skipped']);
    expect(e.steps[1].attempts, 2);
    expect(e.triggerPayload['scheduled_at'], isNotNull);
  });

  test('parses dashboard summary', () {
    final d = DashboardSummary.fromJson(dashboardJson);
    expect(d.successRate, 91.9);
    expect(d.attention, ['Nightly sync']);
    expect(d.recent.single.workflowName, 'Nightly sync');
  });

  test('notification exposes linked execution id', () {
    final n = AppNotification.fromJson({
      'id': 'n1',
      'kind': 'execution_failed',
      'title': 'Nightly sync failed',
      'body': '',
      'link': '/executions/11111111-2222-3333-4444-555555555555',
      'read_at': null,
      'created_at': '2026-10-30T08:00:00Z',
    });
    expect(n.executionId, '11111111-2222-3333-4444-555555555555');
    expect(n.read, isFalse);
  });
}
