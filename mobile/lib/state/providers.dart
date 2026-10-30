import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../data/token_store.dart';

/// Overridden in tests with a client backed by a mock HTTP client.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(baseUrl: apiBaseUrl, tokens: TokenStore.platform()));

sealed class AuthState {
  const AuthState();
}

class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class SignedOut extends AuthState {
  const SignedOut({this.message, this.exitTo});
  final String? message;

  /// Where a deliberate sign-out should land (web: logout(exitTo)).
  final String? exitTo;
}

class SignedIn extends AuthState {
  const SignedIn(this.user);
  final User user;
}

class AuthController extends Notifier<AuthState> {
  late ApiClient _api;

  @override
  AuthState build() {
    _api = ref.watch(apiClientProvider);
    _api.onSessionLost = () => state = const SignedOut(message: 'Your session ended. Please sign in again.');
    Future.microtask(_restore);
    return const AuthUnknown();
  }

  Future<void> _restore() async {
    try {
      final tokens = await _api.refresh();
      state = tokens == null ? const SignedOut() : SignedIn(tokens.user);
    } on ApiException {
      state = const SignedOut();
    }
  }

  Future<void> login(String email, String password) async => state = SignedIn((await _api.login(email.trim(), password)).user);

  Future<void> register(String name, String email, String password, {required bool acceptTerms}) async =>
      state = SignedIn((await _api.register(name.trim(), email.trim(), password, acceptTerms: acceptTerms)).user);

  Future<void> logout({String exitTo = '/login'}) async {
    try {
      await _api.logout();
    } finally {
      state = SignedOut(exitTo: exitTo);
    }
  }

  /// After the account was deleted server-side.
  void forget({String exitTo = '/'}) => state = SignedOut(exitTo: exitTo);

  void updateUser(User user) => state = SignedIn(user);
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Bridges auth changes to go_router's refreshListenable.
final authListenableProvider = Provider<ValueNotifier<AuthState>>((ref) {
  final notifier = ValueNotifier<AuthState>(ref.read(authProvider));
  ref.listen(authProvider, (_, next) => notifier.value = next);
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// Appearance preferences (Settings → Appearance), applied app-wide.
final reduceMotionProvider = Provider<bool?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth is! SignedIn) return null;
  return switch (auth.user.reduceMotion) { 'reduce' => true, 'full' => false, _ => null };
});

final compactProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  return auth is SignedIn && auth.user.density == 'compact';
});

/* ---------------- Data ---------------- */

final dashboardProvider = FutureProvider.autoDispose<DashboardSummary>((ref) => ref.watch(apiClientProvider).dashboard());

typedef WorkflowQuery = ({String q, String status, String sort, int page, int pageSize});

final workflowsProvider = FutureProvider.autoDispose.family<PageOf<WorkflowSummary>, WorkflowQuery>(
  (ref, q) => ref.watch(apiClientProvider).workflows(q: q.q, status: q.status, sort: q.sort, page: q.page, pageSize: q.pageSize),
);

final workflowProvider = FutureProvider.autoDispose.family<Workflow, String>((ref, id) => ref.watch(apiClientProvider).workflow(id));

typedef ExecutionQuery = ({String q, String status, String workflowId, DateTime? from, DateTime? to, int page, int pageSize});

final executionsProvider = FutureProvider.autoDispose.family<PageOf<ExecutionSummary>, ExecutionQuery>(
  (ref, q) => ref.watch(apiClientProvider).executions(
        q: q.q,
        status: q.status,
        workflowId: q.workflowId,
        from: q.from,
        to: q.to,
        page: q.page,
        pageSize: q.pageSize,
      ),
);

final executionProvider = FutureProvider.autoDispose.family<Execution, String>((ref, id) => ref.watch(apiClientProvider).execution(id));

final notificationsProvider = FutureProvider.autoDispose<(List<AppNotification>, int)>((ref) => ref.watch(apiClientProvider).notifications());

final sessionsProvider = FutureProvider.autoDispose<List<SessionInfo>>((ref) => ref.watch(apiClientProvider).sessions());

final activityProvider = FutureProvider.autoDispose.family<PageOf<Activity>, int>((ref, page) => ref.watch(apiClientProvider).activity(page: page));

final nodeTypesProvider = FutureProvider<List<NodeType>>((ref) => ref.watch(apiClientProvider).nodeTypes());

final templatesProvider = FutureProvider.autoDispose<List<Template>>((ref) => ref.watch(apiClientProvider).templates());

final providersProvider = FutureProvider.autoDispose<List<IntegrationProvider>>((ref) => ref.watch(apiClientProvider).providers());

final integrationsProvider = FutureProvider.autoDispose<List<Integration>>((ref) => ref.watch(apiClientProvider).integrations());

final healthProvider = FutureProvider.autoDispose<bool>((ref) => ref.watch(apiClientProvider).health());

/* ---------------- Shared content ---------------- */

class TermsSection {
  TermsSection(this.id, this.title, this.paragraphs, this.bullets);
  final String id;
  final String title;
  final List<String> paragraphs;
  final List<String> bullets;
}

class TermsDoc {
  TermsDoc(this.version, this.effective, this.summary, this.sections);
  final String version;
  final String effective;
  final List<String> summary;
  final List<TermsSection> sections;
}

/// The Terms of Service from assets/terms.json (identical to the web's terms.json).
final termsProvider = FutureProvider<TermsDoc>((ref) async {
  final j = jsonDecode(await rootBundle.loadString('assets/terms.json')) as Map<String, dynamic>;
  return TermsDoc(
    j['version'] as String,
    j['effective'] as String,
    (j['summary'] as List).cast<String>(),
    (j['sections'] as List)
        .map((s) => TermsSection(
              s['id'] as String,
              s['title'] as String,
              (s['paragraphs'] as List).cast<String>(),
              ((s['bullets'] as List?) ?? const []).cast<String>(),
            ))
        .toList(),
  );
});
