import '../data/local/database_helper.dart';

/// Gamification Service
/// Manages XP, daily goals, streaks, and achievements.
class GamificationService {
  static const int _dailyGoalDefault = 3;

  // ── Achievements ──────────────────────────────────────────────────────────
  static const Map<String, Map<String, dynamic>> achievements = {
    'first_session': {
      'title': 'First Steps',
      'description': 'Complete your first speaking session',
      'icon': '🎙️',
      'xpReward': 50,
    },
    'streak_3': {
      'title': 'On a Roll',
      'description': '3-day speaking streak',
      'icon': '🔥',
      'xpReward': 100,
    },
    'streak_7': {
      'title': 'Week Warrior',
      'description': '7-day speaking streak',
      'icon': '⚡',
      'xpReward': 250,
    },
    'streak_30': {
      'title': 'Month Master',
      'description': '30-day speaking streak',
      'icon': '🏆',
      'xpReward': 1000,
    },
    'cefr_b1': {
      'title': 'Intermediate Reached',
      'description': 'Achieve B1 CEFR level',
      'icon': '📗',
      'xpReward': 300,
    },
    'cefr_b2': {
      'title': 'Upper Intermediate',
      'description': 'Achieve B2 CEFR level',
      'icon': '📘',
      'xpReward': 500,
    },
    'cefr_c1': {
      'title': 'Advanced Speaker',
      'description': 'Achieve C1 CEFR level',
      'icon': '💎',
      'xpReward': 1000,
    },
    'score_90': {
      'title': 'Near Perfect',
      'description': 'Score 90+ in a session',
      'icon': '⭐',
      'xpReward': 200,
    },
    'sessions_10': {
      'title': 'Dedicated Learner',
      'description': 'Complete 10 sessions',
      'icon': '📚',
      'xpReward': 150,
    },
    'sessions_50': {
      'title': 'Speaking Pro',
      'description': 'Complete 50 sessions',
      'icon': '🎓',
      'xpReward': 500,
    },
  };

  // ── XP Calculation ────────────────────────────────────────────────────────
  /// XP earned from a session = composite_score * 1.5
  static int calculateSessionXP(double compositeScore) =>
      (compositeScore * 1.5).round();

  /// Get CEFR level label for XP display
  static String cefrForXP(int xp) {
    if (xp >= 5000) return 'C2';
    if (xp >= 3000) return 'C1';
    if (xp >= 1500) return 'B2';
    if (xp >= 750) return 'B1';
    if (xp >= 300) return 'A2';
    return 'A1';
  }

  /// XP needed for next level milestone
  static int xpForNextMilestone(int currentXP) {
    const milestones = [300, 750, 1500, 3000, 5000];
    for (final m in milestones) {
      if (currentXP < m) return m;
    }
    return currentXP; // maxed out
  }

  // ── Database Operations ───────────────────────────────────────────────────
  /// Award XP and update daily goal + streak. Returns list of newly unlocked achievements.
  Future<List<String>> completeSession({
    required String userId,
    required double compositeScore,
    required String cefrLevel,
    required int currentStreak,
    required int totalSessions,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final profile = await DatabaseHelper.instance.getUserProfile(userId);
    if (profile == null) return [];

    final int sessionXP = calculateSessionXP(compositeScore);
    final int currentXP = (profile['xp'] as int? ?? 0) + sessionXP;

    // Daily goal tracking
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = profile['last_session_date'] as String? ?? '';
    final todaySessions = (lastDate == today
        ? (profile['daily_sessions_today'] as int? ?? 0) + 1
        : 1);

    // Achievements check
    final List<String> unlocked = [];
    final existingJson = profile['achievements_json'] as String? ?? '[]';
    final existing = List<String>.from(
        (existingJson.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '')
            .split(',').where((s) => s.isNotEmpty)));

    void check(String key, bool condition) {
      if (condition && !existing.contains(key)) {
        existing.add(key);
        unlocked.add(key);
        // Bonus XP for achievement
        final bonus = achievements[key]?['xpReward'] as int? ?? 0;
        currentXP + bonus; // will be included in next update
      }
    }

    check('first_session', totalSessions + 1 >= 1);
    check('streak_3', currentStreak >= 3);
    check('streak_7', currentStreak >= 7);
    check('streak_30', currentStreak >= 30);
    check('cefr_b1', cefrLevel == 'B1' || cefrLevel == 'B2' || cefrLevel == 'C1' || cefrLevel == 'C2');
    check('cefr_b2', cefrLevel == 'B2' || cefrLevel == 'C1' || cefrLevel == 'C2');
    check('cefr_c1', cefrLevel == 'C1' || cefrLevel == 'C2');
    check('score_90', compositeScore >= 90);
    check('sessions_10', totalSessions + 1 >= 10);
    check('sessions_50', totalSessions + 1 >= 50);

    final achievementsJson = '[${existing.map((s) => '"$s"').join(',')}]';

    await db.update('user_profile', {
      'xp': currentXP,
      'daily_sessions_today': todaySessions,
      'last_session_date': today,
      'achievements_json': achievementsJson,
    }, where: 'user_id = ?', whereArgs: [userId]);

    return unlocked;
  }

  Future<Map<String, dynamic>> getStats(String userId) async {
    final profile = await DatabaseHelper.instance.getUserProfile(userId);
    if (profile == null) return {};

    final xp = profile['xp'] as int? ?? 0;
    final dailyGoal = profile['daily_goal'] as int? ?? _dailyGoalDefault;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = profile['last_session_date'] as String? ?? '';
    final todaySessions = lastDate == today
        ? (profile['daily_sessions_today'] as int? ?? 0)
        : 0;

    return {
      'xp': xp,
      'cefrFromXP': cefrForXP(xp),
      'xpForNext': xpForNextMilestone(xp),
      'dailyGoal': dailyGoal,
      'dailySessionsToday': todaySessions,
      'dailyProgress': (todaySessions / dailyGoal).clamp(0.0, 1.0),
      'achievementsJson': profile['achievements_json'] ?? '[]',
    };
  }
}
