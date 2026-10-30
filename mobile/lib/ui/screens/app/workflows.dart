// Port of frontend/src/app/(app)/workflows/* and components/workflow/WorkflowActions.tsx.
import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../data/api_client.dart';
import '../../../data/models.dart';
import '../../../state/providers.dart';
import '../../canvas/flow_canvas.dart';
import '../../canvas/node_meta.dart';
import '../../components/ui.dart';
import '../../format.dart';
import '../../shell/app_shell.dart';
import 'dashboard.dart' show asyncBody;
import 'executions.dart' show ExecutionList;

String describeError(Object e) => e is ApiException && e.issues.isNotEmpty ? '${e.message} ${e.issues.take(3).join(' ')}' : e.toString();

void refreshWorkflowData(WidgetRef ref, [String? id]) {
  ref.invalidate(workflowsProvider);
  ref.invalidate(dashboardProvider);
  if (id != null) ref.invalidate(workflowProvider(id));
}

/* ============================== Actions menu ============================== */

class WorkflowActions extends ConsumerWidget {
  const WorkflowActions({super.key, required this.workflow, this.showView = true, this.onDeleted});
  final WorkflowSummary workflow;
  final bool showView;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiClientProvider);
    return PopupMenuButton<String>(
      tooltip: 'Actions for ${workflow.name}',
      icon: const Icon(Icons.more_horiz, size: 18, color: Gw.fgSecondary),
      itemBuilder: (_) => [
        if (showView) gwMenuItem('view', 'View details', Icons.visibility_outlined),
        gwMenuItem('builder', 'Open builder', Icons.design_services_outlined),
        gwMenuItem('duplicate', 'Duplicate', Icons.copy),
        workflow.status == 'active' ? gwMenuItem('pause', 'Pause', Icons.pause) : gwMenuItem('activate', 'Activate', Icons.play_arrow),
        const PopupMenuDivider(height: 8),
        gwMenuItem('delete', 'Delete', Icons.delete_outline, danger: true),
      ],
      onSelected: (action) async {
        switch (action) {
          case 'view':
            context.go('/workflows/${workflow.id}');
          case 'builder':
            context.go('/workflows/${workflow.id}/builder');
          case 'duplicate':
            try {
              final copy = await api.duplicateWorkflow(workflow.id);
              refreshWorkflowData(ref);
              if (context.mounted) toast(context, 'Workflow duplicated', description: copy.name);
            } catch (e) {
              if (context.mounted) toast(context, "Couldn't duplicate", description: describeError(e), tone: AlertTone.danger);
            }
          case 'pause':
            try {
              await api.setWorkflowStatus(workflow.id, 'paused');
              refreshWorkflowData(ref, workflow.id);
              if (context.mounted) toast(context, '${workflow.name} paused');
            } catch (e) {
              if (context.mounted) toast(context, "Couldn't pause", description: describeError(e), tone: AlertTone.danger);
            }
          case 'activate':
            final ok = await confirmAction(
              context,
              title: 'Activate workflow?',
              description: 'Once active, its schedule or webhook will start runs automatically. You can pause it at any time.',
              confirmLabel: 'Activate',
              action: () async {
                try {
                  await api.setWorkflowStatus(workflow.id, 'active');
                  return null;
                } catch (e) {
                  return describeError(e);
                }
              },
            );
            if (ok) {
              refreshWorkflowData(ref, workflow.id);
              if (context.mounted) toast(context, '${workflow.name} is active');
            }
          case 'delete':
            final ok = await confirmAction(
              context,
              title: 'Delete workflow?',
              description: "${workflow.name} and its entire execution history will be permanently deleted. This can't be undone.",
              confirmLabel: 'Delete workflow',
              danger: true,
              action: () async {
                try {
                  await api.deleteWorkflow(workflow.id);
                  return null;
                } catch (e) {
                  return describeError(e);
                }
              },
            );
            if (ok) {
              refreshWorkflowData(ref);
              ref.invalidate(executionsProvider);
              if (context.mounted) toast(context, 'Workflow deleted');
              onDeleted?.call();
            }
        }
      },
    );
  }
}

/* ================================ List ================================ */

class WorkflowListScreen extends ConsumerStatefulWidget {
  const WorkflowListScreen({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  ConsumerState<WorkflowListScreen> createState() => _WorkflowListScreenState();
}

class _WorkflowListScreenState extends ConsumerState<WorkflowListScreen> {
  late final _search = TextEditingController(text: widget.initialQuery);
  late String _q = widget.initialQuery;
  String _status = '';
  String _sort = '-updated';
  int _page = 1;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = (q: _q, status: _status, sort: _sort, page: _page, pageSize: 12);
    final workflows = ref.watch(workflowsProvider(query));
    final filtered = _q.isNotEmpty || _status.isNotEmpty;
    return PageBody(
      onRefresh: () => ref.refresh(workflowsProvider(query).future),
      children: [
        GwPageHeader(title: 'Workflows', description: 'Design, run and monitor your automations.', actions: [
          GwButton(label: 'Templates', icon: Icons.view_quilt_outlined, onPressed: () => context.go('/templates')),
          GwButton(label: 'New workflow', icon: Icons.add, variant: GwVariant.primary, onPressed: () => context.go('/workflows/new')),
        ]),
        GwCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Gw.lineSubtle))),
              child: Column(children: [
                GwSearchField(
                  controller: _search,
                  hint: 'Search by name or description',
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
                      items: const [('', 'All statuses'), ('active', 'Active'), ('paused', 'Paused'), ('draft', 'Draft')],
                      onChanged: (v) => setState(() => (_status = v, _page = 1)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GwSelect<String>(
                      value: _sort,
                      semanticLabel: 'Sort',
                      items: const [
                        ('-updated', 'Recently updated'),
                        ('-last_run', 'Recently run'),
                        ('name', 'Name A–Z'),
                        ('-name', 'Name Z–A'),
                        ('-created', 'Newest'),
                        ('created', 'Oldest'),
                      ],
                      onChanged: (v) => setState(() => (_sort = v, _page = 1)),
                    ),
                  ),
                ]),
              ]),
            ),
            workflows.when(
              skipLoadingOnReload: true,
              loading: () => const GwLoading(rows: 5, label: 'Loading workflows'),
              error: (e, _) => GwError(title: "Couldn't load workflows", error: e, onRetry: () => ref.invalidate(workflowsProvider(query))),
              data: (page) => page.items.isEmpty
                  ? (filtered
                      ? GwEmpty(title: 'No matching workflows', description: 'Try a different search or clear the filters.', actions: [
                          GwButton(
                            label: 'Clear filters',
                            onPressed: () {
                              _search.clear();
                              setState(() => (_q = '', _status = '', _page = 1));
                            },
                          ),
                        ])
                      : GwEmpty(
                          icon: Icons.account_tree_outlined,
                          title: 'No workflows yet',
                          description: 'Create one from scratch or start from a template.',
                          actions: [
                            GwButton(label: 'New workflow', icon: Icons.add, variant: GwVariant.primary, onPressed: () => context.go('/workflows/new')),
                            GwButton(label: 'Browse templates', onPressed: () => context.go('/templates')),
                          ],
                        ))
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final (i, w) in page.items.indexed) ...[
                        if (i > 0) const Divider(),
                        InkWell(
                          onTap: () => context.go('/workflows/${w.id}'),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(w.name, overflow: TextOverflow.ellipsis, style: GwText.bodyMedium),
                                  const SizedBox(height: 6),
                                  Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                    StatusBadge(w.status, small: true),
                                    Text(triggerLabel(w.triggerType), style: GwText.micro),
                                    Text('·', style: GwText.micro),
                                    Text(w.lastExecution == null ? 'Never run' : 'Ran ${timeAgo(w.lastExecution!.createdAt)}', style: GwText.micro),
                                  ]),
                                ]),
                              ),
                              WorkflowActions(workflow: w),
                            ]),
                          ),
                        ),
                      ],
                      GwPagination(page: _page, pageSize: 12, total: page.total, onPage: (p) => setState(() => _page = p)),
                    ]),
            ),
          ]),
        ),
      ],
    );
  }
}

/* ================================ New ================================ */

class NewWorkflowScreen extends ConsumerStatefulWidget {
  const NewWorkflowScreen({super.key});

  @override
  ConsumerState<NewWorkflowScreen> createState() => _NewWorkflowScreenState();
}

class _NewWorkflowScreenState extends ConsumerState<NewWorkflowScreen> {
  static const _triggers = [
    ('trigger.manual', Icons.back_hand_outlined, 'Manual', 'Run on demand from GhostWork.', 'Manual trigger', <String, dynamic>{}),
    ('trigger.schedule', Icons.event_repeat, 'Schedule', 'Repeat every few minutes, hours or days.', 'Every hour', <String, dynamic>{'every': 1, 'unit': 'hours'}),
    ('trigger.webhook', Icons.webhook, 'Webhook', 'Run when a unique URL receives a POST.', 'Incoming webhook', <String, dynamic>{}),
  ];

  final _name = TextEditingController();
  final _description = TextEditingController();
  String _trigger = 'trigger.manual';
  String? _nameError;
  String? _error;
  bool _busy = false;
  ({String file, Definition definition})? _imported;
  String? _importError;

  Future<void> _import() async {
    setState(() => _importError = null);
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (files.isEmpty) return;
    final file = files.first;
    if ((await file.length() ?? 0) > 1000000) return setState(() => _importError = 'That file is too large to be a GhostWork workflow.');
    try {
      final data = jsonDecode(utf8.decode(await file.readAsBytes())) as Map<String, dynamic>;
      final raw = (data['definition'] ?? data) as Map<String, dynamic>;
      if (raw['nodes'] is! List || raw['edges'] is! List) throw const FormatException();
      setState(() {
        _imported = (file: file.name, definition: Definition.fromJson(raw));
        if (data['name'] != null) _name.text = '${data['name']}'.substring(0, '${data['name']}'.length.clamp(0, 120));
        if (data['description'] != null) _description.text = '${data['description']}';
      });
    } catch (_) {
      setState(() => _importError = "This file isn't a GhostWork workflow export.");
    }
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    setState(() => _nameError = name.isEmpty ? 'Give your workflow a name.' : (name.length > 120 ? 'Keep it under 120 characters.' : null));
    if (_nameError != null) return;
    final t = _triggers.firstWhere((t) => t.$1 == _trigger);
    final definition = _imported?.definition ??
        Definition(nodes: [NodeDef(id: 'trigger', type: t.$1, name: t.$5, x: 0, y: 0, config: Map.of(t.$6))], edges: []);
    setState(() => (_busy = true, _error = null));
    try {
      final w = await ref.read(apiClientProvider).createWorkflow(name: name, description: _description.text.trim(), definition: definition);
      refreshWorkflowData(ref);
      if (mounted) context.go('/workflows/${w.id}/builder');
    } catch (e) {
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(children: [
        GwBackLink(label: 'Workflows', onTap: () => context.go('/workflows')),
        const GwPageHeader(title: 'New workflow', description: 'Name it, choose how it starts, then build the steps.'),
        GwCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: GwAlert(child: Text(_error!))),
            GwField(label: 'Name', error: _nameError, child: GwInput(controller: _name, hint: 'e.g. Nightly order sync', error: _nameError != null, semanticLabel: 'Name')),
            const SizedBox(height: 20),
            GwField(label: 'Description', optional: true, child: GwInput(controller: _description, hint: 'What does this workflow do?', maxLines: 3, minLines: 3, semanticLabel: 'Description')),
            const SizedBox(height: 20),
            if (_imported != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Gw.violetSoft, borderRadius: BorderRadius.circular(Gw.rLg), border: Border.all(color: Gw.violet.withValues(alpha: 0.4))),
                child: Row(children: [
                  const Icon(Icons.upload_file, size: 16, color: Gw.violet),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Importing ${_imported!.file} · ${_imported!.definition.nodes.length} steps', overflow: TextOverflow.ellipsis, style: GwText.body)),
                  GwButton(label: 'Remove', variant: GwVariant.ghost, size: GwSize.sm, onPressed: () => setState(() => _imported = null)),
                ]),
              )
            else ...[
              Text('How should it start?', style: GwText.meta.copyWith(color: Gw.fgSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              for (final (type, icon, title, body, _, _) in _triggers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    selected: _trigger == type,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Gw.rLg),
                      onTap: () => setState(() => _trigger = type),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _trigger == type ? Gw.violetSoft : Gw.canvas,
                          borderRadius: BorderRadius.circular(Gw.rLg),
                          border: Border.all(color: _trigger == type ? Gw.violet : Gw.line),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(icon, size: 17, color: _trigger == type ? Gw.violet : Gw.fgMuted),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GwText.bodyMedium), Text(body, style: GwText.meta)])),
                        ]),
                      ),
                    ),
                  ),
                ),
              Text('You can change the trigger later in the builder.', style: GwText.meta),
            ],
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: GwLink('Import from a GhostWork JSON export', icon: Icons.upload_file, style: GwText.meta, onTap: _import)),
            if (_importError != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_importError!, style: GwText.meta.copyWith(color: Gw.danger))),
            const Divider(height: 32),
            GwButton(label: 'Create and open builder', variant: GwVariant.primary, expand: true, loading: _busy, onPressed: _create),
            const SizedBox(height: 12),
            Center(child: GwLink('Start from a template instead', icon: Icons.view_quilt_outlined, style: GwText.meta, onTap: () => context.go('/templates'))),
          ]),
        ),
      ]);
}

/* ================================ Detail ================================ */

class WorkflowDetailScreen extends ConsumerStatefulWidget {
  const WorkflowDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<WorkflowDetailScreen> createState() => _WorkflowDetailScreenState();
}

class _WorkflowDetailScreenState extends ConsumerState<WorkflowDetailScreen> {
  bool _running = false;
  bool _statusBusy = false;

  ExecutionQuery get _runsQuery => (q: '', status: '', workflowId: widget.id, from: null, to: null, page: 1, pageSize: 10);

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      final e = await ref.read(apiClientProvider).runWorkflow(widget.id);
      ref.invalidate(executionsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) {
        toast(context, 'Run queued', description: 'Opening the live execution view.');
        context.go('/executions/${e.id}');
      }
    } catch (e) {
      if (mounted) toast(context, "Couldn't start the run", description: describeError(e), tone: AlertTone.danger);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workflow = ref.watch(workflowProvider(widget.id));
    final runs = ref.watch(executionsProvider(_runsQuery));
    final latestId = runs.value?.items.firstOrNull?.id;
    final latest = latestId == null ? null : ref.watch(executionProvider(latestId)).value;
    final api = ref.read(apiClientProvider);

    return PageBody(
      onRefresh: () {
        ref.invalidate(executionsProvider(_runsQuery));
        return ref.refresh(workflowProvider(widget.id).future);
      },
      children: [
        GwBackLink(label: 'Workflows', onTap: () => context.go('/workflows')),
        workflow.when(
          skipLoadingOnReload: true,
          loading: () => const GwLoading(rows: 6, label: 'Loading workflow'),
          error: (e, _) {
            final notFound = e is ApiException && e.status == 404;
            return GwCard(
              child: GwError(
                title: notFound ? 'Workflow not found' : "Couldn't load this workflow",
                error: notFound ? 'It may have been deleted, or it belongs to another account.' : e,
                onRetry: notFound ? null : () => ref.invalidate(workflowProvider(widget.id)),
              ),
            );
          },
          data: (w) {
            final trigger = w.definition.nodes.where((n) => n.kind == 'trigger').firstOrNull;
            final recent = runs.value?.items ?? const <ExecutionSummary>[];
            final succeeded = recent.where((e) => e.status == 'succeeded').length;
            final failed = recent.where((e) => e.status == 'failed').length;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(w.name, style: GwText.title),
                StatusBadge(w.status),
              ]),
              const SizedBox(height: 4),
              Text(w.description.isEmpty ? 'No description' : w.description, style: GwText.body.copyWith(color: Gw.fgMuted)),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                GwButton(label: 'Run now', icon: Icons.play_arrow, loading: _running, onPressed: w.isValid ? _run : null),
                if (w.status == 'active')
                  GwButton(
                    label: 'Pause',
                    icon: Icons.pause,
                    loading: _statusBusy,
                    onPressed: () async {
                      setState(() => _statusBusy = true);
                      try {
                        await api.setWorkflowStatus(w.id, 'paused');
                        refreshWorkflowData(ref, w.id);
                        if (context.mounted) toast(context, 'Workflow paused');
                      } catch (e) {
                        if (context.mounted) toast(context, "Couldn't pause", description: describeError(e), tone: AlertTone.danger);
                      } finally {
                        if (mounted) setState(() => _statusBusy = false);
                      }
                    },
                  )
                else
                  GwButton(
                    label: 'Activate',
                    icon: Icons.check,
                    onPressed: !w.isValid
                        ? null
                        : () async {
                            final ok = await confirmAction(
                              context,
                              title: 'Activate workflow?',
                              description: 'Its schedule or webhook will start runs automatically. You can pause it at any time.',
                              confirmLabel: 'Activate',
                              action: () async {
                                try {
                                  await api.setWorkflowStatus(w.id, 'active');
                                  return null;
                                } catch (e) {
                                  return describeError(e);
                                }
                              },
                            );
                            if (ok) {
                              refreshWorkflowData(ref, w.id);
                              if (context.mounted) toast(context, '${w.name} is active');
                            }
                          },
                  ),
                GwButton(label: 'Export', icon: Icons.download, onPressed: () => _export(context, w)),
                GwButton(label: 'Open builder', icon: Icons.design_services_outlined, variant: GwVariant.primary, onPressed: () => context.go('/workflows/${w.id}/builder')),
                WorkflowActions(workflow: w, showView: false, onDeleted: () => context.go('/workflows')),
              ]),
              if (!w.isValid) ...[
                const SizedBox(height: 20),
                GwAlert(
                  tone: AlertTone.warning,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.error_outline, size: 14, color: Gw.warningText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${w.validation.length} issue${w.validation.length > 1 ? 's' : ''} to fix before this workflow can run',
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    for (final i in w.validation.take(5)) Text('•  ${i.message}'),
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              GwCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  GwCardHeader(
                    title: 'Workflow map',
                    description: latest != null
                        ? 'Showing the latest run (${latest.status}, ${timeAgo(latest.createdAt)})'
                        : 'No runs yet — step results will appear here after the first run',
                  ),
                  if (w.definition.nodes.isEmpty)
                    GwEmpty(title: 'No steps yet', actions: [GwButton(label: 'Open builder', variant: GwVariant.primary, onPressed: () => context.go('/workflows/${w.id}/builder'))])
                  else
                    SizedBox(
                      height: 360,
                      child: FlowCanvas(
                        definition: w.definition,
                        steps: latest != null && latest.workflowVersion == w.version ? {for (final s in latest.steps) s.nodeId: s} : const {},
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 20),
              GwCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const GwCardHeader(title: 'Trigger'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      GwKeyValue('Type', triggerLabel(w.triggerType)),
                      if (trigger != null) ...[const Divider(), GwKeyValue('Setting', summarizeNode(trigger))],
                      if (w.triggerType == 'trigger.schedule') ...[const Divider(), GwKeyValue('Next run', w.status == 'active' ? formatDateTime(w.nextRunAt) : 'When active')],
                      const Divider(),
                      GwKeyValue('Last run', timeAgo(w.lastRunAt)),
                      if (w.webhookUrl != null) _WebhookPanel(workflow: w),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              GwCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  GwCardHeader(title: 'Recent health', description: recent.isEmpty ? null : 'Last ${recent.length} runs'),
                  IntrinsicHeight(
                    child: Row(children: [
                      for (final (i, (label, value, color)) in [
                        ('Succeeded', succeeded, Gw.success),
                        ('Failed', failed, failed > 0 ? Gw.danger : Gw.fg),
                        ('Other', recent.length - succeeded - failed, Gw.fg),
                      ].indexed) ...[
                        if (i > 0) const VerticalDivider(width: 1, color: Gw.lineSubtle),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('$value', style: TextStyle(fontFamily: Gw.fontSans, fontSize: 20, fontWeight: FontWeight.w600, color: color)),
                              Text(label, style: GwText.micro),
                            ]),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              GwCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  GwCardHeader(title: 'Execution history', action: GwLink('View all', onTap: () => context.go('/executions?workflow_id=${w.id}'))),
                  asyncBody(
                    runs,
                    onRetry: () => ref.invalidate(executionsProvider(_runsQuery)),
                    rows: 3,
                    (page) => page.items.isEmpty
                        ? const GwEmpty(icon: Icons.history, title: 'No runs yet', description: 'Press Run now to test this workflow.')
                        : ExecutionList(items: page.items, showWorkflow: false),
                  ),
                ]),
              ),
            ]);
          },
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, Workflow w) async {
    final data = const JsonEncoder.withIndent('  ').convert({'ghostwork': 1, 'name': w.name, 'description': w.description, 'definition': w.definition.toJson()});
    final slug = w.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    Uri? path;
    try {
      path = await FilePicker.saveFile(
        dialogTitle: 'Export workflow',
        fileName: '${slug.isEmpty ? 'workflow' : slug}.ghostwork.json',
        bytes: Uint8List.fromList(utf8.encode(data)),
        mimeType: 'application/json',
      );
    } catch (_) {
      path = null; // no save dialog on this platform: fall back to the clipboard
    }
    if (!context.mounted) return;
    if (path == null) {
      await Clipboard.setData(ClipboardData(text: data));
      if (context.mounted) toast(context, 'Workflow JSON copied to the clipboard', tone: AlertTone.info);
    } else {
      toast(context, 'Workflow exported');
    }
  }
}

class _WebhookPanel extends ConsumerWidget {
  const _WebhookPanel({required this.workflow});
  final Workflow workflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiClientProvider);
    final w = workflow;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Divider(),
      const SizedBox(height: 8),
      Text('Webhook URL', style: GwText.meta),
      const SizedBox(height: 6),
      GwCopyField(value: w.webhookUrl!, label: 'webhook URL'),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: GwLink('Regenerate URL', icon: Icons.refresh, style: GwText.meta, onTap: () async {
          final ok = await confirmAction(
            context,
            title: 'Regenerate webhook URL?',
            description: 'The current URL will stop working immediately. Update any service that calls it.',
            confirmLabel: 'Regenerate',
            danger: true,
            action: () async {
              try {
                await api.rotateWebhook(w.id);
                return null;
              } catch (e) {
                return describeError(e);
              }
            },
          );
          if (ok) {
            ref.invalidate(workflowProvider(w.id));
            if (context.mounted) toast(context, 'Webhook URL regenerated');
          }
        }),
      ),
      if (w.status != 'active') Padding(padding: const EdgeInsets.only(top: 4), child: Text('Activate the workflow to accept webhook calls.', style: GwText.meta.copyWith(color: Gw.warning))),
      const Divider(height: 24),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.key_outlined, size: 15, color: w.webhookSigningEnabled ? Gw.success : Gw.fgMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Signed requests ${w.webhookSigningEnabled ? 'required' : 'off'}', style: GwText.bodyMedium),
            Text(
              w.webhookSigningEnabled
                  ? 'Calls must include a valid X-GhostWork-Signature header.'
                  : 'Anyone with the URL can start a run. Require an HMAC signature for extra protection.',
              style: GwText.meta,
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              GwButton(
                label: w.webhookSigningEnabled ? 'Replace secret' : 'Require signature',
                size: GwSize.sm,
                onPressed: () async {
                  String? secret;
                  final ok = await confirmAction(
                    context,
                    title: w.webhookSigningEnabled ? 'Replace signing secret?' : 'Require signed webhooks?',
                    description: 'Callers without the new secret will be rejected immediately. The secret is shown once.',
                    confirmLabel: w.webhookSigningEnabled ? 'Replace secret' : 'Create secret',
                    action: () async {
                      try {
                        secret = await api.enableWebhookSigning(w.id);
                        return null;
                      } catch (e) {
                        return describeError(e);
                      }
                    },
                  );
                  ref.invalidate(workflowProvider(w.id));
                  if (ok && secret != null && context.mounted) {
                    await showGwDialog(
                      context,
                      title: 'Signing secret',
                      description: "Copy it now — it won't be shown again.",
                      body: (_) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        GwCopyField(value: secret!, label: 'signing secret'),
                        const SizedBox(height: 12),
                        Text('Send X-GhostWork-Signature: sha256=<hex>, where the hex value is the HMAC-SHA256 of the raw request body using this secret.', style: GwText.meta),
                      ]),
                      footer: (ctx) => [GwButton(label: 'Done', variant: GwVariant.primary, onPressed: () => Navigator.pop(ctx))],
                    );
                  }
                },
              ),
              if (w.webhookSigningEnabled)
                GwButton(
                  label: 'Turn off',
                  variant: GwVariant.ghost,
                  size: GwSize.sm,
                  onPressed: () async {
                    final ok = await confirmAction(
                      context,
                      title: 'Turn off signature checks?',
                      description: 'Anyone with the webhook URL will be able to start runs.',
                      confirmLabel: 'Turn off',
                      danger: true,
                      action: () async {
                        try {
                          await api.disableWebhookSigning(w.id);
                          return null;
                        } catch (e) {
                          return describeError(e);
                        }
                      },
                    );
                    if (ok) {
                      ref.invalidate(workflowProvider(w.id));
                      if (context.mounted) toast(context, 'Signature checks turned off');
                    }
                  },
                ),
            ]),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
    ]);
  }
}
