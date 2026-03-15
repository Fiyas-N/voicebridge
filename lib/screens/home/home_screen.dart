import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/prompt.dart';
import '../../providers/auth_provider.dart';
import '../../services/gamification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/glass_card.dart';
import '../history/history_screen.dart';
import '../lessons/lessons_screen.dart';
import '../practice/conversation_screen.dart';
import '../practice/recording_screen.dart';
import '../progress/progress_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _tipController;
  late AnimationController _bannerController;
  late Animation<double> _bannerAnimation;
  int _tipIndex = 0;
  Map<String, dynamic> _gamificationStats = {};

  static const List<Map<String, String>> _tips = [
    {'icon': '🎯', 'tip': 'Speak clearly and at a natural pace — don\'t rush answers.'},
    {'icon': '📚', 'tip': 'Use a variety of vocabulary and avoid repeating the same words.'},
    {'icon': '💡', 'tip': 'Structure answers with: Point → Reason → Example (PRE method).'},
    {'icon': '⏱️', 'tip': 'For Part 2, use your 1-minute planning time wisely — jot keywords.'},
    {'icon': '🔊', 'tip': 'Stress key words in each sentence to sound more natural and emphatic.'},
    {'icon': '🌐', 'tip': 'Use linking phrases: "In addition", "However", "As a result of this"…'},
    {'icon': '✅', 'tip': 'Correct yourself naturally: "Sorry, I meant to say…" shows fluency.'},
  ];

  @override
  void initState() {
    super.initState();
    _tipController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
          _tipController.reset();
          _tipController.forward();
        }
      });
    _tipController.forward();

    _bannerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _bannerAnimation = CurvedAnimation(parent: _bannerController, curve: Curves.elasticOut);
    _bannerController.forward();

    // Load XP/daily goal after first frame (needs auth context)
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGamificationStats());
  }

  @override
  void dispose() {
    _tipController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _loadGamificationStats() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.userId;
    if (userId == null) return;
    try {
      final stats = await GamificationService().getStats(userId);
      if (mounted) setState(() => _gamificationStats = stats);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dailyPrompt = IELTSPrompts.getDailyPrompt();

    return Scaffold(
      body: Stack(
        children: [
          // Solid Gamified Background (Handled by Scaffold, but we can add a simple header background)
          Container(
            height: 220,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Glass App Bar
                SliverAppBar(
                  expandedHeight: 100,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Good ${_getGreeting()},',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                    letterSpacing: 0.5,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.displayName.isNotEmpty ? user.displayName : 'Learner',
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                    color: Colors.white,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.white),
                      tooltip: 'Settings',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),

                // All content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Stats Row ──────────────────────────────────────
                        ScaleTransition(
                          scale: _bannerAnimation,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  '🔥',
                                  '${user.currentStreak}',
                                  'Day Streak',
                                  const Color(0xFFff6b35),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  '📊',
                                  '${user.totalSessions}',
                                  'Sessions',
                                  const Color(0xFF4ecdc4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  '🎯',
                                  user.baselineCompleted ? 'Done' : 'Pending',
                                  'Baseline',
                                  user.baselineCompleted
                                      ? const Color(0xFF6bcb77)
                                      : const Color(0xFFffd166),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── XP & Daily Goal Bar ──────────────────────────────
                        _XpDailyGoalCard(stats: _gamificationStats),
                        const SizedBox(height: 24),

                        // ── Baseline Prompt (if not done) ──────────────────
                        if (!user.baselineCompleted)
                          _buildBaselineBanner(context, user.userId),

                        // ── Today's Practice ──────────────────────────────
                        _buildTodayCard(context, dailyPrompt, user.userId),
                        const SizedBox(height: 24),

                        // ── IELTS Part Selector ────────────────────────────
                        Text(
                          'Practice by Topic',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPartCard(
                                context,
                                'Part 1',
                                'Interview',
                                Icons.chat_bubble_outline,
                                const Color(0xFF4ecdc4),
                                () {
                                  final prompt = IELTSPrompts.getRandomPromptFromPart(1);
                                  _goToRecording(context, prompt, user.userId);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildPartCard(
                                context,
                                'Part 2',
                                'Long Turn',
                                Icons.record_voice_over,
                                const Color(0xFFff6b9d),
                                () {
                                  final prompt = IELTSPrompts.getRandomPromptFromPart(2);
                                  _goToRecording(context, prompt, user.userId);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildPartCard(
                                context,
                                'Part 3',
                                'Discussion',
                                Icons.forum_outlined,
                                const Color(0xFFc77dff),
                                () {
                                  final prompt = IELTSPrompts.getRandomPromptFromPart(3);
                                  _goToRecording(context, prompt, user.userId);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Quick Actions ──────────────────────────────────
                        Text(
                          'Quick Actions',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          context,
                          Icons.forum_rounded,
                          '🎙️  Live Conversation',
                          'Talk with an AI in real-time',
                          const Color(0xFFff6b9d),
                          () => _showConversationTopics(context),
                        ),
                        const SizedBox(height: 10),
                        _buildActionButton(
                          context,
                          Icons.menu_book_rounded,
                          '📚  Lessons Library',
                          'Structured lessons A1 → C2',
                          const Color(0xFFffd166),
                          () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LessonsScreen()),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildActionButton(
                          context,
                          Icons.history_outlined,
                          'Session History',
                          'Review your past recordings',
                          const Color(0xFF4ecdc4),
                          () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const HistoryScreen()),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildActionButton(
                          context,
                          Icons.trending_up_outlined,
                          'Progress Dashboard',
                          'Track your improvement over time',
                          const Color(0xFF6bcb77),
                          () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ProgressScreen()),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Daily Tip ──────────────────────────────────────
                        _buildTipCard(context),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConversationTopics(BuildContext ctx) {
    const topics = [
      ('Daily Life', '🌅', 'Talk about your everyday routine and habits'),
      ('Travel', '✈️', 'Discuss places you\'ve visited or want to visit'),
      ('Work & Career', '💼', 'Talk about your job, goals, and ambitions'),
      ('Technology', '📱', 'Discuss how technology shapes your life'),
      ('Health & Fitness', '🏃', 'Talk about exercise and healthy habits'),
      ('Culture & Society', '🌍', 'Discuss social issues and cultural topics'),
    ];

    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF1e1e3a),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a Conversation Topic',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
            const SizedBox(height: 16),
            ...topics.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => ConversationScreen(
                            topic: t.$1,
                            topicEmoji: t.$2,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        children: [
                          Text(t.$2, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.$1,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                Text(t.$3,
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.55),
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Colors.white38),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _goToRecording(BuildContext ctx, Prompt prompt, String userId) {
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => RecordingScreen(
          prompt: prompt,
          userId: userId,
          isBaseline: false,
        ),
      ),
    );
  }

  // ── Stat Card ──────────────────────────────────────────────────────────────
  Widget _buildStatCard(
    BuildContext ctx,
    String emoji,
    String value,
    String label,
    Color accent,
  ) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(ctx).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Baseline Banner ────────────────────────────────────────────────────────
  Widget _buildBaselineBanner(BuildContext context, String userId) {
    return GestureDetector(
      onTap: () {
        final prompt = IELTSPrompts.getRandomPromptFromPart(1);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecordingScreen(
              prompt: prompt,
              userId: userId,
              isBaseline: true,
            ),
          ),
        );
      },
      child: GlassCard(
        backgroundColor: AppColors.secondary, // Solid blue background
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flag_outlined, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete Your Baseline',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Record a short session to unlock your personalised feedback!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  // ── Today's Practice Card ──────────────────────────────────────────────────
  Widget _buildTodayCard(BuildContext ctx, Prompt prompt, String userId) {
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.premiumGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.today, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Practice",
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Part ${prompt.ieltsPartNumber} · ${prompt.category}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  prompt.difficulty,
                  style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.backgroundOffWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Text(
              prompt.text,
              style: Theme.of(ctx).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: _GradientButton(
              label: 'Start Practice',
              icon: Icons.mic_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              onTap: () => _goToRecording(ctx, prompt, userId),
            ),
          ),
        ],
      ),
    );
  }

  // ── IELTS Part Card ────────────────────────────────────────────────────────
  Widget _buildPartCard(
    BuildContext ctx,
    String title,
    String subtitle,
    IconData icon,
    Color accent,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: Theme.of(ctx).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Action Button ────────────────────────────────────────────────────
  Widget _buildActionButton(
    BuildContext ctx,
    IconData icon,
    String title,
    String subtitle,
    Color accent,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  // ── Daily Tip Card ─────────────────────────────────────────────────────────
  Widget _buildTipCard(BuildContext ctx) {
    final tip = _tips[_tipIndex];
    return GlassCard(
      blur: 16,
      opacity: 0.2,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Speaking Tip of the Day',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${tip['icon']}  ${tip['tip']}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          // Dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _tips.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _tipIndex ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _tipIndex
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

// ── Gradient Button Widget ─────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ── XP & Daily Goal Card ───────────────────────────────────────────────────
class _XpDailyGoalCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _XpDailyGoalCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    final xp = stats['xp'] as int? ?? 0;
    final cefr = stats['cefrFromXP'] as String? ?? 'A1';
    final xpNext = stats['xpForNext'] as int? ?? 300;
    final dailyGoal = stats['dailyGoal'] as int? ?? 3;
    final dailyDone = stats['dailySessionsToday'] as int? ?? 0;
    final dailyPct = (stats['dailyProgress'] as double? ?? 0.0).clamp(0.0, 1.0);

    return GlassCard(
      blur: 16,
      opacity: 0.18,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // CEFR from XP badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  cefr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '⭐  $xp XP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Next: $xpNext XP',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: xpNext > 0 ? (xp / xpNext).clamp(0.0, 1.0) : 1.0,
                        minHeight: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFffd166)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Daily goal ring
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      value: dailyPct,
                      strokeWidth: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(
                        dailyPct >= 1.0
                            ? const Color(0xFF6bcb77)
                            : const Color(0xFF4ecdc4),
                      ),
                    ),
                  ),
                  Text(
                    '$dailyDone/$dailyGoal',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (dailyPct >= 1.0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(
                  'Daily goal complete!',
                  style: TextStyle(
                    color: const Color(0xFF6bcb77).withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
