import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../data/models/prompt.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart' show SessionProvider, PipelineStage;
import '../../services/local_llm_service.dart';
import '../../widgets/common/animated_button.dart';
import 'feedback_screen.dart';

class RecordingScreen extends StatefulWidget {
  final Prompt prompt;
  final String userId;
  final bool isBaseline;

  const RecordingScreen({
    super.key,
    required this.prompt,
    required this.userId,
    this.isBaseline = false,
  });

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> with TickerProviderStateMixin {
  bool _showReview = false;
  bool _isSubmitting = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<SessionProvider>(
          builder: (context, sp, _) {
            if (sp.isRecording && !_pulseController.isAnimating) {
              _pulseController.repeat(reverse: true);
            } else if (!sp.isRecording && _pulseController.isAnimating) {
              _pulseController.stop();
              _pulseController.reset();
            }

            if (_showReview && !sp.isRecording) return _buildReviewScreen(sp);
            if (sp.isRecording) return _buildRecordingScreen(sp);
            return _buildPromptScreen();
          },
        ),
      ),
    );
  }

  Widget _buildPromptScreen() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
            Text(widget.isBaseline ? 'BASELINE_INIT' : 'PRACTICE_FLOW', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.textTertiary)),
          ],
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              Text('PROMPT STATEMENT'.toUpperCase(), style: const TextStyle(fontSize: 9, color: AppColors.textTertiary, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 24),
              Text(
                widget.prompt.text,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                child: Text(widget.prompt.category.toUpperCase(), style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white70)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        const Text('INSTRUCTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.textTertiary)),
        const SizedBox(height: 16),
        _buildCleanTip('Find optimal silent conditions'),
        _buildCleanTip('Deliver continuous responses'),
        _buildCleanTip('Duration limit: 45-60 seconds'),
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _startRecording,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 80, height: 80,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.mic, color: Colors.black, size: 32),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('START TRANSMISSION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCleanTip(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.radio_button_unchecked, size: 14, color: Colors.white38),
          const SizedBox(width: 12),
          Expanded(child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.5))),
        ],
      ),
    );
  }

  Widget _buildRecordingScreen(SessionProvider sp) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: AppColors.accentRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fiber_manual_record, color: AppColors.accentRed, size: 14),
              SizedBox(width: 8),
              Text('LIVE RECORDING', style: TextStyle(fontFamily: 'monospace', color: AppColors.accentRed, fontWeight: FontWeight.bold, fontSize: 10)),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _stopRecording,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (ctx, ch) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 180 * _pulseAnimation.value, height: 180 * _pulseAnimation.value,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.2))),
                ),
                Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accentRed),
                  child: const Icon(Icons.stop_rounded, color: Colors.white, size: 48),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 60),
        Text(
          Formatters.formatDuration(sp.recordingDuration),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 64, fontWeight: FontWeight.bold),
        ),
        const Text('SYSTEM CLOCK ACTIVE', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: AppColors.textTertiary)),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: AnimatedButton(
            text: 'TERMINATE RECORDING',
            onPressed: _stopRecording,
            backgroundColor: Colors.transparent,
            textColor: AppColors.accentRed,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewScreen(SessionProvider sp) {
    final s = sp.currentSession;
    if (s == null) return const SizedBox();
    if (_isSubmitting) return _buildProcessingOverlay(sp.pipelineStage);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Text('ARCHIVE VALIDATED', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(32), border: Border.all(color: AppColors.borderLight)),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline, size: 64, color: Colors.white),
              const SizedBox(height: 24),
              const Text('DATA CAPTURED', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text('LEN: ${Formatters.formatDuration(s.audioDuration ?? 0)}', style: const TextStyle(fontFamily: 'monospace', color: AppColors.textTertiary, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: () => sp.playCurrentRecording(),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow, color: Colors.black),
                SizedBox(width: 8),
                Text('PREVIEW OUTPUT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  sp.clearCurrentSession();
                  setState(() => _showReview = false);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.borderLight), borderRadius: BorderRadius.circular(24)),
                  alignment: Alignment.center,
                  child: const Text('RE-RECORD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AnimatedButton(
                text: 'RUN ANALYTICS',
                onPressed: () => _submitRecording(sp, Provider.of<AuthProvider>(context, listen: false)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _startRecording() async {
    try {
      final sp = Provider.of<SessionProvider>(context, listen: false);
      await sp.startRecording(widget.prompt, widget.userId, isBaseline: widget.isBaseline);
      LocalLlmService().warmLoad();
    } catch (e) {
      if (mounted) _snack('Error', '$e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await Provider.of<SessionProvider>(context, listen: false).stopRecording();
      setState(() => _showReview = true);
    } catch (e) {
      if (mounted) {
        _snack('Failure', '$e');
        Provider.of<SessionProvider>(context, listen: false).clearCurrentSession();
      }
    }
  }

  Future<void> _submitRecording(SessionProvider sp, AuthProvider auth) async {
    setState(() => _isSubmitting = true);
    try {
      sp.submitRecording(auth).catchError((e) {
        setState(() => _isSubmitting = false);
        if (mounted) _snack('Fault', '$e');
      });
      _waitAndNavigate(sp, auth);
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) _snack('Submit Error', '$e');
    }
  }

  Future<void> _waitAndNavigate(SessionProvider sp, AuthProvider auth) async {
    while (mounted && sp.pipelineStage == PipelineStage.transcribing) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    if (sp.earlyTranscript != null && sp.currentSession != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => FeedbackScreen(session: sp.currentSession!, isBaseline: widget.isBaseline, feedbackStream: sp.feedbackStream)),
      );
    }
  }

  void _snack(String t, String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        elevation: 0, behavior: SnackBarBehavior.floating, backgroundColor: Colors.transparent,
        content: AwesomeSnackbarContent(title: t, message: m, contentType: ContentType.failure),
      ));
  }

  Widget _buildProcessingOverlay(PipelineStage stage) {
    final String lbl;
    switch (stage) {
      case PipelineStage.transcribing: lbl = 'DECODING AUDIO SIGNAL'; break;
      case PipelineStage.analyzing: lbl = 'COMPUTING LINGUISTIC DATA'; break;
      case PipelineStage.generating: lbl = 'CONSTRUCTING AI FEEDBACK'; break;
      default: lbl = 'PROCESSING SEQUENCE';
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SpinKitDoubleBounce(color: Colors.white, size: 64),
            const SizedBox(height: 32),
            Text(lbl, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
