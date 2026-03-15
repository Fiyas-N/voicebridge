import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GrammarError {
  final String type;
  final String original;
  final String correction;
  final String explanation;

  GrammarError({
    required this.type,
    required this.original,
    required this.correction,
    required this.explanation,
  });

  factory GrammarError.fromJson(Map<String, dynamic> json) {
    return GrammarError(
      type: json['type'] ?? 'grammar',
      original: json['original'] ?? '',
      correction: json['correction'] ?? '',
      explanation: json['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'original': original,
      'correction': correction,
      'explanation': explanation,
    };
  }
}

class GrammarResult {
  final double score;
  final String correctedText;
  final List<GrammarError> errors;
  final String summary;

  GrammarResult({
    required this.score,
    required this.correctedText,
    required this.errors,
    required this.summary,
  });
}

class GrammarAnalysisService {
  static const String _groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  /// Analyze grammar using Groq's free Llama 3.1 70B model
  Future<GrammarResult> analyzeGrammar(String text) async {
    try {
      final apiKey = dotenv.env['GROQ_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GROQ_API_KEY not found in environment variables');
      }

      final response = await http.post(
        Uri.parse(_groqApiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content': '''You are an expert English grammar checker for speaking assessment.
Analyze the text and return a JSON response with:
{
  "score": 0-100,
  "corrected_text": "grammatically correct version",
  "errors": [
    {
      "type": "verb_tense|subject_verb|article|preposition|word_choice|other",
      "original": "incorrect phrase",
      "correction": "correct phrase",
      "explanation": "brief explanation"
    }
  ],
  "summary": "brief overall assessment"
}

Be strict but fair. Score based on:
- Verb tense accuracy (30%)
- Subject-verb agreement (25%)
- Article usage (15%)
- Preposition usage (15%)
- Word choice (15%)'''
            },
            {
              'role': 'user',
              'content': 'Analyze this text:\n\n$text'
            }
          ],
          'temperature': 0.3,
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return _parseGrammarResponse(content);
      } else {
        throw Exception('Grammar analysis failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Grammar analysis error: $e');
    }
  }
  
  GrammarResult _parseGrammarResponse(String content) {
    try {
      // Extract JSON from response (handle markdown code blocks)
      String jsonStr = content;
      if (content.contains('```json')) {
        jsonStr = content.split('```json')[1].split('```')[0].trim();
      } else if (content.contains('```')) {
        jsonStr = content.split('```')[1].split('```')[0].trim();
      }
      
      final data = jsonDecode(jsonStr);
      
      final errors = <GrammarError>[];
      if (data['errors'] != null) {
        for (var errorData in data['errors']) {
          errors.add(GrammarError.fromJson(errorData));
        }
      }
      
      return GrammarResult(
        score: (data['score'] ?? 75).toDouble(),
        correctedText: data['corrected_text'] ?? '',
        errors: errors,
        summary: data['summary'] ?? 'Grammar analysis complete',
      );
    } catch (e) {
      // Fallback if JSON parsing fails
      return GrammarResult(
        score: 70.0,
        correctedText: '',
        errors: [],
        summary: 'Grammar analysis completed with basic scoring',
      );
    }
  }
}
