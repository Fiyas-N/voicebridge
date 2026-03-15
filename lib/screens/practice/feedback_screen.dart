import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../data/models/session.dart';
import '../../data/models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai_pipeline.dart';
import '../../services/firebase_service.dart';
import '../../services/speech_to_text_service.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/word_highlight_widget.dart';
import '../home/home_screen.dart';

class FeedbackScreen extends StatefulWidget {
  final Session session;
  final bool isBaseline;

  const FeedbackScreen({
    super.key,
    required this.session,
    this.isBaseline = false,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _bandScale;
  late List<AnimationController> _barControllers;
  late List<Animation<double>> _barAnims;
  bool _showTranscript = false;

  static const _scoreKeys = ['fluency', 'grammar', 'pronunciation'];
  static const _scoreLabels = ['Fluency & Coherence', 'Grammar Range', 'Pronunciation'];
  static const _scoreIcons = [Icons.speed_rounded, Icons.spellcheck_rounded, Icons.record_voice_over_rounded];
  static const _scoreColors = [Color(0xFF4ecdc4), Color(0xFF6bcb77), Color(0xFFc77dff)];

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _bandScale = CurvedAnimation(parent: _entryController, curve: Curves.elasticOut);

    _barControllers = List.generate(
      3,
      (i) => AnimationController(duration: Duration(milliseconds: 900 + i * 100), vsync: this),
    );
    _barAnims = _barControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _entryController.forward();
    });
    for (int i = 0; i < _barControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 400 + i * 150), () {
        if (mounted) _barControllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    for (final c in _barControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _markBaselineComplete(BuildContext ctx) async {
    final scores = widget.session.scores;
    try {
      final firebaseService = FirebaseService();
      final authProvider = Provider.of<AuthProvider>(ctx, listen: false);
      final uid = firebaseService.currentUserId;
      if (uid != null && scores != null) {
        // Update Firestore
        await firebaseService.markBaselineCompleted(
          userId: uid,
          scores: BaselineScores(
            fluency: scores.fluency,
            grammar: scores.grammar,
            pronunciation: scores.pronunciation,
            composite: scores.composite,
          ),
          weakAreas: _inferWeakAreas(scores),
        );
        // Refresh in-memory profile so the home screen banner disappears
        final updated = authProvider.currentUser?.copyWith(
          baselineCompleted: true,
          baselineScores: BaselineScores(
            fluency: scores.fluency,
            grammar: scores.grammar,
            pronunciation: scores.pronunciation,
            composite: scores.composite,
          ),
        );
        if (updated != null) authProvider.updateUserProfile(updated);
      }
    } catch (e) {
      debugPrint('Failed to mark baseline complete: $e');
    }
    if (!ctx.mounted) return;
    Navigator.of(ctx).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (r) => false,
    );
  }

  List<String> _inferWeakAreas(SessionScores scores) {
    final areas = <String>[];
    if (scores.fluency < 60) areas.add('Fluency & Coherence');
    if (scores.grammar < 60) areas.add('Grammar Range');
    if (scores.pronunciation < 60) areas.add('Pronunciation');
    return areas;
  }

  @override
  Widget build(BuildContext context) {
    final scores = widget.session.scores;
    if (scores == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundOffWhite,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final band = Formatters.formatIELTSBand(scores.estimatedIELTSBand);
    final composite = scores.composite.round();
    final cefr = scores.cefrLevel;
    final transcript = widget.session.transcript ?? '';
    final feedback = widget.session.feedback ?? '';

    return Scaffold(
      body: Stack(
        children: [
          // Background
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
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App Bar
                SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (r) => false,
                    ),
                  ),
                  title: Text(
                    widget.isBaseline ? 'Baseline Results' : 'Session Results',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Band Score Hero ──────────────────────────────
                        ScaleTransition(
                          scale: _bandScale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _bandGradientColors(scores.estimatedIELTSBand),
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: _bandGradientColors(scores.estimatedIELTSBand).first
                                      .withValues(alpha: 0.45),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Speaking Band',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  band,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 80,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // CEFR Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.white38, width: 1.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        cefr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _cefrDescriptor(cefr),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Overall Score: $composite / 100',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Score Breakdown ──────────────────────────────
                        const _SectionHeader(text: 'Score Breakdown'),
                        const SizedBox(height: 14),
                        GlassCard(
                          blur: 16,
                          opacity: 0.2,
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: List.generate(3, (i) {
                              final key = _scoreKeys[i];
                              final score = _getScore(scores, key);
                              return Padding(
                                padding: EdgeInsets.only(bottom: i < 2 ? 22 : 0),
                                child: _AnimatedScoreBar(
                                  label: _scoreLabels[i],
                                  icon: _scoreIcons[i],
                                  score: score,
                                  color: _scoreColors[i],
                                  animation: _barAnims[i],
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── AI Feedback ──────────────────────────────────
                        if (feedback.isNotEmpty) ...[
                          const _SectionHeader(text: '💬  AI Feedback'),
                          const SizedBox(height: 14),
                          GlassCard(
                            padding: const EdgeInsets.all(22),
                            child: Text(
                              feedback,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 14,
                                height: 1.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],

                        // ── Transcript (collapsible + word highlighting) ─
                        if (transcript.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () => setState(() => _showTranscript = !_showTranscript),
                            child: GlassCard(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  const Icon(Icons.text_snippet_outlined,
                                      color: AppColors.textMedium, size: 20),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Pronunciation Highlight',
                                      style: TextStyle(
                                        color: AppColors.textDark,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    _showTranscript
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    color: AppColors.textMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showTranscript)
                            Builder(builder: (ctx) {
                              // Use word-level results if available
                              final words = (widget.session as dynamic).wordResults
                                as List<WordInfo>? ?? [];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  GlassCard(
                                    blur: 14,
                                    opacity: 0.15,
                                    padding: const EdgeInsets.all(18),
                                    child: words.isNotEmpty
                                        ? WordHighlightWidget(words: words)
                                        : Text(transcript,
                                            style: const TextStyle(
                                              color: AppColors.textDark,
                                              fontSize: 14,
                                              height: 1.7,
                                            )),
                                  ),
                                  const SizedBox(height: 8),
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: WordHighlightLegend(),
                                  ),
                                ],
                              );
                            }),
                          const SizedBox(height: 28),
                        ],

                        // ── Action Buttons ────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Practice Again'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textDark,
                                  side: const BorderSide(color: AppColors.borderMedium, width: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => widget.isBaseline
                                    ? _markBaselineComplete(context)
                                    : Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute(
                                            builder: (_) => const HomeScreen()),
                                        (r) => false,
                                      ),
                                icon: const Icon(Icons.home_rounded),
                                label: Text(widget.isBaseline ? 'Continue' : 'Home'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
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

  double _getScore(dynamic scores, String key) {
    switch (key) {
      case 'fluency':
        return scores.fluency.toDouble();
      case 'grammar':
        return scores.grammar.toDouble();
      case 'pronunciation':
        return scores.pronunciation.toDouble();
      default:
        return 0;
    }
  }

  List<Color> _bandGradientColors(double band) {
    if (band >= 7.5) return [const Color(0xFF11998e), const Color(0xFF38ef7d)];
    if (band >= 6.0) return [const Color(0xFF667eea), const Color(0xFF764ba2)];
    if (band >= 5.0) return [const Color(0xFFffd166), const Color(0xFFef8c59)];
    return [const Color(0xFFef233c), const Color(0xFFb5179e)];
  }

  String _cefrDescriptor(String cefr) {
    switch (cefr) {
      case 'C2': return 'Mastery';
      case 'C1': return 'Advanced';
      case 'B2': return 'Upper Intermediate';
      case 'B1': return 'Intermediate';
      case 'A2': return 'Elementary';
      default:   return 'Beginner';
    }
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textDark,
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _AnimatedScoreBar extends StatelessWidget {
  final String label;
  final IconData icon;
  final double score;
  final Color color;
  final Animation<double> animation;

  const _AnimatedScoreBar({
    required this.label,
    required this.icon,
    required this.score,
    required this.color,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${score.round()}/100',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: animation,
                builder: (_, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (score / 100) * animation.value,
                    minHeight: 8,
                    backgroundColor: AppColors.borderLight,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
