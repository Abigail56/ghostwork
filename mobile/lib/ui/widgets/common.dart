import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../format.dart';

class StatusStyle {
  const StatusStyle(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;

  static StatusStyle of(String status) => switch (status) {
        'succeeded' => const StatusStyle('Succeeded', Gw.success, Icons.check_circle_outline),
        'failed' => const StatusStyle('Failed', Gw.danger, Icons.highlight_off),
        'running' => const StatusStyle('Running', Gw.cyan, Icons.autorenew),
        'queued' => const StatusStyle('Queued', Gw.queued, Icons.schedule),
        'cancelled' => const StatusStyle('Cancelled', Gw.fgSecondary, Icons.block),
        'skipped' => const StatusStyle('Skipped', Gw.fgMuted, Icons.skip_next_outlined),
        'pending' => const StatusStyle('Pending', Gw.fgMuted, Icons.radio_button_unchecked),
        'active' => const StatusStyle('Active', Gw.success, Icons.radio_button_checked),
        'paused' => const StatusStyle('Paused', Gw.warning, Icons.pause_circle_outline),
        'draft' => const StatusStyle('Draft', Gw.fgSecondary, Icons.edit_note),
        _ => StatusStyle(status, Gw.fgSecondary, Icons.info_outline),
      };
}

/// Status is never conveyed by color alone: icon + label + color.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(style.icon, size: 12, color: style.color),
        const SizedBox(width: 4),
        Text(style.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: style.color)),
      ]),
    );
  }
}

/// Loading / error-with-retry / data, for any FutureProvider.
class AsyncView<T> extends ConsumerWidget {
  const AsyncView({super.key, required this.value, required this.builder, required this.onRetry, this.errorTitle = "Couldn't load this"});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final String errorTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) => value.when(
        skipLoadingOnRefresh: true,
        data: builder,
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(strokeWidth: 2.5))),
        error: (error, _) => MessageView(
          icon: Icons.error_outline,
          iconColor: Gw.danger,
          title: errorTitle,
          message: error.toString(),
          action: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 18), label: const Text('Try again')),
        ),
      );
}

class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.icon, required this.title, this.message, this.action, this.iconColor = Gw.fgSecondary});
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Gw.elevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: Gw.line)),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      );
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
            child: Row(children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              ?trailing,
            ]),
          ),
          const Divider(height: 1),
          child,
        ]),
      );
}

class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: Gw.fg)),
            const SizedBox(height: 4),
            Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}

class ExecutionTile extends StatelessWidget {
  const ExecutionTile({super.key, required this.execution, required this.onTap, this.showWorkflow = true});
  final ExecutionSummary execution;
  final VoidCallback onTap;
  final bool showWorkflow;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        title: Row(children: [
          StatusBadge(execution.status),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              showWorkflow ? execution.workflowName : 'Run ${shortId(execution.id)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${triggerLabel(execution.triggerType)} · ${timeAgo(execution.createdAt)} · ${formatDuration(execution.durationMs)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Gw.fgMuted),
      );
}

class StepTimeline extends StatelessWidget {
  const StepTimeline({super.key, required this.steps});
  final List<ExecutionStep> steps;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (index, step) in steps.indexed)
          _StepRow(step: step, last: index == steps.length - 1),
      ]);
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.last});
  final ExecutionStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(step.status);
    final details = step.errorMessage ?? (step.output == null ? null : _preview(step.output!));
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 40,
          child: Column(children: [
            const SizedBox(height: 14),
            Icon(style.icon, size: 18, color: style.color, semanticLabel: style.label),
            if (!last) Expanded(child: Container(width: 1, color: Gw.line)),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(step.nodeName,
                      style: TextStyle(fontWeight: FontWeight.w500, color: step.status == 'skipped' ? Gw.fgMuted : Gw.fg)),
                ),
                Text(formatDuration(step.durationMs), style: Theme.of(context).textTheme.bodySmall),
              ]),
              const SizedBox(height: 2),
              Text(
                '${style.label}${step.attempts > 1 ? ' · ${step.attempts} attempts' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (details != null) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: step.errorMessage != null ? Gw.danger.withValues(alpha: 0.1) : Gw.canvas,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: step.errorMessage != null ? Gw.danger.withValues(alpha: 0.3) : Gw.lineSubtle),
                  ),
                  child: Text(details,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'monospace', fontSize: 11.5, color: step.errorMessage != null ? const Color(0xFFFFB3B8) : Gw.fgSecondary)),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  static String _preview(Map<String, dynamic> output) {
    final text = output.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    return text.length > 400 ? '${text.substring(0, 400)}…' : text;
  }
}
