import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../services/speech_to_text_service.dart';
import '../services/feedback_service.dart';
import '../services/grammar_service.dart';
import '../services/ai_pipeline.dart';

/// A single turn in the conversation
class ConversationTurn {
  final bool isUser;
  final String text;
  final DateTime timestamp;

  ConversationTurn({
    required this.isUser,
    required this.text,
    required this.timestamp,
  });
}

/// Manages a live back-and-forth AI conversation session
class ConversationService {
  final SpeechToTextService _sttService = SpeechToTextService();
  final GrammarAnalysisService _grammarService = GrammarAnalysisService();
  final FeedbackService _feedbackService = FeedbackService();

  final List<ConversationTurn> turns = [];
  final String topic;

  late String _systemPrompt;

  ConversationService({required this.topic}) {
    _systemPrompt = '''You are a friendly English speaking conversation partner.
The topic is: "$topic".
Your role:
- Ask one short, clear follow-up question after each user response.
- Keep your responses to 2–3 sentences maximum.
- Never correct grammar directly — just model good English naturally.
- Be encouraging and positive.
- Keep the conversation flowing naturally on the topic.
Start by giving a warm welcome and asking the first question about the topic.''';
  }

  /// Get the opening message from the AI
  Future<String> startConversation() async {
    final aiResponse = await _callGroqChat([
      {'role': 'system', 'content': _systemPrompt},
      {'role': 'user', 'content': 'Start the conversation.'},
    ]);
    turns.add(ConversationTurn(
        isUser: false, text: aiResponse, timestamp: DateTime.now()));
    return aiResponse;
  }

  /// Process a user's audio turn: transcribe → get AI reply
  Future<({String transcript, String aiReply})> processUserTurn(
      String audioPath) async {
    final transcription = await _sttService.transcribeAudio(audioPath);
    final userText = transcription.transcript.trim();

    if (userText.isEmpty) {
      return (
        transcript: '',
        aiReply: "I didn't catch that — could you try again?"
      );
    }

    turns.add(ConversationTurn(
        isUser: true, text: userText, timestamp: DateTime.now()));

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
    ];
    for (final t in turns) {
      messages.add(
          {'role': t.isUser ? 'user' : 'assistant', 'content': t.text});
    }

    final aiReply = await _callGroqChat(messages);
    turns.add(ConversationTurn(
        isUser: false, text: aiReply, timestamp: DateTime.now()));

    return (transcript: userText, aiReply: aiReply);
  }

  /// End conversation: run full analysis on all user turns combined
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

    return SessionSummary(
      fullTranscript: userTexts,
      cefrLevel: cefr,
      compositeScore: compositeScore,
      feedback: feedback,
      grammarScore: grammar.score,
      fluencyScore: compositeScore * 0.9,
    );
  }

  Future<String> _callGroqChat(List<Map<String, String>> messages) async {
    final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.1-70b-versatile',
          'messages': messages,
          'max_tokens': 150,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>;
        if (choices.isNotEmpty) {
          final msg = choices.first['message'] as Map<String, dynamic>;
          return msg['content'] as String? ?? '';
        }
      }
    } catch (_) {}
    return 'I am having trouble responding. Please try again.';
  }
}

class SessionSummary {
  final String fullTranscript;
  final String cefrLevel;
  final double compositeScore;
  final String feedback;
  final double grammarScore;
  final double fluencyScore;

  SessionSummary({
    required this.fullTranscript,
    required this.cefrLevel,
    required this.compositeScore,
    required this.feedback,
    required this.grammarScore,
    required this.fluencyScore,
  });
}
