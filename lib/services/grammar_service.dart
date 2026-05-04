import 'package:flutter/foundation.dart';
import 'package:language_tool/language_tool.dart';

/// Grammar error model — maps from both LanguageTool and heuristic sources.
class GrammarError {
  final String type;
  final String original;
  final String correction;
  final String explanation;

  GrammarError({
    required this.type,
    required this.original,
    required this.correction,
    required this.explanation,
  });

  factory GrammarError.fromJson(Map<String, dynamic> json) {
    return GrammarError(
      type: json['type'] ?? 'grammar',
      original: json['original'] ?? '',
      correction: json['correction'] ?? '',
      explanation: json['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'original': original,
      'correction': correction,
      'explanation': explanation,
    };
  }
}

class GrammarResult {
  final double score;
  final String correctedText;
  final List<GrammarError> errors;
  final String summary;

  GrammarResult({
    required this.score,
    required this.correctedText,
    required this.errors,
    required this.summary,
  });
}

/// Grammar Analysis Service
///
/// Strategy (fastest first, graceful degradation):
///   1. LanguageTool API  — instant, no LLM needed. Requires internet.
///   2. Heuristic fallback — word-count + known-error rules. Always offline.
///
/// Gemma 3 is NO LONGER used for grammar — it is now reserved exclusively
/// for Step 6 (personalised coaching feedback), halving LLM pressure.
class GrammarAnalysisService {
  LanguageTool? _tool;

  LanguageTool get _langTool {
    _tool ??= LanguageTool();
    return _tool!;
  }

  /// Analyse grammar. Returns fast if internet is available (LanguageTool),
  /// or falls back to heuristics if offline.
  Future<GrammarResult> analyzeGrammar(String text) async {
    if (text.trim().isEmpty) {
      return GrammarResult(
        score: 0,
        correctedText: '',
        errors: [],
        summary: 'No text to analyse.',
      );
    }

    // ── Attempt 1: LanguageTool API (fast, accurate, no LLM) ──────────────
    try {
      debugPrint('Grammar: checking via LanguageTool API…');
      final mistakes = await _langTool.check(text);
      debugPrint('Grammar: LanguageTool returned ${mistakes.length} issues.');
      return _fromLanguageTool(text, mistakes);
    } catch (e) {
      debugPrint('Grammar: LanguageTool unavailable ($e) — using heuristics.');
    }

    // ── Attempt 2: Offline heuristic fallback ────────────────────────────
    return _offlineFallback(text);
  }

  // ---------------------------------------------------------------------------
  // LanguageTool result → GrammarResult
  // ---------------------------------------------------------------------------

  GrammarResult _fromLanguageTool(String text, List<WritingMistake> mistakes) {
    // Convert LanguageTool mistakes to GrammarError list
    final errors = <GrammarError>[];
    String corrected = text;
    int offset = 0; // track cumulative index drift from replacements

    for (final m in mistakes) {
      final original = text.substring(
        m.offset.clamp(0, text.length),
        (m.offset + m.length).clamp(0, text.length),
      );
      final suggestion = m.replacements.isNotEmpty ? m.replacements.first : original;

      errors.add(GrammarError(
        type: _categoryLabel(m.issueType),
        original: original,
        correction: suggestion,
        explanation: m.message,
      ));

      // Apply correction to produce corrected text
      final start = (m.offset + offset).clamp(0, corrected.length);
      final end = (m.offset + m.length + offset).clamp(0, corrected.length);
      corrected = corrected.replaceRange(start, end, suggestion);
      offset += suggestion.length - m.length;
    }

    // Score: start at 100, deduct per error weighted by severity
    double score = 100.0;
    for (final m in mistakes) {
      switch (_categoryLabel(m.issueType)) {
        case 'Grammar':
          score -= 8;
          break;
        case 'Spelling':
          score -= 5;
          break;
        case 'Punctuation':
          score -= 3;
          break;
        default:
          score -= 4;
      }
    }
    score = score.clamp(30.0, 100.0);

    final summary = mistakes.isEmpty
        ? 'No grammar issues found — great writing!'
        : '${mistakes.length} issue${mistakes.length == 1 ? '' : 's'} found.';

    return GrammarResult(
      score: score,
      correctedText: corrected,
      errors: errors,
      summary: summary,
    );
  }

  String _categoryLabel(String? issueType) {
    if (issueType == null) return 'Grammar';
    final t = issueType.toLowerCase();
    if (t.contains('spell')) return 'Spelling';
    if (t.contains('punct')) return 'Punctuation';
    if (t.contains('style')) return 'Style';
    return 'Grammar';
  }

  // ---------------------------------------------------------------------------
  // Offline heuristic fallback
  // ---------------------------------------------------------------------------

  /// Simple rule-based fallback used when LanguageTool API is unreachable.
  GrammarResult _offlineFallback(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    double score = words.length > 3 ? 72.0 : 65.0;
    final errors = <GrammarError>[];
    final lower = text.toLowerCase();

    // Map of known common spoken errors → correction + explanation
    const knownErrors = <String, (String, String, String)>{
      'i am going to went': ('tense', 'going to go', 'Mixed "going to" with past tense "went"'),
      "he don't": ('agreement', "he doesn't", 'Third-person singular requires "doesn\'t"'),
      "she don't": ('agreement', "she doesn't", 'Third-person singular requires "doesn\'t"'),
      'they was': ('agreement', 'they were', '"They" requires "were", not "was"'),
      'we was': ('agreement', 'we were', '"We" requires "were", not "was"'),
      'you is': ('agreement', 'you are', '"You" requires "are", not "is"'),
      'i seen': ('tense', 'I saw / I have seen', 'Missing auxiliary "have" or wrong tense'),
      'i done': ('tense', 'I did / I have done', 'Missing auxiliary "have" or wrong tense'),
      'me and him': ('pronoun', 'he and I', 'Use subject pronouns in subject position'),
    };

    for (final entry in knownErrors.entries) {
      if (lower.contains(entry.key)) {
        final val = entry.value;
        score -= 8;
        errors.add(GrammarError(
          type: val.$1,
          original: entry.key,
          correction: val.$2,
          explanation: val.$3,
        ));
      }
    }

    return GrammarResult(
      score: score.clamp(40.0, 90.0),
      correctedText: '',
      errors: errors,
      summary: errors.isEmpty
          ? 'Basic offline assessment — no obvious errors detected.'
          : '${errors.length} common error${errors.length == 1 ? '' : 's'} detected.',
    );
  }
}
