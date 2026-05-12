import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

/// Discrete progress LEDs (dim → electric purple).
class LedProgressDots extends StatelessWidget {
  const LedProgressDots({
    super.key,
    required this.total,
    required this.filled,
    this.dotSize = 6,
    this.gap = 6,
  })  : assert(total > 0),
        assert(filled >= 0 && filled <= total);

  final int total;
  final int filled;
  final double dotSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final on = i < filled;
        return Padding(
          padding: EdgeInsets.only(right: i == total - 1 ? 0 : gap),
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? VbColor.accentElectric : VbColor.surfaceContainerHighest,
              border: Border.all(
                color: on
                    ? VbColor.accentElectric.withValues(alpha: 0.6)
                    : VbColor.outlineVariant,
                width: 1,
              ),
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: VbColor.accentElectric.withValues(alpha: 0.35),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}
