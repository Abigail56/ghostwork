// Port of frontend/src/components/execution/ExecutionTimeline.tsx.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../components/ui.dart';
import '../format.dart';
import 'node_meta.dart';

class JsonBlock extends StatelessWidget {
  const JsonBlock(this.value, {super.key, this.maxHeight = 288});
  final Object? value;
  final double maxHeight;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(color: Gw.canvas, borderRadius: BorderRadius.circular(Gw.rMd), border: Border.all(color: Gw.lineSubtle)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SelectableText(const JsonEncoder.withIndent('  ').convert(value), style: GwText.mono.copyWith(fontSize: 11.5, height: 1.6)),
        ),
      );
}

class ExecutionTimeline extends StatefulWidget {
  const ExecutionTimeline({super.key, required this.steps, this.totalMs});
  final List<ExecutionStep> steps;
  final int? totalMs;

  @override
  State<ExecutionTimeline> createState() => _ExecutionTimelineState();
}

class _ExecutionTimelineState extends State<ExecutionTimeline> {
  late final Set<String> _open = widget.steps.where((s) => s.status == 'failed').map((s) => s.id).toSet();

  @override
  Widget build(BuildContext context) {
    final longest = math.max(1, widget.steps.fold<int>(0, (m, s) => math.max(m, s.durationMs ?? 0)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (i, step) in widget.steps.indexed) _row(step, i == widget.steps.length - 1, longest),
      if (widget.totalMs != null)
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Gw.lineSubtle))),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('Total', style: GwText.meta),
            const SizedBox(width: 8),
            Text(formatDuration(widget.totalMs), style: GwText.meta.copyWith(color: Gw.fg)),
          ]),
        ),
    ]);
  }

  Widget _row(ExecutionStep step, bool last, int longest) {
    final s = GwStatus.of(step.status);
    final kind = kindStyle(kindOf(step.nodeType));
    final expandable = step.output != null || step.errorMessage != null;
    final expanded = _open.contains(step.id);
    return Stack(children: [
      if (!last) Positioned(left: 19, top: 32, bottom: 0, child: Container(width: 1, color: Gw.line)),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          borderRadius: BorderRadius.circular(Gw.rMd),
          onTap: expandable ? () => setState(() => expanded ? _open.remove(step.id) : _open.add(step.id)) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(color: Gw.surface, shape: BoxShape.circle),
                child: Icon(s.icon, size: 17, color: s.color, semanticLabel: s.label),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(step.nodeName, overflow: TextOverflow.ellipsis, style: GwText.bodyMedium.copyWith(color: step.status == 'skipped' ? Gw.fgMuted : Gw.fg)),
                  Text.rich(TextSpan(style: GwText.micro, children: [
                    TextSpan(text: kind.label, style: TextStyle(color: kind.color)),
                    TextSpan(text: ' · ${s.label}${step.attempts > 1 ? ' · ${step.attempts} attempts' : ''}'),
                  ])),
                ]),
              ),
              SizedBox(
                width: 72,
                child: step.durationMs == null
                    ? null
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: math.max(0.04, step.durationMs! / longest),
                          child: Container(height: 6, decoration: BoxDecoration(color: Gw.cyan.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(99))),
                        ),
                      ),
              ),
              SizedBox(width: 60, child: Text(formatDuration(step.durationMs), textAlign: TextAlign.right, style: GwText.meta)),
              const SizedBox(width: 4),
              SizedBox(
                width: 16,
                child: expandable ? AnimatedRotation(turns: expanded ? 0.25 : 0, duration: const Duration(milliseconds: 150), child: const Icon(Icons.chevron_right, size: 16, color: Gw.fgMuted)) : null,
              ),
            ]),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 0, 8, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (step.errorMessage != null) GwAlert(child: Text(step.errorMessage!)),
              if (step.errorMessage != null && step.output != null) const SizedBox(height: 8),
              if (step.output != null) JsonBlock(step.output),
            ]),
          ),
      ]),
    ]);
  }
}
