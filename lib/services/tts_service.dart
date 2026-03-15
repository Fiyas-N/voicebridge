import 'package:flutter_tts/flutter_tts.dart';

/// TTS Service — wraps flutter_tts for AI voice responses in conversation mode
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  bool _isInitialized = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    if (_isInitialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);  // slightly slower for clarity
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.05);       // slightly higher — sounds more natural

    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((_) => _isSpeaking = false);

    // Pick the best available English voice
    final voices = await _tts.getVoices as List<dynamic>?;
    if (voices != null) {
      final enVoices = voices
          .cast<Map<dynamic, dynamic>>()
          .where((v) =>
              (v['locale'] as String?)?.startsWith('en') == true)
          .toList();
      if (enVoices.isNotEmpty) {
        final voice = enVoices.first;
        await _tts.setVoice({
          'name': voice['name'] as String,
          'locale': voice['locale'] as String,
        });
      }
    }

    _isInitialized = true;
  }

  /// Speak [text] aloud. Stops any current speech first.
  Future<void> speak(String text) async {
    await init();
    await _tts.stop();
    _isSpeaking = true;
    await _tts.speak(text);
  }

  /// Wait until TTS finishes speaking.
  Future<void> waitUntilDone() async {
    while (_isSpeaking) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  void dispose() {
    _tts.stop();
  }
}
