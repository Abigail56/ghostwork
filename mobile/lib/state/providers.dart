import 'package:flutter/foundation.dart';
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
  const SignedOut({this.message});
  final String? message;
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

  Future<void> login(String email, String password) async {
    final tokens = await _api.login(email.trim(), password);
    state = SignedIn(tokens.user);
  }

  Future<void> register(String name, String email, String password, {required bool acceptTerms}) async {
    final tokens = await _api.register(name.trim(), email.trim(), password, acceptTerms: acceptTerms);
    state = SignedIn(tokens.user);
  }

  Future<void> logout() async {
    await _api.logout();
    state = const SignedOut();
  }

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

final dashboardProvider = FutureProvider.autoDispose<DashboardSummary>((ref) => ref.watch(apiClientProvider).dashboard());

typedef WorkflowQuery = ({String q, String? status});

final workflowsProvider = FutureProvider.autoDispose.family<PageOf<WorkflowSummary>, WorkflowQuery>(
  (ref, query) => ref.watch(apiClientProvider).workflows(q: query.q, status: query.status),
);

final workflowProvider = FutureProvider.autoDispose.family<WorkflowDetail, String>(
  (ref, id) => ref.watch(apiClientProvider).workflow(id),
);

typedef ExecutionQuery = ({String? status, String? workflowId});

final executionsProvider = FutureProvider.autoDispose.family<PageOf<ExecutionSummary>, ExecutionQuery>(
  (ref, query) => ref.watch(apiClientProvider).executions(status: query.status, workflowId: query.workflowId),
);

final executionProvider = FutureProvider.autoDispose.family<ExecutionDetail, String>(
  (ref, id) => ref.watch(apiClientProvider).execution(id),
);

final notificationsProvider = FutureProvider.autoDispose<(List<AppNotification>, int)>(
  (ref) => ref.watch(apiClientProvider).notifications(),
);

final sessionsProvider = FutureProvider.autoDispose<List<SessionInfo>>((ref) => ref.watch(apiClientProvider).sessions());
