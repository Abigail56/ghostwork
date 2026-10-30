import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'state/providers.dart';
import 'ui/screens/account_screens.dart';
import 'ui/screens/auth_screens.dart';
import 'ui/screens/execution_screens.dart';
import 'ui/screens/home_screens.dart';
import 'ui/screens/workflow_screens.dart';
import 'ui/widgets/logo.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authListenableProvider);
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onAuthPage = location == '/login' || location == '/register';
      return switch (auth.value) {
        AuthUnknown() => location == '/splash' ? null : '/splash',
        SignedOut() => onAuthPage ? null : '/login',
        SignedIn() => (onAuthPage || location == '/splash') ? '/home' : null,
      };
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: GhostMark(size: 48)))),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const DashboardScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/workflows',
              builder: (_, _) => const WorkflowsScreen(),
              routes: [GoRoute(path: ':id', builder: (_, s) => WorkflowDetailScreen(id: s.pathParameters['id']!))],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/runs',
              builder: (_, _) => const ExecutionsScreen(),
              routes: [GoRoute(path: ':id', builder: (_, s) => ExecutionDetailScreen(id: s.pathParameters['id']!))],
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/alerts', builder: (_, _) => const NotificationsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen())]),
        ],
      ),
    ],
  );
});
