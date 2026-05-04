import 'dart:convert';
import '../../services/local_stt_service.dart';
enum SessionStatus {
  recording,
  pendingUpload,
  uploading,
  processing,
  completed,
  failed
}

class Session {
  final String sessionId;
  final String userId;
  final String type; // 'baseline' or 'daily_practice'
  final DateTime createdAt;
  final DateTime? completedAt;
  final SessionStatus status;
  final String? promptId;
  final String? promptText;
  final String? audioLocalPath;
  final String? audioRemoteUrl;
  final double? audioDuration;
  final String? transcript;
  final SessionScores? scores;
  final String? feedback;
  final List<WordInfo>? wordResults;
  final bool synced;

  // Advanced Feedback
  final List<String> grammarCorrections;
  final List<String> improvementTips;
  final List<String> advancedVocabulary;

  Session({
    required this.sessionId,
    required this.userId,
    required this.type,
    required this.createdAt,
    this.completedAt,
    required this.status,
    this.promptId,
    this.promptText,
    this.audioLocalPath,
    this.audioRemoteUrl,
    this.audioDuration,
    this.transcript,
    this.scores,
    this.feedback,
    this.wordResults,
    this.synced = false,
    this.grammarCorrections = const [],
    this.improvementTips = const [],
    this.advancedVocabulary = const [],
  });

  /// fromJson handles BOTH snake_case keys (from SQLite) and camelCase keys (from Firebase).
  factory Session.fromJson(Map<String, dynamic> json) {
    // Helper to read a key trying snake_case first, then camelCase
    T? pick<T>(String snakeKey, String camelKey) {
      final v = json[snakeKey] ?? json[camelKey];
      return v as T?;
    }

    // Rebuild scores from individual DB columns OR from nested 'scores' map
    SessionScores? scores;
    if (json['fluency_score'] != null) {
      scores = SessionScores(
        fluency: (json['fluency_score'] as num).toDouble(),
        grammar: (json['grammar_score'] as num).toDouble(),
        pronunciation: (json['pronunciation_score'] as num).toDouble(),
        composite: (json['composite_score'] as num).toDouble(),
        estimatedIELTSBand: (json['estimated_band'] as num? ?? 0).toDouble(),
      );
    } else if (json['scores'] != null) {
      scores = SessionScores.fromJson(json['scores'] as Map<String, dynamic>);
    }

    return Session(
      sessionId:    (json['session_id'] ?? json['sessionId']) as String,
      userId:       (json['user_id']    ?? json['userId'])    as String,
      type:          json['type']                             as String,
      createdAt:     DateTime.fromMillisecondsSinceEpoch(
                       (json['created_at'] ?? json['createdAt']) as int),
      completedAt:   (json['completed_at'] ?? json['completedAt']) != null
                       ? DateTime.fromMillisecondsSinceEpoch(
                           (json['completed_at'] ?? json['completedAt']) as int)
                       : null,
      status:        _parseStatus(json['status'] as String),
      promptId:      pick<String>('prompt_id',         'promptId'),
      promptText:    pick<String>('prompt_text',        'promptText'),
      audioLocalPath:pick<String>('audio_local_path',  'audioLocalPath'),
      audioRemoteUrl:pick<String>('audio_remote_url',  'audioUrl'),
      audioDuration: (json['audio_duration'] ?? json['audioDuration']) as double?,
      transcript:    json['transcript']                        as String?,
      scores:        scores,
      feedback:      json['feedback']                          as String?,
      wordResults:   json['word_results'] != null 
                       ? (jsonDecode(json['word_results'] as String) as List).map((w) => WordInfo.fromJson(w)).toList()
                       : (json['wordResults'] != null 
                           ? (json['wordResults'] as List).map((w) => WordInfo.fromJson(w)).toList()
                           : null),
      synced:        json['synced'] == 1 || json['synced'] == true,
      grammarCorrections: (json['grammar_corrections'] != null)
          ? (jsonDecode(json['grammar_corrections'] as String) as List).cast<String>()
          : (json['grammarCorrections'] != null ? (json['grammarCorrections'] as List).cast<String>() : const []),
      improvementTips: (json['improvement_tips'] != null)
          ? (jsonDecode(json['improvement_tips'] as String) as List).cast<String>()
          : (json['improvementTips'] != null ? (json['improvementTips'] as List).cast<String>() : const []),
      advancedVocabulary: (json['advanced_vocabulary'] != null)
          ? (jsonDecode(json['advanced_vocabulary'] as String) as List).cast<String>()
          : (json['advancedVocabulary'] != null ? (json['advancedVocabulary'] as List).cast<String>() : const []),
    );
  }

  static SessionStatus _parseStatus(String status) {
    switch (status) {
      case 'recording':
        return SessionStatus.recording;
      case 'pending_upload':
      case 'pendingUpload':
        return SessionStatus.pendingUpload;
      case 'uploading':
        return SessionStatus.uploading;
      case 'processing':
        return SessionStatus.processing;
      case 'completed':
        return SessionStatus.completed;
      case 'failed':
        return SessionStatus.failed;
      default:
        return SessionStatus.pendingUpload;
    }
  }

  String get statusString {
    switch (status) {
      case SessionStatus.recording:
        return 'recording';
      case SessionStatus.pendingUpload:
        return 'pending_upload';
      case SessionStatus.uploading:
        return 'uploading';
      case SessionStatus.processing:
        return 'processing';
      case SessionStatus.completed:
        return 'completed';
      case SessionStatus.failed:
        return 'failed';
    }
  }

  /// For Firebase serialisation (camelCase keys).
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'type': type,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'status': statusString,
      'promptId': promptId,
      'promptText': promptText,
      'audioLocalPath': audioLocalPath,
      'audioUrl': audioRemoteUrl,
      'audioDuration': audioDuration,
      'transcript': transcript,
      'scores': scores?.toJson(),
      'feedback': feedback,
      'wordResults': wordResults?.map((w) => w.toJson()).toList(),
      'synced': synced ? 1 : 0,
      'grammarCorrections': grammarCorrections,
      'improvementTips': improvementTips,
      'advancedVocabulary': advancedVocabulary,
    };
  }

  /// For SQLite inserts / updates — column names must match DatabaseHelper schema exactly.
  Map<String, dynamic> toDbMap() {
    return {
      'session_id':          sessionId,
      'user_id':             userId,
      'type':                type,
      'created_at':          createdAt.millisecondsSinceEpoch,
      'completed_at':        completedAt?.millisecondsSinceEpoch,
      'status':              statusString,
      'prompt_id':           promptId,
      'prompt_text':         promptText,
      'audio_local_path':    audioLocalPath,
      'audio_remote_url':    audioRemoteUrl,
      'audio_duration':      audioDuration,
      'transcript':          transcript,
      // Expand scores into individual columns
      'fluency_score':       scores?.fluency,
      'grammar_score':       scores?.grammar,
      'pronunciation_score': scores?.pronunciation,
      'composite_score':     scores?.composite,
      'estimated_band':      scores?.estimatedIELTSBand,
      'cefr_level':          scores?.cefrLevel,
      'feedback':            feedback,
      'word_results':        wordResults != null ? jsonEncode(wordResults!.map((w) => w.toJson()).toList()) : null,
      'synced':              synced ? 1 : 0,
      'grammar_corrections': jsonEncode(grammarCorrections),
      'improvement_tips':    jsonEncode(improvementTips),
      'advanced_vocabulary': jsonEncode(advancedVocabulary),
    };
  }


  Session copyWith({
    String? sessionId,
    String? userId,
    String? type,
    DateTime? createdAt,
    DateTime? completedAt,
    SessionStatus? status,
    String? promptId,
    String? promptText,
    String? audioLocalPath,
    String? audioRemoteUrl,
    double? audioDuration,
    String? transcript,
    SessionScores? scores,
    String? feedback,
    List<WordInfo>? wordResults,
    bool? synced,
  }) {
    return Session(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      promptId: promptId ?? this.promptId,
      promptText: promptText ?? this.promptText,
      audioLocalPath: audioLocalPath ?? this.audioLocalPath,
      audioRemoteUrl: audioRemoteUrl ?? this.audioRemoteUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      transcript: transcript ?? this.transcript,
      scores: scores ?? this.scores,
      feedback: feedback ?? this.feedback,
      wordResults: wordResults ?? this.wordResults,
      synced: synced ?? this.synced,
    );
  }
}

class SessionScores {
  final double fluency;
  final double grammar;
  final double pronunciation;
  final double composite;
  final double estimatedIELTSBand;
  final String cefrLevel; // A1, A2, B1, B2, C1, C2

  SessionScores({
    required this.fluency,
    required this.grammar,
    required this.pronunciation,
    required this.composite,
    required this.estimatedIELTSBand,
    this.cefrLevel = 'A1',
  });

  factory SessionScores.fromJson(Map<String, dynamic> json) {
    return SessionScores(
      fluency: (json['fluency'] as num).toDouble(),
      grammar: (json['grammar'] as num).toDouble(),
      pronunciation: (json['pronunciation'] as num).toDouble(),
      composite: (json['composite'] as num).toDouble(),
      estimatedIELTSBand: (json['estimatedIELTSBand'] as num? ?? 0).toDouble(),
      cefrLevel: json['cefrLevel'] as String? ?? 'A1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fluency': fluency,
      'grammar': grammar,
      'pronunciation': pronunciation,
      'composite': composite,
      'estimatedIELTSBand': estimatedIELTSBand,
      'cefrLevel': cefrLevel,
    };
  }
}
