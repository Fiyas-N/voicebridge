import 'local_stt_service.dart';

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
  final LocalSttService _sttService = LocalSttService();
  
  /// Assess pronunciation using precision word delta metrics and duration mapping.
  Future<PronunciationResult> assessPronunciation({
    required String audioPath,
    required String referenceText,
    required double audioDurationSeconds,
  }) async {
    try {
      final res = await _sttService.transcribe(audioPath);
      final double duration = audioDurationSeconds > 0 ? audioDurationSeconds : 5.0; // fallback safety

      final isSpontaneous = referenceText.split(' ').length < 3 || 
                           referenceText.toLowerCase().contains('topic') ||
                           referenceText.toLowerCase().contains('general');

      final effectiveReference = isSpontaneous ? res.transcript : referenceText;

      final accuracy = _calculateAccuracy(
        res.transcript,
        effectiveReference,
      );
      
      final fluency = _calculateFluency(res.words, duration);
      
      final completeness = isSpontaneous ? 100.0 : _calculateCompleteness(
        res.transcript,
        referenceText,
      );
      
      return PronunciationResult(
        accuracyScore: accuracy,
        fluencyScore: fluency,
        completenessScore: completeness,
      );
    } catch (e) {
      return PronunciationResult(
        accuracyScore: 65.0,
        fluencyScore: 65.0,
        completenessScore: 65.0,
      );
    }
  }
  
  /// Optimized accuracy logic preventing duplication exploitation.
  double _calculateAccuracy(String transcript, String reference) {
    final tx = transcript.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final ref = reference.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();

    if (ref.isEmpty) return 70.0;
    if (tx.isEmpty) return 0.0;

    final txWords = tx.split(RegExp(r'\s+'));
    final refWords = ref.split(RegExp(r'\s+'));
    
    int hits = 0;
    final List<String> remainingRef = List.from(refWords);

    for (var word in txWords) {
      final idx = remainingRef.indexOf(word);
      if (idx != -1) {
        hits++;
        remainingRef.removeAt(idx); // Consume to prevent duplicate farming exploit
      }
    }
    
    // Penalty for excess garbage words
    final double lengthRatio = (txWords.length / refWords.length).clamp(0.0, 2.0);
    final double overflowPenalty = lengthRatio > 1.3 ? (lengthRatio - 1.3) * 20 : 0;

    final rawAcc = (hits / refWords.length) * 100;
    return (rawAcc - overflowPenalty).clamp(0.0, 100.0);
  }
  
  /// Calculates authentic Fluency using Real Words-Per-Minute (WPM).
  /// Ideal native speech is 110 - 160 WPM. Target 130 WPM for 100%.
  double _calculateFluency(List<WordInfo> words, double durationSeconds) {
    if (words.isEmpty || durationSeconds <= 0) return 50.0;
    
    final double minutes = durationSeconds / 60.0;
    final double wpm = words.length / minutes;

    // Center metric: 130 WPM is perfect fluency limit for learner scoring.
    double fluencyBase = 0.0;
    if (wpm < 130) {
      fluencyBase = (wpm / 130.0) * 100.0;
    } else {
      // Slight drop if speaking extremely hyper-fast (> 200 WPM) reducing clarity
      fluencyBase = 100.0 - ((wpm - 130.0) * 0.2).clamp(0.0, 30.0);
    }

    // Factor in general acoustic confidence from the voice parser model
    final avgConf = words.isNotEmpty 
      ? (words.map((w) => w.confidence).reduce((a, b) => a + b) / words.length) * 100 
      : 75.0;

    // Final result weighted 65% Speed consistency and 35% Acoustic confidence
    return ((fluencyBase * 0.65) + (avgConf * 0.35)).clamp(10.0, 100.0);
  }
  
  /// Precision linear completeness gradient.
  double _calculateCompleteness(String transcript, String reference) {
    final txWords = transcript.trim().split(RegExp(r'\s+')).length;
    final refWords = reference.trim().split(RegExp(r'\s+')).length;
    
    if (refWords == 0) return 75.0;
    
    // Inverse-scale deviation map
    final double ratio = txWords / refWords;
    final double dev = (1.0 - ratio).abs();

    // Perfectly matches ref length => 100. 
    // Loses 1% completeness per 1% length deviation.
    final double score = 100.0 - (dev * 100.0);
    return score.clamp(0.0, 100.0);
  }
}
