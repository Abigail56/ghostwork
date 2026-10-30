import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../state/providers.dart';
import '../format.dart';
import '../widgets/common.dart';

class ExecutionsScreen extends ConsumerStatefulWidget {
  const ExecutionsScreen({super.key});

  @override
  ConsumerState<ExecutionsScreen> createState() => _ExecutionsScreenState();
}

class _ExecutionsScreenState extends ConsumerState<ExecutionsScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final query = (status: _status, workflowId: null);
    final runs = ref.watch(executionsProvider(query));
    return Scaffold(
      appBar: AppBar(title: const Text('Runs')),
      body: Column(children: [
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final (value, label) in [(null, 'All'), ('failed', 'Failed'), ('succeeded', 'Succeeded'), ('running', 'Running'), ('queued', 'Queued')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(label), selected: _status == value, onSelected: (_) => setState(() => _status = value)),
              ),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(executionsProvider(query).future),
            child: AsyncView(
              value: runs,
              errorTitle: "Couldn't load runs",
              onRetry: () => ref.invalidate(executionsProvider(query)),
              builder: (page) => page.items.isEmpty
                  ? ListView(children: const [MessageView(icon: Icons.history, title: 'No runs to show')])
                  : ListView.separated(
                      itemCount: page.items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) =>
                          ExecutionTile(execution: page.items[i], onTap: () => context.push('/runs/${page.items[i].id}')),
                    ),
            ),
          ),
        ),
      ]),
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
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Poll once a second while the run is queued or running; stop when it finishes.
  void _schedulePoll(bool active) {
    if (active && (_poll == null || !_poll!.isActive)) {
      _poll = Timer.periodic(const Duration(seconds: 1), (_) => ref.invalidate(executionProvider(widget.id)));
    } else if (!active) {
      _poll?.cancel();
    }
  }

  Future<void> _action(String action) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      final result = await ref.read(apiClientProvider).executionAction(widget.id, action);
      ref.invalidate(executionProvider(widget.id));
      ref.invalidate(dashboardProvider);
      if (action == 'rerun') {
        router.pushReplacement('/runs/${result.id}');
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Run cancelled')));
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final execution = ref.watch(executionProvider(widget.id));
    ref.listen(executionProvider(widget.id), (_, next) => _schedulePoll(next.value?.isActive ?? false));
    return Scaffold(
      appBar: AppBar(title: Text('Run ${shortId(widget.id)}')),
      body: AsyncView(
        value: execution,
        errorTitle: "Couldn't load this run",
        onRetry: () => ref.invalidate(executionProvider(widget.id)),
        builder: (e) {
          _schedulePoll(e.isActive);
          final failed = e.steps.where((s) => s.status == 'failed').firstOrNull;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              StatusBadge(e.status),
              const SizedBox(width: 8),
              Expanded(child: Text(e.workflowName, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Text('${triggerLabel(e.triggerType)} · ${timeAgo(e.createdAt)} · ${formatDuration(e.durationMs)}',
                style: Theme.of(context).textTheme.bodySmall),
            if (e.status == 'failed' && e.errorMessage != null)
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Gw.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Gw.danger.withValues(alpha: 0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(failed != null ? '“${failed.nodeName}” failed' : 'This run failed',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFFFB3B8))),
                  const SizedBox(height: 4),
                  Text(e.errorMessage!, style: const TextStyle(color: Color(0xFFFFB3B8), fontSize: 13)),
                ]),
              ),
            const SizedBox(height: 14),
            Row(children: [
              if (e.isActive)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _action('cancel'),
                    icon: const Icon(Icons.block),
                    label: const Text('Cancel run'),
                  ),
                )
              else
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _action('rerun'),
                    icon: const Icon(Icons.replay),
                    label: const Text('Run again'),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            SectionCard(
              title: e.isActive ? 'Steps · updating live' : 'Steps',
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: StepTimeline(steps: e.steps)),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Trigger data',
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(e.triggerPayload),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Gw.fgSecondary),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
