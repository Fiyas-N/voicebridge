import 'package:flutter/material.dart';
import '../../services/speech_to_text_service.dart';

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
    if (confidence >= 0.85) return const Color(0xFF6bcb77); // green
    if (confidence >= 0.65) return const Color(0xFFffd166); // yellow
    return const Color(0xFFef233c);                          // red
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
        _dot(const Color(0xFF6bcb77), 'Good'),
        const SizedBox(width: 12),
        _dot(const Color(0xFFffd166), 'Review'),
        const SizedBox(width: 12),
        _dot(const Color(0xFFef233c), 'Improve'),
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
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65), fontSize: 11)),
      ],
    );
  }
}
