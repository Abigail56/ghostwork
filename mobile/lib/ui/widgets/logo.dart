import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// The GhostWork mark: a geometric ghost whose eyes are two connected workflow nodes.
class GhostMark extends StatelessWidget {
  const GhostMark({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) =>
      Semantics(label: 'GhostWork', child: CustomPaint(size: Size.square(size), painter: _GhostPainter()));
}

class _GhostPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 32;
    canvas.scale(s);
    final body = Path()
      ..moveTo(5.5, 15.5)
      ..arcToPoint(const Offset(26.5, 15.5), radius: const Radius.circular(10.5))
      ..lineTo(26.5, 26.2)
      ..lineTo(22.5, 25.2)
      ..lineTo(19.2, 27.4)
      ..lineTo(16, 25.2)
      ..lineTo(12.8, 27.4)
      ..lineTo(9.5, 25.2)
      ..lineTo(5.5, 26.2)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF9B9BFF), Color(0xFF6E6EF0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(5, 4, 22, 24)),
    );
    final dark = Paint()..color = Gw.canvas;
    canvas.drawLine(const Offset(12.6, 15.2), const Offset(19.4, 15.2), dark..strokeWidth = 1.4);
    canvas.drawCircle(const Offset(12, 15.2), 2.3, dark);
    canvas.drawCircle(const Offset(20, 15.2), 2.3, dark);
    canvas.drawCircle(const Offset(20, 15.2), 1, Paint()..color = Gw.cyan);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GhostMark(size: size),
          const SizedBox(width: 10),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Ghost', style: TextStyle(fontSize: size * 0.62, fontWeight: FontWeight.w600, color: Gw.fg)),
              TextSpan(text: 'Work', style: TextStyle(fontSize: size * 0.62, fontWeight: FontWeight.w600, color: Gw.fgSecondary)),
            ]),
          ),
        ],
      );
}
