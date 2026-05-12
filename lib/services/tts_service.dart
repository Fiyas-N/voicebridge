import 'dart:collection';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:kokoro_tts_flutter/kokoro_tts_flutter.dart';
import 'cloud_tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TTS Service — smart hybrid voice engine.
///
/// Online  → Gemini 2.5 Flash TTS  (more natural, expressive)
/// Offline → Kokoro on-device       (existing, already best free offline TTS)
/// Fallback→ flutter_tts system TTS (last resort if both fail)
///
/// All callers use TtsService().speak() — the routing is 100% transparent.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts  _flutterTts  = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final CloudTtsService _cloudTts = CloudTtsService();
  late Kokoro _kokoro;

  final Queue<String> _textQueue = Queue<String>();
  bool _isProcessingQueue = false;

  bool _isSpeaking     = false;
  bool _isInitialized  = false;
  bool _isMale         = false;

  static const _kokoroFemale = 'af_bella';
  static const _kokoroMale   = 'am_adam';

  bool get isSpeaking => _isSpeaking;
  bool get isMale     => _isMale;

  void setVoice(bool isMale) async {
    _isMale = isMale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tts_voice_is_male', isMale);
    debugPrint('TTS_ENGINE: Saved active gender to persistent storage: $isMale');
  }

  String get currentVoiceProfile => _isMale ? _kokoroMale : _kokoroFemale;

  void setVoiceProfile(String id) {
    // Derives new boolean from provided Kokoro prefix then syncs logic
    final derivedIsMale = id.startsWith('am_');
    if (derivedIsMale != _isMale) {
      setVoice(derivedIsMale);
    }
    debugPrint('TTS_ENGINE: Profile switched to: \$id (derivedMale: \$derivedIsMale)');
  }

  Future<void> init() async {
    if (_isInitialized) return;
    
    // 1. Load persistent gender preference from device storage
    final prefs = await SharedPreferences.getInstance();
    _isMale = prefs.getBool('tts_voice_is_male') ?? false; 
    debugPrint('TTS_ENGINE_BOOT: Loaded persistent gender -> \${_isMale ? "MALE" : "FEMALE"}');

    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.48);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.05);

    _flutterTts.setStartHandler(()      => _isSpeaking = true);
    _flutterTts.setCompletionHandler(() => _isSpeaking = false);
    _flutterTts.setCancelHandler(()     => _isSpeaking = false);
    _flutterTts.setErrorHandler((_)     => _isSpeaking = false);

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
        voicesPath: 'assets/models/kokoro/voices.json',
      ));
      await _kokoro.initialize();
      debugPrint('Kokoro TTS initialized successfully');
    } catch (e, stack) {
      debugPrint('Kokoro TTS Initialization Critical Failure: \$e');
      debugPrint(stack.toString());
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
      await _speakOne(text);

      while (_isSpeaking) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    _isProcessingQueue = false;
  }

  /// Attempts cloud TTS → Kokoro → system TTS in order.
  Future<void> _speakOne(String text) async {
    debugPrint('TTS_ENGINE: Commencing speak cycle for text: "\${text.substring(0, text.length > 30 ? 30 : text.length)}..."');
    debugPrint('TTS_ENGINE: Active Gender Toggle -> \${_isMale ? "MALE" : "FEMALE"}');
    final prefs = await SharedPreferences.getInstance();
    final useOfflineOnly = prefs.getBool('use_offline_only') ?? false;

    // ── 1. Try Gemini TTS (online) ──────────────────────────────────────────
    if (!useOfflineOnly && await _cloudTts.isOnline()) {
      try {
        debugPrint('TTS: Speaking with Gemini Flash TTS (online)');
        final bytes = await _cloudTts.generateAudio(text, isMale: _isMale);
        await _audioPlayer.play(BytesSource(bytes));
        return; // done — completion listener handles _isSpeaking = false
      } catch (e) {
        debugPrint('TTS: Gemini cloud failed ($e) — falling back to Kokoro');
      }
    }

    // ── 2. Kokoro on-device ─────────────────────────────────────────────────
    try {
      debugPrint('TTS: Speaking with Kokoro ($currentVoiceProfile)');
      final result = await _kokoro.createTTS(
        text: text,
        voice: currentVoiceProfile,
      );
      await _audioPlayer.play(BytesSource(
        Uint8List.fromList(result.audio.map((e) => e.toInt()).toList()),
      ));
      return;
    } catch (e) {
      debugPrint('TTS: Kokoro failed ($e) — falling back to system TTS');
    }

    // ── 3. System TTS (last resort) ─────────────────────────────────────────
    debugPrint('TTS: Speaking with system flutter_tts (Fallback)');
    try {
      // Dynamic dynamic gender hack for legacy OS voice synthesis
      final double targetPitch = _isMale ? 0.88 : 1.12;
      await _flutterTts.setPitch(targetPitch);

      // Attempt semantic search for explicit localized gender profiles
      final List<dynamic> voices = await _flutterTts.getVoices;
      final matchKeyword = _isMale ? 'male' : 'female';
      
      dynamic chosenVoice;
      for (final v in voices) {
        final voiceName = (v['name'] ?? '').toString().toLowerCase();
        if (voiceName.contains(matchKeyword)) {
          chosenVoice = v;
          break;
        }
      }

      if (chosenVoice != null) {
        await _flutterTts.setVoice({"name": chosenVoice['name'], "locale": chosenVoice['locale']});
        debugPrint('TTS Fallback: Applied system voice alignment: ${chosenVoice['name']}');
      }
    } catch (e) {
      debugPrint('TTS Fallback: Failed voice alignment logic ($e)');
    }

    await _flutterTts.speak(text);
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
    try { await _flutterTts.stop(); } catch (_) {}
    try { await _audioPlayer.stop(); } catch (_) {}
  }

  void dispose() {
    _flutterTts.stop();
    _audioPlayer.dispose();
  }
}
