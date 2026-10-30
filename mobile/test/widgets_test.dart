import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostwork_mobile/core/theme.dart';
import 'package:ghostwork_mobile/data/api_client.dart';
import 'package:ghostwork_mobile/data/models.dart';
import 'package:ghostwork_mobile/data/token_store.dart';
import 'package:ghostwork_mobile/main.dart';
import 'package:ghostwork_mobile/state/providers.dart';
import 'package:ghostwork_mobile/ui/screens/auth_screens.dart';
import 'package:ghostwork_mobile/ui/widgets/common.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

Widget wrap(Widget child, {ApiClient? api}) => ProviderScope(
      overrides: [if (api != null) apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(theme: buildTheme(), home: Scaffold(body: child)),
    );

ApiClient fakeApi(Future<http.Response> Function(http.Request) handler, {TokenStore? store}) =>
    ApiClient(baseUrl: 'http://api.test', tokens: store ?? MemoryTokenStore(), httpClient: MockClient(handler));

void main() {
  testWidgets('status badges show icon and label, not just color', (tester) async {
    await tester.pumpWidget(wrap(const Column(children: [StatusBadge('failed'), StatusBadge('running'), StatusBadge('paused')])));
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.byIcon(Icons.highlight_off), findsOneWidget);
  });

  testWidgets('step timeline shows statuses, attempts and errors', (tester) async {
    final detail = ExecutionDetail.fromJson(executionDetailJson);
    await tester.pumpWidget(wrap(SingleChildScrollView(child: StepTimeline(steps: detail.steps))));
    expect(find.text('Fetch'), findsOneWidget);
    expect(find.text('Failed · 2 attempts'), findsOneWidget);
    expect(find.text('The server responded with HTTP 500.'), findsOneWidget);
    expect(find.text('Skipped'), findsOneWidget);
  });

  testWidgets('login validates input before calling the API', (tester) async {
    var calls = 0;
    final api = fakeApi((r) async {
      calls++;
      return http.Response('', 204);
    });
    await tester.pumpWidget(wrap(const LoginScreen(), api: api));
    await tester.pump();
    final before = calls;
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(calls, before);
  });

  testWidgets('sign-up requires accepting the terms', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final paths = <String>[];
    final api = fakeApi((r) async {
      paths.add(r.url.path);
      return r.url.path.endsWith('/register') ? http.Response(encode(tokenJson('a', 'r')), 201) : http.Response('', 204);
    });
    await tester.pumpWidget(wrap(const RegisterScreen(), api: api));
    await tester.pump();
    expect(find.textContaining('the short version'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Ada Lovelace');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'ada@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'long-password-123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    expect(find.text('Please read and accept the Terms of Service to continue.'), findsOneWidget);
    expect(paths.where((p) => p.endsWith('/register')), isEmpty);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    expect(paths.where((p) => p.endsWith('/register')), hasLength(1));
  });

  testWidgets('signed-out user sees login, signs in and lands on the dashboard', (tester) async {
    tester.view.physicalSize = const Size(1170, 3600); // tall phone so the whole dashboard is laid out
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final api = fakeApi((r) async => switch (r.url.path) {
          '/api/v1/auth/login' => http.Response(encode(tokenJson('a1', 'r1')), 200),
          '/api/v1/dashboard/summary' => http.Response(encode(dashboardJson), 200),
          '/api/v1/notifications' => http.Response(encode({'items': [], 'unread': 0}), 200),
          _ => http.Response('', 204), // no stored session
        });
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)], child: const GhostWorkApp()));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'ada@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'secret-password-1');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ada'), findsWidgets);
    expect(find.text('91.9%'), findsOneWidget);
    expect(find.text('Nightly sync'), findsWidgets);
    expect(find.text('Needs attention'), findsOneWidget);
  });
}
