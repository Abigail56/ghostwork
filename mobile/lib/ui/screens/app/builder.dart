// Port of frontend/src/components/builder/Builder.tsx.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../data/api_client.dart';
import '../../../data/models.dart';
import '../../../state/providers.dart';
import '../../canvas/flow_canvas.dart';
import '../../canvas/timeline.dart';
import '../../components/ui.dart';
import '../../format.dart';
import 'builder_config.dart';
import 'workflows.dart' show describeError, refreshWorkflowData;

const _slugs = {
  'trigger.manual': 'trigger',
  'trigger.schedule': 'trigger',
  'trigger.webhook': 'trigger',
  'action.http_request': 'http',
  'action.transform': 'transform',
  'action.email': 'email',
  'action.slack': 'slack',
  'action.github_issue': 'github',
  'action.sheets_append': 'sheet',
  'action.sheets_read': 'sheet',
  'condition.if': 'condition',
};

String nextNodeId(String type, Iterable<NodeDef> existing) {
  final slug = _slugs[type] ?? 'step';
  final taken = existing.map((n) => n.id).toSet();
  for (var i = 1; ; i++) {
    if (!taken.contains('${slug}_$i')) return '${slug}_$i';
  }
}

/// Key-order-independent JSON for dirty detection (PostgreSQL JSONB reorders keys).
String canonicalJson(Object? value) {
  Object? canon(Object? v) => switch (v) {
    Map m => {
      for (final k in (m.keys.map((k) => '$k').toList()..sort()))
        k: canon(m[k]),
    },
    List l => l.map(canon).toList(),
    double d when d == d.roundToDouble() => d.toInt(),
    _ => v,
  };
  return jsonEncode(canon(value));
}

/// Validates a new connection the same way as the web builder.
bool canConnect(Definition d, String source, String handle, String target) {
  if (source == target) return false;
  final t = d.nodes.where((n) => n.id == target).firstOrNull;
  if (t == null || t.kind == 'trigger') return false;
  return !d.edges.any(
    (e) => e.source == source && e.target == target && e.handle == handle,
  );
}

class BuilderLoader extends ConsumerWidget {
  const BuilderLoader({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(workflowProvider(id))
      .when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const GwLoading(rows: 4, label: 'Loading builder'),
        error: (e, _) => Center(
          child: GwError(
            title: "Couldn't open the builder",
            error: e,
            onRetry: () => ref.invalidate(workflowProvider(id)),
          ),
        ),
        // Keyed by id so switching workflows resets editor state; later refetches don't overwrite local edits.
        data: (w) => BuilderScreen(key: ValueKey(w.id), workflow: w),
      );
}

class BuilderScreen extends ConsumerStatefulWidget {
  const BuilderScreen({super.key, required this.workflow});
  final Workflow workflow;

  @override
  ConsumerState<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends ConsumerState<BuilderScreen> {
  late Workflow _saved = widget.workflow;
  late Definition _def = Definition.fromJson(
    widget.workflow.definition.toJson(),
  );
  String? _selected;
  final _canvas = FlowCanvasController();

  /// Bumped on every edit so the phone configuration sheet (a separate route) rebuilds.
  final _rev = ValueNotifier<int>(0);

  // Undo / redo
  late List<String> _history = [jsonEncode(_def.toJson())];
  int _cursor = 0;
  Timer? _historyTimer;

  bool _saving = false;
  bool _statusBusy = false;
  String? _executionId;
  Execution? _execution;
  Timer? _poll;
  bool _runCollapsed = false;

  List<Integration> get _integrations =>
      ref.read(integrationsProvider).value ?? const [];

  @override
  void initState() {
    super.initState();
    // Start loading what the panels need before they open.
    ref.read(nodeTypesProvider);
    ref.read(integrationsProvider);
  }

  bool get _dirty =>
      canonicalJson(_def.toJson()) != canonicalJson(_saved.definition.toJson());
  List<ValidationIssue> get _issues => _saved.validation;
  NodeDef? get _selectedNode =>
      _def.nodes.where((n) => n.id == _selected).firstOrNull;

  @override
  void dispose() {
    _historyTimer?.cancel();
    _poll?.cancel();
    _canvas.dispose();
    _rev.dispose();
    super.dispose();
  }

  /* ---------------- Editing ---------------- */

  void _change(Definition next, {bool immediateHistory = false}) {
    // Typing is grouped into one undo step; structural edits are always their own step.
    if (immediateHistory && _hasPendingEdit) {
      _history = [
        ..._history.sublist(0, _cursor + 1),
        jsonEncode(_def.toJson()),
      ];
      _cursor = _history.length - 1;
    }
    setState(() => _def = next);
    _rev.value++;
    _historyTimer?.cancel();
    void push() {
      final json = jsonEncode(_def.toJson());
      if (_history[_cursor] == json) return;
      setState(() {
        _history = [..._history.sublist(0, _cursor + 1), json];
        if (_history.length > 100) {
          _history = _history.sublist(_history.length - 100);
        }
        _cursor = _history.length - 1;
      });
    }

    immediateHistory
        ? push()
        : _historyTimer = Timer(const Duration(milliseconds: 400), push);
  }

  // An edit may not be in the history yet (debounced), so it counts as undoable too.
  bool get _hasPendingEdit => _history[_cursor] != jsonEncode(_def.toJson());
  bool get _canUndo => _cursor > 0 || _hasPendingEdit;

  void _undo() {
    _historyTimer?.cancel();
    if (_hasPendingEdit) {
      // Record the pending edit first, so undo steps back exactly one change.
      _history = [
        ..._history.sublist(0, _cursor + 1),
        jsonEncode(_def.toJson()),
      ];
      _cursor = _history.length - 1;
    }
    if (_cursor > 0) _restore(_cursor - 1);
  }

  void _restore(int cursor) {
    setState(() {
      _cursor = cursor;
      _def = Definition.fromJson(
        jsonDecode(_history[cursor]) as Map<String, dynamic>,
      );
      _selected = null;
    });
    _rev.value++;
  }

  void _updateNode(String id, NodeDef Function(NodeDef) f) => _change(
    Definition(
      nodes: [for (final n in _def.nodes) n.id == id ? f(n) : n],
      edges: _def.edges,
    ),
  );

  void _addNode(NodeType type, {Offset? at}) {
    final trigger = _def.nodes.where((n) => n.kind == 'trigger').firstOrNull;
    if (type.kind == 'trigger' && trigger != null) {
      // One trigger per workflow: swap its type in place and keep its connections.
      _updateNode(
        trigger.id,
        (n) => n.copyWith(
          type: type.type,
          name: type.label,
          config: Map.of(type.defaultConfig),
        ),
      );
      setState(() => _selected = trigger.id);
      toast(context, 'Trigger changed to ${type.label}', tone: AlertTone.info);
      return;
    }
    final id = nextNodeId(type.type, _def.nodes);
    final anchor =
        _selectedNode ??
        (_def.nodes.isEmpty
            ? null
            : (List.of(_def.nodes)..sort((a, b) => b.y.compareTo(a.y))).first);
    final node = NodeDef(
      id: id,
      type: type.type,
      name: type.label,
      x: at?.dx ?? anchor?.x ?? 0,
      y: at?.dy ?? (anchor == null ? 0 : anchor.y + 170),
      config: Map.of(type.defaultConfig),
    );
    final edges = [..._def.edges];
    // Adding continues the flow from the selected (or last) step.
    if (at == null &&
        anchor != null &&
        type.kind != 'trigger' &&
        anchor.kind != 'condition') {
      edges.add(
        EdgeDef(id: 'e_${anchor.id}_out_$id', source: anchor.id, target: id),
      );
    }
    _change(
      Definition(nodes: [..._def.nodes, node], edges: edges),
      immediateHistory: true,
    );
    setState(() => _selected = id);
    WidgetsBinding.instance.addPostFrameCallback((_) => _canvas.fit());
  }

  void _connect(String source, String handle, String target) {
    if (!canConnect(_def, source, handle, target)) return;
    _change(
      Definition(
        nodes: _def.nodes,
        edges: [
          ..._def.edges,
          EdgeDef(
            id: 'e_${source}_${handle}_$target',
            source: source,
            target: target,
            handle: handle,
          ),
        ],
      ),
      immediateHistory: true,
    );
  }

  void _deleteSelected() {
    final id = _selected;
    if (id == null) return;
    _change(
      Definition(
        nodes: _def.nodes.where((n) => n.id != id).toList(),
        edges: _def.edges
            .where((e) => e.source != id && e.target != id)
            .toList(),
      ),
      immediateHistory: true,
    );
    setState(() => _selected = null);
  }

  List<String> _references(String id) {
    final parents = <String, List<String>>{};
    for (final e in _def.edges) {
      parents.putIfAbsent(e.target, () => []).add(e.source);
    }
    final seen = <String>{};
    final stack = [...?parents[id]];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      if (seen.add(p)) stack.addAll(parents[p] ?? const []);
    }
    final ancestors = _def.nodes
        .where((n) => seen.contains(n.id) && n.kind != 'trigger')
        .map((n) => '{{ steps.${n.id} }}');
    return [
      '{{ trigger.payload }}',
      ...ancestors,
      '{{ execution.id }}',
      '{{ workflow.name }}',
    ];
  }

  /* ---------------- Save, run, activate ---------------- */

  Future<Workflow?> _save({bool announce = false}) async {
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(apiClientProvider)
          .updateWorkflow(
            _saved.id,
            definition: _def,
            expectedVersion: _saved.version,
          );
      setState(() {
        _saved = result;
        _def = Definition.fromJson(result.definition.toJson());
        _history = [jsonEncode(_def.toJson())];
        _cursor = 0;
      });
      refreshWorkflowData(ref, result.id);
      if (announce && mounted) {
        toast(
          context,
          'Workflow saved',
          description: result.validation.isEmpty
              ? 'Ready to run.'
              : '${result.validation.length} issue(s) to fix before it can run.',
        );
      }
      return result;
    } on ApiException catch (e) {
      if (mounted) {
        toast(
          context,
          e.status == 409 ? 'Saved elsewhere' : "Couldn't save",
          description: e.issues.isNotEmpty
              ? e.issues.take(2).join(' ')
              : e.message,
          tone: AlertTone.danger,
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _watchExecution(String id) {
    _poll?.cancel();
    setState(
      () => (_executionId = id, _execution = null, _runCollapsed = false),
    );
    Future<void> tick() async {
      try {
        final e = await ref.read(apiClientProvider).execution(id);
        if (!mounted || _executionId != id) return;
        setState(() => _execution = e);
        if (!e.isActive) _poll?.cancel();
      } catch (_) {}
    }

    tick();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _openRunDialog() async {
    final payload = TextEditingController(text: '{}');
    String? error;
    var busy = false;
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xB8050609),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Gw.lineSubtle)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Test run', style: GwText.section),
                          const SizedBox(height: 4),
                          Text(
                            _dirty
                                ? 'Your changes will be saved first. The run uses the saved version.'
                                : 'Run the saved workflow now and watch each step.',
                            style: GwText.body.copyWith(color: Gw.fgMuted),
                          ),
                        ],
                      ),
                    ),
                    GwIconButton(
                      icon: Icons.close,
                      tooltip: 'Close',
                      size: 32,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: GwField(
                  label: 'Test data (JSON)',
                  optional: true,
                  error: error,
                  hint: const Text(
                    'Available to steps as {{ trigger.payload }}.',
                  ),
                  child: GwInput(
                    controller: payload,
                    mono: true,
                    maxLines: 5,
                    minLines: 5,
                    error: error != null,
                    semanticLabel: 'Test data (JSON)',
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(
                  color: Color(0x9910131A),
                  border: Border(top: BorderSide(color: Gw.lineSubtle)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    GwButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    GwButton(
                      label: 'Run now',
                      icon: Icons.play_arrow,
                      variant: GwVariant.primary,
                      loading: busy,
                      onPressed: () async {
                        Map<String, dynamic> data;
                        try {
                          final parsed = payload.text.trim().isEmpty
                              ? <String, dynamic>{}
                              : jsonDecode(payload.text);
                          if (parsed is! Map<String, dynamic>) {
                            throw const FormatException();
                          }
                          data = parsed;
                        } catch (_) {
                          setLocal(
                            () => error = 'Test data must be a JSON object, like {"name": "Ada"}.',
                          );
                          return;
                        }
                        setLocal(() => (busy = true, error = null));
                        var current = _saved;
                        if (_dirty) {
                          final r = await _save();
                          if (r == null) return setLocal(() => busy = false);
                          current = r;
                        }
                        if (current.validation.isNotEmpty) {
                          return setLocal(
                            () => (
                              busy = false,
                              error =
                                  'Fix the validation issues before running.',
                            ),
                          );
                        }
                        try {
                          final e = await ref
                              .read(apiClientProvider)
                              .runWorkflow(current.id, data);
                          ref.invalidate(executionsProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _watchExecution(e.id);
                        } catch (e) {
                          setLocal(
                            () => (busy = false, error = describeError(e)),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _activate() async {
    final description = _saved.triggerType == 'trigger.schedule'
        ? 'It will run automatically on its schedule until you pause it.'
        : _saved.triggerType == 'trigger.webhook'
        ? 'Its webhook URL will start accepting requests and running the workflow.'
        : 'Manual workflows only run when you start them, but activating marks it as in use.';
    await confirmAction(
      context,
      title: 'Activate this workflow?',
      description: _dirty
          ? 'Unsaved changes will be saved first. $description'
          : description,
      confirmLabel: 'Activate',
      action: () async {
        if (_dirty && await _save() == null) {
          return "Couldn't save your changes.";
        }
        try {
          final r = await ref
              .read(apiClientProvider)
              .setWorkflowStatus(_saved.id, 'active');
          setState(() => _saved = r);
          refreshWorkflowData(ref, r.id);
          if (mounted) toast(context, 'Workflow activated');
          return null;
        } catch (e) {
          return describeError(e);
        }
      },
    );
  }

  Future<void> _pause() async {
    setState(() => _statusBusy = true);
    try {
      final r = await ref
          .read(apiClientProvider)
          .setWorkflowStatus(_saved.id, 'paused');
      setState(() => _saved = r);
      refreshWorkflowData(ref, r.id);
      if (mounted) toast(context, 'Workflow paused');
    } catch (e) {
      if (mounted) {
        toast(
          context,
          "Couldn't pause",
          description: describeError(e),
          tone: AlertTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  Future<void> _navigate(String href) async {
    if (!_dirty) return context.go(href);
    final leave = await confirmAction(
      context,
      title: 'Leave without saving?',
      description: "You have unsaved changes in this workflow. They'll be lost if you leave now.",
      confirmLabel: 'Discard changes',
      danger: true,
    );
    if (leave && mounted) context.go(href);
  }

  /* ---------------- UI ---------------- */

  /// Uses its own Consumer: on phones it lives in a separate sheet route that must rebuild when data loads.
  Widget _library() => Consumer(
    builder: (context, ref, _) {
      final types = ref.watch(nodeTypesProvider).value;
      final connected =
          (ref.watch(integrationsProvider).value ?? const <Integration>[])
              .map((i) => i.provider)
              .toSet();
      return _libraryFor(types, connected);
    },
  );

  Widget _libraryFor(List<NodeType>? types, Set<String> connected) {
    return NodeLibrary(
      types: types,
      hasTrigger: _def.nodes.any((n) => n.kind == 'trigger'),
      connectedProviders: connected,
      draggable: MediaQuery.of(context).size.width >= 1024,
      onAdd: (t) {
        final narrow = MediaQuery.of(context).size.width < 1024;
        if (narrow) Navigator.of(context).maybePop();
        _addNode(t);
      },
    );
  }

  Widget _configPanel({bool inSheet = false}) {
    final node = _selectedNode;
    if (node == null) return _settingsPanel(inSheet: inSheet);
    final names = {for (final n in _def.nodes) n.id: n.name};
    return ConfigPanel(
      key: ValueKey(node.id),
      node: node,
      issues: _dirty
          ? const []
          : _issues.where((i) => i.nodeId == node.id).toList(),
      integrations: _integrations,
      references: _references(node.id),
      webhookUrl: _saved.webhookUrl,
      connections: [
        for (final e in _def.edges.where(
          (e) => e.source == node.id || e.target == node.id,
        ))
          (
            e,
            e.source == node.id
                ? '→ ${names[e.target]}${e.handle == 'out' ? '' : ' (${e.handle})'}'
                : '← ${names[e.source]}',
          ),
      ],
      onChange: (config) =>
          _updateNode(node.id, (n) => n.copyWith(config: config)),
      onRename: (name) => _updateNode(node.id, (n) => n.copyWith(name: name)),
      onDelete: () {
        if (inSheet) Navigator.of(context).maybePop();
        _deleteSelected();
      },
      onRemoveConnection: (edge) => _change(
        Definition(
          nodes: _def.nodes,
          edges: _def.edges.where((e) => e.id != edge.id).toList(),
        ),
        immediateHistory: true,
      ),
    );
  }

  Widget _settingsPanel({bool inSheet = false}) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('WORKFLOW', style: GwText.eyebrow),
      const SizedBox(height: 4),
      Text(_saved.name, style: GwText.section),
      const SizedBox(height: 8),
      Row(
        children: [
          StatusBadge(_saved.status, small: true),
          const SizedBox(width: 8),
          Text('Version ${_saved.version}', style: GwText.micro),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        'Select a step to configure it. Rename the workflow or edit its description on the workflow page.',
        style: GwText.body.copyWith(color: Gw.fgMuted),
      ),
      const SizedBox(height: 16),
      Text.rich(
        TextSpan(
          style: GwText.meta.copyWith(
            color: Gw.fgSecondary,
            fontWeight: FontWeight.w500,
          ),
          children: [
            const TextSpan(text: 'Validation '),
            if (_dirty) TextSpan(text: '(as of last save)', style: GwText.meta),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (_issues.isEmpty)
        Row(
          children: [
            const Icon(Icons.check_circle_outline, size: 15, color: Gw.success),
            const SizedBox(width: 6),
            Text(
              'No issues found.',
              style: GwText.body.copyWith(color: Gw.success),
            ),
          ],
        )
      else
        for (final i in _issues)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: i.nodeId == null
                  ? null
                  : () {
                      setState(() => _selected = i.nodeId);
                      if (inSheet) {
                        Navigator.of(context)
                            .maybePop()
                            .then((_) => _openConfigSheet());
                      }
                    },
              child: GwAlert(
                tone: AlertTone.warning,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 14,
                      color: Gw.warningText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(i.message)),
                  ],
                ),
              ),
            ),
          ),
      const SizedBox(height: 16),
      GwCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shortcuts',
              style: GwText.meta.copyWith(
                color: Gw.fgSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ctrl S save · Ctrl Z undo · Ctrl Shift Z redo',
              style: GwText.meta,
            ),
            Text('Delete remove the selected step', style: GwText.meta),
            Text(
              'Drag a step to move it; drag from a bottom handle onto another step to connect them.',
              style: GwText.meta,
            ),
          ],
        ),
      ),
    ],
  );

  void _openLibrarySheet() => showSideSheet(
    context,
    title: 'Add a step',
    left: true,
    builder: (_) => _library(),
  );

  void _openConfigSheet() => showSideSheet(
    context,
    title: _selectedNode == null ? 'Workflow details' : 'Configure step',
    builder: (_) => _ConfigHost(state: this),
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(integrationsProvider); // keep the inline config panel fresh
    final wide = MediaQuery.of(context).size.width >= 1024;
    final running =
        _execution?.isActive ?? (_executionId != null && _execution == null);
    final issueCounts = <String, int>{};
    if (!_dirty) {
      for (final i in _issues) {
        if (i.nodeId != null) {
          issueCounts[i.nodeId!] = (issueCounts[i.nodeId!] ?? 0) + 1;
        }
      }
    }
    final steps = {
      for (final s in _execution?.steps ?? const <ExecutionStep>[]) s.nodeId: s,
    };

    final validationPill = _dirty
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Gw.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text('Unsaved changes', style: GwText.meta),
            ],
          )
        : _issues.isNotEmpty
        ? InkWell(
            onTap: () {
              setState(() => _selected = null);
              if (!wide) _openConfigSheet();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 14, color: Gw.warning),
                const SizedBox(width: 6),
                Text(
                  '${_issues.length} issue${_issues.length > 1 ? 's' : ''}',
                  style: GwText.meta.copyWith(color: Gw.warning),
                ),
              ],
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 14,
                color: Gw.success,
              ),
              const SizedBox(width: 6),
              Text(
                'Saved · valid',
                style: GwText.meta.copyWith(color: Gw.success),
              ),
            ],
          );

    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
          _dirty && !_saving ? _save(announce: true) : null,
      const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
          _dirty && !_saving ? _save(announce: true) : null,
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
          _canUndo ? _undo() : null,
      const SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: true,
        shift: true,
      ): () =>
          _cursor < _history.length - 1 ? _restore(_cursor + 1) : null,
      const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
          _cursor < _history.length - 1 ? _restore(_cursor + 1) : null,
      const SingleActivator(LogicalKeyboardKey.delete): _deleteSelected,
      const SingleActivator(LogicalKeyboardKey.backspace): _deleteSelected,
    };
    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: !_dirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _navigate('/workflows/${_saved.id}');
          },
          child: Column(
            children: [
              // Toolbar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: const BoxDecoration(
                  color: Gw.sidebar,
                  border: Border(bottom: BorderSide(color: Gw.lineSubtle)),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 6,
                      children: [
                        if (wide) ...[
                          InkWell(
                            onTap: () => _navigate('/workflows'),
                            child: Text(
                              'Workflows',
                              style: GwText.body.copyWith(color: Gw.fgMuted),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: Gw.fgMuted,
                          ),
                        ],
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: wide ? 320 : 200,
                          ),
                          child: InkWell(
                            onTap: () => _navigate('/workflows/${_saved.id}'),
                            child: Text(
                              _saved.name,
                              overflow: TextOverflow.ellipsis,
                              style: GwText.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(_saved.status, small: true),
                        const SizedBox(width: 10),
                        validationPill,
                      ],
                    ),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 6,
                      children: [
                        GwIconButton(
                          icon: Icons.undo,
                          tooltip: 'Undo',
                          size: 32,
                          onPressed: _canUndo ? _undo : null,
                        ),
                        GwIconButton(
                          icon: Icons.redo,
                          tooltip: 'Redo',
                          size: 32,
                          onPressed: _cursor < _history.length - 1
                              ? () => _restore(_cursor + 1)
                              : null,
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: Gw.line,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        GwIconButton(
                          icon: Icons.remove,
                          tooltip: 'Zoom out',
                          size: 32,
                          onPressed: _canvas.zoomOut,
                        ),
                        GwIconButton(
                          icon: Icons.add,
                          tooltip: 'Zoom in',
                          size: 32,
                          onPressed: _canvas.zoomIn,
                        ),
                        GwIconButton(
                          icon: Icons.fit_screen_outlined,
                          tooltip: 'Fit to screen',
                          size: 32,
                          onPressed: _canvas.fit,
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: Gw.line,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        GwButton(
                          label: wide ? 'Save' : '',
                          icon: Icons.save_outlined,
                          size: GwSize.sm,
                          loading: _saving,
                          onPressed: _dirty
                              ? () => _save(announce: true)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        GwButton(
                          label: wide ? (running ? 'Running' : 'Test run') : '',
                          icon: running ? Icons.autorenew : Icons.play_arrow,
                          size: GwSize.sm,
                          onPressed: running ? null : _openRunDialog,
                        ),
                        const SizedBox(width: 6),
                        _saved.status == 'active'
                            ? GwButton(
                                label: wide ? 'Pause' : '',
                                icon: Icons.pause,
                                size: GwSize.sm,
                                loading: _statusBusy,
                                onPressed: _pause,
                              )
                            : GwButton(
                                label: 'Activate',
                                variant: GwVariant.primary,
                                size: GwSize.sm,
                                onPressed: _activate,
                              ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    if (wide)
                      Container(
                        width: 256,
                        decoration: const BoxDecoration(
                          color: Gw.sidebar,
                          border: Border(
                            right: BorderSide(color: Gw.lineSubtle),
                          ),
                        ),
                        child: _library(),
                      ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DragTarget<NodeType>(
                              onAcceptWithDetails: (details) {
                                final world = _canvas.worldAt(details.offset);
                                if (world != null) {
                                  _addNode(
                                    details.data,
                                    at: Offset(
                                      ((world.dx - 118) / 10).round() * 10.0,
                                      ((world.dy - 30) / 10).round() * 10.0,
                                    ),
                                  );
                                }
                              },
                              builder: (_, _, _) => FlowCanvas(
                                definition: _def,
                                steps: steps,
                                issueCounts: issueCounts,
                                selectedId: _selected,
                                editable: true,
                                controller: _canvas,
                                onSelect: (id) {
                                  setState(() => _selected = id);
                                  if (id != null && !wide) _openConfigSheet();
                                },
                                onMove: (id, x, y) => _updateNode(
                                  id,
                                  (n) => n.copyWith(x: x, y: y),
                                ),
                                onConnect: _connect,
                              ),
                            ),
                          ),
                          if (_def.nodes.isEmpty)
                            Center(
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 300,
                                ),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xE6151923),
                                  borderRadius: BorderRadius.circular(Gw.rLg),
                                  border: Border.all(color: Gw.lineStrong),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Start with a trigger',
                                      style: GwText.bodyMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Choose how this workflow starts from the steps library.',
                                      textAlign: TextAlign.center,
                                      style: GwText.meta,
                                    ),
                                    if (!wide) ...[
                                      const SizedBox(height: 12),
                                      GwButton(
                                        label: 'Add a step',
                                        icon: Icons.add,
                                        variant: GwVariant.primary,
                                        size: GwSize.sm,
                                        onPressed: _openLibrarySheet,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          if (!wide)
                            Positioned(
                              bottom: 16,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Gw.elevated,
                                    borderRadius: BorderRadius.circular(Gw.rLg),
                                    border: Border.all(color: Gw.line),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GwButton(
                                        label: 'Add step',
                                        icon: Icons.add,
                                        variant: GwVariant.ghost,
                                        size: GwSize.sm,
                                        onPressed: _openLibrarySheet,
                                      ),
                                      GwButton(
                                        label: _selectedNode != null
                                            ? 'Configure'
                                            : 'Details',
                                        icon: Icons.tune,
                                        variant: GwVariant.ghost,
                                        size: GwSize.sm,
                                        onPressed: _openConfigSheet,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (_executionId != null) _runOverlay(wide),
                        ],
                      ),
                    ),
                    if (wide)
                      Container(
                        width: 352,
                        decoration: const BoxDecoration(
                          color: Gw.sidebar,
                          border: Border(
                            left: BorderSide(color: Gw.lineSubtle),
                          ),
                        ),
                        child: _configPanel(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _runOverlay(bool wide) {
    final e = _execution;
    return Positioned(
      right: 12,
      bottom: wide ? 12 : 68,
      child: Container(
        width: (MediaQuery.of(context).size.width - 24)
            .clamp(0, 416)
            .toDouble(),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.45,
        ),
        decoration: BoxDecoration(
          color: Gw.surface,
          borderRadius: BorderRadius.circular(Gw.rLg),
          border: Border.all(color: Gw.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 32,
              offset: Offset(0, 12),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Gw.lineSubtle)),
              ),
              child: Row(
                children: [
                  Text(
                    'Test run',
                    style: GwText.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(e?.status ?? 'queued', small: true),
                  const SizedBox(width: 8),
                  Text(formatDuration(e?.durationMs), style: GwText.micro),
                  const Spacer(),
                  if (e != null)
                    GwLink(
                      'Details',
                      onTap: () => context.go('/executions/${e.id}'),
                    ),
                  GwIconButton(
                    icon: _runCollapsed ? Icons.expand_less : Icons.expand_more,
                    tooltip: _runCollapsed
                        ? 'Expand test run'
                        : 'Collapse test run',
                    size: 32,
                    onPressed: () =>
                        setState(() => _runCollapsed = !_runCollapsed),
                  ),
                  GwIconButton(
                    icon: Icons.close,
                    tooltip: 'Close test run',
                    size: 32,
                    onPressed: () {
                      _poll?.cancel();
                      setState(() => (_executionId = null, _execution = null));
                    },
                  ),
                ],
              ),
            ),
            if (!_runCollapsed && e != null) ...[
              if (e.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: GwAlert(child: Text(e.errorMessage!)),
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(6),
                  child: ExecutionTimeline(
                    key: ValueKey(e.status),
                    steps: e.steps,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rebuilds the config sheet content from the builder's live state.
class _ConfigHost extends StatefulWidget {
  const _ConfigHost({required this.state});
  final _BuilderScreenState state;

  @override
  State<_ConfigHost> createState() => _ConfigHostState();
}

class _ConfigHostState extends State<_ConfigHost> {
  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, _) {
      ref.watch(integrationsProvider); // rebuild when integrations load
      return ValueListenableBuilder<int>(
        valueListenable: widget.state._rev,
        builder: (_, _, _) => widget.state._configPanel(inSheet: true),
      );
    },
  );
}
