// Port of frontend/src/app/(marketing)/* — same copy, same structure.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../state/providers.dart';
import '../../components/logo.dart';
import '../../components/ui.dart';

const _links = [
  ('/features', 'Features'),
  ('/pricing', 'Pricing'),
  ('/docs', 'Docs'),
  ('/about', 'About'),
];

/// Public layout: header (logo + menu) and footer, like the web marketing layout.
class PublicScaffold extends ConsumerWidget {
  const PublicScaffold({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authProvider) is SignedIn;
    return Scaffold(
      endDrawer: Drawer(
        child: SafeArea(
          child: Builder(
            builder: (ctx) => Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text('Menu', style: GwText.section),
                        ),
                      ),
                      GwIconButton(
                        icon: Icons.close,
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final (href, label) in _links)
                    ListTile(
                      title: Text(
                        label,
                        style: GwText.body.copyWith(
                          fontSize: 15,
                          color: Gw.fgSecondary,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Gw.rMd),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.go(href);
                      },
                    ),
                  const Divider(height: 24),
                  if (signedIn)
                    GwButton(
                      label: 'Open dashboard',
                      variant: GwVariant.primary,
                      size: GwSize.lg,
                      expand: true,
                      onPressed: () => context.go('/dashboard'),
                    )
                  else ...[
                    GwButton(
                      label: 'Get started',
                      variant: GwVariant.primary,
                      size: GwSize.lg,
                      expand: true,
                      onPressed: () => context.go('/register'),
                    ),
                    const SizedBox(height: 8),
                    GwButton(
                      label: 'Sign in',
                      size: GwSize.lg,
                      expand: true,
                      onPressed: () => context.go('/login'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xD90B0D12),
                border: Border(bottom: BorderSide(color: Gw.lineSubtle)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.go('/'),
                    child: const Wordmark(size: 26),
                  ),
                  const Spacer(),
                  Builder(
                    builder: (ctx) => GwIconButton(
                      icon: Icons.menu,
                      tooltip: 'Open menu',
                      size: 40,
                      onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: ListView(children: [...children, const _Footer()])),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    Widget column(String title, List<(String, String)> links) => Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: GwText.eyebrow),
          const SizedBox(height: 12),
          for (final (href, label) in links)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => href.startsWith('http')
                    ? launchUrl(Uri.parse(href))
                    : context.go(href),
                child: Text(
                  label,
                  style: GwText.body.copyWith(color: Gw.fgSecondary),
                ),
              ),
            ),
        ],
      ),
    );
    return Container(
      decoration: const BoxDecoration(
        color: Gw.sidebar,
        border: Border(top: BorderSide(color: Gw.lineSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Wordmark(size: 24),
                const SizedBox(height: 12),
                Text(
                  'Let the repetitive work disappear.',
                  style: GwText.body.copyWith(color: Gw.fgMuted),
                ),
                const SizedBox(height: 32),
                column('Product', [
                  ('/features', 'Features'),
                  ('/pricing', 'Pricing'),
                  ('/register', 'Get started'),
                ]),
                column('Resources', [
                  ('/docs', 'Documentation'),
                  ('$apiBaseUrl/docs', 'API reference'),
                ]),
                column('Company', [
                  ('/about', 'About'),
                  ('/privacy', 'Privacy'),
                  ('/terms', 'Terms'),
                ]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Gw.lineSubtle)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('© ${DateTime.now().year} GhostWork', style: GwText.meta),
                const SizedBox(height: 8),
                Text(
                  'Built with FastAPI, PostgreSQL, Redis and Next.js.',
                  style: GwText.meta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    this.eyebrow,
    required this.title,
    this.description,
    this.child,
    this.background = false,
  });
  final String? eyebrow;
  final String title;
  final String? description;
  final Widget? child;
  final bool background;

  @override
  Widget build(BuildContext context) => Container(
    decoration: background
        ? const BoxDecoration(
            color: Color(0x9910131A),
            border: Border.symmetric(
              horizontal: BorderSide(color: Gw.lineSubtle),
            ),
          )
        : null,
    padding: const EdgeInsets.fromLTRB(16, 64, 16, 64),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null)
          Text(
            eyebrow!,
            style: GwText.meta.copyWith(
              color: Gw.violet,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 8),
        Text(title, style: GwText.headline),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              description!,
              style: GwText.body.copyWith(
                fontSize: 15,
                color: Gw.fgSecondary,
                height: 1.6,
              ),
            ),
          ),
        if (child != null)
          Padding(padding: const EdgeInsets.only(top: 40), child: child),
      ],
    ),
  );
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({
    required this.eyebrow,
    required this.title,
    required this.description,
  });
  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 56, 16, 48),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Gw.lineSubtle)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: GwText.meta.copyWith(
            color: Gw.violet,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: GwText.headline.copyWith(
            fontSize: 34,
            height: 1.1,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          description,
          style: GwText.body.copyWith(
            fontSize: 16,
            color: Gw.fgSecondary,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}

class _Prose extends StatelessWidget {
  const _Prose(this.blocks);
  final List<Widget> blocks;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 40, 16, 48),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    ),
  );
}

Widget _h2(String t) => Padding(
  padding: const EdgeInsets.only(top: 36, bottom: 12),
  child: Text(t, style: GwText.title.copyWith(fontSize: 20)),
);
Widget _h3(String t) => Padding(
  padding: const EdgeInsets.only(top: 20, bottom: 8),
  child: Text(t, style: GwText.section),
);
Widget _p(String t) => Padding(
  padding: const EdgeInsets.only(top: 10),
  child: Text(
    t,
    style: GwText.body.copyWith(
      fontSize: 15,
      color: Gw.fgSecondary,
      height: 1.65,
    ),
  ),
);
Widget _bullets(List<String> items) => Padding(
  padding: const EdgeInsets.only(top: 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final i in items)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 9, right: 10, left: 4),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Gw.fgSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  i,
                  style: GwText.body.copyWith(
                    fontSize: 15,
                    color: Gw.fgSecondary,
                    height: 1.65,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  ),
);
Widget _code(String t) => Container(
  width: double.infinity,
  margin: const EdgeInsets.only(top: 12),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Gw.surface,
    borderRadius: BorderRadius.circular(Gw.rLg),
    border: Border.all(color: Gw.line),
  ),
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Text(t, style: GwText.mono.copyWith(fontSize: 13, color: Gw.fg)),
  ),
);

Widget _iconCard(IconData icon, Color color, String title, String body) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GwCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 12),
            Text(title, style: GwText.section),
            const SizedBox(height: 4),
            Text(
              body,
              style: GwText.body.copyWith(color: Gw.fgMuted, height: 1.6),
            ),
          ],
        ),
      ),
    );

/* ================================ Landing ================================ */

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  static const _integrations = [
    (Icons.webhook, 'Webhooks', 'Trigger from any service', true),
    (Icons.public, 'HTTP APIs', 'Call any REST endpoint', true),
    (Icons.mail_outline, 'Email (SMTP)', 'Send through your server', true),
    (Icons.chat_bubble_outline, 'Slack', 'Incoming webhooks', true),
    (Icons.event_repeat, 'Schedules', 'Minutes to days', true),
    (Icons.table_chart_outlined, 'Google Sheets', 'Read and append rows', true),
    (Icons.call_split, 'GitHub', 'Create issues', true),
  ];

  static const _features = [
    (
      Icons.visibility_outlined,
      'See every step',
      'Each run records what happened at every step — inputs, outputs, timing and errors — so you never have to guess.',
    ),
    (
      Icons.call_split,
      'Branch on real data',
      'Route a run down a true or false path based on values from the trigger or any earlier step.',
    ),
    (
      Icons.shuffle,
      'Reshape data without code',
      'Build new objects from earlier results with simple references like {{ steps.fetch.body.id }}.',
    ),
    (
      Icons.refresh,
      'Retries that make sense',
      'HTTP steps retry server errors with backoff. Client errors fail fast with a clear message.',
    ),
    (
      Icons.timer_outlined,
      'Schedules and webhooks',
      'Run on an interval, from a unique webhook URL, or on demand. Pause any workflow in one click.',
    ),
    (
      Icons.history,
      'Searchable history',
      'Filter runs by workflow, status and date. Re-run a failed execution with the same input.',
    ),
  ];

  static const _security = [
    (
      Icons.lock_outline,
      'Argon2 password hashing',
      'Passwords are hashed with Argon2id and never stored or logged in plain text.',
    ),
    (
      Icons.refresh,
      'Rotating, revocable sessions',
      'Short-lived access tokens, HttpOnly refresh cookies, reuse detection and per-device sign-out.',
    ),
    (
      Icons.key_outlined,
      'Encrypted credentials',
      'Integration secrets are encrypted at rest and never returned to the browser or written to run logs.',
    ),
    (
      Icons.shield_outlined,
      'Guarded outbound requests',
      "HTTP steps can't reach private or internal network addresses, including through redirects.",
    ),
  ];

  static const _faq = [
    (
      'What can GhostWork automate today?',
      'Workflows start from a manual run, a schedule or a webhook, and can call HTTP APIs, transform data, branch on conditions, send email through your SMTP server, post to Slack, create GitHub issues and update Google Sheets.',
    ),
    (
      'Does GhostWork use AI to make decisions?',
      'No. Workflows do exactly what you configure. Conditions compare values you choose; nothing is decided by a model.',
    ),
    (
      'What happens when a step fails?',
      'The run stops at that step, later steps are marked as skipped, and you get a notification with the error. You can fix the workflow and re-run with the same input.',
    ),
    (
      'Where are my credentials stored?',
      "Secrets such as SMTP passwords, Slack webhook URLs and API tokens are encrypted in the database. They're only decrypted by the worker when a step needs them.",
    ),
    (
      'Is there a mobile app?',
      'Yes — GhostWork runs on Android and iOS with the same features as the web app, including the workflow builder.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) => PublicScaffold(
    children: [
      // Hero
      Container(
        padding: const EdgeInsets.fromLTRB(16, 64, 16, 40),
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.1),
            radius: 1.1,
            colors: [Color(0x298585FF), Colors.transparent],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Gw.surface,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Gw.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Gw.cyan,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Let the repetitive work disappear',
                      overflow: TextOverflow.ellipsis,
                      style: GwText.meta.copyWith(color: Gw.fgSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text.rich(
              const TextSpan(
                children: [
                  TextSpan(text: 'Your workflows.\n'),
                  TextSpan(
                    text: 'On autopilot.',
                    style: TextStyle(color: Gw.violet),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: GwText.display.copyWith(fontSize: 40, letterSpacing: -1.6),
            ),
            const SizedBox(height: 20),
            Text(
              'Connect your tools, automate repetitive work, and see every workflow clearly — from the first trigger to the final result.',
              textAlign: TextAlign.center,
              style: GwText.body.copyWith(
                fontSize: 16,
                color: Gw.fgSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            GwButton(
              label: 'Get started free',
              trailingIcon: Icons.arrow_forward,
              variant: GwVariant.primary,
              size: GwSize.lg,
              expand: true,
              onPressed: () => context.go('/register'),
            ),
            const SizedBox(height: 12),
            GwButton(
              label: 'See how it works',
              size: GwSize.lg,
              expand: true,
              onPressed: () => context.go('/features'),
            ),
            const SizedBox(height: 56),
            const _HeroPreview(),
          ],
        ),
      ),
      // Integrations
      Container(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
        decoration: const BoxDecoration(
          color: Color(0x9910131A),
          border: Border.symmetric(
            horizontal: BorderSide(color: Gw.lineSubtle),
          ),
        ),
        child: Column(
          children: [
            Text('Works with the tools you already use', style: GwText.meta),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.9,
              children: [
                for (final (icon, name, note, available) in _integrations)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Gw.surface,
                      borderRadius: BorderRadius.circular(Gw.rLg),
                      border: Border.all(color: Gw.lineSubtle),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 17,
                          color: available ? Gw.fgSecondary : Gw.fgDisabled,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: GwText.meta.copyWith(
                                  color: available ? Gw.fg : Gw.fgMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                note,
                                overflow: TextOverflow.ellipsis,
                                style: GwText.micro,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      _Section(
        eyebrow: 'The Living Workflow',
        title: 'Automation you can actually see',
        description: 'Every GhostWork workflow is a map of what starts it, what it does and where data flows. When it runs, the same map shows you exactly where it is and what happened.',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Gw.rXl),
            border: Border.all(color: Gw.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, (icon, title, body)) in _features.indexed)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Gw.surface,
                    border: i == 0
                        ? null
                        : const Border(top: BorderSide(color: Gw.line)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Gw.elevated,
                          borderRadius: BorderRadius.circular(Gw.rMd),
                          border: Border.all(color: Gw.line),
                        ),
                        child: Icon(icon, size: 17, color: Gw.violet),
                      ),
                      const SizedBox(height: 16),
                      Text(title, style: GwText.section),
                      const SizedBox(height: 6),
                      Text(
                        body,
                        style: GwText.body.copyWith(
                          color: Gw.fgMuted,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      _Section(
        background: true,
        eyebrow: 'How it works',
        title: 'From busywork to background work in three steps',
        child: Column(
          children: [
            for (final (i, (title, body)) in const [
              (
                'Choose a trigger',
                'Start on a schedule, from a webhook URL, or whenever you press Run.',
              ),
              (
                'Connect the steps',
                'Drag in HTTP calls, transforms, conditions, email and Slack. Wire them together on the canvas.',
              ),
              (
                'Activate and watch',
                'GhostWork runs it in the background. Every execution is recorded step by step.',
              ),
            ].indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Gw.violetSoft,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Gw.violet.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: GwText.mono.copyWith(
                          color: Gw.violet,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: GwText.section),
                          const SizedBox(height: 6),
                          Text(
                            body,
                            style: GwText.body.copyWith(
                              color: Gw.fgMuted,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      _Section(
        eyebrow: 'Security and reliability',
        title: 'Built to be trusted with your work',
        description: 'GhostWork runs your automations in a background queue with time limits, retries and a full record of every step.',
        child: Column(
          children: [
            for (final (icon, title, body) in _security)
              _iconCard(icon, Gw.cyan, title, body),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 64, 16, 64),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Gw.lineSubtle)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FAQ',
              style: GwText.meta.copyWith(
                color: Gw.violet,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text('Questions, answered', style: GwText.headline),
            const SizedBox(height: 32),
            Container(
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: Gw.lineSubtle),
                ),
              ),
              child: Column(
                children: [
                  for (final (i, (q, a)) in _faq.indexed)
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: Container(
                        decoration: BoxDecoration(
                          border: i == 0
                              ? null
                              : const Border(
                                  top: BorderSide(color: Gw.lineSubtle),
                                ),
                        ),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(
                            bottom: 16,
                            right: 32,
                          ),
                          iconColor: Gw.fgMuted,
                          collapsedIconColor: Gw.fgMuted,
                          title: Text(
                            q,
                            style: GwText.bodyMedium.copyWith(fontSize: 15),
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                a,
                                style: GwText.body.copyWith(
                                  color: Gw.fgMuted,
                                  height: 1.6,
                                ),
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
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 56),
          decoration: BoxDecoration(
            color: Gw.surface,
            borderRadius: BorderRadius.circular(Gw.rXl),
            border: Border.all(color: Gw.line),
            gradient: const RadialGradient(
              center: Alignment.topCenter,
              radius: 1.2,
              colors: [Color(0x1A55C5F2), Gw.surface],
            ),
          ),
          child: Column(
            children: [
              Text(
                'Automate the busywork. Focus on what moves you forward.',
                textAlign: TextAlign.center,
                style: GwText.headline,
              ),
              const SizedBox(height: 32),
              GwButton(
                label: 'Create your account',
                variant: GwVariant.primary,
                size: GwSize.lg,
                expand: true,
                onPressed: () => context.go('/register'),
              ),
              const SizedBox(height: 12),
              GwButton(
                label: 'Read the docs',
                size: GwSize.lg,
                expand: true,
                onPressed: () => context.go('/docs'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Mobile hero illustration (web HeroPreview → MobilePreview): labelled example, nothing "running".
class _HeroPreview extends StatelessWidget {
  const _HeroPreview();

  static const _nodes = [
    ('trigger', Icons.webhook, 'New signup', 'POST /hooks/••••', '2 ms'),
    (
      'action',
      Icons.shuffle,
      'Normalize lead',
      'Builds email, plan, source',
      '3 ms',
    ),
    ('condition', Icons.call_split, 'Is it a Pro plan?', 'plan = pro', '1 ms'),
    (
      'action',
      Icons.public,
      'Create CRM lead',
      'POST crm.example.com/leads',
      '184 ms',
    ),
  ];

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Illustration of an example lead-routing workflow with a webhook trigger, a transform step, a condition and an HTTP request.',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Gw.sidebar,
          borderRadius: BorderRadius.circular(Gw.rXl),
          border: Border.all(color: Gw.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x598585FF),
              blurRadius: 120,
              offset: Offset(0, 40),
              spreadRadius: -40,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Lead routing',
                    overflow: TextOverflow.ellipsis,
                    style: GwText.meta.copyWith(
                      color: Gw.fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Gw.elevated,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Example',
                    style: GwText.micro.copyWith(color: Gw.fgSecondary),
                  ),
                ),
                const Spacer(),
                const StatusBadge('succeeded', small: true),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Gw.canvas,
                borderRadius: BorderRadius.circular(Gw.rMd),
              ),
              child: Column(
                children: [
                  for (final (i, (kind, icon, name, detail, ms))
                      in _nodes.indexed) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Gw.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Gw.success.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _kindSoft(kind),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              icon,
                              size: 14,
                              color: _kindColor(kind),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontFamily: Gw.fontSans,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Gw.fg,
                                  ),
                                ),
                                Text(
                                  detail,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: Gw.fontMono,
                                    fontSize: 10.5,
                                    color: Gw.fgMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(ms, style: GwText.micro),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.check_circle_outline,
                            size: 13,
                            color: Gw.success,
                          ),
                        ],
                      ),
                    ),
                    if (i < _nodes.length - 1)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(left: 24),
                          width: 1,
                          height: 16,
                          color: Gw.cyan.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  static Color _kindColor(String k) =>
      k == 'trigger' ? Gw.violet : (k == 'condition' ? Gw.warning : Gw.cyan);
  static Color _kindSoft(String k) => k == 'trigger'
      ? Gw.violetSoft
      : (k == 'condition' ? Gw.warningSoft : Gw.cyanSoft);
}

/* ================================ Info pages ================================ */

class FeaturesScreen extends StatelessWidget {
  const FeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) => PublicScaffold(
    children: [
      const _PageIntro(
        eyebrow: 'Features',
        title: 'Everything GhostWork can do today',
        description: 'This page lists what is implemented and working now. Planned capabilities are listed separately at the bottom.',
      ),
      _Section(
        eyebrow: 'Triggers',
        title: 'Start a workflow three ways',
        child: Column(
          children: [
            _iconCard(
              Icons.back_hand_outlined,
              Gw.violet,
              'Manual',
              'Start a run from the builder or workflow page, optionally with test data.',
            ),
            _iconCard(
              Icons.event_repeat,
              Gw.violet,
              'Schedule',
              'Repeat every N minutes, hours or days (minimum five minutes) while the workflow is active.',
            ),
            _iconCard(
              Icons.webhook,
              Gw.violet,
              'Webhook',
              'Each workflow gets a secret URL. POST JSON or form data to start a run; the body is available to every step.',
            ),
          ],
        ),
      ),
      _Section(
        eyebrow: 'Steps',
        title: 'Actions and logic',
        child: Column(
          children: [
            _iconCard(
              Icons.public,
              Gw.cyan,
              'HTTP request',
              'GET, POST, PUT, PATCH or DELETE with templated URL, headers and body. Timeouts up to 30s, up to 3 retries for server errors.',
            ),
            _iconCard(
              Icons.shuffle,
              Gw.cyan,
              'Transform data',
              'Build a new object from earlier values. A field that is exactly one reference keeps its original type.',
            ),
            _iconCard(
              Icons.call_split,
              Gw.cyan,
              'Condition',
              'Compare values with equals, contains, greater than, is empty and more. Continue down the true or false branch.',
            ),
            _iconCard(
              Icons.mail_outline,
              Gw.cyan,
              'Send email',
              'Deliver email through an SMTP server you connect. Recipients, subject and body support references.',
            ),
            _iconCard(
              Icons.chat_bubble_outline,
              Gw.cyan,
              'Slack message',
              'Post to a channel through a Slack incoming webhook.',
            ),
            _iconCard(
              Icons.adjust,
              Gw.cyan,
              'GitHub issue',
              'Create an issue in a repository with a personal access token.',
            ),
            _iconCard(
              Icons.table_chart_outlined,
              Gw.cyan,
              'Google Sheets',
              'Append or read rows through a Google service account.',
            ),
          ],
        ),
      ),
      _Section(
        eyebrow: 'Operations',
        title: 'Built for watching, not guessing',
        child: Column(
          children: [
            for (final item in const [
              'Visual builder with validation that points at the exact step to fix',
              'Live step-by-step progress while a run is executing',
              'Execution history with search, status, workflow and date filters',
              'Re-run any execution with the same trigger data',
              'Cancel queued or running executions',
              'Dashboard metrics computed from your real runs',
              'In-app and push notifications for failures (and optionally in-app for successes)',
              'Workflow templates for common jobs',
            ])
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Gw.surface,
                  borderRadius: BorderRadius.circular(Gw.rLg),
                  border: Border.all(color: Gw.lineSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8, right: 10),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Gw.cyan,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: GwText.body.copyWith(color: Gw.fgSecondary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      _Section(
        eyebrow: 'Planned',
        title: 'On the roadmap',
        description: 'These are not available yet.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in const [
                  'Team workspaces and shared workflows',
                  'GitHub and Google sign-in with OAuth',
                ])
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Gw.lineStrong),
                    ),
                    child: Text(item, style: GwText.meta),
                  ),
              ],
            ),
            const SizedBox(height: 40),
            GwButton(
              label: 'Start building',
              variant: GwVariant.primary,
              size: GwSize.lg,
              onPressed: () => context.go('/register'),
            ),
          ],
        ),
      ),
    ],
  );
}

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) => PublicScaffold(
    children: [
      const _PageIntro(
        eyebrow: 'Pricing',
        title: 'Free while GhostWork is in early access',
        description: 'There is no billing in GhostWork today. Every account gets the full feature set, with limits that keep the shared queue healthy.',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 48),
        child: Column(
          children: [
            GwCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Early access',
                    style: GwText.meta.copyWith(
                      color: Gw.violet,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: r'$0 ',
                          style: GwText.headline.copyWith(fontSize: 40),
                        ),
                        TextSpan(
                          text: '/ month',
                          style: GwText.body.copyWith(
                            fontSize: 16,
                            color: Gw.fgMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Everything that is available today.',
                    style: GwText.body.copyWith(color: Gw.fgMuted),
                  ),
                  const SizedBox(height: 24),
                  for (final item in const [
                    'Unlimited workflows',
                    'Up to 50 steps per workflow',
                    'Up to 5 runs in progress at once',
                    'Schedules, webhooks and manual runs',
                    'HTTP, transform, condition, email, Slack, GitHub and Google Sheets steps',
                    'Full execution history',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check, size: 16, color: Gw.success),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: GwText.body.copyWith(
                                color: Gw.fgSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  GwButton(
                    label: 'Create your account',
                    variant: GwVariant.primary,
                    size: GwSize.lg,
                    expand: true,
                    onPressed: () => context.go('/register'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GwCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teams',
                    style: GwText.meta.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Planned',
                    style: GwText.headline.copyWith(
                      fontSize: 40,
                      color: Gw.fgMuted,
                    ),
                  ),
                  Text(
                    'Not available yet. Pricing will be published before launch.',
                    style: GwText.body.copyWith(color: Gw.fgMuted),
                  ),
                  const SizedBox(height: 24),
                  _bullets(const [
                    'Shared workspaces',
                    'Roles and permissions',
                    'Higher concurrency limits',
                    'Audit log export',
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => PublicScaffold(
    children: [
      const _PageIntro(
        eyebrow: 'About',
        title: 'Automation should be visible',
        description: 'GhostWork exists to make repetitive work disappear — without making it mysterious.',
      ),
      _Prose([
        _p(
          'Most automation tools are good at starting things and bad at explaining them. When something breaks you are left reading raw logs or guessing which step went wrong.',
        ),
        _p(
          'GhostWork is built around the Living Workflow: the same diagram you use to design an automation shows you what it is doing while it runs and what it did afterwards. Every step records its input, output, timing and errors.',
        ),
        _h2('Principles'),
        _bullets(const [
          'Show real state. Nothing animates unless something is actually running.',
          'Be honest about capabilities. Planned features are labelled as planned.',
          'Keep secrets secret. Credentials are encrypted and never sent back to the browser.',
          'Fail clearly. Errors say what failed and what to do next.',
        ]),
        _h2('Technology'),
        _p(
          'GhostWork is a Next.js web app and a Flutter mobile app backed by a FastAPI service, PostgreSQL for storage, and Redis with Celery for background execution. Both apps use the same API.',
        ),
      ]),
    ],
  );
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => PublicScaffold(
    children: [
      const _PageIntro(
        eyebrow: 'Legal',
        title: 'Privacy',
        description: 'What GhostWork stores, why, and how it is protected.',
      ),
      _Prose([
        Text(
          'This document describes how the GhostWork software handles data. Operators who host GhostWork for others should review it with their own legal counsel before relying on it.',
          style: GwText.meta,
        ),
        _h2('Data we store'),
        _bullets(const [
          'Account details: your name, email address and an Argon2 hash of your password.',
          'Sign-in sessions: browser user agent, IP address and timestamps, so you can review and revoke devices.',
          'Workflows you create, and the record of each execution, including step outputs (truncated to 64 KB).',
          'Integration credentials, encrypted at rest. They are decrypted only by the worker when a step needs them.',
          'Notifications and an activity log of actions taken in your account.',
          "If you turn on push, a device address from your browser or phone maker's push service. Notification titles and text pass through that service, which is why it's off until you turn it on.",
        ]),
        _h2("What we don't do"),
        _bullets(const [
          "We don't sell or share your data with advertisers.",
          "We don't use third-party analytics or tracking scripts.",
          "We don't return stored secrets to the browser or write them to execution logs.",
        ]),
        _h2('Cookies and device storage'),
        _p(
          'On the web, GhostWork uses one essential cookie: an HttpOnly refresh-session cookie that keeps you signed in. In the mobile app, the refresh token is kept in the device keychain or keystore.',
        ),
        _h2('Retention and deletion'),
        _bullets(const [
          'Finished executions are deleted automatically after 90 days.',
          'Deleting a workflow deletes its execution history.',
          'Disconnecting an integration deletes its stored credentials.',
          'Deleting your account (Settings → Security) permanently deletes your profile, sessions, workflows, run history, integrations and notifications.',
        ]),
        _h2('Terms'),
        _p(
          'Using GhostWork is also subject to the Terms of Service, which you accept when you create an account. We record which version you accepted and when.',
        ),
      ]),
    ],
  );
}

class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PublicScaffold(
    children: [
      const _PageIntro(
        eyebrow: 'Legal',
        title: 'Terms of Service',
        description: 'The agreement that applies when you use GhostWork, written to be read.',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 48),
        child: const TermsContent(),
      ),
    ],
  );
}

/// The full Terms (web TermsContent), from the shared terms.json.
class TermsContent extends ConsumerWidget {
  const TermsContent({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terms = ref.watch(termsProvider);
    return terms.when(
      loading: () => const GwLoading(rows: 6),
      error: (e, _) => GwError(error: e),
      data: (t) {
        final bodySize = compact ? 13.0 : 15.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${t.version} · Effective ${t.effective}',
              style: compact ? GwText.micro : GwText.meta,
            ),
            Container(
              margin: EdgeInsets.only(top: compact ? 12 : 20),
              padding: EdgeInsets.all(compact ? 12 : 20),
              decoration: BoxDecoration(
                color: Gw.violetSoft,
                borderRadius: BorderRadius.circular(Gw.rLg),
                border: Border.all(color: Gw.violet.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The short version',
                    style: GwText.bodyMedium.copyWith(
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final s in t.summary)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 7, right: 8),
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Gw.violet,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              s,
                              style: GwText.body.copyWith(
                                fontSize: compact ? 13 : 14,
                                color: Gw.fgSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    'This summary is for convenience; the full terms below apply.',
                    style: compact ? GwText.micro : GwText.meta,
                  ),
                ],
              ),
            ),
            for (final s in t.sections) ...[
              Padding(
                padding: EdgeInsets.only(top: compact ? 16 : 36),
                child: Semantics(
                  header: true,
                  child: Text(
                    s.title,
                    style: compact
                        ? GwText.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          )
                        : GwText.title.copyWith(fontSize: 18),
                  ),
                ),
              ),
              for (final p in s.paragraphs)
                Padding(
                  padding: EdgeInsets.only(top: compact ? 6 : 12),
                  child: Text(
                    p,
                    style: GwText.body.copyWith(
                      fontSize: bodySize,
                      color: Gw.fgSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
              for (final b in s.bullets)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, right: 10),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Gw.fgSecondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          b,
                          style: GwText.body.copyWith(
                            fontSize: bodySize,
                            color: Gw.fgSecondary,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class DocsScreen extends StatelessWidget {
  const DocsScreen({super.key});

  @override
  Widget build(BuildContext context) => PublicScaffold(
    children: [
      const _PageIntro(
        eyebrow: 'Documentation',
        title: 'Build your first workflow',
        description:
            'Everything you need to design, run and debug GhostWork workflows.',
      ),
      _Prose([
        _h2('Quickstart'),
        _bullets(const [
          'Create an account and open Workflows → New workflow.',
          'Pick a trigger (manual, schedule or webhook), or start from a template.',
          "In the builder, add steps from the steps library and connect them by dragging from a step's bottom handle to the next step.",
          'Select a step to configure it. The toolbar shows whether the workflow is valid.',
          'Press Test run to execute it now and watch each step complete, then Activate to turn on its schedule or webhook.',
        ]),
        _h2('Triggers'),
        _p(
          "Every workflow has exactly one trigger, and it can't have incoming connections.",
        ),
        _bullets(const [
          'Manual — runs when you press Run. You can pass test data, available as trigger.payload.',
          'Schedule — runs every N minutes, hours or days while active. The shortest interval is 5 minutes.',
          'Webhook — runs when its secret URL receives a POST while the workflow is active.',
        ]),
        _p(
          'Manual test runs are always allowed, even for draft or paused workflows, as long as the workflow is valid.',
        ),
        _h2('Steps'),
        _h3('HTTP request'),
        _p(
          'Calls an external API. The response is available as steps.<id>.status_code, steps.<id>.headers and steps.<id>.body (parsed when the response is JSON). Responses with status 400 or above fail the step unless you turn off Fail on error status. Server errors (5xx) and 429 are retried with backoff up to the retry count you set.',
        ),
        _h3('Transform data'),
        _p(
          "Builds an object from named fields. If a field's value is exactly one reference, such as {{ steps.fetch.body.items }}, it keeps its original type (list, number, object). Otherwise the result is text.",
        ),
        _h3('Send email'),
        _p(
          'Sends a plain-text email through an SMTP integration. Requires a connected Email (SMTP) integration.',
        ),
        _h3('Slack message'),
        _p(
          'Posts text to Slack through an incoming webhook. Requires a connected Slack integration.',
        ),
        _h3('GitHub issue'),
        _p(
          'Creates an issue using a connected GitHub personal access token. The result is available as steps.<id>.number and steps.<id>.url. To start a workflow from GitHub, add its webhook URL to a repository; a webhook signing secret from GhostWork works as GitHub\'s "Secret".',
        ),
        _h3('Google Sheets'),
        _p(
          "Append a row or read rows through a Google service account. Share the spreadsheet with the service account's email first. Rows read are available as steps.<id>.rows.",
        ),
        _h2('References'),
        _p(
          'Text fields can include references in double braces. Only plain lookups are supported — no code or expressions.',
        ),
        _code(
          '{{ trigger.payload.body.email }}     webhook JSON body\n{{ trigger.payload.user }}           manual test data\n{{ steps.fetch.body.items.0.id }}    list items by index\n{{ steps.shape.total }}              transform output\n{{ execution.id }}  {{ execution.started_at }}\n{{ workflow.name }}',
        ),
        _p(
          "A step can only reference steps that run before it. Validation points out references that can't resolve.",
        ),
        _h2('Push notifications'),
        _p(
          'Turn on push in Settings → Notifications to get a system notification when a run fails. Each browser or phone is turned on separately.',
        ),
        _h2('Conditions'),
        _p(
          "A condition compares a value with equals, not_equals, contains, not_contains, greater_than, less_than, is_empty or is_not_empty. Connect its True and/or False outputs. Steps on the branch that wasn't taken are marked as skipped.",
        ),
        _h2('Webhooks'),
        _p(
          'After you save a workflow with a webhook trigger, its URL appears in the trigger settings and on the workflow page.',
        ),
        _code(
          'curl -X POST "\$WEBHOOK_URL" \\\n  -H "Content-Type: application/json" \\\n  -d \'{"event": "signup", "priority": "high"}\'',
        ),
        _p(
          'The request body, query string and a safe subset of headers are passed to the run. Authorization and cookie headers are never stored. Payloads are limited to 256 KB. Regenerate the URL at any time if it leaks, and optionally require an HMAC-SHA256 signature in the X-GhostWork-Signature header.',
        ),
        _h2('Credentials'),
        _p(
          'Never paste API keys into plain headers — validation rejects headers such as Authorization. Instead, create an HTTP credential on the Integrations page and select it in the HTTP step. Credentials are encrypted at rest and never shown again after you save them.',
        ),
        _h2('Runs and history'),
        _p(
          'Runs move through queued → running → succeeded or failed (or cancelled). Each step records its status, attempts, duration, output and error. When a step fails, the run stops and later steps are skipped. From the execution page you can cancel an active run or run the workflow again with the same trigger data.',
        ),
        _h2('Limits'),
        _bullets(const [
          '50 steps per workflow.',
          '5 runs in progress per account at once.',
          'HTTP steps: 30 second timeout, 1 MB response, 3 redirects, no private or internal network addresses.',
          'Runs are stopped after 120 seconds.',
          'Stored step outputs are truncated at 64 KB.',
        ]),
        _h2('API'),
        _p(
          'GhostWork is API-first. The interactive OpenAPI reference is served by the backend.',
        ),
        const SizedBox(height: 12),
        GwLink(
          '$apiBaseUrl/docs',
          icon: Icons.open_in_new,
          onTap: () => launchUrl(Uri.parse('$apiBaseUrl/docs')),
        ),
      ]),
    ],
  );
}

/// 404 (web not-found.tsx).
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Opacity(opacity: 0.8, child: GhostMark(size: 44)),
            const SizedBox(height: 24),
            Text('404', style: GwText.mono.copyWith(color: Gw.fgMuted)),
            const SizedBox(height: 4),
            Text('This page vanished', style: GwText.title),
            const SizedBox(height: 8),
            Text(
              "The page you're looking for doesn't exist or has moved.",
              textAlign: TextAlign.center,
              style: GwText.body.copyWith(color: Gw.fgMuted),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              children: [
                GwButton(label: 'Home', onPressed: () => context.go('/')),
                GwButton(
                  label: 'Dashboard',
                  variant: GwVariant.primary,
                  onPressed: () => context.go('/dashboard'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
