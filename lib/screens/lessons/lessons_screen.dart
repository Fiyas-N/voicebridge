import 'package:flutter/material.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/lesson.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai_pipeline.dart';
import '../../services/gamification_service.dart';
import '../../widgets/common/glass_card.dart';
import '../practice/recording_screen.dart';
import 'package:provider/provider.dart';
import '../../data/models/prompt.dart';

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
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Lessons',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: LessonLibrary.levels
              .map((l) => Tab(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _tabController.index ==
                                LessonLibrary.levels.indexOf(l)
                            ? _levelColors[l]!.withValues(alpha: 0.25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(l),
                    ),
                  ))
              .toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
    final color = _levelColors[cefr] ?? Colors.white;
    final completedCount =
        lessons.where((l) => _completedLessons[l.id] == true).length;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                // Level badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color, width: 1.5),
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
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13),
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
                    backgroundColor:
                        Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeWidth: 3,
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
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildLessonCard(Lesson lesson, Color color) {
    final done = _completedLessons[lesson.id] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: GestureDetector(
        onTap: () => _startLesson(lesson),
        child: GlassCard(
          blur: 15,
          opacity: 0.15,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // Emoji icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: done
                      ? color.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: done
                      ? Border.all(color: color, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(lesson.emoji,
                      style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 14),
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
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (done)
                          Icon(Icons.check_circle_rounded,
                              color: color, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lesson.description,
                      style: TextStyle(
                          color:
                              Colors.white.withValues(alpha: 0.6),
                          fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${lesson.prompts.length} prompts',
                      style: TextStyle(
                          color: color.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white38, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
