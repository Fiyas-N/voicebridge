import 'package:flutter/foundation.dart';

// ── Public data models (interface unchanged — callers need no edits) ──────────

class GrammarError {
  final String type;
  final String original;
  final String correction;
  final String explanation;

  const GrammarError({
    required this.type,
    required this.original,
    required this.correction,
    required this.explanation,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'original': original,
        'correction': correction,
        'explanation': explanation,
      };
}

class GrammarResult {
  final double score;
  final String correctedText;
  final List<GrammarError> errors;
  final String summary;

  /// Always true — grammar is now 100% offline rule-based.
  final bool usedHeuristics;

  const GrammarResult({
    required this.score,
    required this.correctedText,
    required this.errors,
    required this.summary,
    this.usedHeuristics = true,
  });
}

// ── Internal rule definition ──────────────────────────────────────────────────

class _Rule {
  final RegExp pattern;
  final String type;

  /// Suggestion string. Use \$1, \$2 for capture groups if pattern has them.
  final String suggestion;
  final String explanation;

  const _Rule(this.pattern, this.type, this.suggestion, this.explanation);
}

// ── Grammar Analysis Service — 100% offline, zero network dependencies ────────

/// Analyses spoken English text against a curated set of grammar rules.
///
/// Rules cover:
///   • Subject-verb agreement
///   • Tense errors (double-past, wrong participles)
///   • Double comparatives / superlatives
///   • Double negatives
///   • Pronoun case errors
///   • Stative verb misuse (Indian English / ESL)
///   • Preposition misuse
///   • Common spoken collocations
///
/// No internet required. Instant. No model loading.
class GrammarAnalysisService {
  static final List<_Rule> _rules = [
    // ── Subject-verb agreement ────────────────────────────────────────────────
    _Rule(RegExp(r'\bI are\b', caseSensitive: false), 'agreement',
        'I am', '"I" takes "am", not "are"'),
    _Rule(RegExp(r'\bI were\b', caseSensitive: false), 'agreement',
        'I was', '"I" takes "was" in simple past, not "were" (except subjunctive)'),
    _Rule(RegExp(r'\bI goes\b', caseSensitive: false), 'agreement',
        'I go', '"I" takes "go", not "goes"'),
    _Rule(RegExp(r'\bhe go\b(?!es)', caseSensitive: false), 'agreement',
        'he goes', 'Third-person singular "he" requires "goes"'),
    _Rule(RegExp(r'\bshe go\b(?!es)', caseSensitive: false), 'agreement',
        'she goes', 'Third-person singular "she" requires "goes"'),
    _Rule(RegExp(r'\bit go\b(?!es)', caseSensitive: false), 'agreement',
        'it goes', 'Third-person singular "it" requires "goes"'),
    _Rule(RegExp(r'\bhe are\b', caseSensitive: false), 'agreement',
        'he is', '"He" requires "is", not "are"'),
    _Rule(RegExp(r'\bshe are\b', caseSensitive: false), 'agreement',
        'she is', '"She" requires "is", not "are"'),
    _Rule(RegExp(r'\bit are\b', caseSensitive: false), 'agreement',
        'it is', '"It" requires "is", not "are"'),
    _Rule(RegExp(r'\bthey was\b', caseSensitive: false), 'agreement',
        'they were', '"They" requires "were", not "was"'),
    _Rule(RegExp(r'\bwe was\b', caseSensitive: false), 'agreement',
        'we were', '"We" requires "were", not "was"'),
    _Rule(RegExp(r'\byou was\b', caseSensitive: false), 'agreement',
        'you were', '"You" requires "were", not "was"'),
    _Rule(RegExp(r"\bhe don't\b", caseSensitive: false), 'agreement',
        "he doesn't", 'Third-person singular requires "doesn\'t"'),
    _Rule(RegExp(r"\bshe don't\b", caseSensitive: false), 'agreement',
        "she doesn't", 'Third-person singular requires "doesn\'t"'),
    _Rule(RegExp(r"\bit don't\b", caseSensitive: false), 'agreement',
        "it doesn't", 'Third-person singular requires "doesn\'t"'),
    _Rule(RegExp(r"\bhe have\b", caseSensitive: false), 'agreement',
        'he has', 'Third-person singular "he" requires "has"'),
    _Rule(RegExp(r"\bshe have\b", caseSensitive: false), 'agreement',
        'she has', 'Third-person singular "she" requires "has"'),
    _Rule(RegExp(r"\bit have\b", caseSensitive: false), 'agreement',
        'it has', 'Third-person singular "it" requires "has"'),

    // ── Tense errors ──────────────────────────────────────────────────────────
    _Rule(RegExp(r'\bdid went\b', caseSensitive: false), 'tense',
        'went', '"Did" already marks past tense — use base form or just "went"'),
    _Rule(RegExp(r'\bdid came\b', caseSensitive: false), 'tense',
        'came', 'Use "came" not "did came"'),
    _Rule(RegExp(r'\bdid saw\b', caseSensitive: false), 'tense',
        'saw', 'Use "saw" not "did saw"'),
    _Rule(RegExp(r'\bdid eaten\b', caseSensitive: false), 'tense',
        'ate', 'Use "ate" not "did eaten"'),
    _Rule(RegExp(r'\bI have went\b', caseSensitive: false), 'tense',
        'I have gone', 'Past participle of "go" is "gone", not "went"'),
    _Rule(RegExp(r'\bI have ate\b', caseSensitive: false), 'tense',
        'I have eaten', 'Past participle of "eat" is "eaten", not "ate"'),
    _Rule(RegExp(r'\bI have ran\b', caseSensitive: false), 'tense',
        'I have run', 'Past participle of "run" is "run", not "ran"'),
    _Rule(RegExp(r'\bI have saw\b', caseSensitive: false), 'tense',
        'I have seen', 'Past participle of "see" is "seen", not "saw"'),
    _Rule(RegExp(r'\bI have came\b', caseSensitive: false), 'tense',
        'I have come', 'Past participle of "come" is "come", not "came"'),
    _Rule(RegExp(r'\bI have drove\b', caseSensitive: false), 'tense',
        'I have driven', 'Past participle of "drive" is "driven"'),
    _Rule(RegExp(r'\bI have broke\b', caseSensitive: false), 'tense',
        'I have broken', 'Past participle of "break" is "broken"'),
    _Rule(RegExp(r'\bI have spoke\b', caseSensitive: false), 'tense',
        'I have spoken', 'Past participle of "speak" is "spoken"'),
    _Rule(RegExp(r'\bI seen\b', caseSensitive: false), 'tense',
        'I saw / I have seen', 'Missing auxiliary "have", or use simple past "saw"'),
    _Rule(RegExp(r'\bI done\b', caseSensitive: false), 'tense',
        'I did / I have done', 'Use "I did" (simple past) or "I have done" (present perfect)'),
    _Rule(RegExp(r'\bI been\b', caseSensitive: false), 'tense',
        'I have been', 'Missing auxiliary "have": use "I have been"'),

    // ── Double comparatives / superlatives ────────────────────────────────────
    _Rule(RegExp(r'\bmore better\b', caseSensitive: false), 'comparative',
        'better', '"Better" is already comparative — don\'t add "more"'),
    _Rule(RegExp(r'\bmore faster\b', caseSensitive: false), 'comparative',
        'faster', '"Faster" is already comparative'),
    _Rule(RegExp(r'\bmore taller\b', caseSensitive: false), 'comparative',
        'taller', '"Taller" is already comparative'),
    _Rule(RegExp(r'\bmore stronger\b', caseSensitive: false), 'comparative',
        'stronger', '"Stronger" is already comparative'),
    _Rule(RegExp(r'\bmore smarter\b', caseSensitive: false), 'comparative',
        'smarter', '"Smarter" is already comparative'),
    _Rule(RegExp(r'\bmore harder\b', caseSensitive: false), 'comparative',
        'harder', '"Harder" is already comparative'),
    _Rule(RegExp(r'\bmost tallest\b', caseSensitive: false), 'comparative',
        'tallest', '"Tallest" is already superlative — don\'t add "most"'),
    _Rule(RegExp(r'\bmost best\b', caseSensitive: false), 'comparative',
        'best', '"Best" is already superlative'),
    _Rule(RegExp(r'\bmost worst\b', caseSensitive: false), 'comparative',
        'worst', '"Worst" is already superlative'),

    // ── Double negatives ──────────────────────────────────────────────────────
    _Rule(RegExp(r"\bdon't have no\b", caseSensitive: false), 'negation',
        "don't have any", 'Double negative — use "don\'t have any"'),
    _Rule(RegExp(r"\bcan't do nothing\b", caseSensitive: false), 'negation',
        "can't do anything", 'Double negative — use "can\'t do anything"'),
    _Rule(RegExp(r"\bdidn't do nothing\b", caseSensitive: false), 'negation',
        "didn't do anything", 'Double negative — use "didn\'t do anything"'),
    _Rule(RegExp(r"\bnever did nothing\b", caseSensitive: false), 'negation',
        'never did anything', 'Double negative — use "never did anything"'),
    _Rule(RegExp(r"\bwon't never\b", caseSensitive: false), 'negation',
        "will never", 'Double negative — use "will never"'),

    // ── Pronoun case ──────────────────────────────────────────────────────────
    _Rule(RegExp(r'\bme and him\b', caseSensitive: false), 'pronoun',
        'he and I', 'Use subject pronouns in subject position: "he and I"'),
    _Rule(RegExp(r'\bme and her\b', caseSensitive: false), 'pronoun',
        'she and I', 'Use subject pronouns in subject position: "she and I"'),
    _Rule(RegExp(r'\bhim and me\b', caseSensitive: false), 'pronoun',
        'he and I', 'Use subject pronouns: "he and I"'),
    _Rule(RegExp(r'\bher and me\b', caseSensitive: false), 'pronoun',
        'she and I', 'Use subject pronouns: "she and I"'),
    _Rule(RegExp(r'\bme and my friend\b', caseSensitive: false), 'pronoun',
        'my friend and I', 'Place "I" last in compound subjects'),
    _Rule(RegExp(r'\bme and \w+\b(?= (?:went|are|is|was|were|have|had|do|did|can|will|would|should))',
        caseSensitive: false), 'pronoun',
        'I and ...', '"Me" cannot be a subject — use "I"'),

    // ── Stative verb misuse (very common in Indian English / ESL) ────────────
    _Rule(RegExp(r'\bI am having\b', caseSensitive: false), 'stative verb',
        'I have', '"Have" is stative — use simple present: "I have"'),
    _Rule(RegExp(r'\bhe is having\b', caseSensitive: false), 'stative verb',
        'he has', '"Have" is stative — "he has"'),
    _Rule(RegExp(r'\bshe is having\b', caseSensitive: false), 'stative verb',
        'she has', '"Have" is stative — "she has"'),
    _Rule(RegExp(r'\bthey are having\b', caseSensitive: false), 'stative verb',
        'they have', '"Have" is stative — "they have"'),
    _Rule(RegExp(r'\bI am knowing\b', caseSensitive: false), 'stative verb',
        'I know', '"Know" is stative — "I know"'),
    _Rule(RegExp(r'\bI am understanding\b', caseSensitive: false), 'stative verb',
        'I understand', '"Understand" is stative — "I understand"'),
    _Rule(RegExp(r'\bI am wanting\b', caseSensitive: false), 'stative verb',
        'I want', '"Want" is stative — "I want"'),
    _Rule(RegExp(r'\bI am needing\b', caseSensitive: false), 'stative verb',
        'I need', '"Need" is stative — "I need"'),
    _Rule(RegExp(r'\bI am believing\b', caseSensitive: false), 'stative verb',
        'I believe', '"Believe" is stative — "I believe"'),

    // ── Preposition / duration errors ─────────────────────────────────────────
    _Rule(RegExp(r'\bsince \d+ years\b', caseSensitive: false), 'preposition',
        'for ... years', 'Use "for" with durations, "since" with a point in time'),
    _Rule(RegExp(r'\bsince \d+ months\b', caseSensitive: false), 'preposition',
        'for ... months', 'Use "for" with durations'),
    _Rule(RegExp(r'\bsince \d+ days\b', caseSensitive: false), 'preposition',
        'for ... days', 'Use "for" with durations'),

    // ── Common spoken collocations ─────────────────────────────────────────────
    _Rule(RegExp(r'\bvery much good\b', caseSensitive: false), 'word choice',
        'very good', '"Very much good" is non-standard — use "very good"'),
    _Rule(RegExp(r'\bdoing the needful\b', caseSensitive: false), 'word choice',
        'doing what is necessary', '"Doing the needful" is not standard outside South Asia'),
    _Rule(RegExp(r'\bprepone\b', caseSensitive: false), 'word choice',
        'reschedule to an earlier time', '"Prepone" is not standard English'),
    _Rule(RegExp(r'\bI am going to went\b', caseSensitive: false), 'tense',
        'I am going to go', 'Mixed tenses — "going to" takes base form'),
    _Rule(RegExp(r'\byesterday I have\b', caseSensitive: false), 'tense',
        'yesterday I', '"Yesterday" signals simple past, not present perfect'),
  ];

  // ── Score weights per error type ───────────────────────────────────────────
  static const Map<String, double> _penalty = {
    'agreement': 8.0,
    'tense': 8.0,
    'negation': 6.0,
    'pronoun': 5.0,
    'comparative': 5.0,
    'stative verb': 4.0,
    'preposition': 4.0,
    'word choice': 3.0,
  };

  /// Analyse [text] against the offline rule set and return a [GrammarResult].
  Future<GrammarResult> analyzeGrammar(String text) async {
    if (text.trim().isEmpty) {
      return const GrammarResult(
        score: 0,
        correctedText: '',
        errors: [],
        summary: 'No text to analyse.',
        usedHeuristics: true,
      );
    }

    // ── Match all rules, track spans to avoid overlapping highlights ──────────
    final List<({int start, int end, GrammarError error})> hits = [];

    for (final rule in _rules) {
      for (final match in rule.pattern.allMatches(text)) {
        // Skip if this span overlaps an already-matched range
        final overlaps = hits.any(
          (h) => h.start < match.end && h.end > match.start,
        );
        if (overlaps) continue;

        final original = match.group(0) ?? '';

        // Expand capture-group references in suggestion ($1, $2…)
        String correction = rule.suggestion;
        for (int g = 1; g <= match.groupCount; g++) {
          correction = correction.replaceAll('\$$g', match.group(g) ?? '');
        }

        hits.add((
          start: match.start,
          end: match.end,
          error: GrammarError(
            type: rule.type,
            original: original,
            correction: correction,
            explanation: rule.explanation,
          ),
        ));
      }
    }

    // ── Build corrected text (apply replacements end → start) ─────────────────
    final sortedHits = hits.toList()
      ..sort((a, b) => b.start.compareTo(a.start));

    String corrected = text;
    for (final h in sortedHits) {
      corrected = corrected.replaceRange(h.start, h.end, h.error.correction);
    }

    // ── Score ─────────────────────────────────────────────────────────────────
    double score = 100.0;
    for (final h in hits) {
      score -= _penalty[h.error.type] ?? 4.0;
    }
    score = score.clamp(30.0, 100.0);

    final errors = hits.map((h) => h.error).toList();
    final summary = errors.isEmpty
        ? 'No grammar issues detected — great speaking!'
        : '${errors.length} issue${errors.length == 1 ? '' : 's'} found.';

    debugPrint(
        'Grammar: ${errors.length} issue(s) — score ${score.toStringAsFixed(0)} (offline rules).');

    return GrammarResult(
      score: score,
      correctedText: corrected,
      errors: errors,
      summary: summary,
      usedHeuristics: true,
    );
  }
}
