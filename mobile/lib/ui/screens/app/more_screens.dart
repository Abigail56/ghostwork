// Ports of the web Integrations, Templates, Settings and Help pages.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../data/api_client.dart';
import '../../../data/models.dart';
import '../../../state/providers.dart';
import '../../canvas/flow_canvas.dart';
import '../../canvas/node_meta.dart';
import '../../components/ui.dart';
import '../../format.dart';
import '../../shell/app_shell.dart';
import '../auth/auth_screens.dart' show PasswordField, PasswordStrength, passwordProblems, validateEmail;
import 'dashboard.dart' show asyncBody;
import 'workflows.dart' show describeError, refreshWorkflowData;

/* ================================ Integrations ================================ */

class IntegrationsScreen extends ConsumerWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(providersProvider);
    final integrations = ref.watch(integrationsProvider);
    return PageBody(
      onRefresh: () {
        ref.invalidate(providersProvider);
        return ref.refresh(integrationsProvider.future);
      },
      children: [
        const GwPageHeader(title: 'Integrations', description: 'Connect services once, then use them in any workflow step.'),
        if (providers.isLoading || integrations.isLoading)
          const GwLoading(rows: 5, label: 'Loading integrations')
        else if (providers.hasError || integrations.hasError)
          GwCard(
            child: GwError(
              title: "Couldn't load integrations",
              error: providers.error ?? integrations.error,
              onRetry: () {
                ref.invalidate(providersProvider);
                ref.invalidate(integrationsProvider);
              },
            ),
          )
        else
          ..._content(context, ref, providers.value!, integrations.value!),
      ],
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, List<IntegrationProvider> providers, List<Integration> integrations) {
    final available = providers.where((p) => p.available);
    final planned = providers.where((p) => !p.available);
    return [
      for (final p in available)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GwCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: Gw.elevated, borderRadius: BorderRadius.circular(Gw.rMd), border: Border.all(color: Gw.line)),
                    child: Icon(providerIcons[p.key] ?? Icons.power_outlined, size: 18, color: Gw.cyan),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(p.label, style: GwText.section),
                        if (integrations.any((i) => i.provider == p.key))
                          StatusBadge('connected', label: '${integrations.where((i) => i.provider == p.key).length} connected', small: true),
                      ]),
                      const SizedBox(height: 4),
                      Text(p.description, style: GwText.meta),
                    ]),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Gw.lineSubtle))),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GwButton(
                    label: integrations.any((i) => i.provider == p.key) ? 'Add another' : 'Connect',
                    icon: Icons.add,
                    size: GwSize.sm,
                    variant: integrations.any((i) => i.provider == p.key) ? GwVariant.secondary : GwVariant.primary,
                    onPressed: () => _connect(context, ref, p),
                  ),
                ),
              ),
            ]),
          ),
        ),
      GwCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const GwCardHeader(title: 'Your connections'),
          if (integrations.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No connections yet. Connect a service above to use it in workflows.', textAlign: TextAlign.center, style: GwText.body.copyWith(color: Gw.fgMuted)),
            )
          else
            for (final (i, it) in integrations.indexed) ...[if (i > 0) const Divider(), _ConnectionRow(integration: it)],
        ]),
      ),
      const SizedBox(height: 20),
      Text('Planned', style: GwText.section),
      const SizedBox(height: 12),
      for (final p in planned)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Gw.rLg), border: Border.all(color: Gw.lineStrong)),
          child: Row(children: [
            Icon(providerIcons[p.key] ?? Icons.power_outlined, size: 18, color: Gw.fgDisabled),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.label, style: GwText.bodyMedium.copyWith(color: Gw.fgSecondary)), Text(p.description, style: GwText.meta)])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Gw.elevated, borderRadius: BorderRadius.circular(99)),
              child: Text('Not available yet', style: GwText.micro),
            ),
          ]),
        ),
    ];
  }

  Future<void> _connect(BuildContext context, WidgetRef ref, IntegrationProvider provider) async {
    final f = <String, TextEditingController>{
      'name': TextEditingController(text: {'smtp': 'Email', 'slack': 'Slack', 'http_auth': 'API credential'}[provider.key]),
      'host': TextEditingController(),
      'port': TextEditingController(text: '587'),
      'username': TextEditingController(),
      'password': TextEditingController(),
      'sender': TextEditingController(),
      'webhook_url': TextEditingController(),
      'header_name': TextEditingController(text: 'X-API-Key'),
      'token': TextEditingController(),
    };
    var useTls = true;
    var scheme = 'bearer';
    String? error;
    var busy = false;
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xB8050609),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        Widget field(String key, String label, {String? hint, bool secret = false, bool optional = false, String? help, TextInputType? type}) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GwField(
                label: label,
                optional: optional,
                hint: help == null ? null : Text(help),
                child: GwInput(controller: f[key], hint: hint, obscure: secret, keyboardType: type, semanticLabel: label),
              ),
            );
        Future<void> submit() async {
          if (f['name']!.text.trim().isEmpty) return setLocal(() => error = 'Give this connection a name.');
          final config = switch (provider.key) {
            'smtp' => {
                'host': f['host']!.text.trim(),
                'port': int.tryParse(f['port']!.text) ?? 587,
                'username': f['username']!.text.trim().isEmpty ? null : f['username']!.text.trim(),
                'password': f['password']!.text.isEmpty ? null : f['password']!.text,
                'use_tls': useTls,
                'sender': f['sender']!.text.trim(),
              },
            'slack' => {'webhook_url': f['webhook_url']!.text.trim()},
            _ => {'scheme': scheme, 'header_name': scheme == 'bearer' ? 'Authorization' : f['header_name']!.text.trim(), 'token': f['token']!.text},
          };
          setLocal(() => (busy = true, error = null));
          try {
            final it = await ref.read(apiClientProvider).connectIntegration(provider.key, f['name']!.text.trim(), config);
            ref.invalidate(integrationsProvider);
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) toast(context, '${it.name} connected');
          } catch (e) {
            setLocal(() => (busy = false, error = describeError(e)));
          }
        }

        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Gw.lineSubtle))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Connect ${provider.label}', style: GwText.section),
                      const SizedBox(height: 4),
                      Text(provider.description, style: GwText.body.copyWith(color: Gw.fgMuted)),
                    ]),
                  ),
                  GwIconButton(icon: Icons.close, tooltip: 'Close', size: 32, onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (error != null) Padding(padding: const EdgeInsets.only(bottom: 14), child: GwAlert(child: Text(error!))),
                    field('name', 'Connection name'),
                    if (provider.key == 'smtp') ...[
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 3, child: field('host', 'SMTP host', hint: 'smtp.example.com')),
                        const SizedBox(width: 8),
                        Expanded(child: field('port', 'Port', type: TextInputType.number)),
                      ]),
                      field('username', 'Username', optional: true),
                      field('password', 'Password', optional: true, secret: true),
                      field('sender', 'Send from', hint: 'automations@example.com', help: 'The address recipients will see.', type: TextInputType.emailAddress),
                      GwSwitch(label: 'Use STARTTLS', description: 'Port 465 always uses implicit TLS.', value: useTls, onChanged: (v) => setLocal(() => useTls = v)),
                      const SizedBox(height: 12),
                      Text('GhostWork signs in to the server to check these settings before saving. Nothing is sent.', style: GwText.meta),
                    ],
                    if (provider.key == 'slack')
                      field('webhook_url', 'Incoming webhook URL', hint: 'https://hooks.slack.com/services/…', help: 'Create one in Slack under Apps → Incoming Webhooks.'),
                    if (provider.key == 'http_auth') ...[
                      Text('How is it sent?', style: GwText.meta.copyWith(color: Gw.fgSecondary, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      GwSegmented<String>(value: scheme, options: const [('bearer', 'Bearer token'), ('header', 'Custom header')], onChanged: (v) => setLocal(() => scheme = v)),
                      const SizedBox(height: 14),
                      if (scheme == 'header') field('header_name', 'Header name'),
                      field('token', 'Token', secret: true, help: 'Encrypted at rest and never shown again.'),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Gw.canvas, borderRadius: BorderRadius.circular(Gw.rMd), border: Border.all(color: Gw.lineSubtle)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.verified_user_outlined, size: 15, color: Gw.success),
                        const SizedBox(width: 8),
                        Expanded(child: Text("Secrets are encrypted before they're stored and are never sent back to your device.", style: GwText.meta)),
                      ]),
                    ),
                  ]),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(color: Color(0x9910131A), border: Border(top: BorderSide(color: Gw.lineSubtle))),
                child: Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
                  GwButton(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
                  GwButton(label: provider.key == 'smtp' ? 'Check and connect' : 'Connect', variant: GwVariant.primary, loading: busy, onPressed: submit),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
  }
}

class _ConnectionRow extends ConsumerStatefulWidget {
  const _ConnectionRow({required this.integration});
  final Integration integration;

  @override
  ConsumerState<_ConnectionRow> createState() => _ConnectionRowState();
}

class _ConnectionRowState extends ConsumerState<_ConnectionRow> {
  bool _testing = false;

  @override
  Widget build(BuildContext context) {
    final it = widget.integration;
    final details = it.details.entries.where((e) => e.key != 'has_password' && e.key != 'use_tls').map((e) => '${e.key}: ${e.value}').join(' · ');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [Text(it.name, style: GwText.bodyMedium), StatusBadge(it.status, small: true)]),
        const SizedBox(height: 4),
        Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: GwText.mono.copyWith(fontSize: 11, color: Gw.fgMuted)),
        if (it.lastError != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(it.lastError!, style: GwText.meta.copyWith(color: Gw.danger))),
        Text('Connected ${timeAgo(it.createdAt)}${it.lastVerifiedAt != null ? ' · checked ${timeAgo(it.lastVerifiedAt)}' : ''}', style: GwText.micro),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          if (it.provider == 'smtp')
            GwButton(
              label: 'Test',
              icon: Icons.bolt,
              size: GwSize.sm,
              loading: _testing,
              onPressed: () async {
                setState(() => _testing = true);
                try {
                  await ref.read(apiClientProvider).testIntegration(it.id);
                  if (context.mounted) toast(context, 'Connection works');
                } catch (e) {
                  if (context.mounted) toast(context, 'Connection check failed', description: describeError(e), tone: AlertTone.danger);
                } finally {
                  ref.invalidate(integrationsProvider);
                  if (mounted) setState(() => _testing = false);
                }
              },
            ),
          GwButton(
            label: 'Disconnect',
            icon: Icons.delete_outline,
            size: GwSize.sm,
            variant: GwVariant.ghost,
            onPressed: () async {
              final ok = await confirmAction(
                context,
                title: 'Disconnect ${it.name}?',
                description: 'Its stored credentials will be deleted. Workflow steps that use it will fail validation until you choose another connection.',
                confirmLabel: 'Disconnect',
                danger: true,
                action: () async {
                  try {
                    await ref.read(apiClientProvider).disconnectIntegration(it.id);
                    return null;
                  } catch (e) {
                    return describeError(e);
                  }
                },
              );
              if (ok) {
                ref.invalidate(integrationsProvider);
                if (context.mounted) toast(context, 'Disconnected');
              }
            },
          ),
        ]),
      ]),
    );
  }
}

/* ================================ Templates ================================ */

class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  String? _using;
  static const _providerLabels = {'smtp': 'Email (SMTP)', 'slack': 'Slack'};

  Future<void> _use(Template t) async {
    setState(() => _using = t.slug);
    try {
      final w = await ref.read(apiClientProvider).useTemplate(t.slug);
      refreshWorkflowData(ref);
      if (mounted) {
        toast(context, 'Workflow created from template', description: 'Review each step, then run a test.');
        context.go('/workflows/${w.id}/builder');
      }
    } catch (e) {
      if (mounted) toast(context, "Couldn't create the workflow", description: describeError(e), tone: AlertTone.danger);
    } finally {
      if (mounted) setState(() => _using = null);
    }
  }

  void _preview(Template t, Set<String> connected) => showGwDialog(
        context,
        title: t.name,
        description: t.description,
        body: (_) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 300,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Gw.rLg), border: Border.all(color: Gw.lineSubtle)),
            clipBehavior: Clip.antiAlias,
            child: FlowCanvas(definition: t.definition),
          ),
          const SizedBox(height: 16),
          for (final n in t.definition.nodes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 84, child: Text(kindStyle(n.kind).label.toUpperCase(), style: GwText.eyebrow.copyWith(color: kindStyle(n.kind).color))),
                Expanded(child: Text(n.name, style: GwText.body.copyWith(color: Gw.fgSecondary))),
              ]),
            ),
          if (t.requires.any((r) => !connected.contains(r)))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GwAlert(
                tone: AlertTone.info,
                child: Text('This template needs ${t.requires.map((r) => _providerLabels[r] ?? r).join(' and ')}. You can create it now and connect the integration before running it.'),
              ),
            ),
        ]),
        footer: (ctx) => [
          GwButton(label: 'Close', onPressed: () => Navigator.pop(ctx)),
          GwButton(
            label: 'Use template',
            trailingIcon: Icons.arrow_forward,
            variant: GwVariant.primary,
            onPressed: () {
              Navigator.pop(ctx);
              _use(t);
            },
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(templatesProvider);
    final connected = (ref.watch(integrationsProvider).value ?? const <Integration>[]).map((i) => i.provider).toSet();
    return PageBody(
      onRefresh: () => ref.refresh(templatesProvider.future),
      children: [
        const GwPageHeader(title: 'Templates', description: 'Start from a working pattern. Every template uses steps that are available today.'),
        asyncBody(
          templates,
          onRetry: () => ref.invalidate(templatesProvider),
          (list) => Column(children: [
            for (final t in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GwCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.category.toUpperCase(), style: GwText.eyebrow),
                        const SizedBox(height: 6),
                        Text(t.name, style: GwText.section),
                        const SizedBox(height: 4),
                        Text(t.description, style: GwText.meta),
                        const SizedBox(height: 16),
                        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                          for (final (i, n) in t.definition.nodes.indexed) ...[
                            Tooltip(
                              message: n.name,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(color: kindStyle(n.kind).soft, borderRadius: BorderRadius.circular(6)),
                                child: Icon(nodeIcon(n.type), size: 14, color: kindStyle(n.kind).color, semanticLabel: n.name),
                              ),
                            ),
                            if (i < t.definition.nodes.length - 1) Container(width: 12, height: 1, margin: const EdgeInsets.symmetric(horizontal: 4), color: Gw.lineStrong),
                          ],
                        ]),
                        if (t.requires.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Uses ${t.requires.map((r) => _providerLabels[r] ?? r).join(', ')}${t.requires.any((r) => !connected.contains(r)) ? ' — not connected yet' : ''}',
                              style: GwText.micro.copyWith(color: t.requires.any((r) => !connected.contains(r)) ? Gw.warning : Gw.fgMuted),
                            ),
                          ),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Gw.lineSubtle))),
                      child: Row(children: [
                        GwButton(label: 'Preview', icon: Icons.visibility_outlined, size: GwSize.sm, variant: GwVariant.ghost, onPressed: () => _preview(t, connected)),
                        const Spacer(),
                        GwButton(label: 'Use template', trailingIcon: Icons.arrow_forward, size: GwSize.sm, variant: GwVariant.primary, loading: _using == t.slug, onPressed: () => _use(t)),
                      ]),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ],
    );
  }
}

/* ================================ Settings ================================ */

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.tab = 'profile'});
  final String tab;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _tabs = [
    ('profile', 'Profile', Icons.person_outline),
    ('security', 'Security', Icons.key_outlined),
    ('sessions', 'Sessions', Icons.devices_outlined),
    ('notifications', 'Notifications', Icons.notifications_none),
    ('appearance', 'Appearance', Icons.palette_outlined),
    ('activity', 'Activity', Icons.receipt_long_outlined),
  ];
  late String _tab = _tabs.any((t) => t.$1 == widget.tab) ? widget.tab : 'profile';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth is! SignedIn) return const SizedBox.shrink();
    return PageBody(children: [
      Text('Settings', style: GwText.title),
      const SizedBox(height: 4),
      Text('Manage your profile, security and preferences.', style: GwText.body.copyWith(color: Gw.fgMuted)),
      const SizedBox(height: 20),
      GwTabs<String>(value: _tab, tabs: _tabs, onChanged: (v) => setState(() => _tab = v)),
      const SizedBox(height: 20),
      KeyedSubtree(
        key: ValueKey(_tab),
        child: switch (_tab) {
          'security' => Column(children: [const _SecurityTab(), const SizedBox(height: 20), const _DangerZone()]),
          'sessions' => const _SessionsTab(),
          'notifications' => _PrefsTab(user: auth.user, kind: 'notifications'),
          'appearance' => _PrefsTab(user: auth.user, kind: 'appearance'),
          'activity' => const _ActivityTab(),
          _ => _ProfileTab(user: auth.user),
        },
      ),
    ]);
  }
}

class _ProfileTab extends ConsumerStatefulWidget {
  const _ProfileTab({required this.user});
  final User user;

  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  late final _name = TextEditingController(text: widget.user.fullName);
  String? _error;
  String? _nameError;
  bool _busy = false;

  Future<void> _changeEmail() async {
    final email = TextEditingController();
    final password = TextEditingController();
    String? error;
    var busy = false;
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xB8050609),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Change email', style: GwText.section),
                const SizedBox(height: 4),
                Text("You'll sign in with the new address. We'll notify your current address about the change.", style: GwText.body.copyWith(color: Gw.fgMuted)),
                const SizedBox(height: 16),
                if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: GwAlert(child: Text(error!))),
                GwField(label: 'New email', child: GwInput(controller: email, keyboardType: TextInputType.emailAddress, semanticLabel: 'New email')),
                const SizedBox(height: 12),
                GwField(label: 'Current password', child: PasswordField(controller: password, autofill: AutofillHints.password)),
                const SizedBox(height: 20),
                Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
                  GwButton(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
                  GwButton(
                    label: 'Change email',
                    variant: GwVariant.primary,
                    loading: busy,
                    onPressed: () async {
                      final invalid = validateEmail(email.text);
                      if (invalid != null) return setLocal(() => error = invalid);
                      setLocal(() => (busy = true, error = null));
                      try {
                        final user = await ref.read(apiClientProvider).changeEmail(email.text.trim(), password.text);
                        ref.read(authProvider.notifier).updateUser(user);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) toast(context, 'Email updated', description: user.email);
                      } catch (e) {
                        setLocal(() => (busy = false, error = describeError(e)));
                      }
                    },
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = (ref.watch(authProvider) as SignedIn).user;
    return GwCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const GwCardHeader(title: 'Profile', description: 'How you appear in GhostWork.'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CircleAvatar(radius: 28, backgroundColor: Gw.violetSoft, child: Text(user.initials, style: GwText.section.copyWith(fontSize: 18, color: Gw.violet))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.fullName, style: GwText.bodyMedium), Text('Member since ${formatDate(user.createdAt)}', style: GwText.meta)])),
            ]),
            const SizedBox(height: 20),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: GwAlert(child: Text(_error!))),
            GwField(label: 'Full name', error: _nameError, child: GwInput(controller: _name, autofillHints: const [AutofillHints.name], semanticLabel: 'Full name', onChanged: (_) => setState(() {}))),
            const SizedBox(height: 16),
            GwField(
              label: 'Email',
              hint: GwLink('Change email', style: GwText.meta.copyWith(color: Gw.violet), onTap: _changeEmail),
              child: GwInput(key: ValueKey(user.email), initialValue: user.email, enabled: false),
            ),
            const Divider(height: 32),
            Align(
              alignment: Alignment.centerRight,
              child: GwButton(
                label: 'Save profile',
                variant: GwVariant.primary,
                loading: _busy,
                onPressed: _name.text.trim() == user.fullName
                    ? null
                    : () async {
                        if (_name.text.trim().isEmpty) return setState(() => _nameError = 'Enter your name.');
                        setState(() => (_busy = true, _error = null, _nameError = null));
                        try {
                          final next = await ref.read(apiClientProvider).updateProfile({'full_name': _name.text.trim()});
                          ref.read(authProvider.notifier).updateUser(next);
                          _name.text = next.fullName;
                          if (context.mounted) toast(context, 'Profile updated');
                        } catch (e) {
                          setState(() => _error = describeError(e));
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SecurityTab extends ConsumerStatefulWidget {
  const _SecurityTab();

  @override
  ConsumerState<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends ConsumerState<_SecurityTab> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final Map<String, String?> _errors = {};
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() {
      _errors['current'] = _current.text.isEmpty ? 'Enter your current password.' : null;
      _errors['next'] = passwordProblems(_next.text);
      _errors['confirm'] = _next.text == _confirm.text ? null : "Passwords don't match.";
      _error = null;
    });
    if (_errors.values.any((e) => e != null)) return;
    setState(() => _busy = true);
    try {
      final message = await ref.read(apiClientProvider).changePassword(_current.text, _next.text);
      _current.clear();
      _next.clear();
      _confirm.clear();
      ref.invalidate(sessionsProvider);
      if (mounted) toast(context, 'Password updated', description: message);
    } catch (e) {
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = (ref.watch(authProvider) as SignedIn).user;
    return GwCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GwCardHeader(
          title: 'Password',
          description: user.passwordChangedAt != null ? 'Last changed ${timeAgo(user.passwordChangedAt)}' : 'Use at least 10 characters, with a letter and a number.',
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: GwAlert(child: Text(_error!))),
            GwField(label: 'Current password', error: _errors['current'], child: PasswordField(controller: _current, error: _errors['current'], autofill: AutofillHints.password)),
            const SizedBox(height: 16),
            GwField(
              label: 'New password',
              error: _errors['next'],
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                PasswordField(controller: _next, error: _errors['next'], autofill: AutofillHints.newPassword, onChanged: (_) => setState(() {})),
                PasswordStrength(_next.text),
              ]),
            ),
            const SizedBox(height: 16),
            GwField(label: 'Confirm new password', error: _errors['confirm'], child: PasswordField(controller: _confirm, error: _errors['confirm'], autofill: AutofillHints.newPassword)),
            const SizedBox(height: 12),
            Text('Changing your password signs you out everywhere except this device.', style: GwText.meta),
            const Divider(height: 32),
            Align(alignment: Alignment.centerRight, child: GwButton(label: 'Update password', variant: GwVariant.primary, loading: _busy, onPressed: _submit)),
          ]),
        ),
      ]),
    );
  }
}

class _DangerZone extends ConsumerWidget {
  const _DangerZone();

  @override
  Widget build(BuildContext context, WidgetRef ref) => GwCard(
        borderColor: Gw.danger.withValues(alpha: 0.3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const GwCardHeader(title: 'Delete account', description: 'Permanently delete your account, workflows, run history and connected integrations.'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerRight,
              child: GwButton(
                label: 'Delete account',
                variant: GwVariant.danger,
                onPressed: () async {
                  final password = TextEditingController();
                  final confirm = TextEditingController();
                  String? error;
                  var busy = false;
                  await showDialog<void>(
                    context: context,
                    barrierColor: const Color(0xB8050609),
                    builder: (ctx) => StatefulBuilder(
                      builder: (ctx, setLocal) => Dialog(
                        insetPadding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Text('Delete your account?', style: GwText.section),
                              const SizedBox(height: 4),
                              Text("This can't be undone. Active schedules and webhooks stop immediately.", style: GwText.body.copyWith(color: Gw.fgMuted)),
                              const SizedBox(height: 16),
                              if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: GwAlert(child: Text(error!))),
                              GwField(label: 'Current password', child: PasswordField(controller: password, autofill: AutofillHints.password, onChanged: (_) => setLocal(() {}))),
                              const SizedBox(height: 12),
                              GwField(label: 'Type "DELETE" to confirm', child: GwInput(controller: confirm, semanticLabel: 'Type DELETE to confirm', onChanged: (_) => setLocal(() {}))),
                              const SizedBox(height: 20),
                              Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
                                GwButton(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
                                GwButton(
                                  label: 'Delete forever',
                                  variant: GwVariant.danger,
                                  loading: busy,
                                  onPressed: confirm.text != 'DELETE' || password.text.isEmpty
                                      ? null
                                      : () async {
                                          setLocal(() => (busy = true, error = null));
                                          try {
                                            await ref.read(apiClientProvider).deleteAccount(password.text);
                                            if (ctx.mounted) Navigator.pop(ctx);
                                            ref.read(authProvider.notifier).forget();
                                          } on ApiException catch (e) {
                                            setLocal(() => (busy = false, error = e.toString()));
                                          }
                                        },
                                ),
                              ]),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ]),
      );
}

class _SessionsTab extends ConsumerWidget {
  const _SessionsTab();

  static String describeAgent(String? ua) {
    if (ua == null) return 'Unknown device';
    final mobile = RegExp('Mobile|Android|iPhone|iPad').hasMatch(ua);
    final browser = ua.contains('Edg/')
        ? 'Edge'
        : ua.contains('Firefox/')
            ? 'Firefox'
            : ua.contains('Chrome/')
                ? 'Chrome'
                : ua.contains('Safari/')
                    ? 'Safari'
                    : RegExp('python|httpx|curl|dart', caseSensitive: false).hasMatch(ua)
                        ? 'GhostWork app'
                        : 'Browser';
    final os = ua.contains('Windows')
        ? 'Windows'
        : ua.contains('Mac OS X') && !mobile
            ? 'macOS'
            : ua.contains('Android')
                ? 'Android'
                : RegExp('iPhone|iPad').hasMatch(ua)
                    ? 'iOS'
                    : ua.contains('Linux')
                        ? 'Linux'
                        : '';
    return os.isEmpty ? browser : '$browser on $os';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final api = ref.read(apiClientProvider);
    return asyncBody(
      sessions,
      onRetry: () => ref.invalidate(sessionsProvider),
      (list) {
        final others = list.where((s) => !s.current).length;
        return GwCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GwCardHeader(
              title: 'Active sessions',
              description: 'Devices currently signed in to your account.',
              action: others == 0
                  ? null
                  : GwButton(
                      label: 'Sign out others',
                      size: GwSize.sm,
                      onPressed: () async {
                        String? message;
                        final ok = await confirmAction(
                          context,
                          title: 'Sign out other sessions?',
                          description: '$others other session${others == 1 ? '' : 's'} will be signed out immediately.',
                          confirmLabel: 'Sign out others',
                          action: () async {
                            try {
                              message = await api.revokeOtherSessions();
                              return null;
                            } catch (e) {
                              return describeError(e);
                            }
                          },
                        );
                        ref.invalidate(sessionsProvider);
                        if (ok && context.mounted) toast(context, message ?? 'Signed out');
                      },
                    ),
            ),
            for (final (i, s) in list.indexed) ...[
              if (i > 0) const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(RegExp('Mobile|Android|iPhone|dart', caseSensitive: false).hasMatch(s.userAgent ?? '') ? Icons.smartphone : Icons.laptop, size: 18, color: Gw.fgMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(describeAgent(s.userAgent), style: GwText.bodyMedium),
                        if (s.current)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Gw.successSoft, borderRadius: BorderRadius.circular(99)),
                            child: Text('This device', style: GwText.micro.copyWith(color: Gw.success)),
                          ),
                      ]),
                      Text('${s.ipAddress ?? 'Unknown IP'} · signed in ${formatDateTime(s.createdAt)} · active ${timeAgo(s.lastUsedAt)}', style: GwText.micro),
                    ]),
                  ),
                  if (!s.current)
                    GwButton(
                      label: 'Sign out',
                      size: GwSize.sm,
                      variant: GwVariant.ghost,
                      onPressed: () async {
                        try {
                          await api.revokeSession(s.id);
                          ref.invalidate(sessionsProvider);
                          if (context.mounted) toast(context, 'Session signed out');
                        } catch (e) {
                          if (context.mounted) toast(context, "Couldn't sign out session", description: describeError(e), tone: AlertTone.danger);
                        }
                      },
                    ),
                ]),
              ),
            ],
          ]),
        );
      },
    );
  }
}

class _PrefsTab extends ConsumerStatefulWidget {
  const _PrefsTab({required this.user, required this.kind});
  final User user;
  final String kind;

  @override
  ConsumerState<_PrefsTab> createState() => _PrefsTabState();
}

class _PrefsTabState extends ConsumerState<_PrefsTab> {
  bool _saving = false;

  Future<void> _save(Map<String, Object?> patch, [String message = 'Preferences saved']) async {
    setState(() => _saving = true);
    try {
      final user = await ref.read(apiClientProvider).updateProfile(patch);
      ref.read(authProvider.notifier).updateUser(user);
      if (mounted) toast(context, message);
    } catch (e) {
      if (mounted) toast(context, "Couldn't save", description: describeError(e), tone: AlertTone.danger);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = (ref.watch(authProvider) as SignedIn).user;
    if (widget.kind == 'notifications') {
      return GwCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const GwCardHeader(title: 'Notifications', description: 'Choose when GhostWork tells you about runs. Changes save immediately.'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              GwSwitch(label: 'Failed runs', description: 'Show an in-app notification when a run fails.', value: user.notifyOnFailure, onChanged: _saving ? null : (v) => _save({'notify_on_failure': v})),
              const SizedBox(height: 20),
              GwSwitch(
                label: 'Successful runs',
                description: 'Show an in-app notification when a run succeeds. Can be noisy for frequent schedules.',
                value: user.notifyOnSuccess,
                onChanged: _saving ? null : (v) => _save({'notify_on_success': v}),
              ),
              const SizedBox(height: 20),
              GwSwitch(
                label: 'Email me when a run fails',
                description: 'Sent to your account email if this server has outgoing email configured.',
                value: user.emailOnFailure,
                onChanged: _saving ? null : (v) => _save({'email_on_failure': v}),
              ),
            ]),
          ),
        ]),
      );
    }
    return GwCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const GwCardHeader(title: 'Appearance', description: 'GhostWork uses a dark interface designed for long sessions.'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Density', style: GwText.bodyMedium),
            Text('Compact fits more rows in tables and lists.', style: GwText.meta),
            const SizedBox(height: 8),
            GwSegmented<String>(
              value: user.density,
              options: const [('comfortable', 'Comfortable'), ('compact', 'Compact')],
              onChanged: (v) => _saving ? null : _save({'density': v}),
            ),
            const SizedBox(height: 24),
            Text('Motion', style: GwText.bodyMedium),
            Text('Reduce animations such as live-run indicators and panel transitions.', style: GwText.meta),
            const SizedBox(height: 8),
            GwSegmented<String>(
              value: user.reduceMotion,
              options: const [('system', 'System'), ('reduce', 'Reduced'), ('full', 'Full')],
              onChanged: (v) => _saving ? null : _save({'reduce_motion': v}),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ActivityTab extends ConsumerStatefulWidget {
  const _ActivityTab();

  @override
  ConsumerState<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<_ActivityTab> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(activityProvider(_page));
    return GwCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const GwCardHeader(title: 'Account activity', description: 'Changes made in your account, newest first.'),
        activity.when(
          skipLoadingOnReload: true,
          loading: () => const GwLoading(rows: 4),
          error: (e, _) => GwError(error: e, onRetry: () => ref.invalidate(activityProvider(_page))),
          data: (page) => page.items.isEmpty
              ? const GwEmpty(title: 'No activity yet')
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final (i, a) in page.items.indexed) ...[
                    if (i > 0) const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: Text(a.message, style: GwText.body.copyWith(color: Gw.fgSecondary))),
                        const SizedBox(width: 12),
                        Text(timeAgo(a.createdAt), style: GwText.micro),
                      ]),
                    ),
                  ],
                  GwPagination(page: _page, pageSize: 10, total: page.total, onPage: (p) => setState(() => _page = p)),
                ]),
        ),
      ]),
    );
  }
}

/* ================================ Help ================================ */

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthProvider);
    Widget link(IconData icon, Color color, String title, String body, VoidCallback onTap, {bool external = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(Gw.rLg),
            onTap: onTap,
            child: GwCard(
              padding: const EdgeInsets.all(20),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Text(title, style: GwText.section), if (external) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.open_in_new, size: 13, color: Gw.fgMuted))]),
                    const SizedBox(height: 4),
                    Text(body, style: GwText.meta),
                  ]),
                ),
              ]),
            ),
          ),
        );
    return PageBody(children: [
      const GwPageHeader(title: 'Help', description: 'Guides, references and the state of this GhostWork server.'),
      link(Icons.menu_book_outlined, Gw.violet, 'Documentation', 'Triggers, steps, references, webhooks and limits.', () => context.push('/docs')),
      link(Icons.code, Gw.cyan, 'API reference', 'Interactive OpenAPI documentation for the GhostWork API.', () => launchUrl(Uri.parse('$apiBaseUrl/docs')), external: true),
      GwCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const GwCardHeader(title: 'System status'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(children: [
              Expanded(child: Text('API', style: GwText.body.copyWith(color: Gw.fgSecondary))),
              health.when(
                loading: () => const StatusBadge('pending', label: 'Checking', small: true),
                error: (_, _) => const StatusBadge('failed', label: 'Unreachable', small: true),
                data: (ok) => ok ? const StatusBadge('succeeded', label: 'Operational', small: true) : const StatusBadge('failed', label: 'Unreachable', small: true),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Gw.lineSubtle))),
            child: Text('This checks the API from your device. Background workers report their health through run results.', style: GwText.meta),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      GwCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const GwCardHeader(title: 'Shortcuts and gestures'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(children: [
              for (final (label, key) in const [
                ('Search workflows', 'Ctrl K'),
                ('Save in the builder', 'Ctrl S'),
                ('Undo / redo in the builder', 'Ctrl Z / Ctrl Shift Z'),
                ('Remove selected step', 'Delete'),
                ('Move a step', 'Drag the step'),
                ('Connect steps', 'Drag from a bottom handle'),
                ('Zoom the canvas', 'Pinch, or + / −'),
                ('Remove a connection', 'Step settings → Connections'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(child: Text(label, style: GwText.body.copyWith(color: Gw.fgSecondary))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Gw.canvas, borderRadius: BorderRadius.circular(4), border: Border.all(color: Gw.line)),
                      child: Text(key, style: GwText.micro),
                    ),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

/// Opens the web Terms page in the browser (used from Settings links).
Future<void> openWeb(String path) => launchUrl(Uri.parse('$webAppUrl$path'), mode: LaunchMode.externalApplication);
