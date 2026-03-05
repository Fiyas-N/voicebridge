import 'speech_to_text_service.dart';

class PronunciationResult {
  final double accuracyScore;
  final double fluencyScore;
  final double completenessScore;
  final double overallScore;

  PronunciationResult({
    required this.accuracyScore,
    required this.fluencyScore,
    required this.completenessScore,
  }) : overallScore = (accuracyScore + fluencyScore + completenessScore) / 3;
}

class PronunciationService {
  final SpeechToTextService _sttService = SpeechToTextService();
  
  /// Assess pronunciation using Whisper confidence scores (FREE - no external API)
  Future<PronunciationResult> assessPronunciation({
    required String audioPath,
    required String referenceText,
  }) async {
    try {
      // Use Whisper transcription with word-level confidence
      final transcription = await _sttService.transcribeAudio(audioPath);
      
      // Calculate accuracy based on transcription match
      final accuracy = _calculateAccuracy(
        transcription.transcript,
        referenceText,
      );
      
      // Calculate fluency based on word confidence scores
      final fluency = _calculateFluency(transcription.words);
      
      // Calculate completeness based on word count match
      final completeness = _calculateCompleteness(
        transcription.transcript,
        referenceText,
      );
      
      return PronunciationResult(
        accuracyScore: accuracy,
        fluencyScore: fluency,
        completenessScore: completeness,
      );
    } catch (e) {
      // Return default scores on error
      return PronunciationResult(
        accuracyScore: 70.0,
        fluencyScore: 70.0,
        completenessScore: 70.0,
      );
    }
  }
  
  double _calculateAccuracy(String transcript, String reference) {
    // Normalize texts
    final transcriptWords = transcript.toLowerCase().split(RegExp(r'\s+'));
    final referenceWords = reference.toLowerCase().split(RegExp(r'\s+'));
    
    // Calculate word overlap
    int matches = 0;
    for (var word in transcriptWords) {
      if (referenceWords.contains(word)) {
        matches++;
      }
    }
    
    if (referenceWords.isEmpty) return 70.0;
    
    // Score based on word match percentage
    final matchPercentage = (matches / referenceWords.length) * 100;
    return matchPercentage.clamp(0.0, 100.0);
  }
  
  double _calculateFluency(List<WordInfo> words) {
    if (words.isEmpty) return 70.0;
    
    // Average word confidence from Whisper
    final avgConfidence = words
        .map((w) => w.confidence)
        .reduce((a, b) => a + b) / words.length;
    
    // Convert to 0-100 scale
    return (avgConfidence * 100).clamp(0.0, 100.0);
  }
  
  double _calculateCompleteness(String transcript, String reference) {
    final transcriptWords = transcript.split(RegExp(r'\s+'));
    final referenceWords = reference.split(RegExp(r'\s+'));
    
    if (referenceWords.isEmpty) return 70.0;
    
    // Score based on word count ratio
    final ratio = transcriptWords.length / referenceWords.length;
    
    // Ideal is 0.8-1.2 ratio (80-120% of expected length)
    if (ratio >= 0.8 && ratio <= 1.2) {
      return 90.0;
    } else if (ratio >= 0.6 && ratio <= 1.4) {
      return 75.0;
    } else {
      return 60.0;
    }
  }
}
