import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../state/providers.dart';
import '../format.dart';
import '../widgets/common.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final api = ref.read(apiClientProvider);
    final unread = notifications.value?.$2 ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts'), actions: [
        if (unread > 0)
          TextButton(
            onPressed: () async {
              await api.markNotification('all');
              ref.invalidate(notificationsProvider);
            },
            child: const Text('Mark all read'),
          ),
      ]),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(notificationsProvider.future),
        child: AsyncView(
          value: notifications,
          onRetry: () => ref.invalidate(notificationsProvider),
          builder: (data) => data.$1.isEmpty
              ? ListView(children: const [MessageView(icon: Icons.notifications_none, title: "You're all caught up")])
              : ListView.separated(
                  itemCount: data.$1.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final n = data.$1[i];
                    final color = n.kind == 'execution_failed' ? Gw.danger : (n.kind == 'security' ? Gw.warning : Gw.success);
                    return ListTile(
                      leading: Icon(
                        n.kind == 'execution_failed' ? Icons.highlight_off : (n.kind == 'security' ? Icons.shield_outlined : Icons.check_circle_outline),
                        color: n.read ? Gw.fgMuted : color,
                      ),
                      title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w400 : FontWeight.w600)),
                      subtitle: Text([if (n.body.isNotEmpty) n.body, timeAgo(n.createdAt)].join('\n'), maxLines: 3, overflow: TextOverflow.ellipsis),
                      onTap: () async {
                        if (!n.read) {
                          await api.markNotification(n.id);
                          ref.invalidate(notificationsProvider);
                        }
                        if (n.executionId != null && context.mounted) context.push('/runs/${n.executionId}');
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _saving = false;

  Future<void> _update(Map<String, Object?> changes) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final user = await ref.read(apiClientProvider).updateProfile(changes);
      ref.read(authProvider.notifier).updateUser(user);
      messenger.showSnackBar(const SnackBar(content: Text('Saved')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth is! SignedIn) return const SizedBox.shrink();
    final user = auth.user;
    final sessions = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Gw.violet.withValues(alpha: 0.15),
              child: Text(user.fullName.isEmpty ? '?' : user.fullName[0].toUpperCase(), style: const TextStyle(color: Gw.violet)),
            ),
            title: Text(user.fullName),
            subtitle: Text(user.email),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Notifications',
          child: Column(children: [
            SwitchListTile(
              title: const Text('Failed runs'),
              subtitle: const Text('In-app alert when a run fails'),
              value: user.notifyOnFailure,
              onChanged: _saving ? null : (v) => _update({'notify_on_failure': v}),
            ),
            SwitchListTile(
              title: const Text('Successful runs'),
              subtitle: const Text('In-app alert when a run succeeds'),
              value: user.notifyOnSuccess,
              onChanged: _saving ? null : (v) => _update({'notify_on_success': v}),
            ),
            SwitchListTile(
              title: const Text('Email me about failures'),
              subtitle: const Text('Requires outgoing email on the server'),
              value: user.emailOnFailure,
              onChanged: _saving ? null : (v) => _update({'email_on_failure': v}),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Active sessions',
          child: AsyncView(
            value: sessions,
            onRetry: () => ref.invalidate(sessionsProvider),
            builder: (list) => Column(children: [
              for (final s in list)
                ListTile(
                  leading: Icon(s.current ? Icons.smartphone : Icons.devices_other, color: Gw.fgMuted),
                  title: Text(s.current ? 'This device' : _describe(s.userAgent)),
                  subtitle: Text('Active ${timeAgo(s.lastUsedAt)}'),
                  trailing: s.current
                      ? null
                      : TextButton(
                          onPressed: () async {
                            await ref.read(apiClientProvider).revokeSession(s.id);
                            ref.invalidate(sessionsProvider);
                          },
                          child: const Text('Sign out'),
                        ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser, color: Gw.fgMuted),
              title: const Text('Open GhostWork on the web'),
              subtitle: const Text('Build and edit workflows, manage integrations'),
              onTap: () => launchUrl(Uri.parse('$webAppUrl/dashboard'), mode: LaunchMode.externalApplication),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: Gw.fgMuted),
              title: const Text('Terms of Service'),
              onTap: () => launchUrl(Uri.parse('$webAppUrl/terms'), mode: LaunchMode.externalApplication),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => ref.read(authProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ]),
    );
  }

  static String _describe(String? ua) {
    if (ua == null) return 'Unknown device';
    if (RegExp('iPhone|iPad').hasMatch(ua)) return 'iOS device';
    if (ua.contains('Android')) return 'Android device';
    if (ua.contains('Windows')) return 'Windows computer';
    if (ua.contains('Mac OS X')) return 'Mac';
    if (ua.contains('Linux')) return 'Linux computer';
    if (RegExp('dart|okhttp', caseSensitive: false).hasMatch(ua)) return 'GhostWork app';
    return 'Browser';
  }
}
