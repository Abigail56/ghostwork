// Port of frontend/src/components/builder/{NodeLibrary,ConfigPanel}.tsx.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../data/models.dart';
import '../../canvas/node_meta.dart';
import '../../components/ui.dart';

class NodeLibrary extends StatelessWidget {
  Widget _maybeDraggable(NodeType t, Widget child) => !draggable
      ? child
      : Draggable<NodeType>(
          data: t,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: Material(
            color: Gw.elevated,
            elevation: 8,
            borderRadius: BorderRadius.circular(Gw.rMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(nodeIcon(t.type), size: 14, color: kindStyle(t.kind).color),
                const SizedBox(width: 8),
                Text(t.label, style: GwText.bodyMedium),
              ]),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.5, child: child),
          child: child,
        );

  const NodeLibrary({super.key, required this.types, required this.hasTrigger, required this.connectedProviders, required this.onAdd, this.draggable = false});

  /// Steps can also be dragged onto the canvas (wide layouts, where the canvas is visible).
  final bool draggable;
  final List<NodeType>? types;
  final bool hasTrigger;
  final Set<String> connectedProviders;
  final ValueChanged<NodeType> onAdd;

  @override
  Widget build(BuildContext context) {
    if (types == null) return const GwLoading(rows: 5, label: 'Loading steps');
    return ListView(padding: const EdgeInsets.all(12), children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 16), child: Text(draggable ? 'Click to add, or drag onto the canvas.' : 'Tap to add a step. It connects to the selected step.', style: GwText.meta)),
      for (final (kind, title) in const [('trigger', 'TRIGGERS'), ('action', 'ACTIONS'), ('condition', 'LOGIC')]) ...[
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: GwText.eyebrow)),
        for (final t in types!.where((t) => t.kind == kind))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _maybeDraggable(t, Semantics(
              button: true,
              label: 'Add ${t.label}${kind == 'trigger' && hasTrigger ? ' (replaces the current trigger)' : ''}',
              child: Material(
                color: Gw.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gw.rLg), side: const BorderSide(color: Gw.lineSubtle)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Gw.rLg),
                  onTap: () => onAdd(t),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(color: kindStyle(kind).soft, borderRadius: BorderRadius.circular(6)),
                        child: Icon(nodeIcon(t.type), size: 14, color: kindStyle(kind).color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.label, style: GwText.bodyMedium),
                          Text(kind == 'trigger' && hasTrigger ? 'Replaces the current trigger' : t.description, style: GwText.micro),
                          if (t.integrationProvider != null && !connectedProviders.contains(t.integrationProvider))
                            Text('Needs a connected integration', style: GwText.micro.copyWith(color: Gw.warning)),
                        ]),
                      ),
                      const Icon(Icons.add, size: 14, color: Gw.fgMuted),
                    ]),
                  ),
                ),
              ),
            )),
          ),
        const SizedBox(height: 14),
      ],
    ]);
  }
}

/// Configuration for one step. Text fields keep their own controllers (keyed by node id).
class ConfigPanel extends StatefulWidget {
  const ConfigPanel({
    super.key,
    required this.node,
    required this.issues,
    required this.integrations,
    required this.references,
    required this.webhookUrl,
    required this.connections,
    required this.onChange,
    required this.onRename,
    required this.onDelete,
    required this.onRemoveConnection,
  });

  final NodeDef node;
  final List<ValidationIssue> issues;
  final List<Integration> integrations;
  final List<String> references;
  final String? webhookUrl;
  final List<(EdgeDef, String)> connections; // edge + description
  final ValueChanged<Map<String, dynamic>> onChange;
  final ValueChanged<String> onRename;
  final VoidCallback onDelete;
  final ValueChanged<EdgeDef> onRemoveConnection;

  @override
  State<ConfigPanel> createState() => _ConfigPanelState();
}

class _ConfigPanelState extends State<ConfigPanel> {
  Map<String, dynamic> get c => widget.node.config;
  void _set(Map<String, dynamic> patch) => widget.onChange({...c, ...patch});

  String? _issue(String field) => widget.issues.where((i) => i.field == field || (i.field?.startsWith('$field.') ?? false)).firstOrNull?.message;

  Widget _text(String field, String label, {String? hint, bool mono = false, int lines = 1, String? help, bool optional = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GwField(
          label: label,
          optional: optional,
          error: _issue(field),
          hint: help == null ? null : Text(help),
          child: GwInput(
            key: ValueKey('${widget.node.id}-$field'),
            initialValue: '${c[field] ?? ''}',
            hint: hint,
            mono: mono,
            maxLines: lines,
            minLines: lines > 1 ? lines : null,
            error: _issue(field) != null,
            semanticLabel: label,
            onChanged: (v) => _set({field: v}),
          ),
        ),
      );

  Widget _integrationSelect(String field, String label, String provider) {
    final options = widget.integrations.where((i) => i.provider == provider).toList();
    final value = c[field] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GwField(
        label: label,
        error: _issue(field),
        hint: options.isEmpty
            ? Row(children: [const Text('None connected yet. '), GwLink('Connect one', style: GwText.meta.copyWith(color: Gw.violet), onTap: () => context.go('/integrations'))])
            : null,
        child: GwSelect<String>(
          key: ValueKey('${widget.node.id}-$field-${options.length}'),
          value: options.any((o) => o.id == value) ? value! : '',
          semanticLabel: label,
          items: [('', provider == 'http_auth' ? 'None' : 'Choose…'), for (final o in options) (o.id, o.name)],
          onChanged: (v) => _set({field: v.isEmpty ? null : v}),
        ),
      ),
    );
  }

  Widget _pairs(String field, String keyName, String valueKey, String keyLabel, String valueLabel, String keyHint, String valueHint, String addLabel, int max) {
    final items = ((c[field] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    void update(List<Map<String, dynamic>> next) => _set({field: next});
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, item) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(
                width: 110,
                child: GwInput(
                  key: ValueKey('${widget.node.id}-$field-$i-k-${items.length}'),
                  initialValue: '${item[keyName] ?? ''}',
                  hint: keyHint,
                  mono: true,
                  semanticLabel: '$keyLabel ${i + 1}',
                  onChanged: (v) => update([for (final (j, it) in items.indexed) j == i ? {...it, keyName: v} : it]),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GwInput(
                  key: ValueKey('${widget.node.id}-$field-$i-v-${items.length}'),
                  initialValue: '${item[valueKey] ?? ''}',
                  hint: valueHint,
                  mono: true,
                  semanticLabel: '$valueLabel ${i + 1}',
                  onChanged: (v) => update([for (final (j, it) in items.indexed) j == i ? {...it, valueKey: v} : it]),
                ),
              ),
              GwIconButton(icon: Icons.close, tooltip: 'Remove ${keyLabel.toLowerCase()} ${i + 1}', size: 32, onPressed: () => update([...items]..removeAt(i))),
            ]),
          ),
        if (items.length < max) GwButton(label: addLabel, icon: Icons.add, variant: GwVariant.ghost, size: GwSize.sm, onPressed: () => update([...items, {keyName: '', valueKey: ''}])),
        if (_issue(field) != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_issue(field)!, style: GwText.meta.copyWith(color: Gw.danger))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final kind = kindOf(n.type);
    final style = kindStyle(kind);
    final general = widget.issues.where((i) => i.field == null).toList();
    return ListView(padding: EdgeInsets.zero, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Gw.lineSubtle))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(color: style.soft, borderRadius: BorderRadius.circular(6)), child: Icon(nodeIcon(n.type), size: 14, color: style.color)),
            const SizedBox(width: 8),
            Text(style.label.toUpperCase(), style: GwText.eyebrow.copyWith(color: style.color)),
            const Spacer(),
            GwIconButton(icon: Icons.delete_outline, tooltip: 'Delete step', size: 32, onPressed: widget.onDelete),
          ]),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GwField(
              label: 'Step name',
              child: GwInput(key: ValueKey('${n.id}-name'), initialValue: n.name, semanticLabel: 'Step name', onChanged: widget.onRename),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [Text('Reference as ', style: GwText.micro), Flexible(child: GwCopyChip('{{ steps.${n.id} }}'))]),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final i in general) Padding(padding: const EdgeInsets.only(bottom: 12), child: GwAlert(tone: AlertTone.warning, child: Text(i.message))),
          ..._fields(n),
          if (widget.connections.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Connections', style: GwText.meta.copyWith(color: Gw.fgSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            for (final (edge, label) in widget.connections)
              Row(children: [
                Expanded(child: Text(label, style: GwText.meta)),
                GwIconButton(icon: Icons.link_off, tooltip: 'Remove connection', size: 32, onPressed: () => widget.onRemoveConnection(edge)),
              ]),
          ],
          if (kind != 'trigger') ...[
            const Divider(height: 24),
            Text('Available references', style: GwText.meta.copyWith(color: Gw.fgSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final r in widget.references) GwCopyChip(r)]),
            const SizedBox(height: 8),
            Text('Add a path after a reference, e.g. .body.id.', style: GwText.micro),
          ],
        ]),
      ),
    ]);
  }

  List<Widget> _fields(NodeDef n) {
    switch (n.type) {
      case 'trigger.manual':
        return [Text('This workflow runs when you press Test run or Run now. You can pass test data with each run.', style: GwText.body.copyWith(color: Gw.fgMuted))];
      case 'trigger.schedule':
        return [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: GwField(
                label: 'Every',
                error: _issue('every'),
                child: GwInput(
                  key: ValueKey('${n.id}-every'),
                  initialValue: '${c['every'] ?? 1}',
                  keyboardType: TextInputType.number,
                  semanticLabel: 'Every',
                  onChanged: (v) => _set({'every': (int.tryParse(v) ?? 1).clamp(1, 10000)}),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: GwField(
                label: 'Unit',
                child: GwSelect<String>(
                  value: '${c['unit'] ?? 'hours'}',
                  semanticLabel: 'Unit',
                  items: const [('minutes', 'Minutes'), ('hours', 'Hours'), ('days', 'Days')],
                  onChanged: (v) => _set({'unit': v}),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text('Runs while the workflow is active. The shortest interval is 5 minutes.', style: GwText.meta),
        ];
      case 'trigger.webhook':
        return [
          if (widget.webhookUrl != null) ...[
            Text('POST to this URL to start a run. The body is available as trigger.payload.body.', style: GwText.body.copyWith(color: Gw.fgMuted)),
            const SizedBox(height: 8),
            GwCopyField(value: widget.webhookUrl!, label: 'webhook URL'),
          ] else
            Text('Save the workflow to generate its webhook URL.', style: GwText.body.copyWith(color: Gw.fgMuted)),
        ];
      case 'action.http_request':
        return [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 104,
              child: GwField(
                label: 'Method',
                child: GwSelect<String>(
                  value: '${c['method'] ?? 'GET'}',
                  semanticLabel: 'Method',
                  items: const [('GET', 'GET'), ('POST', 'POST'), ('PUT', 'PUT'), ('PATCH', 'PATCH'), ('DELETE', 'DELETE')],
                  onChanged: (v) => _set({'method': v}),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _text('url', 'URL', hint: 'https://api.example.com/items', mono: true)),
          ]),
          _integrationSelect('credential_integration_id', 'Credential', 'http_auth'),
          Text('Headers', style: GwText.meta.copyWith(color: Gw.fgSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          _pairs('headers', 'key', 'value', 'Header name', 'Header value', 'Accept', 'application/json', 'Add header', 20),
          if (c['method'] != 'GET' && c['method'] != null)
            _text('body', 'Body', hint: '{"id": "{{ trigger.payload.id }}"}', mono: true, lines: 5, optional: true, help: 'JSON bodies get a JSON content type automatically.'),
          Row(children: [
            Expanded(
              child: GwField(
                label: 'Timeout (s)',
                error: _issue('timeout_seconds'),
                child: GwInput(
                  key: ValueKey('${n.id}-timeout'),
                  initialValue: '${c['timeout_seconds'] ?? 15}',
                  keyboardType: TextInputType.number,
                  semanticLabel: 'Timeout (s)',
                  onChanged: (v) => _set({'timeout_seconds': (int.tryParse(v) ?? 15).clamp(1, 30)}),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GwField(
                label: 'Retries',
                error: _issue('retries'),
                child: GwInput(
                  key: ValueKey('${n.id}-retries'),
                  initialValue: '${c['retries'] ?? 0}',
                  keyboardType: TextInputType.number,
                  semanticLabel: 'Retries',
                  onChanged: (v) => _set({'retries': (int.tryParse(v) ?? 0).clamp(0, 3)}),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          GwSwitch(
            label: 'Fail on error status',
            description: 'Treat HTTP 400 and above as a failed step.',
            value: c['fail_on_error_status'] != false,
            onChanged: (v) => _set({'fail_on_error_status': v}),
          ),
        ];
      case 'action.transform':
        return [
          Text('Fields to build', style: GwText.meta.copyWith(color: Gw.fgSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          _pairs('fields', 'key', 'value', 'Field name', 'Field value', 'name', '{{ steps.fetch.body.name }}', 'Add field', 30),
        ];
      case 'action.email':
        return [
          _integrationSelect('integration_id', 'Send with', 'smtp'),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GwField(
              label: 'To',
              error: _issue('to'),
              hint: const Text('Separate addresses with commas.'),
              child: GwInput(
                key: ValueKey('${n.id}-to'),
                initialValue: ((c['to'] as List?) ?? const []).join(', '),
                hint: 'ops@example.com, {{ trigger.payload.email }}',
                semanticLabel: 'To',
                onChanged: (v) => _set({'to': v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(10).toList()}),
              ),
            ),
          ),
          _text('subject', 'Subject'),
          _text('body', 'Body', lines: 6),
        ];
      case 'action.slack':
        return [_integrationSelect('integration_id', 'Slack connection', 'slack'), _text('text', 'Message', lines: 5)];
      case 'condition.if':
        final unary = c['operator'] == 'is_empty' || c['operator'] == 'is_not_empty';
        return [
          _text('left', 'Value', hint: '{{ steps.fetch.status_code }}', mono: true),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GwField(
              label: 'Operator',
              child: GwSelect<String>(
                value: '${c['operator'] ?? 'equals'}',
                semanticLabel: 'Operator',
                items: const [
                  ('equals', 'equals'),
                  ('not_equals', 'does not equal'),
                  ('contains', 'contains'),
                  ('not_contains', 'does not contain'),
                  ('greater_than', 'is greater than'),
                  ('less_than', 'is less than'),
                  ('is_empty', 'is empty'),
                  ('is_not_empty', 'is not empty'),
                ],
                onChanged: (v) => _set({'operator': v}),
              ),
            ),
          ),
          if (!unary) _text('right', 'Compare to', mono: true),
          Text.rich(TextSpan(style: GwText.meta, children: const [
            TextSpan(text: 'Connect the '),
            TextSpan(text: 'True', style: TextStyle(color: Gw.success)),
            TextSpan(text: ' and False outputs to continue each branch.'),
          ])),
        ];
      default:
        return const [];
    }
  }
}
