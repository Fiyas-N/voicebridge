import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// TTS Service — Provides human-like AI voice using ElevenLabs (if configured)
/// Falls back to flutter_tts if API key is missing.
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isSpeaking = false;
  bool _isInitialized = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    if (_isInitialized) return;
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.48);  
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.05);       

    _flutterTts.setStartHandler(() => _isSpeaking = true);
    _flutterTts.setCompletionHandler(() => _isSpeaking = false);
    _flutterTts.setCancelHandler(() => _isSpeaking = false);
    _flutterTts.setErrorHandler((_) => _isSpeaking = false);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        _isSpeaking = false;
      }
    });
    final voices = await _flutterTts.getVoices as List<dynamic>?;
    if (voices != null) {
      final enVoices = voices
          .cast<Map<dynamic, dynamic>>()
          .where((v) =>
              (v['locale'] as String?)?.startsWith('en') == true)
          .toList();
      if (enVoices.isNotEmpty) {
        final voice = enVoices.first;
        await _flutterTts.setVoice({
          'name': voice['name'] as String,
          'locale': voice['locale'] as String,
        });
      }
    }

    _isInitialized = true;
  }

  /// Speak [text] using ElevenLabs (if available) or fallback to local TTS
  Future<void> speak(String text) async {
    await init();
    await stop();
    _isSpeaking = true;

    final apiKey = dotenv.env['ELEVENLABS_API_KEY'];
    
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        await _speakWithElevenLabs(text, apiKey);
        return;
      } catch (e) {
        debugPrint('ElevenLabs TTS failed ($e), falling back to flutter_tts');
      }
    }
    
    // Fallback to local TTS
    await _flutterTts.speak(text);
  }

  Future<void> _speakWithElevenLabs(String text, String apiKey) async {
    // A nice, friendly female US voice ID from ElevenLabs (e.g., "Rachel" or "Drew")
    const voiceId = 'EXAVITQu4vr4xnSDxMaL'; // "Sarah" - warm/professional

    final url = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId');
    final response = await http.post(
      url,
      headers: {
        'Accept': 'audio/mpeg',
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'model_id': 'eleven_monolingual_v1',
        'voice_settings': {
          'stability': 0.5,
          'similarity_boost': 0.75,
        }
      }),
    );

    if (response.statusCode == 200) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_temp.mp3');
      await file.writeAsBytes(response.bodyBytes);
      
      await _audioPlayer.play(DeviceFileSource(file.path));
    } else {
      throw Exception('ElevenLabs API error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Wait until TTS finishes speaking.
  Future<void> waitUntilDone() async {
    while (_isSpeaking) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    await _audioPlayer.stop();
    _isSpeaking = false;
  }

  void dispose() {
    _flutterTts.stop();
    _audioPlayer.dispose();
  }
}
