import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/lesson.dart';
import '../../data/models/prompt.dart';
import '../../providers/auth_provider.dart';
import '../../services/gamification_service.dart';
import '../practice/recording_screen.dart';

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, bool> _completedLessons = {};
  String _userCefr = 'A1';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: LessonLibrary.levels.length, vsync: this);
    _loadProgress();
    _tabController.addListener(() {
      setState(() {}); // Ensure view refreshes decoration on interaction
    });
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

    final rows = await DatabaseHelper.instance.getLessonProgress(userId);
    final profile = await DatabaseHelper.instance.getUserProfile(userId);
    final xp = profile?['xp'] as int? ?? 0;

    setState(() {
      _completedLessons = {for (final r in rows) r['lesson_id'] as String: true};
      _userCefr = GamificationService.cefrForXP(xp);
      _loading = false;
    });

    final idx = LessonLibrary.levels.indexOf(_userCefr);
    if (idx >= 0) _tabController.animateTo(idx);
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'LESSON MATRIX'.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicator: const BoxDecoration(), // No custom bottom bar
                dividerColor: Colors.transparent,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                tabs: LessonLibrary.levels.map((l) {
                  final active = _tabController.index == LessonLibrary.levels.indexOf(l);
                  return Tab(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: active ? AppColors.primary : AppColors.borderLight),
                      ),
                      child: Text(
                        l,
                        style: TextStyle(
                          color: active ? Colors.black : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.borderLight),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : TabBarView(
              controller: _tabController,
              children: LessonLibrary.levels.map((cefr) => _buildLevelTab(cefr)).toList(),
            ),
    );
  }

  Widget _buildLevelTab(String cefr) {
    final lessons = LessonLibrary.forLevel(cefr);
    final completedCount = lessons.where((l) => _completedLessons[l.id] == true).length;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LEVEL PROGRESS ($cefr)',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$completedCount / ${lessons.length} MODULES READY',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          value: lessons.isEmpty ? 0 : completedCount / lessons.length,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation(completedCount == lessons.length && lessons.isNotEmpty ? AppColors.accentRed : Colors.white),
                          strokeWidth: 3.5,
                        ),
                      ),
                      Text(
                        lessons.isEmpty ? '0%' : '${((completedCount / lessons.length) * 100).toInt()}%',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _buildLessonCard(lessons[i]),
              childCount: lessons.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildLessonCard(Lesson lesson) {
    final done = _completedLessons[lesson.id] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _startLesson(lesson),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: done ? AppColors.accentRed.withValues(alpha: 0.5) : AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: done ? AppColors.accentRed.withValues(alpha: 0.1) : Colors.black,
                  shape: BoxShape.circle,
                  border: Border.all(color: done ? AppColors.accentRed : AppColors.borderLight),
                ),
                child: Center(child: Text(lesson.emoji, style: const TextStyle(fontSize: 20))),
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
                            lesson.topic.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                          ),
                        ),
                        if (done) const Icon(Icons.check_circle_outline, color: AppColors.accentRed, size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lesson.description,
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_ios, color: AppColors.textTertiary, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
