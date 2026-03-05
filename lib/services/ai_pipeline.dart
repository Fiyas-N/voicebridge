import 'speech_to_text_service.dart';
import 'grammar_service.dart';
import 'pronunciation_service.dart';
import 'feedback_service.dart';

/// AI Processing Pipeline
/// Orchestrates all AI services to analyze speech recordings
class AIProcessingPipeline {
  final SpeechToTextService _sttService = SpeechToTextService();
  final GrammarAnalysisService _grammarService = GrammarAnalysisService();
  final PronunciationService _pronunciationService = PronunciationService();
  final FeedbackService _feedbackService = FeedbackService();
  
  /// Process audio file through complete AI pipeline
  Future<SessionAnalysis> processRecording({
    required String audioPath,
    required String promptText,
  }) async {
    try {
      // Step 1: Transcribe audio to text using Groq Whisper
      final transcription = await _sttService.transcribeAudio(audioPath);
      
      if (transcription.transcript.trim().isEmpty) {
        throw Exception('No speech detected in audio');
      }
      
      // Step 2 & 3: Analyze grammar and pronunciation in parallel
      final results = await Future.wait([
        _grammarService.analyzeGrammar(transcription.transcript),
        _pronunciationService.assessPronunciation(
          audioPath: audioPath,
          referenceText: promptText,
        ),
      ]);
      
      final grammar = results[0] as GrammarResult;
      final pronunciation = results[1] as PronunciationResult;
      
      // Step 4: Calculate overall score
      final overallScore = _calculateOverallScore(
        fluency: pronunciation.fluencyScore,
        grammar: grammar.score,
        pronunciation: pronunciation.overallScore,
      );
      
      // Step 5: Map to IELTS band
      final ieltsBand = _mapToIELTSBand(overallScore);
      
      // Step 6: Generate personalized feedback using Groq Llama
      final errorTypes = grammar.errors.map((e) => e.type).toSet().toList();
      
      final feedback = await _feedbackService.generateFeedback(
        fluencyScore: pronunciation.fluencyScore,
        grammarScore: grammar.score,
        pronunciationScore: pronunciation.overallScore,
        grammarErrors: errorTypes,
        correctedSentence: grammar.correctedText,   // corrected text only, not raw transcript
      );
      
      return SessionAnalysis(
        transcription: transcription.transcript,
        transcriptionConfidence: transcription.confidence,
        fluencyScore: pronunciation.fluencyScore,
        grammarScore: grammar.score,
        pronunciationScore: pronunciation.overallScore,
        overallScore: overallScore,
        ieltsBand: ieltsBand,
        feedback: feedback,
        grammarErrors: grammar.errors,
        correctedText: grammar.correctedText,
        timestamp: DateTime.now(),
      );
    } catch (e) {
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
  
  /// Map overall score to estimated speaking proficiency band
  double _mapToIELTSBand(double score) {
    if (score > 90) return 9.0;
    if (score > 75) return 8.0;
    if (score > 60) return 7.0;
    if (score > 45) return 6.0;
    if (score > 30) return 5.0;
    return 4.0;
  }

}

/// Session Analysis Result
/// Contains all analysis results from the AI pipeline
class SessionAnalysis {
  final String transcription;
  final double transcriptionConfidence;
  final double fluencyScore;
  final double grammarScore;
  final double pronunciationScore;
  final double overallScore;
  final double ieltsBand;
  final String feedback;
  final List<GrammarError> grammarErrors;
  final String correctedText;
  final DateTime timestamp;
  
  SessionAnalysis({
    required this.transcription,
    required this.transcriptionConfidence,
    required this.fluencyScore,
    required this.grammarScore,
    required this.pronunciationScore,
    required this.overallScore,
    required this.ieltsBand,
    required this.feedback,
    required this.grammarErrors,
    required this.correctedText,
    required this.timestamp,
  });
  
  /// Get speaking band descriptor
  String get bandDescriptor {
    if (ieltsBand >= 9.0) return 'Expert User';
    if (ieltsBand >= 8.0) return 'Very Good User';
    if (ieltsBand >= 7.0) return 'Good User';
    if (ieltsBand >= 6.0) return 'Competent User';
    if (ieltsBand >= 5.0) return 'Modest User';
    return 'Limited User';
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
