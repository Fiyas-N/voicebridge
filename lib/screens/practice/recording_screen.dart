import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/wav_peaks.dart';
import '../../core/utils/validators.dart';
import '../../data/models/prompt.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart' show SessionProvider, PipelineStage;
import '../../services/local_llm_service.dart';
import '../../widgets/common/animated_button.dart';
import '../../widgets/common/dot_grid_background.dart';
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
  List<double>? _wavePeaks;
  String? _waveLoadPath;
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
      body: DotGridBackground(
        child: SafeArea(
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
            Text(widget.isBaseline ? 'First session' : 'Practice', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.textTertiary)),
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
              Text('Your prompt', style: const TextStyle(fontSize: 9, color: AppColors.textTertiary, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
        const Text('Before you start', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AppColors.textTertiary)),
        const SizedBox(height: 16),
        _buildCleanTip('Find a quiet place with little background noise.'),
        _buildCleanTip('Speak in full sentences without long pauses.'),
        _buildCleanTip('Aim for about 45–60 seconds of continuous speech.'),
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
              const Text('Tap to record', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
          Expanded(child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white70, letterSpacing: 0.2, height: 1.3))),
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
              Text('Recording', style: TextStyle(fontFamily: 'monospace', color: AppColors.accentRed, fontWeight: FontWeight.bold, fontSize: 10)),
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
        const Text('Timer', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: AppColors.textTertiary)),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: AnimatedButton(
            text: 'Stop recording',
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

    final audioPath = s.audioLocalPath;
    if (audioPath != null && _waveLoadPath != audioPath) {
      _waveLoadPath = audioPath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (sp.currentSession?.audioLocalPath != audioPath) return;
        setState(() => _wavePeaks = null);
        loadWavPeaks(audioPath).then((peaks) {
          if (mounted && sp.currentSession?.audioLocalPath == audioPath) {
            setState(() => _wavePeaks = peaks);
          }
        });
      });
    }

    final totalSec = (s.audioDuration ?? 0).clamp(0.1, 9999.0);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Text('Recording saved', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(32), border: Border.all(color: AppColors.borderLight)),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline, size: 64, color: Colors.white),
              const SizedBox(height: 24),
              const Text('Looks good', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text('Length: ${Formatters.formatDuration(s.audioDuration ?? 0)}', style: const TextStyle(fontFamily: 'monospace', color: AppColors.textTertiary, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 40),
        const Text('Preview', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: AppColors.textTertiary, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 12),
        ValueListenableBuilder<bool>(
          valueListenable: sp.recordingPreviewPlaying,
          builder: (context, playing, _) {
            return StreamBuilder<Duration>(
              stream: sp.recordingPlaybackPosition,
              initialData: Duration.zero,
              builder: (context, posSnap) {
                final pos = posSnap.data ?? Duration.zero;
                final progress = totalSec > 0 ? (pos.inMilliseconds / (totalSec * 1000)).clamp(0.0, 1.0) : 0.0;
                return _VoiceNotePreview(
                  peaks: _wavePeaks,
                  progress01: progress,
                  isPlaying: playing,
                  elapsedLabel: Formatters.formatDuration(pos.inSeconds.toDouble()),
                  totalLabel: Formatters.formatDuration(totalSec),
                  onToggle: () async {
                    try {
                      if (playing) {
                        await sp.pauseRecordingPlayback();
                      } else {
                        if (pos.inMilliseconds < 200) {
                          await sp.playCurrentRecording();
                        } else {
                          await sp.resumeRecordingPlayback();
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Playback: $e'), behavior: SnackBarBehavior.floating),
                        );
                      }
                    }
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  sp.clearCurrentSession();
                  setState(() {
                    _showReview = false;
                    _wavePeaks = null;
                    _waveLoadPath = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.borderLight), borderRadius: BorderRadius.circular(24)),
                  alignment: Alignment.center,
                  child: const Text('Re-record', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AnimatedButton(
                text: 'Get feedback',
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
    const deadline = Duration(minutes: 6);
    final start = DateTime.now();
    while (mounted && sp.pipelineStage == PipelineStage.transcribing) {
      if (DateTime.now().difference(start) > deadline) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          _snack('Timeout', 'Speech decoding is taking too long. Check storage and try again.');
        }
        return;
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    if (sp.earlyTranscript != null && sp.currentSession != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => FeedbackScreen(session: sp.currentSession!, isBaseline: widget.isBaseline, feedbackStream: sp.feedbackStream)),
      );
    } else if (mounted) {
      setState(() => _isSubmitting = false);
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
      case PipelineStage.transcribing: lbl = 'Transcribing your answer…'; break;
      case PipelineStage.analyzing: lbl = 'Analyzing your answer…'; break;
      case PipelineStage.generating: lbl = 'Writing your feedback…'; break;
      default: lbl = 'Working…';
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

class _VoiceNotePreview extends StatelessWidget {
  final List<double>? peaks;
  final double progress01;
  final bool isPlaying;
  final String elapsedLabel;
  final String totalLabel;
  final VoidCallback onToggle;

  const _VoiceNotePreview({
    required this.peaks,
    required this.progress01,
    required this.isPlaying,
    required this.elapsedLabel,
    required this.totalLabel,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bars = peaks ?? List<double>.filled(42, 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SizedBox(
              height: 46,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(bars.length, (i) {
                  final h = 6.0 + 38.0 * bars[i];
                  final past = ((i + 0.5) / bars.length) <= progress01;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0.5),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: h.clamp(6.0, 44.0),
                          decoration: BoxDecoration(
                            color: past
                                ? AppColors.primary.withValues(alpha: 0.9)
                                : Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$elapsedLabel\n$totalLabel',
            textAlign: TextAlign.end,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.white60, height: 1.2),
          ),
        ],
      ),
    );
  }
}
