import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostwork_mobile/data/models.dart';
import 'package:ghostwork_mobile/router.dart';
import 'package:ghostwork_mobile/state/providers.dart';
import 'package:ghostwork_mobile/ui/canvas/flow_canvas.dart';
import 'package:ghostwork_mobile/ui/canvas/node_meta.dart';
import 'package:ghostwork_mobile/ui/screens/app/builder.dart';
import 'package:ghostwork_mobile/ui/screens/auth/auth_screens.dart';

import 'fixtures.dart';

void main() {
  final def = Workflow.fromJson(workflowJson).definition;

  test('dirty detection ignores JSONB key order and whole-number doubles', () {
    final fromServer = workflowJson['definition'];
    final local = def.toJson();
    expect(canonicalJson(fromServer), canonicalJson(local));
    final moved = Definition.fromJson(local)..nodes[0] = def.nodes[0].copyWith(x: 10);
    expect(canonicalJson(moved.toJson()) == canonicalJson(fromServer), isFalse);
  });

  test('new node ids follow the web builder scheme', () {
    expect(nextNodeId('action.http_request', def.nodes), 'http_1');
    expect(nextNodeId('condition.if', [...def.nodes, NodeDef(id: 'condition_1', type: 'condition.if', name: '', x: 0, y: 0, config: {})]), 'condition_2');
  });

  test('connections follow the same rules as the web', () {
    expect(canConnect(def, 'check', 'true', 'start'), isFalse); // triggers have no inputs
    expect(canConnect(def, 'fetch', 'out', 'fetch'), isFalse); // no self-loops
    expect(canConnect(def, 'check', 'true', 'fetch'), isFalse); // duplicate
    expect(canConnect(def, 'check', 'false', 'fetch'), isTrue);
  });

  test('edges only animate while their target is running', () {
    final e = def.edges.single;
    expect(edgeStateFor(e, {'check': 'succeeded', 'fetch': 'running'}), EdgeState.active);
    expect(edgeStateFor(e, {'check': 'succeeded', 'fetch': 'succeeded'}), EdgeState.traversed);
    expect(edgeStateFor(e, {'check': 'succeeded', 'fetch': 'skipped'}), EdgeState.skipped);
    expect(edgeStateFor(e, const {}), EdgeState.idle);
  });

  test('node summaries match frontend/src/lib/nodes.ts', () {
    expect(summarize('trigger.schedule', {'every': 1, 'unit': 'hours'}), 'Every 1 hour');
    expect(summarize('trigger.schedule', {'every': 15, 'unit': 'minutes'}), 'Every 15 minutes');
    expect(summarize('action.http_request', {'method': 'POST', 'url': 'https://crm.example.com/leads'}), 'POST crm.example.com/leads');
    expect(summarize('condition.if', {'left': '{{ steps.n.plan }}', 'operator': 'equals', 'right': 'pro'}), 'steps.n.plan = pro');
    expect(summarize('action.transform', {'fields': [{'key': 'a'}, {'key': 'b'}]}), 'Builds a, b');
  });

  test('auth redirects mirror the web app', () {
    const out = SignedOut();
    expect(authRedirect(out, Uri.parse('/workflows/w1')), '/login?next=%2Fworkflows%2Fw1');
    expect(authRedirect(const SignedOut(exitTo: '/'), Uri.parse('/settings')), '/');
    expect(authRedirect(out, Uri.parse('/pricing')), isNull);
    final user = SignedIn(Workflow.fromJson(workflowJson).name.isEmpty ? throw '' : _user());
    expect(authRedirect(user, Uri.parse('/login?next=/executions')), '/executions');
    expect(authRedirect(user, Uri.parse('/login?next=//evil.example')), '/dashboard');
    expect(authRedirect(user, Uri.parse('/splash?next=%2F')), '/dashboard');
    expect(authRedirect(const AuthUnknown(), Uri.parse('/dashboard')), '/splash?next=%2Fdashboard');
  });

  test('validation messages match the web forms', () {
    expect(validateEmail('nope'), 'Enter a valid email address.');
    expect(passwordProblems('short1'), 'Use at least 10 characters.');
    expect(passwordProblems('lettersonlypassword'), 'Include at least one letter and one number.');
    expect(passwordProblems('aaaaaaaaaa1'), 'This password is too repetitive.');
    expect(passwordProblems('correct-horse-42'), isNull);
  });

  test('terms asset is identical to the web terms', () {
    final web = File('../frontend/src/lib/terms.json').readAsStringSync();
    final mobile = File('assets/terms.json').readAsStringSync();
    expect(mobile, web, reason: 'Run scripts/sync-shared.sh');
  });
}

User _user() => User.fromJson(tokenJson('a', 'r')['user'] as Map<String, dynamic>);
