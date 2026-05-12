import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

/// Subtle 1px dots on a 24px grid (Nothing-style depth).
class DotGridBackground extends StatelessWidget {
  const DotGridBackground({
    super.key,
    required this.child,
    this.dotColor,
  });

  final Widget child;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _DotGridPainter(
            color: dotColor ?? Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child,
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double x = 0; x < size.width; x += vbDotGridPitch) {
      for (double y = 0; y < size.height; y += vbDotGridPitch) {
        canvas.drawCircle(Offset(x, y), 0.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.color != color;
}
