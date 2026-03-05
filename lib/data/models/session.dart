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
  final bool synced;

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
    this.synced = false,
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
      synced:        json['synced'] == 1 || json['synced'] == true,
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

  /// For Firebase / Groq API serialisation (camelCase keys).
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
      'synced': synced ? 1 : 0,
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
      'feedback':            feedback,
      'synced':              synced ? 1 : 0,
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

  SessionScores({
    required this.fluency,
    required this.grammar,
    required this.pronunciation,
    required this.composite,
    required this.estimatedIELTSBand,
  });

  factory SessionScores.fromJson(Map<String, dynamic> json) {
    return SessionScores(
      fluency: (json['fluency'] as num).toDouble(),
      grammar: (json['grammar'] as num).toDouble(),
      pronunciation: (json['pronunciation'] as num).toDouble(),
      composite: (json['composite'] as num).toDouble(),
      estimatedIELTSBand: (json['estimatedIELTSBand'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fluency': fluency,
      'grammar': grammar,
      'pronunciation': pronunciation,
      'composite': composite,
      'estimatedIELTSBand': estimatedIELTSBand,
    };
  }
}
