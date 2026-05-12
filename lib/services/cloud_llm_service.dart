import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Cloud LLM service — provides streaming responses from:
///   Primary  → Gemini 2.0 Flash (Google, 1 500 req/day free, no credit card)
///   Fallback → Groq Llama 3.3 70B (fastest inference available, free tier)
///
/// Both providers deliver streamed tokens using Server-Sent Events (SSE).
class CloudLlmService {
  static final CloudLlmService _instance = CloudLlmService._internal();
  factory CloudLlmService() => _instance;
  CloudLlmService._internal();

  // ── Endpoints ──────────────────────────────────────────────────────────────

  static const String _geminiModel = 'gemini-2.0-flash';
  static const String _groqModel   = 'llama-3.3-70b-versatile';

  // ── Connectivity check ────────────────────────────────────────────────────

  /// Returns true when the device has any network connection.
  Future<bool> isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Higher level helper that fetches aggregated text from Cloud.
  /// Falls back automatically between Gemini and Groq.
  Future<String> generateText(String prompt) async {
    try {
      final stream = await streamGemini(prompt);
      final buffer = await stream.toList();
      final res = buffer.join('');
      if (res.trim().isNotEmpty) return res.trim();
    } catch (e) {
      debugPrint('CloudLLM: Gemini fail ($e) attempting Groq fallback...');
    }

    try {
      final stream = await streamGroq(prompt);
      final buffer = await stream.toList();
      return buffer.join('').trim();
    } catch (e) {
      debugPrint('CloudLLM: Groq fallback failed ($e)');
      throw Exception('Both Cloud LLM endpoints failed');
    }
  }

  // ── Gemini 2.0 Flash ──────────────────────────────────────────────────────

  /// Stream tokens from Google Gemini 2.0 Flash via SSE.
  Future<Stream<String>> streamGemini(String prompt) async {
    final key = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (key.isEmpty) throw Exception('No GEMINI_API_KEY in .env');

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_geminiModel:streamGenerateContent?alt=sse&key=$key',
    );

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'contents': [
          {
            'parts': [{'text': prompt}],
          }
        ],
        'generationConfig': {
          'maxOutputTokens': 400,
          'temperature': 0.75,
        },
      });

    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      throw Exception('Gemini HTTP ${response.statusCode}');
    }

    return _parseGeminiStream(response.stream);
  }

  Stream<String> _parseGeminiStream(http.ByteStream byteStream) async* {
    String buffer = '';
    try {
      await for (final chunk in byteStream.transform(utf8.decoder)) {
        buffer += chunk;
        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final event = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);

          for (final line in event.split('\n')) {
            if (!line.startsWith('data: ')) continue;
            final raw = line.substring(6).trim();
            if (raw == '[DONE]' || raw.isEmpty) continue;
            try {
              final json = jsonDecode(raw) as Map<String, dynamic>;
              final text = json['candidates']?[0]?['content']
                          ?['parts']?[0]?['text'] as String?;
              if (text != null && text.isNotEmpty) yield text;
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('CloudLLM: Gemini stream error — $e');
    }
  }

  // ── Groq Llama 3.3 70B ───────────────────────────────────────────────────

  /// Stream tokens from Groq via OpenAI-compatible SSE endpoint.
  Future<Stream<String>> streamGroq(String prompt) async {
    final key = dotenv.env['GROQ_API_KEY'] ?? '';
    if (key.isEmpty) throw Exception('No GROQ_API_KEY in .env');

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final request = http.Request('POST', url)
      ..headers['Authorization'] = 'Bearer $key'
      ..headers['Content-Type']  = 'application/json'
      ..body = jsonEncode({
        'model': _groqModel,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 400,
        'temperature': 0.75,
        'stream': true,
      });

    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      throw Exception('Groq HTTP ${response.statusCode}');
    }

    return _parseGroqStream(response.stream);
  }

  Stream<String> _parseGroqStream(http.ByteStream byteStream) async* {
    String buffer = '';
    try {
      await for (final chunk in byteStream.transform(utf8.decoder)) {
        buffer += chunk;
        while (buffer.contains('\n')) {
          final idx = buffer.indexOf('\n');
          final line = buffer.substring(0, idx).trim();
          buffer = buffer.substring(idx + 1);

          if (!line.startsWith('data: ')) continue;
          final raw = line.substring(6).trim();
          if (raw == '[DONE]' || raw.isEmpty) continue;
          try {
            final json = jsonDecode(raw) as Map<String, dynamic>;
            final text = json['choices']?[0]?['delta']?['content'] as String?;
            if (text != null && text.isNotEmpty) yield text;
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('CloudLLM: Groq stream error — $e');
    }
  }
}
