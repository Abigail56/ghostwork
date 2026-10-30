// Same URLs and auth rules as the web app (frontend/src/app).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'state/providers.dart';
import 'ui/components/logo.dart';
import 'ui/screens/app/builder.dart';
import 'ui/screens/app/dashboard.dart';
import 'ui/screens/app/executions.dart';
import 'ui/screens/app/more_screens.dart';
import 'ui/screens/app/workflows.dart';
import 'ui/screens/auth/auth_screens.dart';
import 'ui/screens/public/public_screens.dart';
import 'ui/shell/app_shell.dart';

const _protected = ['/dashboard', '/workflows', '/executions', '/integrations', '/templates', '/settings', '/help'];
bool _isProtected(String path) => _protected.any((p) => path == p || path.startsWith('$p/'));

/// Pure redirect logic, unit-tested in test/router_test.dart.
String? authRedirect(AuthState auth, Uri uri) {
  final path = uri.path;
  final full = uri.toString();
  final authPage = path == '/login' || path == '/register';
  switch (auth) {
    case AuthUnknown():
      if (path == '/splash') return null;
      return _isProtected(path) || authPage ? '/splash?next=${Uri.encodeComponent(full)}' : null;
    case SignedOut(:final exitTo):
      if (path == '/splash') {
        final next = uri.queryParameters['next'];
        return next != null && !_isProtected(Uri.parse(next).path) ? next : '/';
      }
      if (_isProtected(path)) return exitTo ?? '/login?next=${Uri.encodeComponent(full)}';
      return null;
    case SignedIn():
      final next = uri.queryParameters['next'];
      final safeNext = next != null && next.startsWith('/') && !next.startsWith('//') ? next : null;
      if (path == '/splash') return (safeNext == null || safeNext == '/') ? '/dashboard' : safeNext;
      if (authPage) return safeNext ?? '/dashboard';
      return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authListenableProvider);
  Page<void> page(Widget child) => NoTransitionPage(child: child);
  return GoRouter(
    initialLocation: '/splash?next=%2F',
    refreshListenable: auth,
    redirect: (context, state) => authRedirect(auth.value, state.uri),
    errorBuilder: (_, _) => const NotFoundScreen(),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: GhostMark(size: 44)))),
      GoRoute(path: '/', pageBuilder: (_, _) => page(const LandingScreen())),
      GoRoute(path: '/features', pageBuilder: (_, _) => page(const FeaturesScreen())),
      GoRoute(path: '/pricing', pageBuilder: (_, _) => page(const PricingScreen())),
      GoRoute(path: '/docs', pageBuilder: (_, _) => page(const DocsScreen())),
      GoRoute(path: '/about', pageBuilder: (_, _) => page(const AboutScreen())),
      GoRoute(path: '/privacy', pageBuilder: (_, _) => page(const PrivacyScreen())),
      GoRoute(path: '/terms', builder: (_, _) => const TermsScreen()),
      GoRoute(
        path: '/login',
        pageBuilder: (_, s) => page(LoginScreen(next: s.uri.queryParameters['next'], reset: s.uri.queryParameters['reset'] == '1')),
      ),
      GoRoute(path: '/register', pageBuilder: (_, _) => page(const RegisterScreen())),
      GoRoute(path: '/forgot-password', pageBuilder: (_, _) => page(const ForgotPasswordScreen())),
      GoRoute(path: '/reset-password', pageBuilder: (_, s) => page(ResetPasswordScreen(token: s.uri.queryParameters['token']))),
      ShellRoute(
        builder: (_, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/dashboard', pageBuilder: (_, _) => page(const DashboardScreen())),
          GoRoute(path: '/workflows', pageBuilder: (_, s) => page(WorkflowListScreen(key: ValueKey(s.uri.query), initialQuery: s.uri.queryParameters['q'] ?? ''))),
          GoRoute(path: '/workflows/new', pageBuilder: (_, _) => page(const NewWorkflowScreen())),
          GoRoute(path: '/workflows/:id', pageBuilder: (_, s) => page(WorkflowDetailScreen(key: ValueKey(s.pathParameters['id']), id: s.pathParameters['id']!))),
          GoRoute(path: '/workflows/:id/builder', pageBuilder: (_, s) => page(BuilderLoader(key: ValueKey(s.pathParameters['id']), id: s.pathParameters['id']!))),
          GoRoute(path: '/executions', pageBuilder: (_, s) => page(ExecutionsScreen(key: ValueKey(s.uri.query), workflowId: s.uri.queryParameters['workflow_id'] ?? ''))),
          GoRoute(path: '/executions/:id', pageBuilder: (_, s) => page(ExecutionDetailScreen(key: ValueKey(s.pathParameters['id']), id: s.pathParameters['id']!))),
          GoRoute(path: '/integrations', pageBuilder: (_, _) => page(const IntegrationsScreen())),
          GoRoute(path: '/templates', pageBuilder: (_, _) => page(const TemplatesScreen())),
          GoRoute(path: '/settings', pageBuilder: (_, s) => page(SettingsScreen(key: ValueKey(s.uri.query), tab: s.uri.queryParameters['tab'] ?? 'profile'))),
          GoRoute(path: '/help', pageBuilder: (_, _) => page(const HelpScreen())),
        ],
      ),
    ],
  );
});
