import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  String apiKey = '';
  for (var line in lines) {
    if (line.trim().startsWith('GROQ_API_KEY=')) {
      apiKey = line.split('=')[1].trim();
      break;
    }
  }

  if (apiKey.isEmpty) {
    print('Failed to find GROQ_API_KEY');
    return;
  }

  final String _groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  final String text = 'Hello world, this are a test for the AI feature.';
  
  try {
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

    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
