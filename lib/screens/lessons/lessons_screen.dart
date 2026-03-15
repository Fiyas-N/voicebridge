import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/lesson.dart';
import '../../data/models/prompt.dart';
import '../../providers/auth_provider.dart';
import '../../services/gamification_service.dart';
import '../../widgets/common/glass_card.dart';
import '../practice/recording_screen.dart';

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, bool> _completedLessons = {};
  String _userCefr = 'A1';
  bool _loading = true;

  static const _levelColors = {
    'A1': Color(0xFF9e9e9e),
    'A2': Color(0xFFc77dff),
    'B1': Color(0xFF4e9eff),
    'B2': Color(0xFF4ecdc4),
    'C1': Color(0xFF6bcb77),
    'C2': Color(0xFFffd166),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: LessonLibrary.levels.length, vsync: this);
    _loadProgress();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.userId;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('lesson_progress',
        where: 'user_id = ?', whereArgs: [userId]);
    final profile = await DatabaseHelper.instance.getUserProfile(userId);
    final xp = profile?['xp'] as int? ?? 0;

    setState(() {
      _completedLessons = {
        for (final r in rows)
          r['lesson_id'] as String: true,
      };
      _userCefr = GamificationService.cefrForXP(xp);
      _loading = false;
    });

    // Jump to the user's current CEFR tab
    final idx = LessonLibrary.levels.indexOf(_userCefr);
    if (idx >= 0) _tabController.animateTo(idx);
  }

  // ignore: unused_element
  bool _isLevelUnlocked(String cefr) {
    // A1 always unlocked; others unlock when previous level has ≥1 completed lesson
    final i = LessonLibrary.levels.indexOf(cefr);
    if (i == 0) return true;
    final prevLevel = LessonLibrary.levels[i - 1];
    return LessonLibrary.forLevel(prevLevel)
        .any((l) => _completedLessons[l.id] == true);
  }

  void _startLesson(Lesson lesson) {
    final prompt = Prompt(
      promptId: lesson.id,
      text: lesson.prompts.first,
      category: lesson.topic,
      difficulty: 'beginner',
      ieltsPartNumber: 1,
      focusAreas: const [],
      tags: const [],
    );
    final auth = context.read<AuthProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordingScreen(
          prompt: prompt,
          userId: auth.currentUser?.userId ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundOffWhite,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Lessons',
          style: TextStyle(
              color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.textDark,
          unselectedLabelColor: AppColors.textMedium,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          dividerColor: AppColors.borderLight,
          tabs: LessonLibrary.levels
              .map((l) => Tab(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _tabController.index ==
                                LessonLibrary.levels.indexOf(l)
                            ? _levelColors[l]!.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: _tabController.index ==
                                LessonLibrary.levels.indexOf(l)
                            ? Border.all(color: _levelColors[l]!, width: 2)
                            : Border.all(color: Colors.transparent, width: 2),
                      ),
                      child: Text(
                        l,
                        style: TextStyle(
                          color: _tabController.index == LessonLibrary.levels.indexOf(l) 
                              ? _levelColors[l] 
                              : AppColors.textMedium,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: LessonLibrary.levels
                  .map((cefr) => _buildLevelTab(cefr))
                  .toList(),
            ),
    );
  }

  Widget _buildLevelTab(String cefr) {
    final lessons = LessonLibrary.forLevel(cefr);
    final color = _levelColors[cefr] ?? AppColors.primary;
    final completedCount =
        lessons.where((l) => _completedLessons[l.id] == true).length;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                // Level badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Text(
                    cefr,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$completedCount / ${lessons.length} completed',
                  style: const TextStyle(
                      color: AppColors.textMedium,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const Spacer(),
                // Progress ring
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                   value: lessons.isEmpty
                        ? 0
                        : completedCount / lessons.length,
                    backgroundColor: AppColors.borderLight,
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeWidth: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _buildLessonCard(lessons[i], color),
            childCount: lessons.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildLessonCard(Lesson lesson, Color color) {
    final done = _completedLessons[lesson.id] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GestureDetector(
        onTap: () => _startLesson(lesson),
        child: GlassCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // Emoji icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: done
                      ? color.withOpacity(0.15)
                      : AppColors.backgroundOffWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: done
                      ? Border.all(color: color, width: 2)
                      : Border.all(color: AppColors.borderLight, width: 2),
                ),
                child: Center(
                  child: Text(lesson.emoji,
                      style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lesson.topic,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (done)
                          Icon(Icons.check_circle_rounded,
                              color: color, size: 24),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lesson.description,
                      style: const TextStyle(
                          color: AppColors.textMedium,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${lesson.prompts.length} prompts',
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.play_arrow_rounded,
                  color: AppColors.textLight, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
