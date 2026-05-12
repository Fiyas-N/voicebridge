import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/models/prompt.dart';
import '../../data/local/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../services/tts_service.dart';
import '../../widgets/common/ai_voice_gender_toggle.dart';
import '../../widgets/common/glass_card.dart';
import '../../services/gamification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import 'package:shimmer/shimmer.dart';
import '../lessons/lessons_screen.dart';
import '../practice/conversation_screen.dart';
import '../practice/recording_screen.dart';
import '../progress/progress_screen.dart';
import '../settings/settings_screen.dart';
import '../history/history_screen.dart';
import '../history/session_detail_screen.dart';
import '../../services/smart_prompt_generator.dart';
import '../../data/models/user_profile.dart';

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
  bool _isGenerating = false;
  List<Map<String, dynamic>> _recentSessions = [];

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
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _bannerAnimation = CurvedAnimation(parent: _bannerController, curve: Curves.easeOutCubic);
    _bannerController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGamificationStats();
      _loadRecentSessions();
      Provider.of<AuthProvider>(context, listen: false).addListener(_loadGamificationStats);
    });
  }

  @override
  void dispose() {
    try {
      Provider.of<AuthProvider>(context, listen: false).removeListener(_loadGamificationStats);
    } catch (_) {}
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

  Future<void> _loadRecentSessions() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.userId;
    if (userId == null) return;
    try {
      final rows = await DatabaseHelper.instance.getUserSessions(userId, limit: 4);
      if (mounted) setState(() => _recentSessions = rows);
    } catch (_) {}
  }

  Future<void> _onGenPersonalised(UserProfile user) async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    
    try {
      final generator = SmartPromptGenerator();
      final lesson = await generator.generatePersonalizedLesson(user);
      
      if (!mounted) return;
      setState(() => _isGenerating = false);

      final customPrompt = Prompt(
        promptId: lesson.id,
        text: lesson.prompts.join('\n\n'),
        category: 'Dynamic Drill',
        difficulty: lesson.cefrLevel,
        ieltsPartNumber: 2,
        focusAreas: user.weakAreas,
        tags: ['ai_generated'],
      );

      _goToRecording(context, customPrompt, user.userId);
    } catch (e) {
      if (mounted) setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate: $e'), backgroundColor: AppColors.accentRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return _buildLoadingShimmer();
    }

    final dailyPrompt = IELTSPrompts.getDailyPrompt();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showConversationTopics(context),
            child: const Icon(Icons.mic_none_rounded, color: VbColor.inverseOnSurface),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          body: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    VbSpacing.marginMobile,
                    8,
                    VbSpacing.marginMobile,
                    4,
                  ),
                  sliver: SliverToBoxAdapter(child: _buildBrandTopBar(context, user)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: VbSpacing.marginMobile),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _XpDailyGoalCard(stats: _gamificationStats),
                        const SizedBox(height: VbSpacing.md),
                        ScaleTransition(
                          scale: _bannerAnimation,
                          child: _buildStatsStrip(user),
                        ),
                        const SizedBox(height: VbSpacing.md),
                        if (!user.baselineCompleted) ...[
                          _buildBaselineBanner(context, user.userId),
                          const SizedBox(height: VbSpacing.md),
                        ],
                        _buildActiveModuleCard(context, user, dailyPrompt),
                        const SizedBox(height: VbSpacing.md),
                        _buildPathwayGrid(context, user.userId),
                        const SizedBox(height: VbSpacing.md),
                        _buildHomeHistory(context),
                        const SizedBox(height: VbSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Speaking voice',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                  color: VbColor.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            AiVoiceGenderToggle(
                              compact: true,
                              isMale: TtsService().isMale,
                              onChanged: (male) async {
                                await TtsService().setVoice(male);
                                if (mounted) setState(() {});
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: VbSpacing.sm),
                        _buildActionButton(
                          context,
                          Icons.auto_awesome,
                          'Personalised drill',
                          'Targets your weak areas',
                          () => _onGenPersonalised(user),
                          isAccent: true,
                        ),
                        const SizedBox(height: VbSpacing.sm),
                        _buildActionButton(
                          context,
                          Icons.psychology_outlined,
                          'Mock interview',
                          'Practice for a specific role',
                          () => _showMockInterviewSetup(context),
                        ),
                        const SizedBox(height: VbSpacing.sm),
                        _buildActionButton(
                          context,
                          Icons.horizontal_split,
                          'Quick Part 2',
                          'Jump into a Part 2 cue card',
                          () => _goToRecording(
                            context,
                            IELTSPrompts.getRandomPromptFromPart(2),
                            user.userId,
                          ),
                        ),
                        const SizedBox(height: VbSpacing.md),
                        _buildTipCard(context),
                        const SizedBox(height: 88),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isGenerating)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.92),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: VbColor.inverseSurface,
                      strokeWidth: 2,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Creating your drill…',
                      style: GoogleFonts.jetBrainsMono(
                        color: VbColor.inverseSurface,
                        letterSpacing: 2,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBrandTopBar(BuildContext context, UserProfile user) {
    return Row(
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: const Icon(Icons.menu_rounded, size: 22),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SettingsScreen(),
              ),
            );
          },
        ),
        Expanded(
          child: Text(
            'VOICEBRIDGE',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              color: VbColor.onBackground,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SettingsScreen(),
              ),
            );
          },
          icon: CircleAvatar(
            radius: 18,
            backgroundColor: VbColor.surfaceContainerHigh,
            child: Text(
              (user.displayName.isNotEmpty ? user.displayName[0] : 'V')
                  .toUpperCase(),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: VbColor.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsStrip(UserProfile user) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Streak',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: VbColor.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.currentStreak}',
                  style: GoogleFonts.spaceMono(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: VbColor.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: VbColor.outlineVariant),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Sessions',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: VbColor.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.totalSessions}',
                  style: GoogleFonts.spaceMono(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: VbColor.accentElectric,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveModuleCard(
    BuildContext context,
    UserProfile user,
    Prompt dailyPrompt,
  ) {
    final dp =
        (_gamificationStats['dailyProgress'] as num?)?.toDouble() ?? 0.0;
    final title = dailyPrompt.text.length > 72
        ? '${dailyPrompt.text.substring(0, 72)}…'
        : dailyPrompt.text;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s practice',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: VbColor.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(dp * 100).round()}%',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: VbColor.accentElectric,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '[ ${dailyPrompt.difficulty.toUpperCase()} ]',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              color: VbColor.outline,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.spaceMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: VbColor.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: dp.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: VbColor.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(
                VbColor.accentElectric,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Continue'),
              onPressed: () => _goToRecording(context, dailyPrompt, user.userId),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathwayGrid(BuildContext context, String userId) {
    Widget cell({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      Color iconColor = VbColor.onSurface,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VbRadii.lg),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: iconColor),
                const Spacer(),
                Text(
                  title,
                  style: GoogleFonts.spaceMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: VbColor.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: VbColor.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        cell(
          icon: Icons.graphic_eq,
          title: 'Speak with AI',
          subtitle: 'Live conversation',
          iconColor: VbColor.accentElectric,
          onTap: () => _showConversationTopics(context),
        ),
        cell(
          icon: Icons.mic_none_outlined,
          title: 'Part drill',
          subtitle: 'IELTS practice',
          onTap: () => _goToRecording(
            context,
            IELTSPrompts.getRandomPromptFromPart(1),
            userId,
          ),
        ),
        cell(
          icon: Icons.grid_view_outlined,
          title: 'Lessons',
          subtitle: 'Structured path',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LessonsScreen()),
            );
          },
        ),
        cell(
          icon: Icons.analytics_outlined,
          title: 'Progress',
          subtitle: 'Charts and stats',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProgressScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHomeHistory(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent sessions',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                letterSpacing: 1.4,
                color: VbColor.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HistoryScreen(),
                  ),
                );
              },
              child: Text(
                'See all',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: VbColor.accentElectric,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentSessions.isEmpty)
          Text(
            'No sessions yet.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: VbColor.onSurfaceVariant,
            ),
          )
        else
          ..._recentSessions.map((s) => _historyRow(context, s)),
      ],
    );
  }

  Widget _historyRow(BuildContext context, Map<String, dynamic> s) {
    final raw = (s['prompt_text'] as String? ?? 'Session').trim();
    final short =
        raw.length > 48 ? '${raw.substring(0, 48)}…' : raw;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SessionDetailScreen(session: s),
              ),
            );
          },
          borderRadius: BorderRadius.circular(VbRadii.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VbRadii.lg),
              border: Border.all(color: VbColor.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.graphic_eq,
                  size: 18,
                  color: VbColor.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    short,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: VbColor.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: VbColor.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Shimmer.fromColors(
            baseColor: AppColors.surfaceVariant,
            highlightColor: AppColors.borderLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      Expanded(child: Container(height: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)))),
                      if (i < 2) const SizedBox(width: 12),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < 4; i++)
                  Container(height: 70, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Baseline Call to Action
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
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppColors.purpleNeonGradient,
          borderRadius: BorderRadius.circular(VbRadii.lg),
          boxShadow: [
            BoxShadow(color: AppColors.accentPurple.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get started',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Perform the baseline session to benchmark performance',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Icon(Icons.arrow_forward, color: Colors.black, size: 18),
            )
          ],
        ),
      ),
    );
  }

  // Action Row Items
  Widget _buildActionButton(BuildContext ctx, IconData icon, String title, String subtitle, VoidCallback onTap, {bool isAccent = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isAccent
              ? VbColor.accentElectric.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(VbRadii.lg),
          border: Border.all(
            color: isAccent ? VbColor.accentElectric : VbColor.outlineVariant,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isAccent ? VbColor.accentElectric : VbColor.onSurface,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      fontSize: 11,
                      color: VbColor.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: VbColor.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: VbColor.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // Tip widget
  Widget _buildTipCard(BuildContext ctx) {
    final tip = _tips[_tipIndex];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tip',
            style: GoogleFonts.jetBrainsMono(
              color: VbColor.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tip['tip']!,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: VbColor.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _goToRecording(BuildContext ctx, Prompt prompt, String userId) {
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => RecordingScreen(prompt: prompt, userId: userId, isBaseline: false),
      ),
    );
  }

  // Modals Cleaned Up
  void _showConversationTopics(BuildContext ctx) {
    const topics = [
      ('General Free Chat', '💬', 'Open conversation about any subject'),
      ('Daily Life', '🌅', 'Talk about routine and habits'),
      ('Travel', '✈️', 'Discuss journeys and geography'),
      ('Career Path', '💼', 'Talk about work and future ambitions'),
      ('Technology', '📱', 'How innovations change our lives'),
    ];

    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a topic',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: topics.length,
                itemBuilder: (_, i) {
                  final t = topics[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(ctx, MaterialPageRoute(builder: (_) => ConversationScreen(topic: t.$1, topicEmoji: t.$2)));
                      },
                      tileColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: AppColors.borderLight),
                      ),
                      leading: Text(t.$2, style: const TextStyle(fontSize: 20)),
                      title: Text(t.$1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      trailing: const Icon(Icons.chevron_right, size: 16),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMockInterviewSetup(BuildContext ctx) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 40,
          top: 24, left: 24, right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Interview focus',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(
                hintText: 'Specify Interest/Job Role...',
                prefixIcon: Icon(Icons.edit_note, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    Navigator.pop(context);
                    Navigator.push(ctx, MaterialPageRoute(builder: (_) => ConversationScreen(topic: 'Interview: $text', topicEmoji: '🎙️')));
                  }
                },
                child: const Text('Start interview'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// XP Bar Refactored for Dark Mode
class _XpDailyGoalCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _XpDailyGoalCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    final xp = stats['xp'] as int? ?? 0;
    final cefr = stats['cefrFromXP'] as String? ?? 'A1';
    final xpNext = stats['xpForNext'] as int? ?? 300;
    final dailyPct = (stats['dailyProgress'] as double? ?? 0.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Text(
              cefr,
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Level',
                      style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppColors.textTertiary, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$xp / $xpNext XP',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: xpNext > 0 ? (xp / xpNext).clamp(0.0, 1.0) : 1.0,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 38, height: 38,
                child: CircularProgressIndicator(
                  value: dailyPct,
                  strokeWidth: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              if (dailyPct >= 1.0)
                const Icon(Icons.check, size: 12, color: AppColors.primary)
              else
                const Text('GOAL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
