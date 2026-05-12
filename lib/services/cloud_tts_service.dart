import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Cloud TTS service — Gemini 2.5 Flash TTS (free tier).
///
/// Calls the generateContent endpoint with response_mime_type: audio/wav
/// and decodes the base64 inline_data back to raw WAV bytes.
/// These bytes are played by audioplayers (BytesSource) already in the app.
///
/// Voice options (English-natural): aoide, charon, puck, fenrir, kore
/// aoide  → warm, expressive female  (default — great for English tutor)
/// charon → deep, authoritative male
/// puck   → friendly, energetic male
class CloudTtsService {
  static final CloudTtsService _instance = CloudTtsService._internal();
  factory CloudTtsService() => _instance;
  CloudTtsService._internal();

  // Female voice IDs align with current Kokoro gender toggle
  static const String _femaleVoice = 'Aoede';
  /// Deeper male preset than Charon for clearer gender contrast in Gemini TTS.
  static const String _maleVoice = 'Fenrir';

  static const String _model = 'gemini-2.5-flash-preview-tts';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ── Connectivity ────────────────────────────────────────────────────────────

  Future<bool> isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  // ── Generate ────────────────────────────────────────────────────────────────

  /// Returns WAV bytes for [text] using Gemini TTS.
  /// Throws on failure so the caller can fall back to Kokoro.
  Future<Uint8List> generateAudio(String text, {bool isMale = false}) async {
    final key = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (key.isEmpty) throw Exception('No GEMINI_API_KEY in .env');

    final voice = isMale ? _maleVoice : _femaleVoice;
    final url = Uri.parse('$_baseUrl/$_model:generateContent?key=$key');

    final body = jsonEncode({
      'contents': [
        {
          'parts': [{'text': text}],
        }
      ],
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {
              'voiceName': voice,
            }
          }
        }
      },
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      debugPrint('CloudTTS: HTTP ${response.statusCode} — ${response.body}');
      throw Exception('Gemini TTS HTTP ${response.statusCode}');
    }

    debugPrint('CloudTTS: Raw Body Received: \${response.body.substring(0, response.body.length > 150 ? 150 : response.body.length)}');
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // Path: candidates[0].content.parts[0].inline_data.data (base64 WAV)
    final inlineData = json['candidates']?[0]?['content']?['parts']?[0]
        ?['inline_data'] as Map<String, dynamic>?;

    if (inlineData == null) {
      debugPrint('CloudTTS: No inline_data in response: ${response.body}');
      throw Exception('Gemini TTS: no audio in response');
    }

    final base64Audio = inlineData['data'] as String;
    return base64Decode(base64Audio);
  }
}
