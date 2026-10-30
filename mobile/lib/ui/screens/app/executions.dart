// Port of frontend/src/app/(app)/executions/* and components/execution/ExecutionTable.tsx.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/api_client.dart';
import '../../../data/models.dart';
import '../../../state/providers.dart';
import '../../canvas/flow_canvas.dart';
import '../../canvas/timeline.dart';
import '../../components/ui.dart';
import '../../format.dart';
import '../../shell/app_shell.dart';
import 'workflows.dart' show describeError;

/// Compact execution cards (the web table's mobile layout).
class ExecutionList extends StatelessWidget {
  const ExecutionList({super.key, required this.items, this.showWorkflow = true});
  final List<ExecutionSummary> items;
  final bool showWorkflow;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, e) in items.indexed) ...[
          if (i > 0) const Divider(),
          InkWell(
            onTap: () => context.go('/executions/${e.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  StatusBadge(e.status, small: true),
                  const SizedBox(width: 8),
                  Text(shortId(e.id), style: GwText.mono.copyWith(fontSize: 11, color: Gw.fgMuted)),
                  const Spacer(),
                  Text(formatDuration(e.durationMs), style: GwText.micro),
                ]),
                if (showWorkflow) Padding(padding: const EdgeInsets.only(top: 6), child: Text(e.workflowName, overflow: TextOverflow.ellipsis, style: GwText.bodyMedium)),
                const SizedBox(height: 2),
                Text('${triggerLabel(e.triggerType)} · ${timeAgo(e.createdAt)}', style: GwText.micro),
                if (e.status == 'failed' && e.errorMessage != null)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.errorMessage!, maxLines: 2, overflow: TextOverflow.ellipsis, style: GwText.meta.copyWith(color: Gw.danger))),
              ]),
            ),
          ),
        ],
      ]);
}

class ExecutionsScreen extends ConsumerStatefulWidget {
  const ExecutionsScreen({super.key, this.workflowId = ''});
  final String workflowId;

  @override
  ConsumerState<ExecutionsScreen> createState() => _ExecutionsScreenState();
}

class _ExecutionsScreenState extends ConsumerState<ExecutionsScreen> {
  final _search = TextEditingController();
  String _q = '';
  String _status = '';
  late String _workflowId = widget.workflowId;
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  Timer? _debounce;
  Timer? _poll;

  ExecutionQuery get _query => (
        q: _q,
        status: _status,
        workflowId: _workflowId,
        from: _from,
        to: _to?.add(const Duration(days: 1)),
        page: _page,
        pageSize: 20,
      );

  @override
  void initState() {
    super.initState();
    // Refresh while any visible run is queued or running (web: 2.5s).
    _poll = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (ref.read(executionsProvider(_query)).value?.items.any((e) => e.isActive) ?? false) ref.invalidate(executionsProvider(_query));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _pickDate(bool from) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(surface: Gw.surface)), child: child!),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final runs = ref.watch(executionsProvider(_query));
    final workflows = ref.watch(workflowsProvider((q: '', status: '', sort: 'name', page: 1, pageSize: 100)));
    final filtered = _q.isNotEmpty || _status.isNotEmpty || _workflowId.isNotEmpty || _from != null || _to != null;
    final df = DateFormat('MM/dd/yyyy');
    Widget dateButton(String label, DateTime? value, bool from) => Expanded(
          child: InkWell(
            onTap: () => _pickDate(from),
            child: InputDecorator(
              decoration: gwInputDecoration(dense: true, suffix: const Icon(Icons.calendar_today_outlined, size: 15, color: Gw.fgMuted)),
              child: Text(value == null ? label : df.format(value), style: GwText.body.copyWith(color: value == null ? Gw.fgMuted : Gw.fg)),
            ),
          ),
        );
    return PageBody(
      onRefresh: () => ref.refresh(executionsProvider(_query).future),
      children: [
        const GwPageHeader(title: 'Executions', description: 'Every run of every workflow, step by step.'),
        GwCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Gw.lineSubtle))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                GwSearchField(
                  controller: _search,
                  hint: 'Search by workflow or execution ID',
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => (_q = v.trim(), _page = 1)));
                  },
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: GwSelect<String>(
                      value: _status,
                      semanticLabel: 'Status',
                      items: const [('', 'All statuses'), ('succeeded', 'Succeeded'), ('failed', 'Failed'), ('running', 'Running'), ('queued', 'Queued'), ('cancelled', 'Cancelled')],
                      onChanged: (v) => setState(() => (_status = v, _page = 1)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GwSelect<String>(
                      key: ValueKey(workflows.value?.items.length),
                      value: _workflowId,
                      semanticLabel: 'Workflow',
                      items: [('', 'All workflows'), for (final w in workflows.value?.items ?? const <WorkflowSummary>[]) (w.id, w.name)],
                      onChanged: (v) => setState(() => (_workflowId = v, _page = 1)),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [dateButton('From', _from, true), const SizedBox(width: 8), dateButton('To', _to, false)]),
                if (filtered)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GwButton(
                        label: 'Clear',
                        icon: Icons.close,
                        variant: GwVariant.ghost,
                        size: GwSize.sm,
                        onPressed: () {
                          _search.clear();
                          setState(() => (_q = '', _status = '', _workflowId = '', _from = null, _to = null, _page = 1));
                        },
                      ),
                    ),
                  ),
              ]),
            ),
            runs.when(
              skipLoadingOnReload: true,
              loading: () => const GwLoading(rows: 6, label: 'Loading executions'),
              error: (e, _) => GwError(title: "Couldn't load executions", error: e, onRetry: () => ref.invalidate(executionsProvider(_query))),
              data: (page) => page.items.isEmpty
                  ? (filtered
                      ? const GwEmpty(title: 'No matching executions', description: 'Try different filters.')
                      : GwEmpty(
                          icon: Icons.history,
                          title: 'No executions yet',
                          description: 'When a workflow runs — manually, on a schedule or from a webhook — it appears here.',
                          actions: [GwButton(label: 'Go to workflows', variant: GwVariant.primary, onPressed: () => context.go('/workflows'))],
                        ))
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      ExecutionList(items: page.items),
                      GwPagination(page: _page, pageSize: 20, total: page.total, onPage: (p) => setState(() => _page = p)),
                    ]),
            ),
          ]),
        ),
      ],
    );
  }
}

class ExecutionDetailScreen extends ConsumerStatefulWidget {
  const ExecutionDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ExecutionDetailScreen> createState() => _ExecutionDetailScreenState();
}

class _ExecutionDetailScreenState extends ConsumerState<ExecutionDetailScreen> {
  Timer? _poll;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Poll every second while the run is queued or running (web: 1s).
    _poll = Timer.periodic(const Duration(seconds: 1), (_) {
      if (ref.read(executionProvider(widget.id)).value?.isActive ?? false) ref.invalidate(executionProvider(widget.id));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _rerun() async {
    setState(() => _busy = true);
    try {
      final next = await ref.read(apiClientProvider).executionAction(widget.id, 'rerun');
      ref.invalidate(executionsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) {
        toast(context, 'Run queued', description: 'Same trigger data, current workflow version.');
        context.go('/executions/${next.id}');
      }
    } catch (e) {
      if (mounted) toast(context, "Couldn't run again", description: describeError(e), tone: AlertTone.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final execution = ref.watch(executionProvider(widget.id));
    return PageBody(
      onRefresh: () => ref.refresh(executionProvider(widget.id).future),
      children: [
        GwBackLink(label: 'Executions', onTap: () => context.go('/executions')),
        execution.when(
          skipLoadingOnReload: true,
          loading: () => const GwLoading(rows: 6, label: 'Loading execution'),
          error: (e, _) {
            final notFound = e is ApiException && e.status == 404;
            return GwCard(
              child: GwError(
                title: notFound ? 'Execution not found' : "Couldn't load this execution",
                error: notFound ? 'It may belong to a deleted workflow or another account.' : e,
                onRetry: notFound ? null : () => ref.invalidate(executionProvider(widget.id)),
              ),
            );
          },
          data: (e) {
            final failedStep = e.steps.where((s) => s.status == 'failed').firstOrNull;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text.rich(TextSpan(style: GwText.title, children: [
                  const TextSpan(text: 'Run '),
                  TextSpan(text: shortId(e.id), style: GwText.title.copyWith(fontFamily: Gw.fontMono, color: Gw.fgSecondary)),
                ])),
                StatusBadge(e.status),
              ]),
              const SizedBox(height: 4),
              Wrap(children: [
                InkWell(onTap: () => context.go('/workflows/${e.workflowId}'), child: Text(e.workflowName, style: GwText.body.copyWith(color: Gw.fgSecondary))),
                Text(' · ${triggerLabel(e.triggerType)} · ${formatDateTime(e.createdAt)}', style: GwText.body.copyWith(color: Gw.fgMuted)),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (e.isActive)
                  GwButton(
                    label: 'Cancel run',
                    icon: Icons.block,
                    onPressed: () async {
                      final ok = await confirmAction(
                        context,
                        title: 'Cancel this run?',
                        description: "A queued run won't start. A running run stops before its next step; a step already in progress finishes first.",
                        confirmLabel: 'Cancel run',
                        danger: true,
                        action: () async {
                          try {
                            await ref.read(apiClientProvider).executionAction(e.id, 'cancel');
                            return null;
                          } catch (err) {
                            return describeError(err);
                          }
                        },
                      );
                      if (ok) {
                        ref.invalidate(executionProvider(e.id));
                        ref.invalidate(executionsProvider);
                        if (context.mounted) toast(context, 'Run cancelled');
                      }
                    },
                  ),
                GwButton(label: 'Run again', icon: Icons.replay, variant: GwVariant.primary, loading: _busy, onPressed: e.isActive ? null : _rerun),
              ]),
              if (e.status == 'failed' && e.errorMessage != null) ...[
                const SizedBox(height: 20),
                GwAlert(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(failedStep != null ? '“${failedStep.nodeName}” failed' : 'This run failed', style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(e.errorMessage!),
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              GwCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  GwCardHeader(title: 'Workflow map', description: 'Version ${e.workflowVersion} as it ran${e.isActive ? ' — updating live' : ''}'),
                  SizedBox(height: 340, child: FlowCanvas(definition: e.definition, steps: {for (final s in e.steps) s.nodeId: s})),
                ]),
              ),
              const SizedBox(height: 20),
              GwCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const GwCardHeader(title: 'Steps', description: 'Select a step to see its output or error.'),
                  Padding(padding: const EdgeInsets.all(8), child: ExecutionTimeline(key: ValueKey('${e.id}-${e.status}'), steps: e.steps, totalMs: e.durationMs)),
                ]),
              ),
              const SizedBox(height: 20),
              GwCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const GwCardHeader(title: 'Details'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(children: [
                      for (final (i, (k, v, mono)) in [
                        ('Execution ID', e.id, true),
                        ('Status', e.status, false),
                        ('Trigger', triggerLabel(e.triggerType), false),
                        ('Queued', formatDateTime(e.createdAt), false),
                        ('Started', formatDateTime(e.startedAt), false),
                        ('Finished', formatDateTime(e.finishedAt), false),
                        ('Duration', formatDuration(e.durationMs), false),
                      ].indexed) ...[
                        if (i > 0) const Divider(),
                        GwKeyValue(k, v, mono: mono),
                      ],
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              GwCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const GwCardHeader(title: 'Trigger data', description: 'Available to steps as trigger.payload'),
                  Padding(padding: const EdgeInsets.all(12), child: JsonBlock(e.triggerPayload, maxHeight: 320)),
                ]),
              ),
            ]);
          },
        ),
      ],
    );
  }
}
