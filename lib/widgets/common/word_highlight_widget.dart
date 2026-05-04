import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/local_stt_service.dart';

/// Displays a transcript with each word color-coded by Whisper confidence.
/// 🟢 ≥0.85 — 🟡 0.65–0.84 — 🔴 <0.65
class WordHighlightWidget extends StatelessWidget {
  final List<WordInfo> words;
  final double fontSize;
  final double lineHeight;

  const WordHighlightWidget({
    super.key,
    required this.words,
    this.fontSize = 15,
    this.lineHeight = 1.7,
  });

  Color _colorForConfidence(double confidence) {
    if (confidence >= 0.85) return AppColors.success;
    if (confidence >= 0.65) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) return const SizedBox.shrink();

    return RichText(
      text: TextSpan(
        children: words.map((w) {
          final color = _colorForConfidence(w.confidence);
          return TextSpan(
            text: '${w.word} ',
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              height: lineHeight,
              fontWeight: w.confidence < 0.65
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Legend widget to show the color key below the transcript.
class WordHighlightLegend extends StatelessWidget {
  const WordHighlightLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(AppColors.success, 'Good'),
        const SizedBox(width: 12),
        _dot(AppColors.warning, 'Review'),
        const SizedBox(width: 12),
        _dot(AppColors.error, 'Improve'),
      ],
    );
  }

  Widget _dot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: AppColors.textMedium, fontSize: 11)),
      ],
    );
  }
}
