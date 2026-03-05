import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/utils/validators.dart';
import '../../data/models/session.dart';
import '../../widgets/common/glass_card.dart';
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

  @override
  Widget build(BuildContext context) {
    final scores = widget.session.scores;
    if (scores == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1a1a2e),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final band = Formatters.formatIELTSBand(scores.estimatedIELTSBand);
    final composite = scores.composite.round();
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
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (r) => false,
                    ),
                  ),
                  title: Text(
                    widget.isBaseline ? 'Baseline Results' : 'Session Results',
                    style: const TextStyle(
                      color: Colors.white,
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
                                const SizedBox(height: 4),
                                Text(
                                  _bandLabel(scores.estimatedIELTSBand),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
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
                            blur: 14,
                            opacity: 0.18,
                            padding: const EdgeInsets.all(22),
                            child: Text(
                              feedback,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],

                        // ── Transcript (collapsible) ─────────────────────
                        if (transcript.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () => setState(() => _showTranscript = !_showTranscript),
                            child: GlassCard(
                              blur: 14,
                              opacity: 0.18,
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  const Icon(Icons.text_snippet_outlined,
                                      color: Colors.white70, size: 20),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'View Transcript',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    _showTranscript
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    color: Colors.white54,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showTranscript) ...[
                            const SizedBox(height: 8),
                            GlassCard(
                              blur: 14,
                              opacity: 0.15,
                              padding: const EdgeInsets.all(18),
                              child: Text(
                                transcript,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.7,
                                ),
                              ),
                            ),
                          ],
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
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white38),
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                                  (r) => false,
                                ),
                                icon: const Icon(Icons.home_rounded),
                                label: Text(widget.isBaseline ? 'Continue' : 'Home'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF764ba2),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
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

  String _bandLabel(double band) {
    if (band >= 8.0) return 'Expert User';
    if (band >= 7.0) return 'Good User';
    if (band >= 6.0) return 'Competent User';
    if (band >= 5.0) return 'Modest User';
    return 'Keep Practising!';
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
        color: Colors.white,
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
                      color: Colors.white,
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
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
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
