import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/prompt.dart';
import '../../providers/auth_provider.dart';
import '../../services/gamification_service.dart';
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
          // Animated Liquid Glass Background
          LiquidGlassContainer(
            height: MediaQuery.of(context).size.height,
            colors: const [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
              Color(0xFF533483),
            ],
            child: const SizedBox.expand(),
          ),

          // Content
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Glass App Bar
                SliverAppBar(
                  expandedHeight: 130,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.18),
                              Colors.white.withValues(alpha: 0.08),
                            ],
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Good ${_getGreeting()},',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.75),
                                        letterSpacing: 0.5,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user.displayName.isNotEmpty ? user.displayName : 'Learner',
                                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
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
                                color: Colors.white,
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
                                color: Colors.white,
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
      blur: 16,
      opacity: 0.18,
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
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.75),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Baseline Banner ────────────────────────────────────────────────────────
  Widget _buildBaselineBanner(BuildContext ctx, String userId) {
    return GestureDetector(
      onTap: () {
        final prompt = IELTSPrompts.getRandomPromptFromPart(1);
        Navigator.of(ctx).push(
          MaterialPageRoute(
            builder: (_) => RecordingScreen(
              prompt: prompt,
              userId: userId,
              isBaseline: true,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFFffd166), Color(0xFFef8c59)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFffd166).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flag_outlined, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Complete Your Baseline',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
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
      blur: 18,
      opacity: 0.22,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Part ${prompt.ieltsPartNumber} · ${prompt.category}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  prompt.difficulty,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Text(
              prompt.text,
              style: TextStyle(
                fontSize: 15,
                height: 1.65,
                color: Colors.white.withValues(alpha: 0.92),
              ),
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
        blur: 14,
        opacity: 0.18,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 11,
              ),
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
        blur: 14,
        opacity: 0.18,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.5),
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
