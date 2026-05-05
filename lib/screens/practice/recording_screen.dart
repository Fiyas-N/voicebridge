import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
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

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  bool _showReview = false;
  bool _isSubmitting = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<SessionProvider>(
          builder: (context, sessionProvider, _) {
            if (sessionProvider.isRecording && !_pulseController.isAnimating) {
              _pulseController.repeat(reverse: true);
            } else if (!sessionProvider.isRecording &&
                _pulseController.isAnimating) {
              _pulseController.stop();
              _pulseController.reset();
            }

            if (_showReview && !sessionProvider.isRecording) {
              return _buildReviewScreen(sessionProvider);
            }

            if (sessionProvider.isRecording) {
              return _buildRecordingScreen(sessionProvider);
            }

            return _buildPromptScreen();
          },
        ),
      ),
    );
  }

  Widget _buildPromptScreen() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 100,
          floating: false,
          pinned: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: AppColors.secondary, // Solid vibrant background
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        widget.isBaseline
                            ? 'Baseline Assessment'
                            : 'Practice Session',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        'Part ${widget.prompt.ieltsPartNumber} · ${widget.prompt.category}',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Neumorphic(
                  style: NeumorphicStyle(
                    shape: NeumorphicShape.flat,
                    boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
                    depth: 6,
                    intensity: 0.65,
                    color: AppColors.backgroundOffWhite,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          widget.prompt.text,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  '💡 Recording Tips',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Neumorphic(
                  style: NeumorphicStyle(
                    shape: NeumorphicShape.flat,
                    boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
                    depth: 4,
                    intensity: 0.6,
                    color: AppColors.backgroundOffWhite,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildTip('Speak for 30-60 seconds'),
                        const SizedBox(height: 12),
                        _buildTip('Speak naturally and clearly'),
                        const SizedBox(height: 12),
                        _buildTip('Don\'t worry about mistakes'),
                        const SizedBox(height: 12),
                        _buildTip('Find a quiet environment'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    children: [
                      NeumorphicButton(
                        onPressed: _startRecording,
                        style: const NeumorphicStyle(
                          shape: NeumorphicShape.convex,
                          boxShape: NeumorphicBoxShape.circle(),
                          depth: 10,
                          intensity: 0.85,
                          color: AppColors.secondary,
                        ),
                        padding: EdgeInsets.zero,
                        child: const SizedBox(
                          width: 120,
                          height: 120,
                          child: Icon(
                            Icons.mic,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Tap to Start Recording',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingScreen(SessionProvider sessionProvider) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.error,
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recording...',
                    style:
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 200 * _pulseAnimation.value,
                            height: 200 * _pulseAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.error.withValues(
                                  alpha: 0.3 * (1 - (_pulseAnimation.value - 1) / 0.3),
                                ),
                                width: 4,
                              ),
                            ),
                          ),
                          Container(
                            width: 160,
                            height: 160,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mic,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 60),
                  Text(
                    Formatters.formatDuration(sessionProvider.recordingDuration),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '/ ${widget.isBaseline ? "00:45" : "01:00"}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.textMedium,
                        ),
                  ),
                  const Spacer(),
                  AnimatedButton(
                    text: 'Stop Recording',
                    icon: Icons.stop,
                    width: double.infinity,
                    backgroundColor: AppColors.error,
                    onPressed: _stopRecording,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewScreen(SessionProvider sessionProvider) {
    final session = sessionProvider.currentSession;
    if (session == null) return const SizedBox();

    // Show pipeline-aware loading overlay while processing
    if (_isSubmitting) {
      return _buildProcessingOverlay(sessionProvider.pipelineStage);
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 100,
          floating: false,
          pinned: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: AppColors.success,
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Review Your Recording',
                        style:
                            Theme.of(context).textTheme.displayMedium?.copyWith(
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Neumorphic(
                  style: NeumorphicStyle(
                    shape: NeumorphicShape.flat,
                    boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
                    depth: 6,
                    intensity: 0.7,
                    color: AppColors.success,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle, size: 80, color: Colors.white),
                        const SizedBox(height: 20),
                        Text(
                          'Recording Complete!',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Duration: ${Formatters.formatDuration(session.audioDuration ?? 0)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => sessionProvider.playCurrentRecording(),
                  icon: const Icon(Icons.play_arrow, size: 24),
                  label: const Text('Play Recording'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 60),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          sessionProvider.clearCurrentSession();
                          setState(() {
                            _showReview = false;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Re-record'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AnimatedButton(
                        text: 'Submit',
                        icon: Icons.send,
                        onPressed: () => _submitRecording(
                          sessionProvider,
                          Provider.of<AuthProvider>(context, listen: false),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTip(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Future<void> _startRecording() async {
    try {
      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);
      await sessionProvider.startRecording(
        widget.prompt,
        widget.userId,
        isBaseline: widget.isBaseline,
      );

      // Pre-warm Gemma while the user is speaking.
      // User typically speaks 5–30 seconds — plenty of time to load the
      // model into GPU memory so there is no cold-start wait after STT.
      LocalLlmService().warmLoad();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Recording Error',
              message: '$e',
              contentType: ContentType.failure,
            ),
          ));
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);
      await sessionProvider.stopRecording();
      setState(() => _showReview = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Oops',
              message: '$e',
              contentType: ContentType.failure,
            ),
          ));
        final sessionProvider =
            Provider.of<SessionProvider>(context, listen: false);
        sessionProvider.clearCurrentSession();
      }
    }
  }

  Future<void> _submitRecording(
      SessionProvider sessionProvider, AuthProvider authProvider) async {
    setState(() => _isSubmitting = true);
    try {
      _startPipelineAndNavigate(sessionProvider, authProvider);
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Submit Failed',
              message: '$e',
              contentType: ContentType.failure,
            ),
          ));
      }
    }
  }

  void _startPipelineAndNavigate(
      SessionProvider sessionProvider, AuthProvider authProvider) {
    // Start the async pipeline — don't await here so we can react to
    // intermediate state changes immediately.
    sessionProvider.submitRecording(authProvider).catchError((e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Pipeline Error',
              message: '$e',
              contentType: ContentType.failure,
            ),
          ));
      }
    });

    // Poll for transcript availability, then navigate forward.
    // The pipeline notifies listeners when earlyTranscript is set.
    _waitForTranscriptThenNavigate(sessionProvider, authProvider);
  }

  Future<void> _waitForTranscriptThenNavigate(
      SessionProvider sessionProvider, AuthProvider authProvider) async {
    // Wait until STT finishes (stage transitions to 'analyzing' or beyond).
    while (mounted &&
        sessionProvider.pipelineStage == PipelineStage.transcribing) {
      await Future.delayed(const Duration(milliseconds: 150));
    }

    if (!mounted) return;

    if (sessionProvider.earlyTranscript != null &&
        sessionProvider.currentSession != null) {
      // Navigate immediately — FeedbackScreen will stream the rest.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => FeedbackScreen(
            session: sessionProvider.currentSession!,
            isBaseline: widget.isBaseline,
            feedbackStream: sessionProvider.feedbackStream,
          ),
        ),
      );
    }
  }

  // ── Processing overlay — shown while pipeline runs ───────────────────────
  Widget _buildProcessingOverlay(PipelineStage stage) {
    final String label;
    final Widget spinner;

    switch (stage) {
      case PipelineStage.transcribing:
        label = 'Transcribing your speech…';
        spinner = const SpinKitPulse(color: AppColors.primary, size: 64);
        break;
      case PipelineStage.analyzing:
        label = 'Analysing grammar & pronunciation…';
        spinner = const SpinKitThreeBounce(color: AppColors.secondary, size: 40);
        break;
      case PipelineStage.generating:
        label = 'Generating AI coaching feedback…';
        spinner = const SpinKitWave(color: AppColors.primary, size: 40, itemCount: 5);
        break;
      default:
        label = 'Processing…';
        spinner = const SpinKitRing(color: AppColors.primary, size: 60, lineWidth: 4);
    }

    return Container(
      color: AppColors.backgroundOffWhite,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            spinner,
            const SizedBox(height: 32),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
