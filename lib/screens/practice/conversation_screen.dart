import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/conversation_service.dart';
import '../../services/tts_service.dart';
import '../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import 'dart:math' as math;
import 'dart:ui';

enum _TurnState { idle, listening, processing, aiThinking, aiSpeaking }

class ConversationScreen extends StatefulWidget {
  final String? topic;
  final String topicEmoji;

  const ConversationScreen({
    super.key,
    this.topic,
    this.topicEmoji = '💬',
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen>
    with SingleTickerProviderStateMixin {
  late ConversationService _conversationService;
  final AudioRecorder _recorder = AudioRecorder();
  final ScrollController _scrollController = ScrollController();

  _TurnState _state = _TurnState.idle;
  bool _sessionStarted = false;
  bool _ending = false;
  String? _currentAudioPath;
  DateTime? _startTime;

  // Pulse animation for mic
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _conversationService = ConversationService(topic: widget.topic);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.18)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _startSession();
  }

  @override
  void dispose() {
    TtsService().stop();
    _recorder.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (immediate) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  String _stateLabel() {
    switch (_state) {
      case _TurnState.listening: return 'LISTENING';
      case _TurnState.processing: return 'TRANSCRIBING';
      case _TurnState.aiThinking: return 'THINKING';
      case _TurnState.aiSpeaking: return 'SPEAKING';
      default: return 'TAP TO SPEAK';
    }
  }

  Color _stateColor() {
    switch (_state) {
      case _TurnState.listening:
        return AppColors.orbActive;
      case _TurnState.aiSpeaking:
        return AppColors.orbSpeaking;
      case _TurnState.processing:
      case _TurnState.aiThinking:
        return AppColors.orbThinking;
      default:
        return Colors.white.withAlpha(128);
    }
  }

  Future<void> _startSession() async {
    setState(() => _state = _TurnState.aiThinking);
    final opening = await _conversationService.startConversation();
    if (!mounted) return;
    setState(() => _startTime = DateTime.now());
    
    // Create a temporary stream for the opening so it renders character by character too
    final stream = _simulateTypingStream(opening);
    await _handleStreamingAIResponse(stream);
  }
  
  Stream<String> _simulateTypingStream(String text) async* {
    for (int i = 0; i < text.length; i++) {
      await Future.delayed(const Duration(milliseconds: 15));
      yield text[i];
    }
  }

  Future<void> _speakAI(String text) async {
    await TtsService().speak(text);
  }

  Future<void> _startListening() async {
    final dir = await getApplicationDocumentsDirectory();
    _currentAudioPath =
        '${dir.path}/conv_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: _currentAudioPath!,
    );
    setState(() => _state = _TurnState.listening);
  }

  Future<void> _stopListening() async {
    await _recorder.stop();
    setState(() => _state = _TurnState.processing);
    _scrollToBottom();

    try {
      final result =
          await _conversationService.processUserTurnStream(_currentAudioPath!);
      setState(() {
        _state = _TurnState.aiThinking;
      });
      _scrollToBottom();

      if (result.transcript.isNotEmpty) {
        await _handleStreamingAIResponse(result.aiReplyStream);
      }
    } catch (e) {
      final fallbackStream = _simulateTypingStream('Sorry, I had trouble understanding that. Please try again.');
      await _handleStreamingAIResponse(fallbackStream);
    }

    // Clean up audio file
    if (_currentAudioPath != null) {
      final f = File(_currentAudioPath!);
      if (await f.exists()) await f.delete();
    }

    setState(() => _state = _TurnState.idle);
  }

  Future<void> _handleStreamingAIResponse(Stream<String> aiStream) async {
    setState(() {
      _state = _TurnState.aiSpeaking;
      // Inject an empty message that we will mutate as the stream flows
      _conversationService.turns.add(
        ConversationTurn(isUser: false, text: '', timestamp: DateTime.now())
      );
    });

    String currentFullText = '';
    String currentSentenceBuffer = '';

    DateTime lastUpdate = DateTime.now();
    await for (final chunk in aiStream) {
      if (!mounted) return;
      currentFullText += chunk;
      currentSentenceBuffer += chunk;
      
      final now = DateTime.now();
      // Update UI at most every 100ms to prevent frame saturation
      if (now.difference(lastUpdate).inMilliseconds > 100) {
        setState(() {
          _conversationService.turns.last = ConversationTurn(
            isUser: false, 
            text: currentFullText, 
            timestamp: now
          );
        });
        _scrollToBottom(immediate: true);
        lastUpdate = now;
      }

      // Check for sentence boundaries to trigger TTS early
      if (currentSentenceBuffer.contains(RegExp(r'[.!?]\s'))) {
        final match = RegExp(r'[.!?]\s').firstMatch(currentSentenceBuffer);
        if (match != null) {
          final sentence = currentSentenceBuffer.substring(0, match.end);
          _speakAI(sentence.trim());
          currentSentenceBuffer = currentSentenceBuffer.substring(match.end);
        }
      }
    }

    // Final UI update to ensure last chunks are visible
    setState(() {
      _conversationService.turns.last = ConversationTurn(
        isUser: false, 
        text: currentFullText, 
        timestamp: DateTime.now()
      );
    });
    _scrollToBottom();

    // Speak any remaining text in the buffer
    if (currentSentenceBuffer.trim().isNotEmpty) {
      _speakAI(currentSentenceBuffer.trim());
    }

    // Wait for the final speech parts to end
    await TtsService().waitUntilDone();

    if (mounted) {
      setState(() {
        _state = _TurnState.idle;
        if (!_sessionStarted) _sessionStarted = true;
      });
    }
  }

  Future<void> _endConversation() async {
    if (_ending) return;
    setState(() => _ending = true);
    await TtsService().stop();

    // Ensure the last generated text gets finalized before summarization
    if (_conversationService.turns.isNotEmpty && !_conversationService.turns.last.isUser) {
      final lastTurnText = _conversationService.turns.removeLast().text;
      _conversationService.appendFinalAiTurn(lastTurnText);
    }

    final summary = await _conversationService.endConversation();

    // Save session to database
    if (mounted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final uid = auth.currentUser?.userId;
      
      if (uid != null) {
        final duration = _startTime != null 
            ? DateTime.now().difference(_startTime!).inSeconds.toDouble() 
            : 0.0;

        await sessionProvider.saveCompletedSession(
          authProvider: auth,
          userId: uid,
          type: 'live_conversation',
          promptText: widget.topic ?? 'Natural Chat',
          duration: duration,
          compositeScore: summary.compositeScore,
          cefrLevel: summary.cefrLevel,
          feedback: summary.feedback,
          transcript: summary.fullTranscript,
          grammarCorrections: summary.grammarCorrections,
          improvementTips: summary.improvementTips,
          advancedVocabulary: summary.advancedVocabulary,
          wordResults: summary.wordResults,
        );
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SummaryDialog(summary: summary),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.immersiveDark, AppColors.immersiveBlack],
          ),
        ),
        child: Stack(
          children: [
            // ── Background Glow ──────────────────────────────────────────
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _stateColor().withAlpha(25),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            // ── App Bar ──────────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withAlpha(25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.topicEmoji, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              widget.topic ?? 'Natural Chat',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _ending ? null : _endConversation,
                        child: Text(
                          'End',
                          style: TextStyle(
                            color: _ending ? Colors.white24 : AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Voice Selector ───────────────────────────────────────────
            const Positioned(
              top: 100,
              right: 16,
              child: _VoiceSelector(),
            ),

            // ── Main Content Area ────────────────────────────────────────
            Positioned.fill(
              top: 100,
              child: Column(
                children: [
                  // ── Immersion Visualizer (The Orb) ──────────────────────
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: _VoiceOrb(
                        state: _state,
                        pulse: _pulse.value,
                        baseColor: _stateColor(),
                      ),
                    ),
                  ),

                  // ── Compact Glassy Transcript ───────────────────────────
                  Expanded(
                    flex: 2,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(12),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                              border: Border.all(
                                color: Colors.white.withAlpha(25),
                                width: 1.5,
                              ),
                            ),
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(24),
                              itemCount: _conversationService.turns.length,
                              itemBuilder: (ctx, i) =>
                                  _TurnMiniBubble(turn: _conversationService.turns[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Interaction Pad ──────────────────────────────────────
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withAlpha(0),
                            Colors.black.withAlpha(102),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _stateLabel(),
                            style: TextStyle(
                              color: _stateColor().withAlpha(204),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTapDown: _state == _TurnState.idle
                                ? (_) => _startListening()
                                : null,
                            onTapUp: _state == _TurnState.listening
                                ? (_) => _stopListening()
                                : null,
                            child: AnimatedScale(
                              scale: _state == _TurnState.listening ? 0.9 : 1.0,
                              duration: const Duration(milliseconds: 100),
                              child: Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _state == _TurnState.listening
                                      ? AppColors.error
                                      : Colors.white.withAlpha(25),
                                  border: Border.all(
                                    color: _state == _TurnState.listening
                                        ? AppColors.error
                                        : Colors.white.withAlpha(51),
                                    width: 4,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    _state == _TurnState.listening
                                        ? Icons.stop_rounded
                                        : Icons.mic_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
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
      ),
    );
  }
}

// ── Voice Selector Widget ─────────────────────────────────────────────────────
class _VoiceSelector extends StatefulWidget {
  const _VoiceSelector();

  @override
  State<_VoiceSelector> createState() => _VoiceSelectorState();
}

class _VoiceSelectorState extends State<_VoiceSelector> {
  @override
  Widget build(BuildContext context) {
    final tts = TtsService();
    final isFemale = tts.currentVoiceProfile == 'af_heart';

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _voiceOption(id: 'af_heart', icon: '👩', active: isFemale),
          _voiceOption(id: 'am_adam', icon: '👨', active: !isFemale),
        ],
      ),
    );
  }

  Widget _voiceOption({required String id, required String icon, required bool active}) {
    return GestureDetector(
      onTap: () {
        setState(() => TtsService().setVoiceProfile(id));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(icon, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

// ── Voice Orb Widget ──────────────────────────────────────────────────────────
class _VoiceOrb extends StatelessWidget {
  final _TurnState state;
  final double pulse;
  final Color baseColor;

  const _VoiceOrb({
    required this.state,
    required this.pulse,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer Glow
        Container(
          width: 220 * pulse,
          height: 220 * pulse,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: baseColor.withAlpha(12),
          ),
        ),
        // Active Wave/Orb
        CustomPaint(
          size: const Size(180, 180),
          painter: _OrbPainter(
            color: baseColor,
            animationValue: pulse,
            isThinking: state == _TurnState.processing || state == _TurnState.aiThinking,
          ),
        ),
      ],
    );
  }
}

class _OrbPainter extends CustomPainter {
  final Color color;
  final double animationValue;
  final bool isThinking;

  _OrbPainter({
    required this.color,
    required this.animationValue,
    required this.isThinking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    if (isThinking) {
      // Draw 3 spinning dots/blobs
      for (int i = 0; i < 3; i++) {
        final angle = (animationValue * 2 * math.pi) + (i * 2 * math.pi / 3);
        final dotPos = Offset(
          center.dx + math.cos(angle) * (radius * 0.5),
          center.dy + math.sin(angle) * (radius * 0.5),
        );
        canvas.drawCircle(dotPos, radius * 0.2, paint);
      }
    } else {
      // Organic flowy circle
      final path = Path();
      const int points = 30;
      for (int i = 0; i <= points; i++) {
        final double angle = (i * 2 * math.pi) / points;
        final double r = radius * (0.8 + 0.2 * math.sin(angle * 4 + animationValue * 10));
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint..color = color.withAlpha(204));
      
      // Secondary layer
      final path2 = Path();
      for (int i = 0; i <= points; i++) {
        final double angle = (i * 2 * math.pi) / points;
        final double r = radius * (0.9 + 0.1 * math.cos(angle * 3 - animationValue * 8));
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (i == 0) {
          path2.moveTo(x, y);
        } else {
          path2.lineTo(x, y);
        }
      }
      path2.close();
      canvas.drawPath(path2, paint..color = color.withAlpha(102));
    }
  }

  @override
  bool shouldRepaint(_OrbPainter oldDelegate) => true;
}

// ── Mini Bubble Widget ────────────────────────────────────────────────────────
class _TurnMiniBubble extends StatelessWidget {
  final ConversationTurn turn;
  const _TurnMiniBubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final isUser = turn.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Icon(
                isUser ? Icons.person_rounded : Icons.auto_awesome_rounded,
                size: 14,
                color: Colors.white38,
              ),
              const SizedBox(width: 8),
              Text(
                isUser ? 'You' : 'AI Coach',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            turn.text,
            style: TextStyle(
              color: isUser ? Colors.white.withAlpha(230) : Colors.white,
              fontSize: 16,
              height: 1.5,
              fontWeight: isUser ? FontWeight.normal : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Session summary dialog ────────────────────────────────────────────────────
class _SummaryDialog extends StatelessWidget {
  final SessionSummary summary;
  const _SummaryDialog({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Session Complete! 🎉',
                  style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 16),
              
              // CEFR badge & Score
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(summary.cefrLevel,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Text('${summary.compositeScore.toInt()}%',
                      style: const TextStyle(color: AppColors.textDark, fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 20),

              // Summary Feedback
              Text(summary.feedback,
                  style: const TextStyle(color: AppColors.textMedium, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center),
              
              const Divider(height: 40),

              // ── DEEP DIVE SECTION ─────────────────────────────────────
              const _SectionHeader(title: 'GRAMMAR FIXES', icon: Icons.spellcheck_rounded),
              if (summary.grammarCorrections.isEmpty)
                const _EmptySection(text: 'No grammar issues found! Great job.')
              else
                ...summary.grammarCorrections.map((g) => _FeedbackItem(text: g, color: AppColors.error)),

              const SizedBox(height: 24),
              const _SectionHeader(title: 'NATIVE TIPS', icon: Icons.tips_and_updates_rounded),
              ...summary.improvementTips.map((t) => _FeedbackItem(text: t, color: AppColors.primary)),

              const SizedBox(height: 24),
              const _SectionHeader(title: 'ADVANCED VOCAB', icon: Icons.auto_stories_rounded),
              ...summary.advancedVocabulary.map((v) => _FeedbackItem(text: v, color: AppColors.secondary)),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // dismiss dialog
                    Navigator.pop(context); // back to home
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Back to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMedium),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: AppColors.textMedium, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
      ],
    );
  }
}

class _FeedbackItem extends StatelessWidget {
  final String text;
  final Color color;
  const _FeedbackItem({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color.withAlpha(230), fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String text;
  const _EmptySection({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: const TextStyle(color: AppColors.textLight, fontSize: 12, fontStyle: FontStyle.italic)),
    );
  }
}
