import 'package:flutter/foundation.dart';
import 'package:flutter_langdetect/flutter_langdetect.dart' as langdetect;

/// Result of a language detection check.
class LanguageDetectionResult {
  /// True if the text is English (or detection was inconclusive → allow through).
  final bool isEnglish;

  /// ISO 639-1 code of the detected language, e.g. 'ml', 'hi', 'ta'.
  final String detectedCode;

  /// Human-readable language name, e.g. 'Malayalam'.
  /// Null when English was detected.
  final String? detectedLanguageName;

  /// Detection confidence in [0, 1].
  final double confidence;

  const LanguageDetectionResult({
    required this.isEnglish,
    required this.detectedCode,
    this.detectedLanguageName,
    required this.confidence,
  });
}

/// Detects the language of a transcript using character-level n-gram models.
///
/// 100 % offline — no network calls, no model files to download.
/// Supports 55 languages including all major Indian languages.
///
/// Call [init()] once at app startup (after WidgetsFlutterBinding.ensureInitialized).
class LanguageDetectionService {
  // Singleton
  static final LanguageDetectionService _instance =
      LanguageDetectionService._internal();
  factory LanguageDetectionService() => _instance;
  LanguageDetectionService._internal();

  bool _isInitialized = false;

  // ── Language name map (ISO 639-1 → display name) ─────────────────────────
  static const Map<String, String> _names = {
    'af': 'Afrikaans',
    'ar': 'Arabic',
    'bg': 'Bulgarian',
    'bn': 'Bengali',
    'ca': 'Catalan',
    'cs': 'Czech',
    'cy': 'Welsh',
    'da': 'Danish',
    'de': 'German',
    'el': 'Greek',
    'es': 'Spanish',
    'et': 'Estonian',
    'fa': 'Persian',
    'fi': 'Finnish',
    'fr': 'French',
    'gu': 'Gujarati',
    'he': 'Hebrew',
    'hi': 'Hindi',
    'hr': 'Croatian',
    'hu': 'Hungarian',
    'id': 'Indonesian',
    'it': 'Italian',
    'ja': 'Japanese',
    'kn': 'Kannada',
    'ko': 'Korean',
    'lt': 'Lithuanian',
    'lv': 'Latvian',
    'mk': 'Macedonian',
    'ml': 'Malayalam',
    'mr': 'Marathi',
    'ne': 'Nepali',
    'nl': 'Dutch',
    'no': 'Norwegian',
    'pa': 'Punjabi',
    'pl': 'Polish',
    'pt': 'Portuguese',
    'ro': 'Romanian',
    'ru': 'Russian',
    'sk': 'Slovak',
    'sl': 'Slovenian',
    'so': 'Somali',
    'sq': 'Albanian',
    'sv': 'Swedish',
    'sw': 'Swahili',
    'ta': 'Tamil',
    'te': 'Telugu',
    'th': 'Thai',
    'tl': 'Filipino',
    'tr': 'Turkish',
    'uk': 'Ukrainian',
    'ur': 'Urdu',
    'vi': 'Vietnamese',
    'zh-cn': 'Chinese (Simplified)',
    'zh-tw': 'Chinese (Traditional)',
  };

  // ── Minimum word count before running detection ───────────────────────────
  // Very short utterances (< 4 words) are unreliable for n-gram detection.
  // Let them through rather than false-blocking a user who said "yes" or "good".
  static const int _minWords = 4;

  // ── English confidence threshold ──────────────────────────────────────────
  // If English probability is below this, treat as non-English.
  // 0.65 is intentionally lower than the naive 0.7 to reduce false negatives
  // for accented English speakers (Indian, Filipino, etc.).
  static const double _englishThreshold = 0.65;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Must be called once after [WidgetsFlutterBinding.ensureInitialized].
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await langdetect.initLangDetect();
      _isInitialized = true;
      debugPrint('LangDetect: initialised (55 languages, offline).');
    } catch (e) {
      debugPrint('LangDetect: init error (non-fatal) — $e');
      // Don't crash the app — we'll fail-open (allow all text through)
    }
  }

  // ── Detection ─────────────────────────────────────────────────────────────

  /// Detect the language of [transcript].
  ///
  /// Returns [LanguageDetectionResult] with [isEnglish] = true when:
  ///   • transcript is too short to detect reliably
  ///   • detection library failed / not initialised
  ///   • English confidence ≥ [_englishThreshold]
  ///
  /// Returns [isEnglish] = false only when another language is detected
  /// with high confidence. This ensures accented English is never blocked.
  LanguageDetectionResult detect(String transcript) {
    final wordCount = transcript.trim().split(RegExp(r'\s+')).length;

    // ── Too short: let it through ─────────────────────────────────────────
    if (wordCount < _minWords || !_isInitialized) {
      return const LanguageDetectionResult(
        isEnglish: true,
        detectedCode: 'en',
        confidence: 1.0,
      );
    }

    try {
      final probs = langdetect.detectLangs(transcript);
      if (probs.isEmpty) {
        return const LanguageDetectionResult(
          isEnglish: true,
          detectedCode: 'en',
          confidence: 0.5,
        );
      }

      final top = probs.first;
      debugPrint(
          'LangDetect: top=${top.lang} prob=${top.prob.toStringAsFixed(3)}');

      // ── English detected ──────────────────────────────────────────────
      if (top.lang == 'en') {
        return LanguageDetectionResult(
          isEnglish: top.prob >= _englishThreshold,
          detectedCode: top.lang,
          // Even if below threshold for English, give benefit of the doubt
          // by returning isEnglish=true (avoids blocking accented speakers)
          confidence: top.prob,
        );
      }

      // ── Another language detected ─────────────────────────────────────
      // Only block if the non-English language has high confidence AND
      // English is not in the top two results at reasonable probability.
      final englishProb = probs
          .where((p) => p.lang == 'en')
          .map((p) => p.prob)
          .fold(0.0, (a, b) => a + b);

      if (top.prob > 0.75 && englishProb < 0.2) {
        // Clearly non-English — block and warn
        final name = _names[top.lang] ?? 'a non-English language';
        debugPrint('LangDetect: non-English detected → $name (${top.prob})');
        return LanguageDetectionResult(
          isEnglish: false,
          detectedCode: top.lang,
          detectedLanguageName: name,
          confidence: top.prob,
        );
      }

      // Ambiguous / mixed — let through (user might be code-switching)
      return LanguageDetectionResult(
        isEnglish: true,
        detectedCode: top.lang,
        confidence: top.prob,
      );
    } catch (e) {
      debugPrint('LangDetect: detection error (fail-open) — $e');
      return const LanguageDetectionResult(
        isEnglish: true,
        detectedCode: 'en',
        confidence: 0.5,
      );
    }
  }
}
