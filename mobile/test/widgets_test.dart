import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostwork_mobile/core/theme.dart';
import 'package:ghostwork_mobile/data/api_client.dart';
import 'package:ghostwork_mobile/data/models.dart';
import 'package:ghostwork_mobile/data/token_store.dart';
import 'package:ghostwork_mobile/main.dart';
import 'package:ghostwork_mobile/state/providers.dart';
import 'package:ghostwork_mobile/ui/canvas/flow_canvas.dart';
import 'package:ghostwork_mobile/ui/screens/app/builder.dart';
import 'package:ghostwork_mobile/ui/components/ui.dart';
import 'package:ghostwork_mobile/ui/screens/auth/auth_screens.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

ApiClient fakeApi(Future<http.Response> Function(http.Request) handler) =>
    ApiClient(baseUrl: 'http://api.test', tokens: MemoryTokenStore(), httpClient: MockClient(handler));

Widget wrap(Widget child, {ApiClient? api}) => ProviderScope(
      overrides: [if (api != null) apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(theme: buildTheme(), home: Scaffold(body: child)),
    );

void phone(WidgetTester tester, {double height = 2532}) {
  tester.view.physicalSize = Size(1170, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('status badges carry an icon and a label, not just color', (tester) async {
    await tester.pumpWidget(wrap(const Column(children: [StatusBadge('failed'), StatusBadge('running'), StatusBadge('paused')])));
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.byIcon(Icons.highlight_off), findsOneWidget);
  });

  testWidgets('canvas renders nodes with real step statuses', (tester) async {
    final w = Workflow.fromJson(workflowJson);
    final e = Execution.fromJson(executionDetailJson);
    await tester.pumpWidget(wrap(SizedBox(width: 400, height: 500, child: FlowCanvas(definition: w.definition, steps: {'check': e.steps[0], 'fetch': e.steps[1]}))));
    await tester.pumpAndSettle();
    expect(find.text('Every hour'), findsOneWidget);
    expect(find.text('Fetch orders'), findsOneWidget);
    expect(find.text('TRUE'), findsOneWidget); // condition edge label
    expect(find.byIcon(Icons.highlight_off), findsOneWidget); // failed step
  });

  testWidgets('login validates before calling the API', (tester) async {
    phone(tester);
    var logins = 0;
    final api = fakeApi((r) async {
      if (r.url.path.endsWith('/login')) logins++;
      return http.Response('', 204);
    });
    await tester.pumpWidget(wrap(const LoginScreen(), api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(GwButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(logins, 0);
  });

  testWidgets('sign-up shows the Terms and requires accepting them', (tester) async {
    phone(tester, height: 4200);
    final registered = <Map<String, dynamic>>[];
    final api = fakeApi((r) async {
      if (r.url.path.endsWith('/register')) {
        registered.add(jsonDecode(r.body) as Map<String, dynamic>);
        return http.Response(encode(tokenJson('a', 'r')), 201);
      }
      return http.Response('', 204);
    });
    await tester.pumpWidget(wrap(const RegisterScreen(), api: api));
    await tester.pumpAndSettle();
    expect(find.text('The short version'), findsOneWidget);
    expect(find.text('5. Acceptable use'), findsOneWidget);

    final inputs = find.byType(TextFormField);
    await tester.enterText(inputs.at(0), 'Ada Lovelace');
    await tester.enterText(inputs.at(1), 'ada@example.com');
    await tester.enterText(inputs.at(2), 'long-password-123');
    await tester.tap(find.widgetWithText(GwButton, 'Create account'));
    await tester.pump();
    expect(find.text('Please read and accept the Terms of Service to continue.'), findsWidgets);
    expect(registered, isEmpty);

    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.widgetWithText(GwButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(registered.single['accept_terms'], isTrue);
  });

  testWidgets('sign in, land on the dashboard, open workflows and delete with confirmation', (tester) async {
    phone(tester, height: 5000);
    var deleted = false;
    final api = fakeApi((r) async => switch ((r.method, r.url.path)) {
          ('POST', '/api/v1/auth/login') => http.Response(encode(tokenJson('a1', 'r1')), 200),
          ('GET', '/api/v1/dashboard/summary') => http.Response(encode(dashboardJson), 200),
          ('GET', '/api/v1/workflows') => http.Response(encode({'items': deleted ? [] : [workflowSummaryJson], 'total': deleted ? 0 : 1, 'page': 1, 'page_size': 12}), 200),
          ('GET', '/api/v1/integrations') => http.Response('[]', 200),
          ('GET', '/api/v1/notifications') => http.Response(encode({'items': [], 'unread': 0}), 200),
          ('DELETE', '/api/v1/workflows/w1') => (() {
              deleted = true;
              return http.Response(encode({'message': 'Workflow deleted.'}), 200);
            })(),
          _ => http.Response('', 204), // no stored session
        });
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const GhostWorkApp()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your workflows.'), findsOneWidget); // landing page for signed-out users

    final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!;
    (router as dynamic).go('/login');
    await tester.pumpAndSettle();
    final inputs = find.byType(TextFormField);
    await tester.enterText(inputs.at(0), 'ada@example.com');
    await tester.enterText(inputs.at(1), 'secret-password-1');
    await tester.tap(find.widgetWithText(GwButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.textContaining(', Ada'), findsOneWidget);
    expect(find.text('91.9%'), findsOneWidget);
    expect(find.text('Workflow health'), findsOneWidget);

    (router as dynamic).go('/workflows');
    await tester.pumpAndSettle();
    expect(find.text('Nightly sync'), findsOneWidget);
    await tester.tap(find.byTooltip('Actions for Nightly sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete workflow?'), findsOneWidget);
    await tester.tap(find.widgetWithText(GwButton, 'Delete workflow'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
    expect(find.text('No workflows yet'), findsOneWidget);
  });

  testWidgets('builder: adding a step connects it to the selected step and marks unsaved changes', (tester) async {
    phone(tester);
    final w = Workflow.fromJson({
      ...workflowJson,
      'definition': {
        'nodes': [
          {'id': 'trigger', 'type': 'trigger.manual', 'name': 'Manual trigger', 'position': {'x': 0, 'y': 0}, 'config': {}},
        ],
        'edges': [],
      },
    });
    final api = fakeApi((r) async => switch (r.url.path) {
          '/api/v1/node-types' => http.Response(encode(nodeTypesJson), 200),
          '/api/v1/integrations' => http.Response('[]', 200),
          _ => http.Response('', 204),
        });
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(theme: buildTheme(), home: Scaffold(body: BuilderScreen(workflow: w))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Saved · valid'), findsNothing); // has a validation issue
    await tester.tap(find.widgetWithText(GwButton, 'Add step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transform data'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.text('Transform data'), findsWidgets); // the new node on the canvas

    // Undo right away removes exactly that step, even before the edit debounce fires.
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Transform data'), findsNothing);
    expect(find.text('Manual trigger'), findsOneWidget);
  });
}

