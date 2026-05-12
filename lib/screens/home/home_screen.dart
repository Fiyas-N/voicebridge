import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/prompt.dart';
import '../../providers/auth_provider.dart';
import '../../services/tts_service.dart';
import '../../services/gamification_service.dart';
import '../../core/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';
import '../lessons/lessons_screen.dart';
import '../practice/conversation_screen.dart';
import '../practice/recording_screen.dart';
import '../settings/settings_screen.dart';
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
          body: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good ${_getGreeting()}'.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.displayName.isNotEmpty ? user.displayName : 'Learner',
                              style: Theme.of(context).textTheme.displayMedium,
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SettingsScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _XpDailyGoalCard(stats: _gamificationStats),
                        const SizedBox(height: 24),
                        ScaleTransition(
                          scale: _bannerAnimation,
                          child: Row(
                            children: [
                              Expanded(child: _buildStatCard('🔥', '${user.currentStreak}', 'STREAK')),
                              const SizedBox(width: 12),
                              Expanded(child: _buildStatCard('📊', '${user.totalSessions}', 'SESSIONS')),
                              const SizedBox(width: 12),
                              Expanded(child: _buildStatCard('🎯', user.baselineCompleted ? 'DONE' : 'TBD', 'BASE')),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (!user.baselineCompleted) ...[
                          _buildBaselineBanner(context, user.userId),
                          const SizedBox(height: 24),
                        ],
                        _buildTodayCard(context, dailyPrompt, user.userId),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('PRACTICE BY PART'.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildPartCard(context, 'P1', Icons.forum_outlined, () => _goToRecording(context, IELTSPrompts.getRandomPromptFromPart(1), user.userId))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildPartCard(context, 'P2', Icons.record_voice_over_outlined, () => _goToRecording(context, IELTSPrompts.getRandomPromptFromPart(2), user.userId))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildPartCard(context, 'P3', Icons.groups_outlined, () => _goToRecording(context, IELTSPrompts.getRandomPromptFromPart(3), user.userId))),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('AI TOOLS'.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13, color: AppColors.textSecondary)),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderLight)),
                              child: Row(
                                children: [
                                  _voiceOption(context, 'F', !TtsService().isMale, () => setState(() => TtsService().setVoice(false))),
                                  _voiceOption(context, 'M', TtsService().isMale, () => setState(() => TtsService().setVoice(true))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildActionButton(
                          context,
                          Icons.auto_awesome,
                          'GENERATE AI DRILL',
                          'Targeted training generated just for you',
                          () => _onGenPersonalised(user),
                          isAccent: true,
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(context, Icons.psychology_outlined, 'MOCK INTERVIEW', 'Specialised practice simulation', () => _showMockInterviewSetup(context)),
                        const SizedBox(height: 12),
                        _buildActionButton(context, Icons.auto_awesome_outlined, 'LIVE TALK AI', 'Natural fluid conversations', () => _showConversationTopics(context)),
                        const SizedBox(height: 12),
                        _buildActionButton(context, Icons.menu_book_rounded, 'LESSONS MATRIX', 'Structured syllabus path', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LessonsScreen()))),
                        const SizedBox(height: 32),
                        _buildTipCard(context),
                        const SizedBox(height: 40),
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
              color: Colors.black.withValues(alpha: 0.9),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    SizedBox(height: 24),
                    Text(
                      'SYNTHESIZING_BESPOKE_SEQUENCE...',
                      style: TextStyle(color: Colors.white, fontFamily: 'monospace', letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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

  // Voice Selector mini widget
  Widget _voiceOption(BuildContext context, String text, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // Basic Helper - Stat Cards stripped of Neumorphism
  Widget _buildStatCard(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textTertiary,
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
          borderRadius: BorderRadius.circular(28),
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
                    'INITIALIZE SYSTEM',
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

  // Daily Practice Item
  Widget _buildTodayCard(BuildContext ctx, Prompt prompt, String userId) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "DAILY PROMPT".toUpperCase(),
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.textTertiary),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  prompt.difficulty.toUpperCase(),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            prompt.text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'PART ${prompt.ieltsPartNumber} · ${prompt.category.toUpperCase()}',
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.mic_none, size: 20),
              label: const Text('EXECUTE PRACTICE'),
              onPressed: () => _goToRecording(ctx, prompt, userId),
            ),
          ),
        ],
      ),
    );
  }

  // Part Practice Cards (P1, P2, P3)
  Widget _buildPartCard(BuildContext ctx, String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 28),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.0,
              ),
            ),
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isAccent ? AppColors.cyberGradient : null,
          color: isAccent ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isAccent ? Colors.transparent : AppColors.borderLight),
          boxShadow: isAccent ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))] : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isAccent ? Colors.black : AppColors.textPrimary, size: 24),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8, fontSize: 14, color: isAccent ? Colors.black : Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: isAccent ? Colors.black54 : AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: isAccent ? Colors.black54 : AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  // Tip widget transformed to Glass/Dark Minimal Gradient
  Widget _buildTipCard(BuildContext ctx) {
    final tip = _tips[_tipIndex];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SYS_TIP //',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tip['tip']!,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Logic Utilities
  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
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
              'SELECT CONVERSATION CORE',
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
              'MOCK INTERVIEW PARAMETER',
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
                child: const Text('INITIALISE'),
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
                      'SYS_LEVEL',
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
