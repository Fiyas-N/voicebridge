import 'package:flutter/foundation.dart';
import 'local_llm_service.dart';
import 'grammar_service.dart';
import 'cloud_llm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackService {
  final LocalLlmService _localLlm = LocalLlmService();
  final CloudLlmService _cloudLlm = CloudLlmService();

  /// Build the raw prompt string for Gemma.
  /// Called by session_provider when using streaming mode.
  String buildPrompt({
    required double fluencyScore,
    required double grammarScore,
    required double pronunciationScore,
    required List<GrammarError> grammarErrors,
    List<String> mispronounced = const [],
    String? correctedSentence,
  }) {
    final errorLines = grammarErrors.isNotEmpty
        ? grammarErrors
            .map((e) => '  • "${e.original}" → "${e.correction}": ${e.explanation}')
            .join('\n')
        : '  None detected';

    final pronLines = mispronounced.isNotEmpty
        ? mispronounced.map((w) => '  • $w').join('\n')
        : '  None detected';

    return '''You are a patient, professional English Tutor conducting a private lesson.
Provide an encouraging assessment and clear, educational corrections.

Performance Analysis:
- Fluency (Pacing/Smoothness): ${fluencyScore.toStringAsFixed(1)}%
- Grammar & Structure: ${grammarScore.toStringAsFixed(1)}%
- Word Pronunciation: ${pronunciationScore.toStringAsFixed(1)}%

---
GRAMMAR CORRECTIONS:
$errorLines

---
PRONUNCIATION DRILL:
$pronLines

---
${correctedSentence != null && correctedSentence.isNotEmpty ? "THE IDEAL SENTENCE STRUCTURE IS: \"$correctedSentence\"" : ""}

INSTRUCTIONS AS TUTOR:
1. Address the student warmly.
2. For EVERY word in the PRONUNCIATION DRILL list, show them HOW to say it phonetically using simple English sounds in quotes (Example: "Make" -> "MEIK", "Thought" -> "THAWT"). 
3. Give 1 specific grammar tip based on the corrections above.
4. Keep language easy to understand. Max 150 words.
''';
  }

  /// Generate personalized coaching feedback using hybrid routing.
  Future<String> generateFeedback({
    required double fluencyScore,
    required double grammarScore,
    required double pronunciationScore,
    required List<GrammarError> grammarErrors,
    List<String> mispronounced = const [],
    String? correctedSentence,
  }) async {
    final prompt = buildPrompt(
      fluencyScore: fluencyScore,
      grammarScore: grammarScore,
      pronunciationScore: pronunciationScore,
      grammarErrors: grammarErrors,
      mispronounced: mispronounced,
      correctedSentence: correctedSentence,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final useOfflineOnly = prefs.getBool('use_offline_only') ?? false;

      // ── 1. Try Cloud LLM first (faster, better reasoning) if allowed and online
      if (!useOfflineOnly && await _cloudLlm.isOnline()) {
        debugPrint('Feedback: Routing to Gemini Flash (online)');
        final response = await _cloudLlm.generateText(prompt);
        if (response.length > 20) return response;
      }

      // ── 2. Fallback to On-Device LLM (always local — do not use smartGenerate
      //     here or a "Wi‑Fi but no internet" device would hit cloud again).
      debugPrint('Feedback: Routing to Local Qwen/Gemma (offline)');
      try {
        final response = await _localLlm.generateResponse(prompt);
        if (response.isNotEmpty && response.length > 20) {
          return response.trim();
        }
      } finally {
        await _localLlm.unloadModel();
      }
    } catch (e) {
      debugPrint('Feedback: Model generation error — $e');
    }
    return _generateTemplateFeedback(fluencyScore, grammarScore, pronunciationScore);
  }

  /// Same text as the template fallback inside [generateFeedback] — for streaming
  /// pipelines when the on-device LLM cannot start and cloud is unavailable.
  String buildTemplateFeedback({
    required double fluencyScore,
    required double grammarScore,
    required double pronunciationScore,
  }) {
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
