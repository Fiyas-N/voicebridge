import 'package:flutter/foundation.dart';
import 'local_llm_service.dart';

class FeedbackService {
  final LocalLlmService _localLlm = LocalLlmService();

  /// Build the raw prompt string for Gemma.
  /// Called by session_provider when using streaming mode.
  String buildPrompt({
    required double fluencyScore,
    required double grammarScore,
    required double pronunciationScore,
    required List<String> grammarErrors,
    String? correctedSentence,
  }) {
    return '''You are an encouraging English coach.
Provide 1 sentence of encouragement and 3 short actionable improvement tips.

Performance:
- Fluency: ${fluencyScore.toStringAsFixed(1)}
- Grammar: ${grammarScore.toStringAsFixed(1)}
- Pronunciation: ${pronunciationScore.toStringAsFixed(1)}
- Error types: ${grammarErrors.isNotEmpty ? grammarErrors.join(", ") : "None"}
${correctedSentence != null && correctedSentence.isNotEmpty ? "- Corrected: $correctedSentence" : ""}

Rules:
- Max 100 words.
- Be warm and specific.
''';
  }

  /// Generate personalized coaching feedback using the on-device Gemma 3 1B model.
  Future<String> generateFeedback({
    required double fluencyScore,
    required double grammarScore,
    required double pronunciationScore,
    required List<String> grammarErrors,
    String? correctedSentence,
  }) async {
    final prompt = buildPrompt(
      fluencyScore: fluencyScore,
      grammarScore: grammarScore,
      pronunciationScore: pronunciationScore,
      grammarErrors: grammarErrors,
      correctedSentence: correctedSentence,
    );
    try {
      final response = await _localLlm.generateResponse(prompt);
      if (response.isNotEmpty && response.length > 20) {
        debugPrint('Feedback: local generation complete');
        return response.trim();
      }
    } catch (e) {
      debugPrint('Feedback: local generation error — $e');
    }
    return _generateTemplateFeedback(fluencyScore, grammarScore, pronunciationScore);
  }

  String _generateTemplateFeedback(
    double fluency,
    double grammar,
    double pronunciation,
  ) {
    final overall = (fluency * 0.4 + grammar * 0.35 + pronunciation * 0.25);

    String encouragement;
    String improvement;

    if (overall >= 80) {
      encouragement = 'Excellent work! Your English speaking skills are impressive.';
      improvement = 'Focus on maintaining this high level with regular practice.';
    } else if (overall >= 65) {
      encouragement = "Great job! You're making solid progress.";
      improvement =
          'Work on ${_getWeakestArea(fluency, grammar, pronunciation)} to reach the next level.';
    } else {
      encouragement = "Good effort! You're on the right track.";
      improvement =
          'Focus on ${_getWeakestArea(fluency, grammar, pronunciation)} and practice daily for best results.';
    }

    return '$encouragement Your fluency is ${_getLevel(fluency)}, '
        'grammar is ${_getLevel(grammar)}, and pronunciation is ${_getLevel(pronunciation)}. '
        '$improvement Keep up the great work!';
  }

  String _getWeakestArea(double fluency, double grammar, double pronunciation) {
    if (fluency <= grammar && fluency <= pronunciation) return 'fluency';
    if (grammar <= pronunciation) return 'grammar accuracy';
    return 'pronunciation';
  }

  String _getLevel(double score) {
    if (score >= 85) return 'excellent';
    if (score >= 70) return 'good';
    if (score >= 55) return 'fair';
    return 'developing';
  }
}
