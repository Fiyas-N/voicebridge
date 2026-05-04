import 'dart:io';
import 'package:flutter/foundation.dart';
import 'local_stt_service.dart';
import 'local_llm_service.dart';
import 'grammar_service.dart';
import 'pronunciation_service.dart';
import 'feedback_service.dart';

/// AI Processing Pipeline
/// Orchestrates all AI services to analyze speech recordings
class AIProcessingPipeline {
  final LocalSttService _sttService = LocalSttService();
  final GrammarAnalysisService _grammarService = GrammarAnalysisService();
  final PronunciationService _pronunciationService = PronunciationService();
  final FeedbackService _feedbackService = FeedbackService();

  /// Process audio file through the fully on-device pipeline:
  ///   STT      → Whisper tiny  (on-device, audio never leaves phone)
  ///   Grammar  → LanguageTool API (online) or heuristics (offline) — no LLM
  ///   LLM      → Gemma 3 1B (on-device, loaded once for feedback only)
  ///   TTS      → Kokoro (on-device, handled by TtsService upstream)
  Future<SessionAnalysis> processRecording({
    required String audioPath,
    required String promptText,
  }) async {
    final llm = LocalLlmService();
    try {
      // Step 1: Transcribe audio — Whisper runs fully on-device
      debugPrint('Pipeline: Starting STT transcription…');
      final transcription = await _sttService.transcribe(audioPath);

      if (transcription.transcript.trim().isEmpty) {
        throw Exception('No speech detected in audio');
      }

      // Step 2: Grammar analysis — LanguageTool API (online) or heuristics
      // NOTE: No LLM needed here — Gemma is reserved for feedback only.
      debugPrint('Pipeline: Running grammar analysis…');
      final grammar = await _grammarService.analyzeGrammar(transcription.transcript);

      // Step 3: Pronunciation assessment (heuristics, no extra model)
      final pronunciation = await _pronunciationService.assessPronunciation(
        audioPath: audioPath,
        referenceText: promptText,
      );

      // Step 4: Score calculation
      final overallScore = _calculateOverallScore(
        fluency: pronunciation.fluencyScore,
        grammar: grammar.score,
        pronunciation: pronunciation.overallScore,
      );
      final ieltsBand = _mapToSpeakingBand(overallScore);
      final cefr = _mapToCEFR(overallScore);

      // Step 5: Load Gemma — STT done, grammar done, now we need feedback.
      // warmLoad() was already called at recording start so this is usually instant.
      debugPrint('Pipeline: Loading Gemma 3 1B for feedback… RSS: ${ProcessInfo.currentRss ~/ 1024 ~/ 1024}MB');
      await llm.loadModel();

      // Step 6: Personalised feedback — single Gemma call
      final errorTypes = grammar.errors.map((e) => e.type).toSet().toList();
      final feedback = await _feedbackService.generateFeedback(
        fluencyScore: pronunciation.fluencyScore,
        grammarScore: grammar.score,
        pronunciationScore: pronunciation.overallScore,
        grammarErrors: errorTypes,
        correctedSentence: grammar.correctedText,
      );

      // Step 7: Unload LLM immediately — free RAM before TTS loads
      debugPrint('Pipeline: Unloading LLM… RSS: ${ProcessInfo.currentRss ~/ 1024 ~/ 1024}MB');
      await llm.unloadModel();

      debugPrint('Pipeline: Complete.');
      return SessionAnalysis(
        transcription: transcription.transcript,
        transcriptionConfidence: transcription.confidence,
        wordResults: transcription.words,
        fluencyScore: pronunciation.fluencyScore,
        grammarScore: grammar.score,
        pronunciationScore: pronunciation.overallScore,
        overallScore: overallScore,
        ieltsBand: ieltsBand,
        cefrLevel: cefr,
        feedback: feedback,
        grammarErrors: grammar.errors,
        correctedText: grammar.correctedText,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      await llm.unloadModel(); // always free RAM on error
      throw Exception('AI processing failed: $e');
    }
  }

  /// Calculate weighted overall score
  /// Fluency: 40%, Grammar: 35%, Pronunciation: 25%
  double _calculateOverallScore({
    required double fluency,
    required double grammar,
    required double pronunciation,
  }) {
    return (fluency * 0.40) + (grammar * 0.35) + (pronunciation * 0.25);
  }

  /// Map overall score to estimated speaking proficiency band (4–9 scale)
  double _mapToSpeakingBand(double score) {
    if (score > 90) return 9.0;
    if (score > 75) return 8.0;
    if (score > 60) return 7.0;
    if (score > 45) return 6.0;
    if (score > 30) return 5.0;
    return 4.0;
  }

  /// Map overall score to CEFR level (A1→C2)
  static String mapToCEFR(double score) {
    if (score >= 85) return 'C2';
    if (score >= 75) return 'C1';
    if (score >= 65) return 'B2';
    if (score >= 50) return 'B1';
    if (score >= 40) return 'A2';
    return 'A1';
  }

  String _mapToCEFR(double score) => AIProcessingPipeline.mapToCEFR(score);
}

/// Session Analysis Result
/// Contains all analysis results from the AI pipeline
class SessionAnalysis {
  final String transcription;
  final double transcriptionConfidence;
  final List<WordInfo> wordResults; // per-word confidence for highlighting
  final double fluencyScore;
  final double grammarScore;
  final double pronunciationScore;
  final double overallScore;
  final double ieltsBand;
  final String cefrLevel; // A1, A2, B1, B2, C1, C2
  final String feedback;
  final List<GrammarError> grammarErrors;
  final String correctedText;
  final DateTime timestamp;

  SessionAnalysis({
    required this.transcription,
    required this.transcriptionConfidence,
    this.wordResults = const [],
    required this.fluencyScore,
    required this.grammarScore,
    required this.pronunciationScore,
    required this.overallScore,
    required this.ieltsBand,
    required this.cefrLevel,
    required this.feedback,
    required this.grammarErrors,
    required this.correctedText,
    required this.timestamp,
  });

  /// Get speaking band descriptor
  String get bandDescriptor {
    if (cefrLevel == 'C2') return 'Mastery';
    if (cefrLevel == 'C1') return 'Advanced';
    if (cefrLevel == 'B2') return 'Upper Intermediate';
    if (cefrLevel == 'B1') return 'Intermediate';
    if (cefrLevel == 'A2') return 'Elementary';
    return 'Beginner';
  }

  /// Color for CEFR badge
  static Map<String, int> cefrColor(String cefr) {
    switch (cefr) {
      case 'C2': return {'r': 255, 'g': 215, 'b': 0};   // gold
      case 'C1': return {'r': 107, 'g': 203, 'b': 119}; // green
      case 'B2': return {'r': 78,  'g': 205, 'b': 196}; // teal
      case 'B1': return {'r': 78,  'g': 121, 'b': 255}; // blue
      case 'A2': return {'r': 199, 'g': 125, 'b': 255}; // purple
      default:   return {'r': 180, 'g': 180, 'b': 180}; // grey (A1)
    }
  }

  /// Convert to JSON for cloud sync (metadata only)
  Map<String, dynamic> toCloudJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'fluencyScore': fluencyScore,
      'grammarScore': grammarScore,
      'pronunciationScore': pronunciationScore,
      'overallScore': overallScore,
      'ieltsBand': ieltsBand,
      'cefrLevel': cefrLevel,
    };
  }

  /// Convert to JSON for local storage (full data)
  Map<String, dynamic> toLocalJson() {
    return {
      ...toCloudJson(),
      'transcription': transcription,
      'transcriptionConfidence': transcriptionConfidence,
      'feedback': feedback,
      'grammarErrors': grammarErrors.map((e) => e.toJson()).toList(),
      'correctedText': correctedText,
    };
  }
}
