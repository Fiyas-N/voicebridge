import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/conversation_service.dart';
import '../../services/tts_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/common/animated_button.dart';
import '../../widgets/common/ai_voice_gender_toggle.dart';
import '../../widgets/common/dot_grid_background.dart';
import '../../widgets/common/glass_card.dart';

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

class _ConversationScreenState extends State<ConversationScreen> with SingleTickerProviderStateMixin {
  late ConversationService _conversationService;
  final AudioRecorder _recorder = AudioRecorder();
  final ScrollController _scrollController = ScrollController();

  _TurnState _state = _TurnState.idle;
  bool _sessionStarted = false;
  bool _ending = false;
  /// Stops in-flight AI typing/TTS so [ _endConversation ] can run safely.
  bool _endRequested = false;
  String? _currentAudioPath;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _conversationService = ConversationService(topic: widget.topic);
    _startSession();
  }

  @override
  void dispose() {
    _endRequested = true;
    TtsService().stop();
    _recorder.dispose();
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

  Future<void> _startSession() async {
    setState(() => _state = _TurnState.aiThinking);
    final opening = await _conversationService.startConversation();
    if (!mounted) return;
    setState(() => _startTime = DateTime.now());
    
    final stream = _simulateTypingStream(opening);
    await _handleStreamingAIResponse(stream);
  }
  
  Stream<String> _simulateTypingStream(String text) async* {
    for (int i = 0; i < text.length; i++) {
      if (_endRequested) break;
      await Future.delayed(const Duration(milliseconds: 15));
      yield text[i];
    }
  }

  Future<void> _speakAI(String text) async {
    await TtsService().speak(text);
  }

  Future<void> _startListening() async {
    final dir = await getApplicationDocumentsDirectory();
    _currentAudioPath = '${dir.path}/conv_${DateTime.now().millisecondsSinceEpoch}.wav';

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 256000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _currentAudioPath!,
    );
    setState(() => _state = _TurnState.listening);
  }

  Future<void> _cleanupRecordingFile() async {
    if (_currentAudioPath != null) {
      final f = File(_currentAudioPath!);
      if (await f.exists()) await f.delete();
    }
  }

  Future<void> _stopListening() async {
    await _recorder.stop();
    if (_endRequested) {
      await _cleanupRecordingFile();
      if (mounted) setState(() => _state = _TurnState.idle);
      return;
    }
    setState(() => _state = _TurnState.processing);
    _scrollToBottom();

    try {
      final result = await _conversationService.processUserTurnStream(_currentAudioPath!);
      if (_endRequested || !mounted) {
        await _cleanupRecordingFile();
        if (mounted) setState(() => _state = _TurnState.idle);
        return;
      }
      setState(() => _state = _TurnState.aiThinking);
      _scrollToBottom();

      if (result.transcript.isNotEmpty && !_endRequested) {
        await _handleStreamingAIResponse(result.aiReplyStream);
      }
    } catch (e) {
      if (!_endRequested) {
        final fallbackStream = _simulateTypingStream('Something went wrong. Please try again.');
        await _handleStreamingAIResponse(fallbackStream);
      }
    }

    await _cleanupRecordingFile();
    if (mounted) setState(() => _state = _TurnState.idle);
  }

  Future<void> _handleStreamingAIResponse(Stream<String> aiStream) async {
    setState(() {
      _state = _TurnState.aiSpeaking;
      _conversationService.turns.add(ConversationTurn(isUser: false, text: '', timestamp: DateTime.now()));
    });

    String currentFullText = '';
    DateTime lastUpdate = DateTime.now();

    await for (final chunk in aiStream) {
      if (!mounted || _endRequested) break;
      currentFullText += chunk;

      final now = DateTime.now();
      if (now.difference(lastUpdate).inMilliseconds > 80) {
        if (!mounted || _endRequested) break;
        setState(() {
          _conversationService.turns.last = ConversationTurn(isUser: false, text: currentFullText, timestamp: now);
        });
        _scrollToBottom(immediate: true);
        lastUpdate = now;
      }
    }

    if (!mounted) return;

    if (_endRequested) {
      if (_conversationService.turns.isNotEmpty && !_conversationService.turns.last.isUser) {
        final t = _conversationService.turns.last.text.trim();
        if (t.isEmpty) {
          _conversationService.turns.removeLast();
        }
      }
      setState(() {
        _state = _TurnState.idle;
        if (!_sessionStarted) _sessionStarted = true;
      });
      return;
    }

    setState(() {
      _conversationService.turns.last = ConversationTurn(isUser: false, text: currentFullText, timestamp: DateTime.now());
    });
    _scrollToBottom();

    // One full utterance after the reply finishes — avoids choppy robotic sentence-by-sentence TTS.
    if (currentFullText.trim().isNotEmpty) {
      await _speakAI(currentFullText.trim());
    }

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
    _endRequested = true;
    try {
      await TtsService().stop();

      if (_conversationService.turns.isNotEmpty && !_conversationService.turns.last.isUser) {
        final lastTurnText = _conversationService.turns.removeLast().text;
        _conversationService.appendFinalAiTurn(lastTurnText);
      }

      final summary = await _conversationService.endConversation();

      if (!mounted) return;

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      final uid = auth.currentUser?.userId;

      if (uid != null) {
        final duration = _startTime != null
            ? DateTime.now().difference(_startTime!).inSeconds.toDouble()
            : 0.0;

        try {
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
            pronunciationTips: summary.pronunciationTips,
            wordResults: summary.wordResults,
          );
        } catch (e, st) {
          debugPrint('saveCompletedSession failed: $e\n$st');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not save session: $e')),
            );
          }
        }
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SummaryDialog(summary: summary),
      );
    } catch (e, st) {
      debugPrint('_endConversation failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not end session: $e')),
        );
      }
    } finally {
      _endRequested = false;
      if (mounted) setState(() => _ending = false);
    }
  }

  String _stateHeadline() {
    switch (_state) {
      case _TurnState.listening:
        return 'Listening…';
      case _TurnState.processing:
        return 'Processing…';
      case _TurnState.aiThinking:
        return 'Thinking…';
      case _TurnState.aiSpeaking:
        return 'Speaking…';
      case _TurnState.idle:
        return 'Tap the orb to speak';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VbColor.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: DotGridBackground(
              child: Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: VbColor.onSurface),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              'VOICEBRIDGE',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.spaceMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.5,
                                color: VbColor.onBackground,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _ending ? null : _endConversation,
                            child: Text(
                              'END',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                color: VbColor.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: VbSpacing.marginMobile),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'CONNECTED',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                color: VbColor.onSurfaceVariant,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        AiVoiceGenderToggle(
                          compact: true,
                          isMale: TtsService().isMale,
                          onChanged: (male) async {
                            await TtsService().setVoice(male);
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _stateHeadline(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceMono(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: VbColor.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (widget.topic ?? 'Practice').toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: VbColor.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          if (_state == _TurnState.idle) {
                            _startListening();
                          } else if (_state == _TurnState.listening) {
                            _stopListening();
                          }
                        },
                        child: _VoiceOrb(state: _state),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: VbSpacing.marginMobile,
                      ),
                      child: GlassCard(
                        showLeadingAccent: true,
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Live transcript',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                letterSpacing: 1.2,
                                color: VbColor.accentElectric,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _conversationService.turns.isEmpty
                                  ? Center(
                                      child: Text(
                                        'You and your tutor will appear here.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: VbColor.onSurfaceVariant,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                                      itemCount: _conversationService.turns.length,
                                      itemBuilder: (ctx, i) =>
                                          _TurnMiniBubble(
                                        turn: _conversationService.turns[i],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      VbSpacing.marginMobile,
                      4,
                      VbSpacing.marginMobile,
                      MediaQuery.paddingOf(context).bottom + 12,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _ending ? null : _endConversation,
                        child: Text(
                          'End session',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_ending)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: VbColor.accentElectric,
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Ending session…',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                            color: VbColor.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VoiceOrb extends StatelessWidget {
  final _TurnState state;
  const _VoiceOrb({required this.state});

  @override
  Widget build(BuildContext context) {
    final listening = state == _TurnState.listening;
    final thinking =
        state == _TurnState.processing || state == _TurnState.aiThinking;
    final active = listening || state == _TurnState.aiSpeaking;
    final outer = active ? 210.0 : 180.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      width: outer,
      height: outer,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: VbColor.accentElectric
                .withValues(alpha: listening ? 0.4 : 0.15),
            blurRadius: listening ? 26 : 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VbColor.surfaceContainerLowest,
                border: Border.all(color: VbColor.outlineVariant, width: 1),
              ),
            ),
            ClipOval(
              child: CustomPaint(
                painter: _OrbDotPainter(active: active),
                child: const SizedBox.expand(),
              ),
            ),
            Center(
              child: Icon(
                thinking ? Icons.more_horiz : Icons.mic_none_rounded,
                size: 42,
                color: listening ? VbColor.accentElectric : VbColor.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbDotPainter extends CustomPainter {
  _OrbDotPainter({required this.active});
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: active ? 0.14 : 0.06);
    const step = 12.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy <= r * r) {
          canvas.drawCircle(Offset(x, y), 0.55, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OrbDotPainter oldDelegate) =>
      oldDelegate.active != active;
}

class _TurnMiniBubble extends StatelessWidget {
  final ConversationTurn turn;
  const _TurnMiniBubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final isU = turn.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: isU ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(VbRadii.lg),
              topRight: const Radius.circular(VbRadii.lg),
              bottomLeft: Radius.circular(isU ? VbRadii.lg : 4),
              bottomRight: Radius.circular(isU ? 4 : VbRadii.lg),
            ),
            border: Border.all(
              color: VbColor.outlineVariant,
              width: 1,
            ),
          ),
          child: Text(
            turn.text,
            style: GoogleFonts.inter(
              color: isU ? VbColor.onSurface : VbColor.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryDialog extends StatelessWidget {
  final SessionSummary summary;
  const _SummaryDialog({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Session complete', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _metric('CEFR', summary.cefrLevel),
                  _metric('SCORE', '${summary.compositeScore.toInt()}%'),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.borderLight),
              const SizedBox(height: 20),
              Text(summary.feedback, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              
              const Text('Grammar notes', style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppColors.textTertiary, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              if (summary.grammarCorrections.isEmpty)
                const Text('None noted', style: TextStyle(fontSize: 11, color: Colors.white24))
              else
                ...summary.grammarCorrections.map((g) => _fbItem(g)),

              const SizedBox(height: 40),
              AnimatedButton(
                text: 'Done',
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String l, String v) {
    return Column(
      children: [
        Text(l, style: const TextStyle(fontSize: 9, color: AppColors.textTertiary, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(v, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _fbItem(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('» ', style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold)),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4))),
        ],
      ),
    );
  }
}
