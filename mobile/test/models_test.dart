import 'package:flutter_test/flutter_test.dart';
import 'package:ghostwork_mobile/data/models.dart';

import 'fixtures.dart';

void main() {
  test('token response carries the mobile refresh token', () {
    final t = TokenResponse.fromJson(tokenJson('a1', 'r1'));
    expect((t.accessToken, t.refreshToken, t.user.initials), ('a1', 'r1', 'AL'));
  });

  test('workflow definition round-trips through JSON', () {
    final w = Workflow.fromJson(workflowJson);
    expect(w.definition.nodes.map((n) => n.kind), ['trigger', 'condition', 'action']);
    expect(w.definition.edges.single.handle, 'true');
    expect(w.validation.single.nodeId, 'check');
    final again = Definition.fromJson(w.definition.toJson());
    expect(again.toJson(), w.definition.toJson());
  });

  test('execution detail includes steps and the definition snapshot', () {
    final e = Execution.fromJson(executionDetailJson);
    expect(e.isActive, isFalse);
    expect(e.steps.map((s) => s.status), ['succeeded', 'failed', 'skipped']);
    expect(e.steps[1].attempts, 2);
  });

  test('dashboard summary parses trend, health and activity', () {
    final d = DashboardSummary.fromJson(dashboardJson);
    expect(d.successRate, 91.9);
    expect(d.trend.single.total, 3);
    expect(d.attention.single.workflowName, 'Nightly sync');
    expect(d.activity.single.message, 'Nightly sync activated');
  });

  test('notification exposes the linked execution', () {
    final n = AppNotification.fromJson(notificationJson);
    expect(n.executionId, '11111111-2222-3333-4444-555555555555');
  });
}
