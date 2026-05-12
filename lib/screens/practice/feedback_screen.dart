import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../data/models/session.dart';
import '../../data/models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/common/word_highlight_widget.dart';
import '../../widgets/common/animated_button.dart';
import '../home/home_screen.dart';

class FeedbackScreen extends StatefulWidget {
  final Session session;
  final bool isBaseline;
  final Stream<String>? feedbackStream;

  const FeedbackScreen({
    super.key,
    required this.session,
    this.isBaseline = false,
    this.feedbackStream,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _bandScale;
  late List<AnimationController> _barControllers;
  late List<Animation<double>> _barAnims;
  bool _showTranscript = false;

  final StringBuffer _streamedFeedback = StringBuffer();
  bool _streamDone = false;
  String? _lastWrittenToken;

  static const _scoreKeys = ['fluency', 'grammar', 'pronunciation'];
  static const _scoreLabels = ['FLUENCY', 'GRAMMAR', 'VOICE'];

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(duration: const Duration(milliseconds: 900), vsync: this);
    _bandScale = CurvedAnimation(parent: _entryController, curve: Curves.decelerate);

    _barControllers = List.generate(3, (i) => AnimationController(duration: Duration(milliseconds: 900 + i * 100), vsync: this));
    _barAnims = _barControllers.map((c) => CurvedAnimation(parent: c, curve: Curves.easeOutCubic)).toList();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _entryController.forward();
    });
    for (int i = 0; i < _barControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 400 + i * 150), () {
        if (mounted) _barControllers[i].forward();
      });
    }

    if (widget.feedbackStream == null) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && widget.session.feedback != null) TtsService().speak(widget.session.feedback!);
      });
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    for (final c in _barControllers) c.dispose();
    TtsService().stop();
    super.dispose();
  }

  Future<void> _markBaselineComplete(BuildContext ctx) async {
    final scores = widget.session.scores;
    try {
      final fbs = FirebaseService();
      final auth = Provider.of<AuthProvider>(ctx, listen: false);
      final uid = fbs.currentUserId;
      if (uid != null && scores != null) {
        await fbs.markBaselineCompleted(
          userId: uid,
          scores: BaselineScores(fluency: scores.fluency, grammar: scores.grammar, pronunciation: scores.pronunciation, composite: scores.composite),
          weakAreas: _inferWeakAreas(scores),
        );
        final up = auth.currentUser?.copyWith(
          baselineCompleted: true,
          baselineScores: BaselineScores(fluency: scores.fluency, grammar: scores.grammar, pronunciation: scores.pronunciation, composite: scores.composite),
        );
        if (up != null) auth.updateUserProfile(up);
      }
    } catch (e) {}
    if (!ctx.mounted) return;
    Navigator.of(ctx).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
  }

  List<String> _inferWeakAreas(SessionScores sc) {
    final out = <String>[];
    if (sc.fluency < 60) out.add('Fluency');
    if (sc.grammar < 60) out.add('Grammar');
    if (sc.pronunciation < 60) out.add('Pronunciation');
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final w = context.select<SessionProvider, String?>((sp) => sp.languageWarning);
    if (w != null) return _buildLanguageWarning(context, w);

    final sc = widget.session.scores;
    if (sc == null) return _buildDarkSkeleton();

    final band = Formatters.formatIELTSBand(sc.estimatedIELTSBand);
    final comp = sc.composite.round();
    final tr = widget.session.transcript ?? '';
    final fb = widget.session.feedback ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent, pinned: true, elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false),
              ),
              title: Text(
                widget.isBaseline ? 'INIT_METRICS' : 'ANALYTICS_LOG',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScaleTransition(
                      scale: _bandScale,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Column(
                          children: [
                            const Text('EVALUATED BAND', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: AppColors.textTertiary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            const SizedBox(height: 12),
                            Text(band, style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(20)),
                              child: Text(sc.cefrLevel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 1)),
                            ),
                            const SizedBox(height: 24),
                            Text('COMPOSITE $comp / 100', style: const TextStyle(fontSize: 10, color: AppColors.textTertiary, letterSpacing: 1, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const _SectionHeader(title: 'DIAGNOSTIC SCORES'),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.borderLight)),
                      child: Column(
                        children: List.generate(3, (i) {
                          final v = _getV(sc, _scoreKeys[i]);
                          return Padding(
                            padding: EdgeInsets.only(bottom: i < 2 ? 24 : 0),
                            child: _ScoreLinear(lbl: _scoreLabels[i], score: v, anim: _barAnims[i]),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    if (widget.feedbackStream != null || fb.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _SectionHeader(title: 'AI COMMENTARY'),
                          IconButton(icon: const Icon(Icons.spatial_audio_off_sharp, color: Colors.white70, size: 20), onPressed: () {
                            final t = _streamDone ? _streamedFeedback.toString() : fb;
                            if (t.isNotEmpty) { TtsService().stop(); TtsService().speak(t); }
                          })
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.borderLight)),
                        child: widget.feedbackStream != null
                          ? StreamBuilder<String>(
                              stream: widget.feedbackStream,
                              builder: (c, snap) {
                                if (snap.hasData && snap.data != _lastWrittenToken) {
                                  _lastWrittenToken = snap.data;
                                  _streamedFeedback.write(snap.data);
                                }
                                if (snap.connectionState == ConnectionState.done) {
                                  if (!_streamDone) {
                                    _streamDone = true;
                                    Future.delayed(const Duration(milliseconds: 300), () { if (mounted) TtsService().speak(_streamedFeedback.toString()); });
                                  }
                                  return Text(_streamedFeedback.toString(), style: const TextStyle(height: 1.6, color: Colors.white70));
                                }
                                return Text(_streamedFeedback.isEmpty ? 'PARSING...' : '${_streamedFeedback}_', style: const TextStyle(height: 1.6, color: Colors.white70, fontFamily: 'monospace'));
                              }
                            )
                          : Text(fb, style: const TextStyle(height: 1.6, color: Colors.white70)),
                      ),
                      const SizedBox(height: 40),
                    ],

                    if (widget.session.grammarCorrections.isNotEmpty || widget.session.improvementTips.isNotEmpty || widget.session.advancedVocabulary.isNotEmpty) ...[
                      const _SectionHeader(title: 'DEEP ANALYSIS'),
                      const SizedBox(height: 16),
                      _FeedbackExpand(title: 'ERRORS_DETECTED', items: widget.session.grammarCorrections, isWarn: true),
                      const SizedBox(height: 12),
                      _FeedbackExpand(title: 'STABILITY_TIPS', items: widget.session.improvementTips),
                      const SizedBox(height: 12),
                      _FeedbackExpand(title: 'SYNTAX_ENHANCEMENTS', items: widget.session.advancedVocabulary),
                      const SizedBox(height: 40),
                    ],

                    if (tr.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => setState(() => _showTranscript = !_showTranscript),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.borderLight)),
                          child: Row(
                            children: [
                              const Text('SIGNAL TRANSCRIPT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppColors.textTertiary)),
                              const Spacer(),
                              Icon(_showTranscript ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white54),
                            ],
                          ),
                        ),
                      ),
                      if (_showTranscript)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: Colors.black, border: Border.all(color: AppColors.borderLight), borderRadius: BorderRadius.circular(20)),
                            child: (widget.session.wordResults ?? []).isNotEmpty
                              ? WordHighlightWidget(words: widget.session.wordResults!)
                              : Text(tr, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6)),
                          ),
                        ),
                      const SizedBox(height: 40),
                    ],

                    Row(
                      children: [
                        Expanded(child: AnimatedButton(text: 'CLOSE_VIEW', onPressed: () => Navigator.pop(context), backgroundColor: Colors.transparent)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AnimatedButton(
                            text: widget.isBaseline ? 'FINISH' : 'DASHBOARD',
                            onPressed: () => widget.isBaseline ? _markBaselineComplete(context) : Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false)
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  double _getV(dynamic s, String k) {
    if (k == 'fluency') return s.fluency.toDouble();
    if (k == 'grammar') return s.grammar.toDouble();
    return s.pronunciation.toDouble();
  }

  Widget _buildDarkSkeleton() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Shimmer.fromColors(
        baseColor: Colors.white.withValues(alpha: 0.05), highlightColor: Colors.white.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(height: 180, decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.white10), borderRadius: BorderRadius.circular(32))),
              const SizedBox(height: 40),
              for (int i = 0; i < 3; i++) Container(height: 40, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageWarning(BuildContext context, String lang) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.accentRed, size: 48),
              const SizedBox(height: 24),
              const Text('SYSTEM ALERT', style: TextStyle(color: AppColors.accentRed, fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 24),
              Text('DETECTED LANGUAGE: ${lang.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Linguistic flow demands English response inputs only. Recapture required.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, height: 1.4, fontSize: 13)),
              const SizedBox(height: 40),
              AnimatedButton(text: 'REATTEMPT', onPressed: () => Navigator.pop(context)),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false), child: const Text('ABORT_TO_MAIN', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.textTertiary));
}

class _ScoreLinear extends StatelessWidget {
  final String lbl;
  final double score;
  final Animation<double> anim;
  const _ScoreLinear({required this.lbl, required this.score, required this.anim});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lbl, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white70)),
            Text('${score.round()}%', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: anim,
          builder: (_, __) => ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (score / 100) * anim.value,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackExpand extends StatelessWidget {
  final String title;
  final List<String> items;
  final bool isWarn;
  const _FeedbackExpand({required this.title, required this.items, this.isWarn = false});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface, border: Border.all(color: AppColors.borderLight), borderRadius: BorderRadius.circular(20),
        ),
        child: ExpansionTile(
          title: Text(title, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white70)),
          iconColor: Colors.white54, collapsedIconColor: Colors.white54,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: items.isEmpty
            ? [const Text('NO_ANOMALIES_DETECTED', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white24))]
            : items.map((it) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('» ', style: TextStyle(color: isWarn ? AppColors.accentRed : Colors.white38, fontWeight: FontWeight.bold)),
                    Expanded(child: Text(it, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4))),
                  ],
                ),
              )).toList(),
        ),
      ),
    );
  }
}
