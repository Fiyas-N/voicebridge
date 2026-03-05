class UserProfile {
  final String userId;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool baselineCompleted;
  final DateTime? baselineCompletedAt;
  final int currentStreak;
  final int longestStreak;
  final int totalSessions;
  final BaselineScores? baselineScores;
  final List<String> weakAreas;

  UserProfile({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.lastActiveAt,
    this.baselineCompleted = false,
    this.baselineCompletedAt,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalSessions = 0,
    this.baselineScores,
    this.weakAreas = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      lastActiveAt: DateTime.fromMillisecondsSinceEpoch(json['lastActiveAt'] as int),
      baselineCompleted: json['baselineCompleted'] as bool? ?? false,
      baselineCompletedAt: json['baselineCompletedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['baselineCompletedAt'] as int)
          : null,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      totalSessions: json['totalSessions'] as int? ?? 0,
      baselineScores: json['baselineScores'] != null
          ? BaselineScores.fromJson(json['baselineScores'] as Map<String, dynamic>)
          : null,
      weakAreas: json['weakAreas'] != null
          ? List<String>.from(json['weakAreas'] as List)
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastActiveAt': lastActiveAt.millisecondsSinceEpoch,
      'baselineCompleted': baselineCompleted,
      'baselineCompletedAt': baselineCompletedAt?.millisecondsSinceEpoch,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalSessions': totalSessions,
      'baselineScores': baselineScores?.toJson(),
      'weakAreas': weakAreas,
    };
  }

  UserProfile copyWith({
    String? userId,
    String? email,
    String? displayName,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    bool? baselineCompleted,
    DateTime? baselineCompletedAt,
    int? currentStreak,
    int? longestStreak,
    int? totalSessions,
    BaselineScores? baselineScores,
    List<String>? weakAreas,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      baselineCompleted: baselineCompleted ?? this.baselineCompleted,
      baselineCompletedAt: baselineCompletedAt ?? this.baselineCompletedAt,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalSessions: totalSessions ?? this.totalSessions,
      baselineScores: baselineScores ?? this.baselineScores,
      weakAreas: weakAreas ?? this.weakAreas,
    );
  }
}

class BaselineScores {
  final double fluency;
  final double grammar;
  final double pronunciation;
  final double composite;

  BaselineScores({
    required this.fluency,
    required this.grammar,
    required this.pronunciation,
    required this.composite,
  });

  factory BaselineScores.fromJson(Map<String, dynamic> json) {
    return BaselineScores(
      fluency: (json['fluency'] as num).toDouble(),
      grammar: (json['grammar'] as num).toDouble(),
      pronunciation: (json['pronunciation'] as num).toDouble(),
      composite: (json['composite'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fluency': fluency,
      'grammar': grammar,
      'pronunciation': pronunciation,
      'composite': composite,
    };
  }
}
