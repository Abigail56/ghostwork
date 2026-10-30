import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'token_store.dart';

class ApiException implements Exception {
  ApiException(this.status, this.message, [this.issues = const []]);

  final int status;
  final String message;
  final List<String> issues;

  @override
  String toString() => issues.isEmpty ? message : '$message ${issues.join(' ')}';
}

/// Talks to the GhostWork API using the mobile auth mode: refresh tokens travel in
/// request bodies (never cookies) and rotate on every refresh.
class ApiClient {
  ApiClient({required this.baseUrl, required this.tokens, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final TokenStore tokens;
  final http.Client _http;

  String? _accessToken;
  Future<TokenResponse?>? _refreshing;

  /// Called when the session can't be refreshed (expired, revoked, signed out elsewhere).
  void Function()? onSessionLost;

  bool get hasAccessToken => _accessToken != null;

  Uri _uri(String path, [Map<String, Object?>? query]) {
    final params = <String, String>{};
    query?.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) params[key] = value.toString();
    });
    return Uri.parse('$baseUrl/api/v1$path').replace(queryParameters: params.isEmpty ? null : params);
  }

  Future<http.Response> _send(String method, Uri uri, {Object? body, bool auth = true}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (auth && _accessToken != null) headers['Authorization'] = 'Bearer $_accessToken';
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    try {
      return await http.Response.fromStream(await _http.send(request).timeout(const Duration(seconds: 30)));
    } on TimeoutException {
      throw ApiException(0, 'The GhostWork server took too long to respond.');
    } catch (_) {
      throw ApiException(0, "Can't reach the GhostWork server. Check your connection.");
    }
  }

  ApiException _error(http.Response r) {
    var message = 'Request failed (${r.statusCode}).';
    var issues = <String>[];
    try {
      final detail = (jsonDecode(r.body) as Map<String, dynamic>)['detail'];
      if (detail is String) {
        message = detail;
      } else if (detail is Map) {
        message = detail['message'] as String? ?? message;
        issues = ((detail['issues'] as List?) ?? const []).map((i) => (i as Map)['message'] as String).toList();
      } else if (detail is List) {
        message = detail.map((d) => ((d as Map)['msg'] as String).replaceFirst('Value error, ', '')).join(' ');
      }
    } catch (_) {}
    return ApiException(r.statusCode, message, issues);
  }

  Future<dynamic> request(String method, String path, {Object? body, Map<String, Object?>? query, bool auth = true}) async {
    final uri = _uri(path, query);
    var response = await _send(method, uri, body: body, auth: auth);
    if (response.statusCode == 401 && auth) {
      final refreshed = await refresh();
      if (refreshed == null) {
        onSessionLost?.call();
        throw ApiException(401, 'Your session has ended. Please sign in again.');
      }
      response = await _send(method, uri, body: body, auth: auth);
    }
    if (response.statusCode >= 400) throw _error(response);
    if (response.statusCode == 204 || response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getJson(String path, {Map<String, Object?>? query}) async =>
      (await request('GET', path, query: query)) as Map<String, dynamic>;

  Future<List<dynamic>> getList(String path) async => (await request('GET', path)) as List<dynamic>;

  /* ---------------- Auth ---------------- */

  Future<TokenResponse> _accept(Map<String, dynamic> json) async {
    final tokens = TokenResponse.fromJson(json);
    _accessToken = tokens.accessToken;
    if (tokens.refreshToken != null) await this.tokens.write(tokens.refreshToken!);
    return tokens;
  }

  Future<TokenResponse> login(String email, String password) async {
    final json = await request('POST', '/auth/login',
        auth: false, body: {'email': email, 'password': password, 'client': 'mobile'});
    return _accept(json as Map<String, dynamic>);
  }

  Future<TokenResponse> register(String fullName, String email, String password, {required bool acceptTerms}) async {
    final json = await request('POST', '/auth/register', auth: false, body: {
      'full_name': fullName,
      'email': email,
      'password': password,
      'accept_terms': acceptTerms,
      'client': 'mobile',
    });
    return _accept(json as Map<String, dynamic>);
  }

  /// Rotate the stored refresh token. Concurrent callers share one request.
  Future<TokenResponse?> refresh() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<TokenResponse?> _doRefresh() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = await tokens.read();
      if (token == null) return null;
      final response = await _send('POST', _uri('/auth/refresh'), body: {'refresh_token': token}, auth: false);
      if (response.statusCode == 200) return _accept(jsonDecode(response.body) as Map<String, dynamic>);
      if (response.statusCode == 409 && attempt == 0) {
        // Another refresh rotated the token a moment ago; retry with whatever is stored now.
        await Future<void>.delayed(const Duration(milliseconds: 400));
        continue;
      }
      if (response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 204) {
        _accessToken = null;
        await tokens.clear();
        return null;
      }
      throw _error(response);
    }
    return null;
  }

  Future<void> logout() async {
    final token = await tokens.read();
    try {
      if (token != null) await _send('POST', _uri('/auth/logout'), body: {'refresh_token': token}, auth: false);
    } finally {
      _accessToken = null;
      await tokens.clear();
    }
  }

  /* ---------------- Account ---------------- */

  Future<User> me() async => User.fromJson(await getJson('/auth/me'));

  Future<({String message, bool emailConfigured})> forgotPassword(String email) async {
    final j = (await request('POST', '/auth/forgot-password', auth: false, body: {'email': email})) as Map<String, dynamic>;
    return (message: j['message'] as String, emailConfigured: j['email_delivery_configured'] as bool);
  }

  Future<void> resetPassword(String token, String password) =>
      request('POST', '/auth/reset-password', auth: false, body: {'token': token, 'password': password});

  Future<String> changePassword(String current, String next) async =>
      ((await request('POST', '/auth/change-password', body: {'current_password': current, 'new_password': next})) as Map)['message'] as String;

  Future<User> changeEmail(String email, String password) async =>
      User.fromJson((await request('POST', '/users/me/email', body: {'new_email': email, 'password': password})) as Map<String, dynamic>);

  Future<void> deleteAccount(String password) async {
    await request('DELETE', '/users/me', body: {'password': password});
    _accessToken = null;
    await tokens.clear();
  }

  Future<User> updateProfile(Map<String, Object?> changes) async =>
      User.fromJson((await request('PATCH', '/users/me', body: changes)) as Map<String, dynamic>);

  Future<List<SessionInfo>> sessions() async =>
      (await getList('/auth/sessions')).map((e) => SessionInfo.fromJson(e as Map<String, dynamic>)).toList();

  Future<void> revokeSession(String id) => request('DELETE', '/auth/sessions/$id');

  Future<String> revokeOtherSessions() async => ((await request('POST', '/auth/sessions/revoke-others')) as Map)['message'] as String;

  Future<PageOf<Activity>> activity({int page = 1}) async =>
      PageOf.fromJson(await getJson('/activity', query: {'page': page, 'page_size': 10}), Activity.fromJson);

  Future<(List<AppNotification>, int)> notifications() async {
    final json = await getJson('/notifications');
    return ((json['items'] as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList(), json['unread'] as int);
  }

  Future<void> markNotification(String id) => request('POST', id == 'all' ? '/notifications/read-all' : '/notifications/$id/read');

  Future<bool> health() async {
    try {
      await request('GET', '/health', auth: false);
      return true;
    } on ApiException {
      return false;
    }
  }

  /* ---------------- Dashboard & workflows ---------------- */

  Future<DashboardSummary> dashboard() async => DashboardSummary.fromJson(await getJson('/dashboard/summary'));

  Future<PageOf<WorkflowSummary>> workflows({String? q, String? status, String sort = '-updated', int page = 1, int pageSize = 12}) async =>
      PageOf.fromJson(
        await getJson('/workflows', query: {'q': q, 'status': status, 'sort': sort, 'page': page, 'page_size': pageSize}),
        WorkflowSummary.fromJson,
      );

  Future<Workflow> workflow(String id) async => Workflow.fromJson(await getJson('/workflows/$id'));

  Future<Workflow> _workflowCall(String method, String path, [Object? body]) async =>
      Workflow.fromJson((await request(method, path, body: body)) as Map<String, dynamic>);

  Future<Workflow> createWorkflow({required String name, String description = '', Definition? definition}) =>
      _workflowCall('POST', '/workflows', {'name': name, 'description': description, 'definition': definition?.toJson()});

  Future<Workflow> updateWorkflow(String id, {String? name, String? description, Definition? definition, int? expectedVersion}) =>
      _workflowCall('PATCH', '/workflows/$id', {
        'name': ?name,
        'description': ?description,
        if (definition != null) 'definition': definition.toJson(),
        'expected_version': ?expectedVersion,
      });

  Future<void> deleteWorkflow(String id) => request('DELETE', '/workflows/$id');

  Future<Workflow> duplicateWorkflow(String id) => _workflowCall('POST', '/workflows/$id/duplicate');

  Future<Workflow> setWorkflowStatus(String id, String status) => _workflowCall('POST', '/workflows/$id/status', {'status': status});

  Future<Workflow> rotateWebhook(String id) => _workflowCall('POST', '/workflows/$id/webhook/rotate');

  Future<String> enableWebhookSigning(String id) async =>
      ((await request('POST', '/workflows/$id/webhook/secret')) as Map)['secret'] as String;

  Future<Workflow> disableWebhookSigning(String id) => _workflowCall('DELETE', '/workflows/$id/webhook/secret');

  Future<ExecutionSummary> runWorkflow(String id, [Map<String, dynamic> payload = const {}]) async =>
      ExecutionSummary.fromJson((await request('POST', '/workflows/$id/run', body: {'payload': payload})) as Map<String, dynamic>);

  /* ---------------- Executions ---------------- */

  Future<PageOf<ExecutionSummary>> executions({String? q, String? status, String? workflowId, DateTime? from, DateTime? to, int page = 1, int pageSize = 20}) async =>
      PageOf.fromJson(
        await getJson('/executions', query: {
          'q': q,
          'status': status,
          'workflow_id': workflowId,
          'from': from?.toUtc().toIso8601String(),
          'to': to?.toUtc().toIso8601String(),
          'page': page,
          'page_size': pageSize,
        }),
        ExecutionSummary.fromJson,
      );

  Future<Execution> execution(String id) async => Execution.fromJson(await getJson('/executions/$id'));

  Future<ExecutionSummary> executionAction(String id, String action) async =>
      ExecutionSummary.fromJson((await request('POST', '/executions/$id/$action')) as Map<String, dynamic>);

  /* ---------------- Catalog, templates, integrations ---------------- */

  Future<List<NodeType>> nodeTypes() async =>
      ((await request('GET', '/node-types', auth: false)) as List).map((e) => NodeType.fromJson(e as Map<String, dynamic>)).toList();

  Future<List<Template>> templates() async =>
      ((await request('GET', '/templates', auth: false)) as List).map((e) => Template.fromJson(e as Map<String, dynamic>)).toList();

  Future<Workflow> useTemplate(String slug) => _workflowCall('POST', '/templates/$slug/use', <String, dynamic>{});

  Future<List<IntegrationProvider>> providers() async =>
      ((await request('GET', '/integrations/providers', auth: false)) as List).map((e) => IntegrationProvider.fromJson(e as Map<String, dynamic>)).toList();

  Future<List<Integration>> integrations() async =>
      (await getList('/integrations')).map((e) => Integration.fromJson(e as Map<String, dynamic>)).toList();

  Future<Integration> connectIntegration(String provider, String name, Map<String, dynamic> config) async => Integration.fromJson(
      (await request('POST', '/integrations', body: {'provider': provider, 'name': name, 'config': config})) as Map<String, dynamic>);

  Future<Integration> testIntegration(String id) async =>
      Integration.fromJson((await request('POST', '/integrations/$id/test')) as Map<String, dynamic>);

  Future<void> disconnectIntegration(String id) => request('DELETE', '/integrations/$id');
}
