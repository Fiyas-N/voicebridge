import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../data/models/prompt.dart';
import '../../providers/session_provider.dart';
import '../../widgets/common/gradient_card.dart';
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
  bool _hasStarted = false;
  bool _showReview = false;
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
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
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
                            Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        'Part ${widget.prompt.ieltsPartNumber} · ${widget.prompt.category}',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.white.withValues(alpha: 0.8),
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
                GradientCard(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.prompt.text,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  '💡 Recording Tips',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 16),
                GradientCard(
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
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _startRecording,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.large,
                          ),
                          child: const Icon(
                            Icons.mic,
                            size: 56,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Tap to Start Recording',
                        style:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
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
        gradient: LinearGradient(
          colors: [
            AppColors.errorRed.withValues(alpha: 0.1),
            AppColors.errorRed.withValues(alpha: 0.05),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.errorRed, Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recording...',
                    style:
                        Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.white,
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
                                color: AppColors.errorRed.withValues(
                                  alpha: 0.3 *
                                      (1 -
                                          (_pulseAnimation.value - 1) / 0.3),
                                ),
                                width: 2,
                              ),
                            ),
                          ),
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.errorRed,
                                  Color(0xFFDC2626)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.errorRed.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.mic,
                              size: 80,
                              color: AppColors.white,
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
                          color: AppColors.errorRed,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '/ ${widget.isBaseline ? "00:45" : "01:00"}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.mediumGray,
                        ),
                  ),
                  const Spacer(),
                  AnimatedButton(
                    text: 'Stop Recording',
                    icon: Icons.stop,
                    width: double.infinity,
                    backgroundColor: AppColors.errorRed,
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
              decoration: const BoxDecoration(
                gradient: AppColors.successGradient,
              ),
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
                                  color: AppColors.white,
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
                GradientCard(
                  gradient: AppColors.successGradient,
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 80,
                        color: AppColors.white,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Recording Complete!',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: AppColors.white,
                                ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Duration: ${Formatters.formatDuration(session.audioDuration ?? 0)}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.white.withValues(alpha: 0.9),
                            ),
                      ),
                    ],
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
                            _hasStarted = false;
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
                        onPressed: () => _submitRecording(sessionProvider),
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
        const Icon(Icons.check_circle, size: 20, color: AppColors.successGreen),
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
      setState(() => _hasStarted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
        final sessionProvider =
            Provider.of<SessionProvider>(context, listen: false);
        sessionProvider.clearCurrentSession();
        setState(() => _hasStarted = false);
      }
    }
  }

  Future<void> _submitRecording(SessionProvider sessionProvider) async {
    try {
      await sessionProvider.submitRecording();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => FeedbackScreen(
              session: sessionProvider.currentSession!,
              isBaseline: widget.isBaseline,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    }
  }
}
