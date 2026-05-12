import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Two-option control: female vs male AI voice (Kokoro / cloud TTS).
/// Uses page-level glass styling and brand violet accent for the active option.
class AiVoiceGenderToggle extends StatelessWidget {
  /// `true` = male voice, `false` = female.
  final bool isMale;
  final ValueChanged<bool> onChanged;
  final bool compact;

  const AiVoiceGenderToggle({
    super.key,
    required this.isMale,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
        : const EdgeInsets.all(4);
    final chipH = compact ? 32.0 : 40.0;
    final fontSize = compact ? 10.0 : 12.0;
    final radius = BorderRadius.circular(compact ? 14 : 18);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: pad,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: radius,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Segment(
                label: 'Female',
                selected: !isMale,
                height: chipH,
                fontSize: fontSize,
                onTap: () {
                  if (isMale) onChanged(false);
                },
              ),
              SizedBox(width: compact ? 2 : 4),
              _Segment(
                label: 'Male',
                selected: isMale,
                height: chipH,
                fontSize: fontSize,
                onTap: () {
                  if (!isMale) onChanged(true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final double height;
  final double fontSize;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.height,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.3,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
