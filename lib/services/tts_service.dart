import 'dart:collection';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:kokoro_tts_flutter/kokoro_tts_flutter.dart';

/// TTS Service — on-device voice using Kokoro TTS with flutter_tts fallback.
/// 100% offline, no cloud API calls.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late Kokoro _kokoro;

  final Queue<String> _textQueue = Queue<String>();
  bool _isProcessingQueue = false;

  bool _isSpeaking = false;
  bool _isInitialized = false;
  bool _isMale = false;

  static const _kokoroFemale = 'af_heart';
  static const _kokoroMale = 'am_adam';

  bool get isSpeaking => _isSpeaking;
  bool get isMale => _isMale;

  void setVoice(bool isMale) {
    _isMale = isMale;
    debugPrint('TTS Voice set to: ${isMale ? 'Male' : 'Female'}');
  }

  String get currentVoiceProfile => _isMale ? _kokoroMale : _kokoroFemale;

  void setVoiceProfile(String id) {
    _isMale = (id == _kokoroMale);
    debugPrint('TTS Voice profile set to: $id (isMale: $_isMale)');
  }

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

    _initKokoro();
    _isInitialized = true;
  }

  Future<void> _initKokoro() async {
    try {
      _kokoro = Kokoro(const KokoroConfig(
        modelPath: 'assets/models/kokoro/kokoro-v1.0.onnx',
        voicesPath: 'assets/models/kokoro/voices-v1.0.bin',
      ));
      await _kokoro.initialize();
      debugPrint('Kokoro TTS initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Kokoro TTS: $e');
    }
  }

  Future<void> speak(String text) async {
    await init();
    _textQueue.add(text);
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_textQueue.isNotEmpty) {
      final text = _textQueue.removeFirst();
      if (text.trim().isEmpty) continue;

      _isSpeaking = true;

      try {
        debugPrint('TTS: Speaking with Kokoro ($currentVoiceProfile)');
        final result =
            await _kokoro.createTTS(text: text, voice: currentVoiceProfile);
        await _audioPlayer.play(BytesSource(
            Uint8List.fromList(result.audio.map((e) => e.toInt()).toList())));
      } catch (e) {
        debugPrint('Kokoro TTS failed ($e), using system TTS fallback');
        await _flutterTts.speak(text);
      }

      while (_isSpeaking) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    _isProcessingQueue = false;
  }

  Future<void> waitUntilDone() async {
    while (_isSpeaking || _isProcessingQueue || _textQueue.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> stop() async {
    _textQueue.clear();
    _isProcessingQueue = false;
    _isSpeaking = false;
    try {
      await _flutterTts.stop();
    } catch (_) {}
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  void dispose() {
    _flutterTts.stop();
    _audioPlayer.dispose();
  }
}
