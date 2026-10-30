import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostwork_mobile/data/api_client.dart';
import 'package:ghostwork_mobile/data/token_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

void main() {
  late MemoryTokenStore store;
  setUp(() => store = MemoryTokenStore());

  ApiClient client(Future<http.Response> Function(http.Request) handler) =>
      ApiClient(baseUrl: 'http://api.test', tokens: store, httpClient: MockClient(handler));

  test('login uses mobile mode and stores the refresh token', () async {
    late Map<String, dynamic> sent;
    final api = client((r) async {
      sent = jsonDecode(r.body) as Map<String, dynamic>;
      return http.Response(encode(tokenJson('a1', 'r1')), 200);
    });
    await api.login('ada@example.com', 'pw');
    expect(sent['client'], 'mobile');
    expect(await store.read(), 'r1');
  });

  test('register sends terms acceptance', () async {
    late Map<String, dynamic> sent;
    final api = client((r) async {
      sent = jsonDecode(r.body) as Map<String, dynamic>;
      return http.Response(encode(tokenJson('a1', 'r1')), 201);
    });
    await api.register('Ada', 'ada@example.com', 'pw-1234567890', acceptTerms: true);
    expect(sent['accept_terms'], isTrue);
  });

  test('401 triggers one refresh, rotates the token, and retries', () async {
    await store.write('r1');
    final calls = <String>[];
    final api = client((r) async {
      calls.add('${r.method} ${r.url.path} ${r.headers['Authorization'] ?? ''}');
      if (r.url.path.endsWith('/auth/refresh')) {
        expect(jsonDecode(r.body)['refresh_token'], 'r1');
        return http.Response(encode(tokenJson('a2', 'r2')), 200);
      }
      if (r.headers['Authorization'] == 'Bearer a2') return http.Response(encode(dashboardJson), 200);
      return http.Response('{"detail":"expired"}', 401);
    });
    final d = await api.dashboard();
    expect(d.totalWorkflows, 4);
    expect(await store.read(), 'r2');
    expect(calls, ['GET /api/v1/dashboard/summary ', 'POST /api/v1/auth/refresh ', 'GET /api/v1/dashboard/summary Bearer a2']);
  });

  test('concurrent refreshes share one request', () async {
    await store.write('r1');
    var refreshes = 0;
    final api = client((r) async {
      refreshes++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response(encode(tokenJson('a2', 'r2')), 200);
    });
    await Future.wait([api.refresh(), api.refresh(), api.refresh()]);
    expect(refreshes, 1);
  });

  test('409 from refresh is retried once', () async {
    await store.write('r1');
    var attempts = 0;
    final api = client((r) async {
      attempts++;
      return attempts == 1 ? http.Response('{"detail":"race"}', 409) : http.Response(encode(tokenJson('a2', 'r2')), 200);
    });
    expect((await api.refresh())?.accessToken, 'a2');
    expect(attempts, 2);
  });

  test('failed refresh clears the token and reports session loss', () async {
    await store.write('stale');
    var lost = false;
    final api = client((r) async =>
        r.url.path.endsWith('/auth/refresh') ? http.Response('{"detail":"ended"}', 401) : http.Response('{}', 401))
      ..onSessionLost = () => lost = true;
    await expectLater(api.dashboard(), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    expect(lost, isTrue);
    expect(await store.read(), isNull);
  });

  test('validation errors surface issues', () async {
    final api = client((r) async => http.Response(
        encode({'detail': {'message': 'Fix the workflow before running it.', 'issues': [{'message': 'Add a trigger.', 'node_id': null, 'field': null}]}}),
        422));
    final error = await api.runWorkflow('w1').then<ApiException?>((_) => null, onError: (Object e) => e as ApiException);
    expect(error!.message, 'Fix the workflow before running it.');
    expect(error.issues, ['Add a trigger.']);
  });

  test('network failures become friendly errors', () async {
    final api = client((r) async => throw http.ClientException('offline'));
    await expectLater(api.dashboard(), throwsA(isA<ApiException>().having((e) => e.status, 'status', 0)));
  });

  test('logout revokes the stored token and clears it', () async {
    await store.write('r1');
    String? sentToken;
    final api = client((r) async {
      sentToken = jsonDecode(r.body)['refresh_token'] as String?;
      return http.Response('{"message":"Signed out."}', 200);
    });
    await api.logout();
    expect(sentToken, 'r1');
    expect(await store.read(), isNull);
  });
}
