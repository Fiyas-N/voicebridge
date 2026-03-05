import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FeedbackService {
  static const String _groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  /// Generate personalized feedback using Groq's free Llama model.
  /// LLM receives ONLY structured summary data (scores + corrected sentence).
  /// Per architecture doc: never sends raw audio, full transcript, or personal data.
  Future<String> generateFeedback({
    required double fluencyScore,
    required double grammarScore,
    required double pronunciationScore,
    required List<String> grammarErrors,
    String? correctedSentence,   // corrected text, NOT the raw transcript
  }) async {
    try {
      final apiKey = dotenv.env['GROQ_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return _generateTemplateFeedback(
          fluencyScore,
          grammarScore,
          pronunciationScore,
        );
      }

      final response = await http.post(
        Uri.parse(_groqApiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.1-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content': '''You are an encouraging English speaking coach for English speaking improvement.
Provide short encouraging feedback and 3 improvement tips.

Guidelines:
- Max 150 words total
- Start with genuine encouragement
- Suggest 3 specific, actionable improvements
- End with motivation
- Be warm, supportive, and specific
- Do NOT make exam score predictions or certification claims'''
            },
            {
              'role': 'user',
              'content': '''Generate feedback for this performance:

Fluency: ${fluencyScore.toStringAsFixed(1)}/100
Grammar: ${grammarScore.toStringAsFixed(1)}/100
Pronunciation: ${pronunciationScore.toStringAsFixed(1)}/100

Grammar errors found: ${grammarErrors.length}
${grammarErrors.isNotEmpty ? 'Error types: ${grammarErrors.take(3).join(", ")}' : 'No major grammar errors detected.'}
${correctedSentence != null && correctedSentence.isNotEmpty ? '\nCorrected sentence:\n"$correctedSentence"' : ''}'''
            }
          ],
          'temperature': 0.7,
          'max_tokens': 200,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        return _generateTemplateFeedback(
          fluencyScore,
          grammarScore,
          pronunciationScore,
        );
      }
    } catch (e) {
      return _generateTemplateFeedback(
        fluencyScore,
        grammarScore,
        pronunciationScore,
      );
    }
  }
  
  String _generateTemplateFeedback(
    double fluency,
    double grammar,
    double pronunciation,
  ) {
    final overall = (fluency * 0.4 + grammar * 0.35 + pronunciation * 0.25);
    
    String encouragement;
    String improvement;
    
    if (overall >= 80) {
      encouragement = "Excellent work! Your English speaking skills are impressive.";
      improvement = "Focus on maintaining this high level with regular practice.";
    } else if (overall >= 65) {
      encouragement = "Great job! You're making solid progress.";
      improvement = "Work on ${_getWeakestArea(fluency, grammar, pronunciation)} to reach the next level.";
    } else {
      encouragement = "Good effort! You're on the right track.";
      improvement = "Focus on ${_getWeakestArea(fluency, grammar, pronunciation)} and practice daily for best results.";
    }
    
    return "$encouragement Your fluency is ${_getLevel(fluency)}, grammar is ${_getLevel(grammar)}, and pronunciation is ${_getLevel(pronunciation)}. $improvement Keep up the great work!";
  }
  
  String _getWeakestArea(double fluency, double grammar, double pronunciation) {
    if (fluency <= grammar && fluency <= pronunciation) return "fluency";
    if (grammar <= pronunciation) return "grammar accuracy";
    return "pronunciation";
  }
  
  String _getLevel(double score) {
    if (score >= 85) return "excellent";
    if (score >= 70) return "good";
    if (score >= 55) return "fair";
    return "developing";
  }
}
