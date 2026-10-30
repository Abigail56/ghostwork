import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationsProvider).value?.$2 ?? 0;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.account_tree_outlined), label: 'Workflows'),
          const NavigationDestination(icon: Icon(Icons.history), label: 'Runs'),
          NavigationDestination(
            icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_none)),
            label: 'Alerts',
          ),
          const NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final firstName = auth is SignedIn ? auth.user.fullName.split(' ').first : '';
    final dashboard = ref.watch(dashboardProvider);
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    return Scaffold(
      appBar: AppBar(title: const Wordmark(size: 24)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardProvider.future),
        child: AsyncView(
          value: dashboard,
          errorTitle: "Couldn't load your dashboard",
          onRetry: () => ref.invalidate(dashboardProvider),
          builder: (d) => ListView(padding: const EdgeInsets.all(16), children: [
            Text('$greeting, $firstName', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text("Here's what your automations have been doing.", style: TextStyle(color: Gw.fgMuted)),
            const SizedBox(height: 16),
            // Rows that size to their content (no fixed aspect ratio), so large text never overflows.
            _MetricRow(children: [
              MetricTile(label: 'Workflows', value: '${d.totalWorkflows}', detail: '${d.activeWorkflows} active'),
              MetricTile(label: 'Executions', value: '${d.totalExecutions}', detail: 'All time'),
            ]),
            const SizedBox(height: 10),
            _MetricRow(children: [
              MetricTile(
                label: 'Success rate',
                value: d.successRate == null ? '—' : '${d.successRate}%',
                detail: d.successRate == null ? 'No finished runs' : 'Last 30 days',
              ),
              MetricTile(label: 'Failures (24h)', value: '${d.failures24h}', detail: '${d.inProgress} in progress'),
            ]),
            const SizedBox(height: 16),
            if (d.attention.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SectionCard(
                  title: 'Needs attention',
                  child: Column(children: [
                    for (final name in d.attention)
                      ListTile(
                        leading: const Icon(Icons.warning_amber_rounded, color: Gw.warning),
                        title: Text(name),
                        subtitle: const Text('Last run failed'),
                      ),
                  ]),
                ),
              ),
            SectionCard(
              title: 'Recent runs',
              trailing: TextButton(onPressed: () => context.go('/runs'), child: const Text('View all')),
              child: d.recent.isEmpty
                  ? const MessageView(
                      icon: Icons.history,
                      title: 'No runs yet',
                      message: 'Build a workflow in the web app, then run it from here.',
                    )
                  : Column(children: [
                      for (final e in d.recent) ExecutionTile(execution: e, onTap: () => context.push('/runs/${e.id}')),
                    ]),
            ),
            const SizedBox(height: 8),
            Text('Last updated ${timeAgo(DateTime.now())}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: children[0]),
          const SizedBox(width: 10),
          Expanded(child: children[1]),
        ]),
      );
}
