import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TranscriptionResult {
  final String transcript;
  final double confidence;
  final List<WordInfo> words;

  TranscriptionResult({
    required this.transcript,
    required this.confidence,
    this.words = const [],
  });
}

class WordInfo {
  final String word;
  final double confidence;
  final double startTime;
  final double endTime;

  WordInfo({
    required this.word,
    required this.confidence,
    required this.startTime,
    required this.endTime,
  });
}

class SpeechToTextService {
  static const String _groqApiUrl = 'https://api.groq.com/openai/v1/audio/transcriptions';
  
  /// Transcribe audio file using Groq's free Whisper API
  Future<TranscriptionResult> transcribeAudio(String audioPath) async {
    try {
      final apiKey = dotenv.env['GROQ_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GROQ_API_KEY not found in environment variables');
      }

      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(_groqApiUrl));
      request.headers['Authorization'] = 'Bearer $apiKey';
      
      // Add audio file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          audioPath,
          filename: 'audio.wav',
        ),
      );
      
      // Specify model and response format
      request.fields['model'] = 'whisper-large-v3';
      request.fields['response_format'] = 'verbose_json';
      request.fields['temperature'] = '0';
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseGroqResponse(data);
      } else {
        throw Exception('Transcription failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Speech-to-text error: $e');
    }
  }
  
  TranscriptionResult _parseGroqResponse(Map<String, dynamic> data) {
    final transcript = data['text'] as String? ?? '';
    
    // Parse word-level timestamps if available
    final List<WordInfo> words = [];
    if (data['words'] != null) {
      for (var wordData in data['words']) {
        words.add(WordInfo(
          word: wordData['word'] ?? '',
          confidence: (wordData['probability'] ?? 0.9).toDouble(),
          startTime: (wordData['start'] ?? 0.0).toDouble(),
          endTime: (wordData['end'] ?? 0.0).toDouble(),
        ));
      }
    }
    
    // Calculate average confidence
    double avgConfidence = 0.9;
    if (words.isNotEmpty) {
      avgConfidence = words.map((w) => w.confidence).reduce((a, b) => a + b) / words.length;
    }
    
    return TranscriptionResult(
      transcript: transcript,
      confidence: avgConfidence,
      words: words,
    );
  }
}
