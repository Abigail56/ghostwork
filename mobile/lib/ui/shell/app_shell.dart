// Port of frontend/src/components/app/{AppShell,Sidebar,Topbar}.tsx (mobile layout).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../components/logo.dart';
import '../components/ui.dart';
import '../format.dart';

const appNav = [
  ('/dashboard', 'Dashboard', Icons.space_dashboard_outlined),
  ('/workflows', 'Workflows', Icons.account_tree_outlined),
  ('/executions', 'Executions', Icons.history),
  ('/integrations', 'Integrations', Icons.power_outlined),
  ('/templates', 'Templates', Icons.view_quilt_outlined),
  ('/settings', 'Settings', Icons.settings_outlined),
];

bool isActive(String location, String href) => location == href || location.startsWith('$href/');

String pageTitle(String location) {
  if (location.endsWith('/builder')) return 'Builder';
  if (location == '/workflows/new') return 'New workflow';
  if (isActive(location, '/help')) return 'Help';
  for (final (href, label, _) in appNav) {
    if (isActive(location, href)) return label;
  }
  return 'GhostWork';
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.of(context).size.width >= 768;
    final builder = location.endsWith('/builder');
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => context.go('/workflows'),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => context.go('/workflows'),
      },
      child: Scaffold(
        drawer: wide ? null : const Drawer(child: SafeArea(child: SidebarContent())),
        body: SafeArea(
          child: Row(
            children: [
              if (wide)
                Container(
                  width: MediaQuery.of(context).size.width >= 1280 && !builder ? 240 : 68,
                  decoration: const BoxDecoration(
                    color: Gw.sidebar,
                    border: Border(right: BorderSide(color: Gw.lineSubtle)),
                  ),
                  child: SidebarContent(compact: MediaQuery.of(context).size.width < 1280 || builder),
                ),
              Expanded(
                child: Column(
                  children: [
                    _Topbar(location: location, showMenu: !wide),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard scrolling page body (web <main> with max width and padding).
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.onRefresh});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ],
    );
    return onRefresh == null ? list : RefreshIndicator(color: Gw.violet, backgroundColor: Gw.elevated, onRefresh: onRefresh!, child: list);
  }
}

class SidebarContent extends ConsumerWidget {
  const SidebarContent({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final auth = ref.watch(authProvider);
    void go(String href) {
      if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) Navigator.pop(context);
      context.go(href);
    }

    Widget item(String href, String label, IconData icon) {
      final active = isActive(location, href);
      return Tooltip(
        message: compact ? label : '',
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Material(
            color: active ? Gw.violetSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(Gw.rMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(Gw.rMd),
              onTap: () => go(href),
              child: SizedBox(
                height: 40,
                width: compact ? 40 : null,
                child: Stack(
                  children: [
                    if (active)
                      Positioned(
                        left: 0,
                        top: 9,
                        bottom: 9,
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(color: Gw.violet, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    Positioned.fill(
                      left: compact ? 11 : 12,
                      right: compact ? 11 : 12,
                      child: Row(
                        children: [
                          Icon(icon, size: 18, color: active ? Gw.violet : Gw.fgMuted, semanticLabel: compact ? label : null),
                          if (!compact) ...[const SizedBox(width: 12), Text(label, style: GwText.bodyMedium.copyWith(color: active ? Gw.fg : Gw.fgSecondary))],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 12, vertical: 16),
      child: Column(
        crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(left: compact ? 0 : 8, bottom: 24),
            child: Align(alignment: compact ? Alignment.center : Alignment.centerLeft, child: compact ? const GhostMark(size: 26) : const Wordmark(size: 26)),
          ),
          for (final (href, label, icon) in appNav) item(href, label, icon),
          const Spacer(),
          item('/help', 'Help', Icons.support_outlined),
          Tooltip(
            message: compact ? 'Log out' : '',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(Gw.rMd),
                onTap: () => ref.read(authProvider.notifier).logout(),
                child: SizedBox(
                  height: 40,
                  width: compact ? 40 : null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 11 : 12),
                    child: Row(
                      children: [
                        const Icon(Icons.logout, size: 18, color: Gw.fgMuted, semanticLabel: 'Log out'),
                        if (!compact) ...[const SizedBox(width: 12), Text('Log out', style: GwText.bodyMedium.copyWith(color: Gw.fgSecondary))],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (auth is SignedIn && !compact)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Gw.surface,
                borderRadius: BorderRadius.circular(Gw.rLg),
                border: Border.all(color: Gw.lineSubtle),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Gw.violetSoft,
                    child: Text(
                      auth.user.initials,
                      style: GwText.meta.copyWith(color: Gw.violet, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.user.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: GwText.meta.copyWith(color: Gw.fg, fontWeight: FontWeight.w500),
                        ),
                        Text(auth.user.email, overflow: TextOverflow.ellipsis, style: GwText.micro),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Topbar extends ConsumerWidget {
  const _Topbar({required this.location, required this.showMenu});
  final String location;
  final bool showMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final unread = ref.watch(notificationsProvider).value?.$2 ?? 0;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xE60B0D12),
        border: Border(bottom: BorderSide(color: Gw.lineSubtle)),
      ),
      child: Row(
        children: [
          if (showMenu) GwIconButton(icon: Icons.menu, tooltip: 'Open navigation', size: 40, onPressed: () => Scaffold.of(context).openDrawer()),
          const SizedBox(width: 4),
          Text(pageTitle(location), style: GwText.bodyMedium.copyWith(color: Gw.fgSecondary)),
          const Spacer(),
          GwIconButton(icon: Icons.search, tooltip: 'Search workflows', onPressed: () => context.go('/workflows')),
          Stack(
            clipBehavior: Clip.none,
            children: [
              GwIconButton(
                icon: Icons.notifications_none,
                tooltip: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
                onPressed: () => _showNotifications(context, ref),
              ),
              if (unread > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Gw.violet, borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(fontFamily: Gw.fontSans, fontSize: 10, fontWeight: FontWeight.w700, color: Gw.canvas),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Account menu',
            offset: const Offset(0, 44),
            onSelected: (v) => switch (v) {
              'profile' => context.go('/settings?tab=profile'),
              'settings' => context.go('/settings'),
              _ => ref.read(authProvider.notifier).logout(),
            },
            itemBuilder: (_) => [
              _menuItem('profile', 'Profile', Icons.person_outline),
              _menuItem('settings', 'Settings', Icons.settings_outlined),
              const PopupMenuDivider(height: 8),
              _menuItem('logout', 'Log out', Icons.logout),
            ],
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Gw.violetSoft,
              child: Text(
                auth is SignedIn ? auth.user.initials : '',
                style: GwText.meta.copyWith(color: Gw.violet, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

PopupMenuItem<String> _menuItem(String value, String label, IconData icon, {bool danger = false}) => PopupMenuItem(
  value: value,
  height: 40,
  child: Row(
    children: [
      Icon(icon, size: 16, color: danger ? Gw.danger : Gw.fgSecondary),
      const SizedBox(width: 10),
      Text(label, style: GwText.body.copyWith(color: danger ? Gw.danger : Gw.fgSecondary)),
    ],
  ),
);

PopupMenuItem<String> gwMenuItem(String value, String label, IconData icon, {bool danger = false}) => _menuItem(value, label, icon, danger: danger);

void _showNotifications(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    barrierColor: Colors.transparent,
    builder: (ctx) => Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 60, 12, 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 352, maxHeight: 520),
          child: Material(
            color: Gw.elevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Gw.rLg),
              side: const BorderSide(color: Gw.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Consumer(
              builder: (ctx, ref, _) {
                final data = ref.watch(notificationsProvider);
                final api = ref.read(apiClientProvider);
                final items = data.value?.$1 ?? const [];
                final unread = data.value?.$2 ?? 0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Gw.lineSubtle)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Notifications', style: GwText.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                          ),
                          if (unread > 0)
                            GwLink(
                              'Mark all read',
                              icon: Icons.done_all,
                              onTap: () async {
                                await api.markNotification('all');
                                ref.invalidate(notificationsProvider);
                              },
                            ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text("You're all caught up.", style: GwText.body.copyWith(color: Gw.fgMuted)),
                            )
                          : ListView(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              children: [
                                for (final n in items)
                                  InkWell(
                                    onTap: () async {
                                      Navigator.pop(ctx);
                                      if (!n.read) {
                                        await api.markNotification(n.id);
                                        ref.invalidate(notificationsProvider);
                                      }
                                      if (n.link != null && context.mounted) context.go(n.link!);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin: const EdgeInsets.only(top: 6, right: 12),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: n.read
                                                  ? Colors.transparent
                                                  : (n.kind == 'execution_failed' ? Gw.danger : (n.kind == 'security' ? Gw.warning : Gw.success)),
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  n.title,
                                                  style: GwText.body.copyWith(
                                                    color: n.read ? Gw.fgSecondary : Gw.fg,
                                                    fontWeight: n.read ? FontWeight.w400 : FontWeight.w500,
                                                  ),
                                                ),
                                                if (n.body.isNotEmpty) Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: GwText.meta),
                                                Text(timeAgo(n.createdAt), style: GwText.micro),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
