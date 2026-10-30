import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../state/providers.dart';
import '../format.dart';
import '../widgets/common.dart';

class WorkflowsScreen extends ConsumerStatefulWidget {
  const WorkflowsScreen({super.key});

  @override
  ConsumerState<WorkflowsScreen> createState() => _WorkflowsScreenState();
}

class _WorkflowsScreenState extends ConsumerState<WorkflowsScreen> {
  String _q = '';
  String? _status;

  @override
  Widget build(BuildContext context) {
    final query = (q: _q, status: _status);
    final workflows = ref.watch(workflowsProvider(query));
    return Scaffold(
      appBar: AppBar(title: const Text('Workflows')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 20), hintText: 'Search workflows', isDense: true),
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => setState(() => _q = v.trim()),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final (value, label) in [(null, 'All'), ('active', 'Active'), ('paused', 'Paused'), ('draft', 'Draft')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(label), selected: _status == value, onSelected: (_) => setState(() => _status = value)),
              ),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(workflowsProvider(query).future),
            child: AsyncView(
              value: workflows,
              errorTitle: "Couldn't load workflows",
              onRetry: () => ref.invalidate(workflowsProvider(query)),
              builder: (page) => page.items.isEmpty
                  ? ListView(children: [
                      MessageView(
                        icon: Icons.account_tree_outlined,
                        title: _q.isEmpty && _status == null ? 'No workflows yet' : 'No matching workflows',
                        message: _q.isEmpty && _status == null ? 'Create workflows in the GhostWork web app.' : 'Try another search or filter.',
                      ),
                    ])
                  : ListView.separated(
                      itemCount: page.items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final w = page.items[i];
                        return ListTile(
                          onTap: () => context.push('/workflows/${w.id}'),
                          title: Text(w.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(children: [
                              StatusBadge(w.status),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('${triggerLabel(w.triggerType)} · ran ${timeAgo(w.lastRunAt)}',
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                              ),
                            ]),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Gw.fgMuted),
                        );
                      },
                    ),
            ),
          ),
        ),
      ]),
    );
  }
}

class WorkflowDetailScreen extends ConsumerStatefulWidget {
  const WorkflowDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<WorkflowDetailScreen> createState() => _WorkflowDetailScreenState();
}

class _WorkflowDetailScreenState extends ConsumerState<WorkflowDetailScreen> {
  bool _busy = false;

  Future<void> _act(Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
      ref.invalidate(workflowProvider(widget.id));
      ref.invalidate(dashboardProvider);
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Gw.surface,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final workflow = ref.watch(workflowProvider(widget.id));
    final runs = ref.watch(executionsProvider((status: null, workflowId: widget.id)));
    final api = ref.read(apiClientProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Workflow')),
      body: AsyncView(
        value: workflow,
        errorTitle: "Couldn't load this workflow",
        onRetry: () => ref.invalidate(workflowProvider(widget.id)),
        builder: (w) => RefreshIndicator(
          onRefresh: () {
            ref.invalidate(executionsProvider((status: null, workflowId: widget.id)));
            return ref.refresh(workflowProvider(widget.id).future);
          },
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text(w.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Row(children: [StatusBadge(w.status), const SizedBox(width: 8), Text(triggerLabel(w.triggerType), style: const TextStyle(color: Gw.fgSecondary))]),
            if (w.description.isNotEmpty) ...[const SizedBox(height: 10), Text(w.description, style: const TextStyle(color: Gw.fgMuted))],
            const SizedBox(height: 16),
            if (!w.isValid)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Gw.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Gw.warning.withValues(alpha: 0.3)),
                ),
                child: Text('Fix in the web builder before running:\n• ${w.validation.join('\n• ')}',
                    style: const TextStyle(color: Color(0xFFFFD99A), fontSize: 13)),
              ),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || !w.isValid
                      ? null
                      : () => _act(() async {
                            final run = await api.runWorkflow(w.id);
                            if (context.mounted) context.push('/runs/${run.id}');
                          }, 'Run queued'),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Run now'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || (w.status != 'active' && !w.isValid)
                      ? null
                      : () async {
                          if (w.status == 'active') {
                            await _act(() => api.setWorkflowStatus(w.id, 'paused'), 'Workflow paused');
                          } else if (await _confirm('Activate workflow?',
                              'Its schedule or webhook will start runs automatically until you pause it.', 'Activate')) {
                            await _act(() => api.setWorkflowStatus(w.id, 'active'), 'Workflow activated');
                          }
                        },
                  icon: Icon(w.status == 'active' ? Icons.pause_rounded : Icons.check_rounded),
                  label: Text(w.status == 'active' ? 'Pause' : 'Activate'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Steps',
              child: Column(children: [
                for (final (i, name) in w.stepNames.indexed)
                  ListTile(dense: true, leading: CircleAvatar(radius: 12, backgroundColor: Gw.elevated, child: Text('${i + 1}', style: const TextStyle(fontSize: 11))), title: Text(name)),
              ]),
            ),
            const SizedBox(height: 16),
            if (w.triggerType == 'trigger.schedule')
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_repeat, color: Gw.fgMuted),
                title: const Text('Next scheduled run'),
                subtitle: Text(w.status == 'active' ? timeAgo(w.nextRunAt) : 'When active'),
              ),
            SectionCard(
              title: 'Recent runs',
              child: AsyncView(
                value: runs,
                onRetry: () => ref.invalidate(executionsProvider((status: null, workflowId: widget.id))),
                builder: (page) => page.items.isEmpty
                    ? const MessageView(icon: Icons.history, title: 'No runs yet')
                    : Column(children: [
                        for (final e in page.items.take(10))
                          ExecutionTile(execution: e, showWorkflow: false, onTap: () => context.push('/runs/${e.id}')),
                      ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
