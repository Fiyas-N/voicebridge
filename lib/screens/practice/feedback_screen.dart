import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/validators.dart';
import '../../data/models/session.dart';
import '../../data/models/user_profile.dart';
import '../../data/local/database_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart' show SessionProvider, PipelineStage;
import '../../services/firebase_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/common/word_highlight_widget.dart';
import '../../widgets/common/animated_button.dart';
import '../../widgets/common/ai_voice_gender_toggle.dart';
import '../../widgets/common/main_navigation.dart';
import '../../widgets/common/dot_grid_background.dart';
import '../../widgets/common/glass_card.dart';

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
  bool _showTranscript = false;

  final StringBuffer _streamedFeedback = StringBuffer();
  bool _streamDone = false;
  String? _lastWrittenToken;

  Session? _dbSession;
  bool _dbHydrationDone = false;
  bool _dbRefreshing = false;
  bool _wasProcessing = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(duration: const Duration(milliseconds: 900), vsync: this);
    _bandScale = CurvedAnimation(parent: _entryController, curve: Curves.decelerate);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _entryController.forward();
    });

    _loadDbSession();

    if (widget.feedbackStream == null) {
      Future.delayed(const Duration(milliseconds: 1200), () async {
        if (!mounted) return;
        final sp = context.read<SessionProvider>();
        final s = sp.currentSession?.sessionId == widget.session.sessionId
            ? sp.currentSession
            : widget.session;
        if (s?.feedback != null) {
          await TtsService().init();
          await TtsService().speak(s!.feedback!);
        }
      });
    }
  }

  Future<void> _speakCommentary(String text) async {
    if (text.trim().isEmpty) return;
    await TtsService().init();
    await TtsService().stop();
    await TtsService().speak(text);
  }

  @override
  void dispose() {
    _entryController.dispose();
    TtsService().stop();
    super.dispose();
  }

  Future<void> _markBaselineComplete(BuildContext ctx) async {
    final sp = Provider.of<SessionProvider>(ctx, listen: false);
    final session = sp.currentSession?.sessionId == widget.session.sessionId
        ? sp.currentSession
        : widget.session;
    final scores = session?.scores;
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
    } catch (e) {
      debugPrint('FeedbackScreen: baseline completion side-effect failed: $e');
    }
    if (!ctx.mounted) return;
    Navigator.of(ctx).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainNavigationScreen()), (r) => false);
  }

  List<String> _inferWeakAreas(SessionScores sc) {
    final out = <String>[];
    if (sc.fluency < 60) out.add('Fluency');
    if (sc.grammar < 60) out.add('Grammar');
    if (sc.pronunciation < 60) out.add('Pronunciation');
    return out;
  }

  Future<void> _loadDbSession() async {
    if (mounted && _dbHydrationDone) {
      setState(() => _dbRefreshing = true);
    }
    try {
      final row = await DatabaseHelper.instance.getSession(widget.session.sessionId);
      if (!mounted) return;
      setState(() {
        _dbHydrationDone = true;
        _dbRefreshing = false;
        _dbSession = row != null ? Session.fromJson(row) : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _dbHydrationDone = true;
          _dbRefreshing = false;
        });
      }
    }
  }

  Session _resolveSession(SessionProvider sp) {
    final id = widget.session.sessionId;
    final live = sp.currentSession;

    if (live != null && live.sessionId == id && live.scores != null) {
      return live;
    }
    final db = _dbSession;
    if (db != null && db.sessionId == id && db.scores != null) {
      return db;
    }
    if (live != null && live.sessionId == id) {
      return live;
    }
    if (db != null && db.sessionId == id) {
      return db;
    }
    return widget.session;
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SessionProvider>();
    final processingNow = sp.isProcessing;
    if (_wasProcessing && !processingNow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadDbSession();
      });
    }
    _wasProcessing = processingNow;

    final id = widget.session.sessionId;
    final session = _resolveSession(sp);

    final w = sp.languageWarning;
    if (w != null) return _buildLanguageWarning(context, w);

    final sc = session.scores;
    final pipelineForSession =
        sp.isProcessing && (sp.currentSession?.sessionId == id);

    if (sc == null) {
      if (pipelineForSession) {
        return _buildPipelineLoading(context, sp.pipelineStage);
      }
      if (!_dbHydrationDone || _dbRefreshing) {
        return _buildDbHydrating(context);
      }
      return _buildAnalysisIncomplete(context, sp);
    }

    final band = Formatters.formatIELTSBand(sc.estimatedIELTSBand);
    final comp = sc.composite.round();
    final tr = session.transcript ??
        (sp.currentSession?.sessionId == id ? sp.earlyTranscript : null) ??
        '';
    final fb = session.feedback ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DotGridBackground(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent, pinned: true, elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainNavigationScreen()), (r) => false),
                ),
              title: Text(
                widget.isBaseline ? 'Your starting scores' : 'Your feedback',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: AiVoiceGenderToggle(
                      compact: true,
                      isMale: TtsService().isMale,
                      onChanged: (male) async {
                        await TtsService().setVoice(male);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScaleTransition(
                      scale: _bandScale,
                      child: _buildPerformanceHero(context, band, comp, sc),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'How you did',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        letterSpacing: 1.4,
                        color: VbColor.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fluency, grammar, and pronunciation rolled into one composite.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        color: VbColor.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildMetricsGrid(sc),
                    _buildPronunciationPanel(session),
                    const SizedBox(height: 32),
                    
                    if (widget.feedbackStream != null || fb.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _SectionHeader(title: 'Coach feedback'),
                          IconButton(icon: const Icon(Icons.spatial_audio_off_sharp, color: Colors.white70, size: 20), onPressed: () async {
                            final t = _streamDone ? _streamedFeedback.toString() : fb;
                            if (t.isNotEmpty) await _speakCommentary(t);
                          })
                        ],
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.all(20),
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
                                    Future.delayed(const Duration(milliseconds: 300), () async {
                                      if (!mounted) return;
                                      await _speakCommentary(_streamedFeedback.toString());
                                    });
                                  }
                                  return Text(
                                    _streamedFeedback.toString(),
                                    style: GoogleFonts.inter(
                                      height: 1.6,
                                      color: VbColor.onSurfaceVariant,
                                    ),
                                  );
                                }
                                return Text(
                                  _streamedFeedback.isEmpty
                                      ? 'Just a moment…'
                                      : '${_streamedFeedback}_',
                                  style: GoogleFonts.jetBrainsMono(
                                    height: 1.6,
                                    color: VbColor.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                );
                              }
                            )
                          : Text(fb, style: GoogleFonts.inter(height: 1.6, color: VbColor.onSurfaceVariant)),
                      ),
                      const SizedBox(height: 40),
                    ],

                    if (session.grammarCorrections.isNotEmpty || session.improvementTips.isNotEmpty || session.advancedVocabulary.isNotEmpty) ...[
                      const _SectionHeader(title: 'More detail'),
                      const SizedBox(height: 16),
                      _FeedbackExpand(title: 'Grammar fixes', items: session.grammarCorrections, isWarn: true),
                      const SizedBox(height: 12),
                      _FeedbackExpand(title: 'Fluency tips', items: session.improvementTips),
                      const SizedBox(height: 12),
                      _FeedbackExpand(title: 'Vocabulary ideas', items: session.advancedVocabulary),
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
                              const Text('Your transcript', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1, color: AppColors.textTertiary)),
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
                            child: (session.wordResults ?? []).isNotEmpty
                              ? WordHighlightWidget(words: session.wordResults!)
                              : Text(tr, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6)),
                          ),
                        ),
                      const SizedBox(height: 40),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: AnimatedButton(
                            text: 'Close',
                            isPrimary: false,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AnimatedButton(
                            text: widget.isBaseline ? 'Finish' : 'Home',
                            onPressed: () => widget.isBaseline ? _markBaselineComplete(context) : Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainNavigationScreen()), (r) => false)
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
    ),
    );
  }

  Widget _buildPerformanceHero(
    BuildContext context,
    String band,
    int comp,
    SessionScores sc,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          SizedBox(
            height: 172,
            width: 172,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: -3.1415926535 / 2,
                  child: SizedBox(
                    width: 172,
                    height: 172,
                    child: CircularProgressIndicator(
                      value: (comp / 100).clamp(0.0, 1.0),
                      strokeWidth: 5,
                      backgroundColor: VbColor.surfaceContainerHighest,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        VbColor.accentElectric,
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$comp',
                      style: GoogleFonts.spaceMono(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: VbColor.onSurface,
                      ),
                    ),
                    Text(
                      '/ 100',
                      style: GoogleFonts.spaceMono(
                        fontSize: 12,
                        color: VbColor.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'IELTS $band · ${sc.cefrLevel}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: VbColor.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(SessionScores sc) {
    Widget chip(String k, String v) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              k,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                letterSpacing: 1,
                color: VbColor.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              v,
              style: GoogleFonts.spaceMono(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: VbColor.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scores',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            letterSpacing: 1.4,
            color: VbColor.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            chip('Fluency', '${sc.fluency.round()}%'),
            chip('Grammar', '${sc.grammar.round()}%'),
            chip('Pronunciation', '${sc.pronunciation.round()}%'),
            chip('CEFR', sc.cefrLevel),
          ],
        ),
      ],
    );
  }

  Widget _buildPronunciationPanel(Session session) {
    if (session.pronunciationTips.isEmpty) return const SizedBox.shrink();
    final tip = session.pronunciationTips.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Text(
          'Pronunciation',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            letterSpacing: 1.4,
            color: VbColor.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.mic_none_rounded,
                    color: VbColor.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Coach tip',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: VbColor.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VbColor.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VbColor.outlineVariant),
                ),
                child: Text(
                  tip,
                  style: GoogleFonts.inter(fontSize: 13, height: 1.45),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _speakCommentary(tip),
                  child: Text(
                    'Hear the tip',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPipelineLoading(BuildContext context, PipelineStage stage) {
    final String lbl;
    switch (stage) {
      case PipelineStage.transcribing:
        lbl = 'Transcribing your answer…';
        break;
      case PipelineStage.analyzing:
        lbl = 'Analyzing your answer…';
        break;
      case PipelineStage.generating:
        lbl = 'Writing your feedback…';
        break;
      default:
        lbl = 'Working…';
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SpinKitDoubleBounce(color: AppColors.primary, size: 56),
              const SizedBox(height: 28),
              Text(
                lbl,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDbHydrating(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpinKitDoubleBounce(color: AppColors.primary, size: 56),
              SizedBox(height: 28),
              Text(
                'Loading your results',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisIncomplete(BuildContext context, SessionProvider sp) {
    final err = sp.pipelineError;
    final displayErr = err != null && err.length > 1800 ? '${err.substring(0, 1800)}…' : err;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    const Icon(Icons.info_outline, color: AppColors.textTertiary, size: 48),
                    const SizedBox(height: 20),
                    const Text(
                      'Couldn\'t load results',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      err != null && err.isNotEmpty
                          ? 'Analysis didn\'t finish. You can try getting feedback again, or open History after a successful run.'
                          : 'This screen could not load scores for this session. Try Home → History, or record again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55), height: 1.4, fontSize: 13),
                    ),
                    if (displayErr != null && displayErr.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: SelectableText(
                          displayErr,
                          style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.35, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (Navigator.of(context).canPop())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AnimatedButton(
                        text: 'Go back',
                        onPressed: () {
                          sp.clearPipelineError();
                          Navigator.of(context).maybePop();
                        },
                      ),
                    ),
                  AnimatedButton(
                    text: 'Back to home',
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                      (r) => false,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              const Text('English only', style: TextStyle(color: AppColors.accentRed, fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 24),
              Text('We heard: ${lang.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 16),
              const Text('VoiceBridge works best when you speak in English. Please try your answer again in English.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, height: 1.4, fontSize: 13)),
              const SizedBox(height: 40),
              AnimatedButton(text: 'Try again', onPressed: () => Navigator.pop(context)),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainNavigationScreen()), (r) => false), child: const Text('Back to home', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold))),
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
            ? [const Text('Nothing here yet', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white24))]
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
