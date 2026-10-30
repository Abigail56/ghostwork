// Port of frontend/src/app/(app)/dashboard/DashboardView.tsx + TrendChart.tsx.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/theme.dart';
import '../../../data/models.dart';
import '../../../state/providers.dart';
import '../../components/ui.dart';
import '../../format.dart';
import '../../shell/app_shell.dart';

Widget asyncBody<T>(AsyncValue<T> value, Widget Function(T) builder, {required VoidCallback onRetry, String errorTitle = "Couldn't load this", int rows = 4}) =>
    value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: builder,
      loading: () => GwLoading(rows: rows),
      error: (e, _) => GwCard(child: GwError(title: errorTitle, error: e, onRetry: onRetry)),
    );

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _poll;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    // Same cadence as the web: every 3s while runs are in progress, otherwise every 30s.
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      _ticks++;
      final busy = (ref.read(dashboardProvider).value?.inProgress ?? 0) > 0;
      if (busy || _ticks % 10 == 0) ref.invalidate(dashboardProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final dashboard = ref.watch(dashboardProvider);
    final workflows = ref.watch(workflowsProvider((q: '', status: '', sort: '-updated', page: 1, pageSize: 4)));
    final integrations = ref.watch(integrationsProvider);
    final firstName = auth is SignedIn ? auth.user.firstName : '';

    return PageBody(
      onRefresh: () {
        ref.invalidate(workflowsProvider);
        return ref.refresh(dashboardProvider.future);
      },
      children: [
        Text('${greeting()}, $firstName', style: GwText.title),
        const SizedBox(height: 4),
        Text("Here's what your automations have been doing.", style: GwText.body.copyWith(color: Gw.fgMuted)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          GwButton(label: 'Templates', icon: Icons.view_quilt_outlined, onPressed: () => context.go('/templates')),
          GwButton(label: 'New workflow', icon: Icons.add, variant: GwVariant.primary, onPressed: () => context.go('/workflows/new')),
        ]),
        const SizedBox(height: 20),
        asyncBody(
          dashboard,
          errorTitle: "Couldn't load your dashboard",
          onRetry: () => ref.invalidate(dashboardProvider),
          (d) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Onboarding(hasWorkflow: d.totalWorkflows > 0, hasIntegration: (integrations.value?.length ?? 0) > 0, hasRun: d.totalExecutions > 0),
            _metrics(d),
            const SizedBox(height: 20),
            GwCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const GwCardHeader(title: 'Execution trend', description: 'Runs per day, last 14 days'),
                Padding(padding: const EdgeInsets.all(16), child: TrendChart(trend: d.trend)),
              ]),
            ),
            const SizedBox(height: 20),
            _Health(d),
            const SizedBox(height: 20),
            GwCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                GwCardHeader(title: 'Recent executions', action: GwLink('View all', onTap: () => context.go('/executions'))),
                if (d.recent.isEmpty)
                  const GwEmpty(icon: Icons.history, title: 'No runs yet', description: 'Run a workflow and its progress will show up here.')
                else
                  for (final (i, e) in d.recent.indexed) ...[
                    if (i > 0) const Divider(),
                    InkWell(
                      onTap: () => context.go('/executions/${e.id}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(children: [
                          SizedBox(width: 96, child: Align(alignment: Alignment.centerLeft, child: StatusBadge(e.status, small: true))),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(e.workflowName, overflow: TextOverflow.ellipsis, style: GwText.bodyMedium),
                              Text('${triggerLabel(e.triggerType)} · ${timeAgo(e.createdAt)}', style: GwText.micro),
                            ]),
                          ),
                          Text(formatDuration(e.durationMs), style: GwText.meta),
                        ]),
                      ),
                    ),
                  ],
              ]),
            ),
            const SizedBox(height: 20),
            GwCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const GwCardHeader(title: 'Recent activity'),
                if (d.activity.isEmpty)
                  const GwEmpty(title: 'Nothing yet', description: 'Changes you make will be listed here.')
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(children: [
                      for (final (i, a) in d.activity.indexed)
                        IntrinsicHeight(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            SizedBox(
                              width: 9,
                              child: Column(children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: Gw.canvas, border: Border.all(color: Gw.violet, width: 2)),
                                ),
                                if (i < d.activity.length - 1) Expanded(child: Container(width: 1, color: Gw.line)),
                              ]),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(a.message, style: GwText.body.copyWith(color: Gw.fgSecondary)),
                                  Text(timeAgo(a.createdAt), style: GwText.micro),
                                ]),
                              ),
                            ),
                          ]),
                        ),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Text('Your workflows', style: GwText.section)),
          GwLink('Manage workflows', onTap: () => context.go('/workflows')),
        ]),
        const SizedBox(height: 12),
        asyncBody(
          workflows,
          onRetry: () => ref.invalidate(workflowsProvider),
          rows: 2,
          (page) => page.items.isEmpty
              ? GwCard(
                  child: GwEmpty(
                    icon: Icons.account_tree_outlined,
                    title: 'Create your first workflow',
                    description: 'Automate a repetitive task: call an API on a schedule, react to a webhook, or send an alert when something fails.',
                    actions: [
                      GwButton(label: 'New workflow', icon: Icons.add, variant: GwVariant.primary, onPressed: () => context.go('/workflows/new')),
                      GwButton(label: 'Explore templates', onPressed: () => context.go('/templates')),
                    ],
                  ),
                )
              : Column(children: [
                  for (final w in page.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Gw.rLg),
                        onTap: () => context.go('/workflows/${w.id}'),
                        child: GwCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(w.name, overflow: TextOverflow.ellipsis, style: GwText.bodyMedium.copyWith(fontWeight: FontWeight.w600))),
                              StatusBadge(w.status, small: true),
                            ]),
                            const SizedBox(height: 4),
                            Text(w.description.isEmpty ? 'No description' : w.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: GwText.meta),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: Text('${triggerLabel(w.triggerType)} · ${w.stepCount} steps', overflow: TextOverflow.ellipsis, style: GwText.micro)),
                              const SizedBox(width: 8),
                              Flexible(child: Text('Ran ${timeAgo(w.lastRunAt)}', overflow: TextOverflow.ellipsis, style: GwText.micro)),
                            ]),
                          ]),
                        ),
                      ),
                    ),
                ]),
        ),
        const SizedBox(height: 8),
        Text('Quick actions', style: GwText.section),
        const SizedBox(height: 12),
        for (final (href, icon, title, body) in const [
          ('/workflows/new', Icons.add, 'New workflow', 'Start from a trigger'),
          ('/templates', Icons.view_quilt_outlined, 'Use a template', 'Monitoring, data pulls, alerts'),
          ('/integrations', Icons.power_outlined, 'Connect a service', 'SMTP, Slack, API credentials'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(Gw.rLg),
              onTap: () => context.go(href),
              child: GwCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: Gw.violetSoft, borderRadius: BorderRadius.circular(Gw.rMd)), child: Icon(icon, size: 16, color: Gw.violet)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GwText.bodyMedium), Text(body, style: GwText.meta)])),
                  const Icon(Icons.arrow_forward, size: 15, color: Gw.fgMuted),
                ]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _metrics(DashboardSummary d) {
    Widget tile(String label, String value, String detail, IconData icon) => Expanded(
          child: GwCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(label, style: GwText.meta)), Icon(icon, size: 16, color: Gw.fgMuted)]),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontFamily: Gw.fontSans, fontSize: 28, height: 1, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: Gw.fg)),
              const SizedBox(height: 8),
              Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: GwText.meta),
            ]),
          ),
        );
    return Column(children: [
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          tile('Total workflows', '${d.totalWorkflows}', '${d.totalWorkflows - d.activeWorkflows} draft or paused', Icons.account_tree_outlined),
          const SizedBox(width: 12),
          tile('Active workflows', '${d.activeWorkflows}', 'Running on schedule or webhook', Icons.show_chart),
        ]),
      ),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          tile('Total executions', NumberFormat.decimalPattern().format(d.totalExecutions), '${d.executions30d} in the last 30 days', Icons.history),
          const SizedBox(width: 12),
          tile('Success rate', d.successRate == null ? '—' : '${d.successRate}%', d.successRate == null ? 'No finished runs in 30 days' : 'Of finished runs, last 30 days', Icons.check_circle_outline),
        ]),
      ),
    ]);
  }
}

class _Onboarding extends StatelessWidget {
  const _Onboarding({required this.hasWorkflow, required this.hasIntegration, required this.hasRun});
  final bool hasWorkflow;
  final bool hasIntegration;
  final bool hasRun;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (hasWorkflow, 'Create your first workflow', 'Start blank or from a template.', '/workflows/new', 'New workflow'),
      (hasIntegration, 'Connect an integration', 'Email, Slack or an API credential.', '/integrations', 'Integrations'),
      (hasRun, 'Run a workflow', 'Test it and watch each step complete.', '/workflows', 'Open workflows'),
    ];
    final remaining = steps.where((s) => !s.$1).length;
    if (remaining == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GwCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0x148585FF), Colors.transparent]),
              border: Border(bottom: BorderSide(color: Gw.lineSubtle)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Get set up', style: GwText.section),
              const SizedBox(height: 4),
              Text('${3 - remaining} of 3 done. These steps are checked against your account.', style: GwText.meta),
            ]),
          ),
          for (final (i, (done, title, body, href, cta)) in steps.indexed) ...[
            if (i > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(done ? Icons.check_circle_outline : Icons.radio_button_unchecked, size: 18, color: done ? Gw.success : Gw.fgMuted, semanticLabel: done ? 'Done' : 'Not done'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: GwText.bodyMedium.copyWith(color: done ? Gw.fgMuted : Gw.fg, decoration: done ? TextDecoration.lineThrough : null)),
                    const SizedBox(height: 2),
                    Text(body, style: GwText.meta),
                    if (!done) Padding(padding: const EdgeInsets.only(top: 8), child: GwLink(cta, icon: Icons.arrow_forward, onTap: () => context.go(href))),
                  ]),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Health extends StatelessWidget {
  const _Health(this.d);
  final DashboardSummary d;

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label, Color color) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: TextStyle(fontFamily: Gw.fontSans, fontSize: 20, fontWeight: FontWeight.w600, color: color)),
              Text(label, style: GwText.micro),
            ]),
          ),
        );
    return GwCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GwCardHeader(title: 'Workflow health', description: 'Last run ${timeAgo(d.lastExecutionAt)}'),
        Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Gw.lineSubtle))),
          child: IntrinsicHeight(
            child: Row(children: [
              stat('${d.failures24h}', 'Failures (24h)', d.failures24h > 0 ? Gw.danger : Gw.fg),
              const VerticalDivider(width: 1, color: Gw.lineSubtle),
              stat('${d.successes24h}', 'Successes (24h)', Gw.fg),
              const VerticalDivider(width: 1, color: Gw.lineSubtle),
              stat('${d.inProgress}', 'In progress', d.inProgress > 0 ? Gw.cyan : Gw.fg),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: d.attention.isEmpty
              ? Row(children: [
                  const Icon(Icons.check_circle_outline, size: 15, color: Gw.success),
                  const SizedBox(width: 8),
                  Expanded(child: Text('No active workflows need attention.', style: GwText.body.copyWith(color: Gw.fgMuted))),
                ])
              : Column(children: [
                  for (final a in d.attention)
                    InkWell(
                      onTap: () => context.go('/workflows/${a.workflowId}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded, size: 15, color: Gw.warning),
                          const SizedBox(width: 10),
                          Expanded(child: Text(a.workflowName, overflow: TextOverflow.ellipsis, style: GwText.body.copyWith(color: Gw.fgSecondary))),
                          Text(a.reason, style: GwText.meta),
                        ]),
                      ),
                    ),
                ]),
        ),
      ]),
    );
  }
}

/// Stacked bars, 14 days (web TrendChart): status colors, legend, tap for details, table view.
class TrendChart extends StatefulWidget {
  const TrendChart({super.key, required this.trend});
  final List<TrendPoint> trend;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  static const _series = [('Succeeded', Gw.success), ('Failed', Gw.danger), ('Other', Color(0xFF6B7385))];
  bool _table = false;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final total = widget.trend.fold<int>(0, (s, p) => s + p.total);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Wrap(spacing: 16, runSpacing: 4, children: [
            for (final (label, color) in _series)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Text(label, style: GwText.meta.copyWith(color: Gw.fgSecondary)),
              ]),
          ]),
        ),
        GwLink(_table ? 'Show chart' : 'Show as table', style: GwText.meta, onTap: () => setState(() => _table = !_table)),
      ]),
      const SizedBox(height: 12),
      if (_table)
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Gw.rMd), border: Border.all(color: Gw.lineSubtle)),
          child: Column(children: [
            _tableRow(['Day', 'Succeeded', 'Failed', 'Other'], header: true),
            for (final p in widget.trend) _tableRow([DateFormat.MMMd().format(p.date), '${p.succeeded}', '${p.failed}', '${p.other}']),
          ]),
        )
      else
        Semantics(
          label: 'Bar chart of $total executions over the last 14 days',
          child: SizedBox(
            height: 220,
            child: Stack(children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, c) => GestureDetector(
                    onTapDown: (d) {
                      final i = ((d.localPosition.dx - 28) / ((c.maxWidth - 28) / widget.trend.length)).floor();
                      setState(() => _selected = (i >= 0 && i < widget.trend.length && _selected != i) ? i : null);
                    },
                    child: CustomPaint(painter: _BarsPainter(widget.trend, _selected)),
                  ),
                ),
              ),
              if (total == 0) Center(child: Text('No runs in the last 14 days', style: GwText.body.copyWith(color: Gw.fgMuted))),
              if (_selected != null) Positioned(top: 0, right: 0, child: _tooltip(widget.trend[_selected!])),
            ]),
          ),
        ),
    ]);
  }

  Widget _tooltip(TrendPoint p) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Gw.elevated, borderRadius: BorderRadius.circular(Gw.rMd), border: Border.all(color: Gw.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(DateFormat.MMMd().format(p.date), style: GwText.meta.copyWith(color: Gw.fg, fontWeight: FontWeight.w500)),
          for (final (i, (label, color)) in _series.indexed)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, color: color),
              const SizedBox(width: 6),
              SizedBox(width: 72, child: Text(label, style: GwText.meta.copyWith(color: Gw.fgSecondary))),
              Text('${[p.succeeded, p.failed, p.other][i]}', style: GwText.meta.copyWith(color: Gw.fg)),
            ]),
        ]),
      );

  Widget _tableRow(List<String> cells, {bool header = false}) => Container(
        color: header ? Gw.elevated : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          for (final (i, c) in cells.indexed)
            Expanded(child: Text(c, textAlign: i == 0 ? TextAlign.left : TextAlign.right, style: GwText.meta.copyWith(color: header ? Gw.fgMuted : (i == 0 ? Gw.fgSecondary : Gw.fg)))),
        ]),
      );
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.trend, this.selected);
  final List<TrendPoint> trend;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0;
    const bottom = 22.0;
    final chartH = size.height - bottom - 4;
    final maxV = math.max(1, trend.fold<int>(0, (m, p) => math.max(m, p.total)));
    final step = (maxV / 4).ceil().clamp(1, 1 << 30);
    final top = step * 4;
    final grid = Paint()..color = Gw.lineSubtle;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 4; i++) {
      final y = 4 + chartH - chartH * i / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      tp
        ..text = TextSpan(text: '${step * i}', style: const TextStyle(fontFamily: Gw.fontSans, fontSize: 11, color: Gw.fgMuted))
        ..layout();
      tp.paint(canvas, Offset(left - tp.width - 6, y - tp.height / 2));
    }
    if (trend.isEmpty) return;
    final slot = (size.width - left) / trend.length;
    final barW = math.min(28.0, slot * 0.72);
    const colors = [Gw.success, Gw.danger, Color(0xFF6B7385)];
    for (final (i, p) in trend.indexed) {
      final x = left + slot * i + (slot - barW) / 2;
      if (i == selected) canvas.drawRect(Rect.fromLTWH(left + slot * i, 4, slot, chartH), Paint()..color = const Color(0x0FA0A8B8));
      var y = 4 + chartH;
      final values = [p.succeeded, p.failed, p.other];
      final lastNonZero = values.lastIndexWhere((v) => v > 0);
      for (final (j, v) in values.indexed) {
        if (v == 0) continue;
        final h = chartH * v / top;
        final rect = Rect.fromLTWH(x, y - h, barW, h);
        final rr = j == lastNonZero ? RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(4), topRight: const Radius.circular(4)) : RRect.fromRectXY(rect, 0, 0);
        canvas.drawRRect(rr, Paint()..color = colors[j]);
        canvas.drawLine(Offset(x, y - h), Offset(x + barW, y - h), Paint()
          ..color = Gw.surface
          ..strokeWidth = 2);
        y -= h;
      }
      if (i == 0 || i == trend.length - 1 || i % 3 == 0) {
        tp
          ..text = TextSpan(text: DateFormat.MMMd().format(p.date), style: const TextStyle(fontFamily: Gw.fontSans, fontSize: 10.5, color: Gw.fgMuted))
          ..layout();
        tp.paint(canvas, Offset((left + slot * i + slot / 2 - tp.width / 2).clamp(left, size.width - tp.width), size.height - bottom + 6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => old.trend != trend || old.selected != selected;
}
