import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/conversation_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/common/glass_card.dart';

enum _TurnState { idle, listening, processing, aiSpeaking }

class ConversationScreen extends StatefulWidget {
  final String topic;
  final String topicEmoji;

  const ConversationScreen({
    super.key,
    required this.topic,
    this.topicEmoji = '🎙️',
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen>
    with SingleTickerProviderStateMixin {
  late ConversationService _conversationService;
  late TtsService _ttsService;
  final AudioRecorder _recorder = AudioRecorder();
  final ScrollController _scrollController = ScrollController();

  _TurnState _state = _TurnState.idle;
  bool _sessionStarted = false;
  bool _ending = false;
  String? _currentAudioPath;

  // Pulse animation for mic
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _conversationService = ConversationService(topic: widget.topic);
    _ttsService = TtsService();

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
    _ttsService.dispose();
    _recorder.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() => _state = _TurnState.processing);
    final opening = await _conversationService.startConversation();
    setState(() {});
    await _speakAI(opening);
    setState(() {
      _state = _TurnState.idle;
      _sessionStarted = true;
    });
  }

  Future<void> _speakAI(String text) async {
    setState(() => _state = _TurnState.aiSpeaking);
    await _ttsService.speak(text);
    await _ttsService.waitUntilDone();
  }

  Future<void> _startListening() async {
    final dir = await getApplicationDocumentsDirectory();
    _currentAudioPath =
        '${dir.path}/conv_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    await _recorder.start(
      RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
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
          await _conversationService.processUserTurn(_currentAudioPath!);
      setState(() {});
      _scrollToBottom();

      if (result.transcript.isNotEmpty) {
        await _speakAI(result.aiReply);
      }
    } catch (e) {
      await _speakAI('Sorry, I had trouble understanding that. Please try again.');
    }

    // Clean up audio file
    if (_currentAudioPath != null) {
      final f = File(_currentAudioPath!);
      if (await f.exists()) await f.delete();
    }

    setState(() => _state = _TurnState.idle);
  }

  Future<void> _endConversation() async {
    if (_ending) return;
    setState(() => _ending = true);
    await _ttsService.stop();

    final summary = await _conversationService.endConversation();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SummaryDialog(summary: summary),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _stateLabel() {
    switch (_state) {
      case _TurnState.listening: return 'Listening…';
      case _TurnState.processing: return 'Processing…';
      case _TurnState.aiSpeaking: return 'AI Speaking…';
      default: return 'Tap to speak';
    }
  }

  Color _micColor() {
    switch (_state) {
      case _TurnState.listening: return const Color(0xFFef233c);
      case _TurnState.aiSpeaking: return const Color(0xFF4ecdc4);
      case _TurnState.processing: return const Color(0xFFffd166);
      default: return const Color(0xFF764ba2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(widget.topicEmoji,
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.topic,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _ending ? null : _endConversation,
            child: const Text('End',
                style: TextStyle(color: Color(0xFFef233c), fontSize: 15)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Chat bubbles ─────────────────────────────────────────────────
          Expanded(
            child: _conversationService.turns.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white54),
                        const SizedBox(height: 16),
                        Text('Starting conversation…',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5))),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _conversationService.turns.length,
                    itemBuilder: (ctx, i) =>
                        _ChatBubble(turn: _conversationService.turns[i]),
                  ),
          ),

          // ── State label ──────────────────────────────────────────────────
          if (_sessionStarted)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _stateLabel(),
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13),
              ),
            ),

          // ── Mic button ───────────────────────────────────────────────────
          if (_sessionStarted)
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: GestureDetector(
                onTapDown: _state == _TurnState.idle
                    ? (_) => _startListening()
                    : null,
                onTapUp: _state == _TurnState.listening
                    ? (_) => _stopListening()
                    : null,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (ctx, child) => Transform.scale(
                    scale: _state == _TurnState.listening
                        ? _pulse.value
                        : 1.0,
                    child: child,
                  ),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _micColor(),
                      boxShadow: [
                        BoxShadow(
                          color: _micColor().withValues(alpha: 0.5),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      _state == _TurnState.listening
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                      color: Colors.white,
                      size: 38,
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

// ── Chat bubble widget ────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final ConversationTurn turn;
  const _ChatBubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final isUser = turn.isUser;
    return Padding(
      padding: EdgeInsets.only(
        top: 6,
        bottom: 6,
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF764ba2),
              ),
              child: const Center(
                child: Text('AI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF4e79ff).withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Text(
                turn.text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: isUser ? 1.0 : 0.9),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
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
      backgroundColor: const Color(0xFF1e1e3a),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Session Complete! 🎉',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
            const SizedBox(height: 20),
            // CEFR badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                summary.cefrLevel,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3),
              ),
            ),
            const SizedBox(height: 8),
            Text('Overall: ${summary.compositeScore.toInt()} / 100',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14)),
            const SizedBox(height: 20),
            if (summary.feedback.isNotEmpty)
              Text(summary.feedback,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.6),
                  textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);  // dismiss dialog
                  Navigator.pop(context);  // back to home
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF764ba2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Done',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
