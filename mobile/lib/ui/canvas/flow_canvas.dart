// Native port of the web's Living Workflow canvas (React Flow + FlowNode/FlowEdge).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../format.dart';
import 'node_meta.dart';

const kNodeW = 236.0;
const kNodeH = 86.0;
const kCondH = 110.0;
const _world = 12000.0; // virtual canvas size; node (0,0) sits at its center
const _origin = _world / 2;

double nodeHeight(String type) => kindOf(type) == 'condition' ? kCondH : kNodeH;

/// Where an output handle sits, relative to the node's top-left.
Offset handleOffset(String type, String handle) {
  final h = nodeHeight(type);
  if (handle == 'true') return Offset(kNodeW * 0.22, h);
  if (handle == 'false') return Offset(kNodeW * 0.78, h);
  return Offset(kNodeW / 2, h);
}

enum EdgeState { idle, traversed, active, skipped }

/// Edge state derived from real step results — only animate while a run is in progress.
EdgeState edgeStateFor(EdgeDef e, Map<String, String> statuses) {
  final s = statuses[e.source];
  final t = statuses[e.target];
  if (s == null) return EdgeState.idle;
  if (s == 'succeeded' && t == 'running') return EdgeState.active;
  if (s == 'succeeded' && (t == 'succeeded' || t == 'failed')) return EdgeState.traversed;
  if (t == 'skipped') return EdgeState.skipped;
  return EdgeState.idle;
}

class FlowCanvasController extends ChangeNotifier {
  _FlowCanvasState? _state;
  void zoomIn() => _state?._zoom(1.25);
  void zoomOut() => _state?._zoom(0.8);
  void fit() => _state?._fit();

  /// Canvas position under a global point (used for steps dropped from the library).
  Offset? worldAt(Offset global) => _state?._worldKey.currentContext == null ? null : _state!._toWorld(global);
}

class FlowCanvas extends StatefulWidget {
  const FlowCanvas({
    super.key,
    required this.definition,
    this.steps = const {},
    this.issueCounts = const {},
    this.selectedId,
    this.editable = false,
    this.onSelect,
    this.onMove,
    this.onConnect,
    this.controller,
    this.interactive = true,
  });

  final Definition definition;
  final Map<String, ExecutionStep> steps;
  final Map<String, int> issueCounts;
  final String? selectedId;
  final bool editable;
  final bool interactive;
  final ValueChanged<String?>? onSelect;
  final void Function(String id, double x, double y)? onMove;
  final void Function(String source, String handle, String target)? onConnect;
  final FlowCanvasController? controller;

  @override
  State<FlowCanvas> createState() => _FlowCanvasState();
}

class _FlowCanvasState extends State<FlowCanvas> with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  final _worldKey = GlobalKey();
  late final AnimationController _flow = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  Size _viewport = Size.zero;
  bool _lockPan = false;

  // Node drag
  String? _dragNode;
  Offset _dragStartWorld = Offset.zero;
  Offset _dragStartPos = Offset.zero;

  // Connection drag
  ({String source, String handle, Offset from})? _connecting;
  Offset? _connectTo;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(covariant FlowCanvas old) {
    super.didUpdateWidget(old);
    widget.controller?._state = this;
    if (old.definition.nodes.length != widget.definition.nodes.length && widget.definition.nodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    _transform.dispose();
    super.dispose();
  }

  Map<String, String> get _statuses => {for (final s in widget.steps.values) s.nodeId: s.status};

  Rect get _bounds {
    final nodes = widget.definition.nodes;
    if (nodes.isEmpty) return const Rect.fromLTWH(-kNodeW / 2, -kNodeH / 2, kNodeW, kNodeH);
    var r = Rect.fromLTWH(nodes.first.x, nodes.first.y, kNodeW, nodeHeight(nodes.first.type));
    for (final n in nodes.skip(1)) {
      r = r.expandToInclude(Rect.fromLTWH(n.x, n.y, kNodeW, nodeHeight(n.type)));
    }
    return r;
  }

  void _fit() {
    if (_viewport.isEmpty || !mounted) return;
    final b = _bounds.inflate(math.max(_bounds.width, _bounds.height) * 0.12 + 24);
    final scale = math.min(1.0, math.min(_viewport.width / b.width, _viewport.height / b.height)).clamp(0.25, 1.0);
    final center = b.center + const Offset(_origin, _origin);
    final tx = _viewport.width / 2 - center.dx * scale;
    final ty = _viewport.height / 2 - center.dy * scale;
    _transform.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _zoom(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(0.25, 1.75);
    final f = next / current;
    final c = Offset(_viewport.width / 2, _viewport.height / 2);
    _transform.value = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(f, f, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1)
      ..multiply(_transform.value);
  }

  Offset _toWorld(Offset global) {
    final box = _worldKey.currentContext!.findRenderObject() as RenderBox;
    return box.globalToLocal(global) - const Offset(_origin, _origin);
  }

  NodeDef? _nodeAt(Offset world) {
    for (final n in widget.definition.nodes.reversed) {
      if (Rect.fromLTWH(n.x, n.y, kNodeW, nodeHeight(n.type)).inflate(16).contains(world)) return n;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final statuses = _statuses;
    final edgeStates = {for (final e in widget.definition.edges) e.id: widget.steps.isEmpty ? EdgeState.idle : edgeStateFor(e, statuses)};
    final animate = !reduceMotion && edgeStates.values.contains(EdgeState.active);
    if (animate && !_flow.isAnimating) _flow.repeat();
    if (!animate && _flow.isAnimating) _flow.stop();

    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      if (size != _viewport) {
        _viewport = size;
        WidgetsBinding.instance.addPostFrameCallback((_) => _fit()); // same as the web AutoFit
      }
      final byId = {for (final n in widget.definition.nodes) n.id: n};
      return ClipRect(
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _DotsPainter(_transform))),
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transform,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.25,
              maxScale: 1.75,
              panEnabled: widget.interactive && !_lockPan,
              scaleEnabled: widget.interactive,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => widget.onSelect?.call(null),
                child: SizedBox(
                  key: _worldKey,
                  width: _world,
                  height: _world,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _flow,
                        builder: (_, _) => CustomPaint(
                          painter: _EdgesPainter(
                            nodes: byId,
                            edges: widget.definition.edges,
                            states: edgeStates,
                            phase: _flow.value,
                            connecting: _connecting == null || _connectTo == null ? null : (_connecting!.from, _connectTo!),
                          ),
                        ),
                      ),
                    ),
                    for (final e in widget.definition.edges)
                      if ((e.handle == 'true' || e.handle == 'false') && byId[e.source] != null && byId[e.target] != null)
                        _edgeLabel(e, byId[e.source]!, byId[e.target]!),
                    for (final n in widget.definition.nodes) _positioned(n),
                  ]),
                ),
              ),
            ),
          ),
          // Read-only maps get the same corner controls as React Flow's <Controls> on the web.
          if (widget.interactive && !widget.editable)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                decoration: BoxDecoration(color: Gw.elevated, border: Border.all(color: Gw.line), borderRadius: BorderRadius.circular(4)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final (icon, tip, action) in [(Icons.add, 'Zoom in', () => _zoom(1.25)), (Icons.remove, 'Zoom out', () => _zoom(0.8)), (Icons.fit_screen_outlined, 'Fit view', _fit)])
                    Tooltip(
                      message: tip,
                      child: InkWell(onTap: action, child: SizedBox.square(dimension: 28, child: Icon(icon, size: 15, color: Gw.fgSecondary))),
                    ),
                ]),
              ),
            ),
        ]),
      );
    });
  }

  Widget _edgeLabel(EdgeDef e, NodeDef s, NodeDef t) {
    final from = Offset(s.x, s.y) + handleOffset(s.type, e.handle);
    final to = Offset(t.x + kNodeW / 2, t.y);
    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    return Positioned(
      left: _origin + mid.dx - 22,
      top: _origin + mid.dy - 9,
      child: IgnorePointer(
        child: Container(
          width: 44,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Gw.elevated, borderRadius: BorderRadius.circular(99), border: Border.all(color: Gw.line)),
          child: Text(e.handle.toUpperCase(),
              style: TextStyle(fontFamily: Gw.fontSans, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: e.handle == 'true' ? Gw.success : Gw.fgSecondary)),
        ),
      ),
    );
  }

  Widget _positioned(NodeDef n) {
    final step = widget.steps[n.id];
    final card = FlowNodeCard(
      node: n,
      stepStatus: step?.status,
      stepDuration: step?.durationMs,
      issueCount: widget.issueCounts[n.id] ?? 0,
      selected: widget.selectedId == n.id,
    );
    final kind = kindOf(n.type);
    return Positioned(
      left: _origin + n.x,
      top: _origin + n.y,
      child: Semantics(
        button: widget.onSelect != null,
        label: '${kindStyle(kind).label}: ${n.name}${step != null ? ', ${step.status}' : ''}',
        child: SizedBox(
          width: kNodeW,
          height: nodeHeight(n.type) + 12,
          child: Stack(clipBehavior: Clip.none, children: [
            Listener(
              onPointerDown: widget.editable ? (_) => setState(() => _lockPan = true) : null,
              onPointerUp: widget.editable ? (_) => setState(() => _lockPan = false) : null,
              onPointerCancel: widget.editable ? (_) => setState(() => _lockPan = false) : null,
              child: GestureDetector(
                onTap: widget.onSelect == null ? null : () => widget.onSelect!(n.id),
                onPanStart: !widget.editable
                    ? null
                    : (d) {
                        _dragNode = n.id;
                        _dragStartWorld = _toWorld(d.globalPosition);
                        _dragStartPos = Offset(n.x, n.y);
                        widget.onSelect?.call(n.id);
                      },
                onPanUpdate: !widget.editable
                    ? null
                    : (d) {
                        if (_dragNode != n.id) return;
                        final p = _dragStartPos + (_toWorld(d.globalPosition) - _dragStartWorld);
                        widget.onMove?.call(n.id, (p.dx / 10).round() * 10.0, (p.dy / 10).round() * 10.0);
                      },
                onPanEnd: !widget.editable ? null : (_) => _dragNode = null,
                child: card,
              ),
            ),
            if (kind != 'trigger') _handle(Offset(kNodeW / 2, 0), connectable: false),
            if (kind == 'condition') ...[
              _handle(handleOffset(n.type, 'true'), source: n, handleName: 'true'),
              _handle(handleOffset(n.type, 'false'), source: n, handleName: 'false'),
            ] else
              _handle(handleOffset(n.type, 'out'), source: n, handleName: 'out'),
          ]),
        ),
      ),
    );
  }

  Widget _handle(Offset at, {bool connectable = true, NodeDef? source, String handleName = 'out'}) {
    final canDrag = widget.editable && connectable && source != null;
    final touch = canDrag ? 28.0 : 10.0;
    return Positioned(
      left: at.dx - touch / 2,
      top: at.dy - touch / 2,
      child: Listener(
        onPointerDown: canDrag ? (_) => setState(() => _lockPan = true) : null,
        onPointerUp: canDrag ? (_) => setState(() => _lockPan = false) : null,
        child: GestureDetector(
          onPanStart: !canDrag
              ? null
              : (d) => setState(() {
                    _connecting = (source: source.id, handle: handleName, from: Offset(source.x, source.y) + at);
                    _connectTo = _toWorld(d.globalPosition);
                  }),
          onPanUpdate: !canDrag ? null : (d) => setState(() => _connectTo = _toWorld(d.globalPosition)),
          onPanEnd: !canDrag
              ? null
              : (_) {
                  final target = _connectTo == null ? null : _nodeAt(_connectTo!);
                  final c = _connecting;
                  setState(() => (_connecting = null, _connectTo = null, _lockPan = false));
                  if (c != null && target != null && target.id != c.source) widget.onConnect?.call(c.source, c.handle, target.id);
                },
          child: Container(
            width: touch,
            height: touch,
            alignment: Alignment.center,
            color: Colors.transparent,
            child: Container(
              width: canDrag ? 14 : 10,
              height: canDrag ? 14 : 10,
              decoration: BoxDecoration(
                color: _connecting?.source == source?.id && _connecting?.handle == handleName ? Gw.cyan : Gw.elevated,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF4A5266), width: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The node card (web FlowNode).
class FlowNodeCard extends StatelessWidget {
  const FlowNodeCard({super.key, required this.node, this.stepStatus, this.stepDuration, this.issueCount = 0, this.selected = false});

  final NodeDef node;
  final String? stepStatus;
  final int? stepDuration;
  final int issueCount;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final kind = kindOf(node.type);
    final style = kindStyle(kind);
    final (borderColor, glow, opacity) = switch (stepStatus) {
      'running' => (Gw.cyan, const Color(0x2655C5F2), 1.0),
      'succeeded' => (Gw.success.withValues(alpha: 0.55), Colors.transparent, 1.0),
      'failed' => (Gw.danger.withValues(alpha: 0.7), const Color(0x1FF2616B), 1.0),
      'skipped' => (Gw.line, Colors.transparent, 0.55),
      _ => (Gw.line, Colors.transparent, 1.0),
    };
    return Opacity(
      opacity: opacity,
      child: Container(
        width: kNodeW,
        height: nodeHeight(node.type),
        decoration: BoxDecoration(
          color: Gw.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? Gw.violet : borderColor),
          boxShadow: [
            if (selected) const BoxShadow(color: Color(0x338585FF), spreadRadius: 3),
            if (!selected && glow != Colors.transparent) BoxShadow(color: glow, spreadRadius: 3),
            const BoxShadow(color: Color(0x8C000000), blurRadius: 18, offset: Offset(0, 6), spreadRadius: -6),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: style.soft, borderRadius: BorderRadius.circular(6)),
                child: Icon(nodeIcon(node.type), size: 14, color: style.color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(style.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(fontFamily: Gw.fontSans, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.66, color: style.color)),
              ),
              if (stepStatus != null && stepStatus != 'pending') _stepIndicator() else if (issueCount > 0) _setupIndicator(),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: Gw.fontSans, fontSize: 13, fontWeight: FontWeight.w600, color: Gw.fg)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
            child: Text(summarizeNode(node), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: Gw.fontMono, fontSize: 11, color: Gw.fgMuted)),
          ),
          if (kind == 'condition') ...[
            const Spacer(),
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Gw.lineSubtle))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('True', style: TextStyle(fontFamily: Gw.fontSans, fontSize: 11, fontWeight: FontWeight.w500, color: Gw.success)),
                Text('False', style: TextStyle(fontFamily: Gw.fontSans, fontSize: 11, fontWeight: FontWeight.w500, color: Gw.fgMuted)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _stepIndicator() {
    final (icon, color) = switch (stepStatus) {
      'running' => (Icons.autorenew, Gw.cyan),
      'succeeded' => (Icons.check_circle_outline, Gw.success),
      'failed' => (Icons.highlight_off, Gw.danger),
      _ => (Icons.skip_next_outlined, Gw.fgMuted),
    };
    return Row(children: [
      if (stepStatus != 'running' && stepStatus != 'skipped' && stepDuration != null)
        Padding(padding: const EdgeInsets.only(right: 4), child: Text(formatDuration(stepDuration), style: GwText.micro)),
      Icon(icon, size: 14, color: color),
    ]);
  }

  Widget _setupIndicator() => const Row(children: [
        Icon(Icons.error_outline, size: 13, color: Gw.warning),
        SizedBox(width: 4),
        Text('Setup', style: TextStyle(fontFamily: Gw.fontSans, fontSize: 11, fontWeight: FontWeight.w500, color: Gw.warning)),
      ]);
}

class _EdgesPainter extends CustomPainter {
  _EdgesPainter({required this.nodes, required this.edges, required this.states, required this.phase, this.connecting});

  final Map<String, NodeDef> nodes;
  final List<EdgeDef> edges;
  final Map<String, EdgeState> states;
  final double phase;
  final (Offset, Offset)? connecting;

  static const _colors = {
    EdgeState.idle: Color(0xFF3A4254),
    EdgeState.traversed: Gw.cyan,
    EdgeState.active: Gw.cyan,
    EdgeState.skipped: Color(0xFF262C38),
  };

  /// React Flow-style smooth step: down, across, down — with rounded corners.
  static Path stepPath(Offset a, Offset b) {
    final p = Path()..moveTo(a.dx, a.dy);
    if ((a.dx - b.dx).abs() < 1 || b.dy - a.dy < 24) {
      if (b.dy - a.dy < 24) {
        final c = (b.dy - a.dy).abs() / 2 + 40;
        p.cubicTo(a.dx, a.dy + c, b.dx, b.dy - c, b.dx, b.dy);
      } else {
        p.lineTo(b.dx, b.dy);
      }
      return p;
    }
    final midY = (a.dy + b.dy) / 2;
    final dir = b.dx > a.dx ? 1.0 : -1.0;
    final r = math.min(10.0, math.min((b.dx - a.dx).abs() / 2, (b.dy - a.dy).abs() / 2));
    p
      ..lineTo(a.dx, midY - r)
      ..quadraticBezierTo(a.dx, midY, a.dx + dir * r, midY)
      ..lineTo(b.dx - dir * r, midY)
      ..quadraticBezierTo(b.dx, midY, b.dx, midY + r)
      ..lineTo(b.dx, b.dy);
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(_origin, _origin);
    for (final e in edges) {
      final s = nodes[e.source];
      final t = nodes[e.target];
      if (s == null || t == null) continue;
      final a = Offset(s.x, s.y) + handleOffset(s.type, e.handle);
      final b = Offset(t.x + kNodeW / 2, t.y);
      final path = stepPath(a, b);
      final state = states[e.id] ?? EdgeState.idle;
      canvas.drawPath(path, Paint()
        ..color = _colors[state]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
      if (state == EdgeState.active) _dashed(canvas, path, phase);
    }
    if (connecting != null) {
      canvas.drawPath(stepPath(connecting!.$1, connecting!.$2), Paint()
        ..color = Gw.cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }
  }

  void _dashed(Canvas canvas, Path path, double phase) {
    final paint = Paint()
      ..color = const Color(0xFFBFEAFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in path.computeMetrics()) {
      var d = phase * 12;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 5, metric.length)), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgesPainter old) => true;
}

/// Dotted background that pans and zooms with the canvas.
class _DotsPainter extends CustomPainter {
  _DotsPainter(this.transform) : super(repaint: transform);
  final TransformationController transform;

  @override
  void paint(Canvas canvas, Size size) {
    final m = transform.value;
    final scale = m.getMaxScaleOnAxis();
    final gap = 20 * scale;
    if (gap < 6) return;
    final tx = m.getTranslation().x % gap;
    final ty = m.getTranslation().y % gap;
    final paint = Paint()..color = const Color(0x24A0A8B8);
    for (var x = tx; x < size.width; x += gap) {
      for (var y = ty; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => false;
}
