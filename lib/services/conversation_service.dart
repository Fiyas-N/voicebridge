import 'dart:async';
import '../services/local_stt_service.dart';
import '../services/local_llm_service.dart';
import '../services/feedback_service.dart';
import '../services/grammar_service.dart';
import '../services/ai_pipeline.dart';

/// A single turn in the conversation
class ConversationTurn {
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final List<WordInfo> words;

  ConversationTurn({
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.words = const [],
  });
}

/// Manages a live back-and-forth AI conversation session (100% On-Device).
///
/// Architecture:
///   STT  → Whisper (on-device)    audio never leaves the device
///   LLM  → Gemma 3 1B (on-device)  text stays local
///   TTS  → Kokoro (on-device)     everything fully offline
class ConversationService {
  final LocalSttService _sttService = LocalSttService();
  final LocalLlmService _llmService = LocalLlmService();
  final GrammarAnalysisService _grammarService = GrammarAnalysisService();
  final FeedbackService _feedbackService = FeedbackService();

  final List<ConversationTurn> turns = [];
  final String? topic;

  late final String _systemPrompt;

  ConversationService({this.topic}) {
    final isInterview =
        topic?.toLowerCase().contains('mock interview') ?? false;

    _systemPrompt =
        '''You are a friendly, highly expressive English speaking conversation partner.
Personality:
- Be warm, human-like, and slightly playful.
- Use natural conversational cues like "Hmm", "Oh wow!", "Haha!", or "Wait, really?"
- Incorporate expressive reactions: laugh if something is funny, tease gently, show genuine curiosity.
${isInterview ? '- Persona: Act as an expert recruiter or interviewer.' : '- Persona: Act as a supportive friend who loves to chat and joke around.'}
- If the user makes a mistake, don't point it out — just continue while modeling the correct phrasing naturally.

Conversation Mode:
${isInterview ? 'This is a MOCK INTERVIEW for: "${topic!.replaceFirst('Mock Interview: ', '')}". Act like a professional but friendly interviewer. Ask one challenging or situational interview question at a time.' : topic != null ? 'Focus the conversation on: "$topic".' : 'Start a natural, open-ended conversation. Don\'t just say "Hello"; share a small relatable thought or ask about something specific like a weekend plan, a hobby, or a hypothetical "would you rather" to get things moving immediately!'}

Instructions:
- Keep your responses to 2–3 sentences maximum.
- Ask one engaging follow-up question.
- Avoid being overly formal or sounding like a programmed assistant.
Start by giving a warm, natural greeting (with an expressive touch).''';
  }

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

  /// Get the opening message from the AI (fully on-device).
  Future<String> startConversation() async {
    final stream = await _llmService.generateResponseStream(
      '$_systemPrompt\nStart the conversation.',
    );

    String aiResponse = '';
    await for (final chunk in stream) {
      aiResponse += chunk;
    }

    turns.add(ConversationTurn(
      isUser: false,
      text: aiResponse,
      timestamp: DateTime.now(),
    ));
    return aiResponse;
  }

  /// Process a user's audio turn: transcribe (on-device) → stream AI reply (on-device).
  Future<({String transcript, Stream<String> aiReplyStream})>
      processUserTurnStream(String audioPath) async {
    final res = await _sttService.transcribe(audioPath);
    final userText = res.transcript;

    if (userText.isEmpty) {
      return (
        transcript: '',
        aiReplyStream:
            Stream.value("I didn't catch that — could you try again?"),
      );
    }

    turns.add(ConversationTurn(
      isUser: true,
      text: userText,
      timestamp: DateTime.now(),
      words: res.words,
    ));

    // Build prompt with conversation history
    String prompt = '$_systemPrompt\n\nConversation History:\n';
    for (final t in turns) {
      prompt += '${t.isUser ? 'User' : 'Assistant'}: ${t.text}\n';
    }
    prompt += 'Assistant:';

    // Truncate if too long for the 512-token context window
    if (prompt.length > 1400) {
      prompt = prompt.substring(prompt.length - 1400);
    }

    final stream = await _llmService.generateResponseStream(prompt);
    return (transcript: userText, aiReplyStream: stream);
  }

  /// Appends the finalized AI turn to the history once it finishes streaming.
  void appendFinalAiTurn(String fullReply) {
    if (fullReply.trim().isNotEmpty) {
      turns.add(ConversationTurn(
        isUser: false,
        text: fullReply,
        timestamp: DateTime.now(),
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // End-of-session analysis
  // ---------------------------------------------------------------------------

  Future<SessionSummary> endConversation() async {
    final userTexts =
        turns.where((t) => t.isUser).map((t) => t.text).join(' ');

    if (userTexts.trim().isEmpty) {
      return SessionSummary(
        fullTranscript: '',
        cefrLevel: 'A1',
        compositeScore: 0,
        feedback: 'No speech was recorded.',
        grammarScore: 0,
        fluencyScore: 0,
      );
    }

    final grammar = await _grammarService.analyzeGrammar(userTexts);
    final compositeScore = grammar.score.clamp(0.0, 100.0);
    final cefr = AIProcessingPipeline.mapToCEFR(compositeScore);

    final feedback = await _feedbackService.generateFeedback(
      fluencyScore: compositeScore * 0.9,
      grammarScore: grammar.score,
      pronunciationScore: compositeScore * 0.85,
      grammarErrors: grammar.errors.map((e) => e.type).toSet().toList(),
      correctedSentence: grammar.correctedText,
    );

    // Aggregate word-level highlights
    final List<WordInfo> allUserWords = [];
    for (var turn in turns) {
      if (turn.isUser) allUserWords.addAll(turn.words);
    }

    // Deep analysis: grammar fixes, tips, vocabulary
    final grammarCorrections = <String>[];
    final improvementTips = <String>[];
    final advancedVocabulary = <String>[];

    final deepPrompt =
        '''Analyze the following English conversation transcript for an English learner.
Transcript: "$userTexts"

Provide the feedback in the following format:
GRAMMAR_FIXES:
- [Original mistake] -> [Correction]: [Short explanation]
TIPS:
- [Pro tip for reaching native level fluency]
VOCABULARY:
- [Advanced word/phrase]: [Meaning]
''';

    final deepAnalysisText = await _llmService.generateResponse(deepPrompt);

    final lines = deepAnalysisText.split('\n');
    String section = '';
    for (var line in lines) {
      if (line.contains('GRAMMAR_FIXES:')) { section = 'G'; continue; }
      if (line.contains('TIPS:')) { section = 'T'; continue; }
      if (line.contains('VOCABULARY:')) { section = 'V'; continue; }

      final clean = line.replaceFirst(RegExp(r'^[-*]\s*'), '').trim();
      if (clean.isEmpty) continue;

      if (section == 'G') grammarCorrections.add(clean);
      if (section == 'T') improvementTips.add(clean);
      if (section == 'V') advancedVocabulary.add(clean);
    }

    return SessionSummary(
      fullTranscript: userTexts,
      cefrLevel: cefr,
      compositeScore: compositeScore,
      feedback: feedback,
      grammarScore: grammar.score,
      fluencyScore: compositeScore * 0.9,
      grammarCorrections: grammarCorrections,
      improvementTips: improvementTips,
      advancedVocabulary: advancedVocabulary,
      wordResults: allUserWords,
    );
  }
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class SessionSummary {
  final String fullTranscript;
  final String cefrLevel;
  final double compositeScore;
  final String feedback;
  final double grammarScore;
  final double fluencyScore;
  final List<String> grammarCorrections;
  final List<String> improvementTips;
  final List<String> advancedVocabulary;
  final List<WordInfo> wordResults;

  SessionSummary({
    required this.fullTranscript,
    required this.cefrLevel,
    required this.compositeScore,
    required this.feedback,
    required this.grammarScore,
    required this.fluencyScore,
    this.grammarCorrections = const [],
    this.improvementTips = const [],
    this.advancedVocabulary = const [],
    this.wordResults = const [],
  });
}
