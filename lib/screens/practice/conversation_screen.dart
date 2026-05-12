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
import '../../widgets/common/animated_button.dart';

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

  String _stateLabel() {
    switch (_state) {
      case _TurnState.listening: return 'MIC_ACTIVE';
      case _TurnState.processing: return 'RENDERING';
      case _TurnState.aiThinking: return 'AI_COMPUTING';
      case _TurnState.aiSpeaking: return 'TRANSMITTING';
      default: return 'AWAITING_INPUT';
    }
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

  Future<void> _stopListening() async {
    await _recorder.stop();
    setState(() => _state = _TurnState.processing);
    _scrollToBottom();

    try {
      final result = await _conversationService.processUserTurnStream(_currentAudioPath!);
      setState(() => _state = _TurnState.aiThinking);
      _scrollToBottom();

      if (result.transcript.isNotEmpty) {
        await _handleStreamingAIResponse(result.aiReplyStream);
      }
    } catch (e) {
      final fallbackStream = _simulateTypingStream('Error loading signal. Try again.');
      await _handleStreamingAIResponse(fallbackStream);
    }

    if (_currentAudioPath != null) {
      final f = File(_currentAudioPath!);
      if (await f.exists()) await f.delete();
    }
    setState(() => _state = _TurnState.idle);
  }

  Future<void> _handleStreamingAIResponse(Stream<String> aiStream) async {
    setState(() {
      _state = _TurnState.aiSpeaking;
      _conversationService.turns.add(ConversationTurn(isUser: false, text: '', timestamp: DateTime.now()));
    });

    String currentFullText = '';
    String currentSentenceBuffer = '';
    DateTime lastUpdate = DateTime.now();

    await for (final chunk in aiStream) {
      if (!mounted) return;
      currentFullText += chunk;
      currentSentenceBuffer += chunk;
      
      final now = DateTime.now();
      if (now.difference(lastUpdate).inMilliseconds > 80) {
        setState(() {
          _conversationService.turns.last = ConversationTurn(isUser: false, text: currentFullText, timestamp: now);
        });
        _scrollToBottom(immediate: true);
        lastUpdate = now;
      }

      if (currentSentenceBuffer.contains(RegExp(r'[.!?]\s'))) {
        final match = RegExp(r'[.!?]\s').firstMatch(currentSentenceBuffer);
        if (match != null) {
          final sentence = currentSentenceBuffer.substring(0, match.end);
          _speakAI(sentence.trim());
          currentSentenceBuffer = currentSentenceBuffer.substring(match.end);
        }
      }
    }

    setState(() {
      _conversationService.turns.last = ConversationTurn(isUser: false, text: currentFullText, timestamp: DateTime.now());
    });
    _scrollToBottom();

    if (currentSentenceBuffer.trim().isNotEmpty) {
      _speakAI(currentSentenceBuffer.trim());
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
    await TtsService().stop();

    if (_conversationService.turns.isNotEmpty && !_conversationService.turns.last.isUser) {
      final lastTurnText = _conversationService.turns.removeLast().text;
      _conversationService.appendFinalAiTurn(lastTurnText);
    }

    final summary = await _conversationService.endConversation();

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
          pronunciationTips: summary.pronunciationTips,
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
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Text(
                            (widget.topic ?? 'LIVE_SESSION').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 10, fontFamily: 'monospace'),
                          ),
                        ),
                        GestureDetector(
                          onTap: _ending ? null : _endConversation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.accentRed,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('END', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.black, fontSize: 10)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const Positioned(child: _VoiceSelector()),
                const SizedBox(height: 32),
                Expanded(
                  flex: 2,
                  child: Center(child: _VoiceOrb(state: _state)),
                ),
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      border: const Border(top: BorderSide(color: AppColors.borderLight), left: BorderSide(color: AppColors.borderLight), right: BorderSide(color: AppColors.borderLight)),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _conversationService.turns.length,
                      itemBuilder: (ctx, i) => _TurnMiniBubble(turn: _conversationService.turns[i]),
                    ),
                  ),
                ),
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _stateLabel(),
                          style: const TextStyle(color: Colors.white54, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () {
                            if (_state == _TurnState.idle) {
                              _startListening();
                            } else if (_state == _TurnState.listening) {
                              _stopListening();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _state == _TurnState.listening ? AppColors.purpleNeonGradient : AppColors.cyberGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: (_state == _TurnState.listening ? AppColors.accentRed : AppColors.primary).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            ),
                            child: Center(
                              child: Icon(
                                _state == _TurnState.listening ? Icons.square_rounded : Icons.mic,
                                color: Colors.black, size: 32,
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
    );
  }
}

class _VoiceSelector extends StatefulWidget {
  const _VoiceSelector();
  @override
  State<_VoiceSelector> createState() => _VoiceSelectorState();
}

class _VoiceSelectorState extends State<_VoiceSelector> {
  @override
  Widget build(BuildContext context) {
    final tts = TtsService();
    final isF = tts.currentVoiceProfile == 'af_bella';
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _opt(id: 'af_bella', txt: 'ALPHA', active: isF),
          _opt(id: 'am_adam', txt: 'BETA', active: !isF),
        ],
      ),
    );
  }

  Widget _opt({required String id, required String txt, required bool active}) {
    return GestureDetector(
      onTap: () => setState(() => TtsService().setVoiceProfile(id)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? AppColors.cyberGradient : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(txt, style: TextStyle(color: active ? Colors.black : Colors.white54, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      ),
    );
  }
}

class _VoiceOrb extends StatelessWidget {
  final _TurnState state;
  const _VoiceOrb({required this.state});

  @override
  Widget build(BuildContext context) {
    final isThinking = state == _TurnState.processing || state == _TurnState.aiThinking;
    final isActive = state == _TurnState.listening || state == _TurnState.aiSpeaking;
    
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isActive ? 200 : 160,
          height: isActive ? 200 : 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isThinking ? 140 : 120,
          height: isThinking ? 140 : 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? AppColors.primary : Colors.white.withValues(alpha: 0.2), width: 2),
            boxShadow: isActive ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 20)] : null,
          ),
          child: Center(
            child: Icon(
              isThinking ? Icons.more_horiz : Icons.circle,
              color: state == _TurnState.listening ? AppColors.accentRed : (isActive ? AppColors.primary : Colors.white24),
              size: 16,
            ),
          ),
        ),
      ],
    );
  }
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
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isU ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isU ? 20 : 4),
              bottomRight: Radius.circular(isU ? 4 : 20),
            ),
            border: Border.all(color: isU ? AppColors.primary.withValues(alpha: 0.1) : AppColors.borderLight),
          ),
          child: Text(
            turn.text,
            style: TextStyle(color: isU ? AppColors.textPrimary : Colors.white.withValues(alpha: 0.9), fontSize: 13, height: 1.4),
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
              const Text('SESSION COMPLETE', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
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
              
              const Text('CORRECTIONS', style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppColors.textTertiary, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              if (summary.grammarCorrections.isEmpty)
                const Text('NONE DETECTED', style: TextStyle(fontSize: 11, color: Colors.white24))
              else
                ...summary.grammarCorrections.map((g) => _fbItem(g)),

              const SizedBox(height: 40),
              AnimatedButton(
                text: 'CLOSE ARCHIVE',
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
