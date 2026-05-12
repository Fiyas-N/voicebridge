import 'dart:collection';
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:kokoro_tts_flutter/kokoro_tts_flutter.dart';
import 'cloud_tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Picks a system [flutter_tts] voice map for [wantMale], using gender fields
/// and common Android/iOS naming patterns (not only the word "male"/"female").
Map<String, dynamic>? _pickSystemTtsVoice(List<dynamic> rawVoices, bool wantMale) {
  int localeBonus(String locale) {
    final l = locale.toLowerCase();
    if (l.startsWith('en-us')) return 8;
    if (l.startsWith('en-gb')) return 6;
    if (l.startsWith('en')) return 4;
    if (l.contains('en')) return 2;
    return 0;
  }

  /// Positive = matches desired gender; negative = opposite gender.
  int genderScore(String name, String genderField) {
    final g = genderField.toLowerCase();
    final n = name.toLowerCase();

    bool oppositeMale = n.contains('#female') || g == 'female' || g == 'f';
    bool oppositeFemale = n.contains('#male') || g == 'male' || g == 'm';

    if (wantMale) {
      if (oppositeMale) return -100;
      if (g == 'male' || g == 'm') return 100;
      if (n.contains('#male')) return 100;
      if (n.contains(' male') || n.endsWith(' male')) return 85;
      if (n.contains('male') && !n.contains('female')) return 70;
      if (oppositeFemale) return -50;
      return 0;
    } else {
      if (oppositeFemale) return -100;
      if (g == 'female' || g == 'f') return 100;
      if (n.contains('#female')) return 100;
      if (n.contains('female')) return 90;
      if (n.contains('sfg')) return 45;
      if (oppositeMale) return -50;
      return 0;
    }
  }

  Map<String, dynamic>? best;
  var bestTotal = -9999;

  for (final raw in rawVoices) {
    if (raw is! Map) continue;
    final m = Map<String, dynamic>.from(raw);
    final name = (m['name'] ?? '').toString();
    final locale = (m['locale'] ?? '').toString();
    final genderField = (m['gender'] ?? '').toString();
    final gs = genderScore(name, genderField);
    if (gs <= 0) continue;
    final total = gs + localeBonus(locale);
    if (total > bestTotal) {
      bestTotal = total;
      best = m;
    }
  }

  if (best != null) return best;

  // No confident gender match: prefer any English voice for intelligibility.
  for (final raw in rawVoices) {
    if (raw is! Map) continue;
    final m = Map<String, dynamic>.from(raw);
    final locale = (m['locale'] ?? '').toString().toLowerCase();
    if (!locale.startsWith('en')) continue;
    final bonus = localeBonus(locale);
    if (bonus > bestTotal) {
      bestTotal = bonus;
      best = m;
    }
  }
  return best;
}

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

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final CloudTtsService _cloudTts = CloudTtsService();
  Kokoro? _kokoro;

  final Queue<String> _textQueue = Queue<String>();
  bool _isProcessingQueue = false;

  bool _isSpeaking = false;
  bool _isInitialized = false;
  bool _isMale = false;

  static const _kokoroFemale = 'af_bella';
  /// Prefer deeper male timbre; falls back to [am_adam] in [_speakOne] if missing from voices.json.
  static const _kokoroMale = 'bm_george';
  static const _kokoroMaleFallback = 'am_adam';

  /// Same routing as recording preview: speaker + media focus for WAV/PCM bytes.
  static const AudioContext _bytesPlaybackContext = AudioContext(
    android: AudioContextAndroid(
      isSpeakerphoneOn: true,
      audioMode: AndroidAudioMode.normal,
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gain,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
    ),
  );

  static const String _kokoroOnnxUrl =
      'https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx';
  static const String _kokoroVoicesBinUrl =
      'https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin';

  static bool _warnedKokoroUnavailable = false;

  bool get isSpeaking => _isSpeaking;
  bool get isMale => _isMale;

  Future<void> setVoice(bool isMale) async {
    _isMale = isMale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tts_voice_is_male', isMale);
    debugPrint('TTS_ENGINE: Saved active gender to persistent storage: $isMale');
  }

  String get currentVoiceProfile => _isMale ? _kokoroMale : _kokoroFemale;

  Future<void> setVoiceProfile(String id) async {
    final derivedIsMale = id.startsWith('am_') || id.startsWith('bm_');
    if (derivedIsMale != _isMale) {
      await setVoice(derivedIsMale);
    }
    debugPrint('TTS_ENGINE: Profile switched to: $id (derivedMale: $derivedIsMale)');
  }

  Future<void> init() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _isMale = prefs.getBool('tts_voice_is_male') ?? false;
    debugPrint('TTS_ENGINE_BOOT: Loaded persistent gender -> ${_isMale ? "MALE" : "FEMALE"}');

    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.52);
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

    await _initKokoro();
    _isInitialized = true;
  }

  Future<void> _initKokoro() async {
    try {
      final k = Kokoro(const KokoroConfig(
        modelPath: 'assets/models/kokoro/kokoro-v1.0.onnx',
        voicesPath: 'assets/models/kokoro/voices.json',
      ));
      await k.initialize();
      _kokoro = k;
      debugPrint('Kokoro TTS initialized successfully');
    } catch (e, stack) {
      _kokoro = null;
      debugPrint(
        'Kokoro TTS failed to initialize ($e). '
        'Place kokoro-v1.0.onnx and voices.json under assets/models/kokoro/ (see pubspec). '
        'Download ONNX: $_kokoroOnnxUrl — voices bin: $_kokoroVoicesBinUrl (convert .bin to voices.json per kokoro_tts_flutter README).',
      );
      debugPrint(stack.toString());
    }
  }

  void _warnKokoroSkippedOnce() {
    if (_warnedKokoroUnavailable) return;
    _warnedKokoroUnavailable = true;
    debugPrint(
      'TTS: Kokoro engine unavailable (_kokoro is null) — using system TTS. '
      'Fix: add Kokoro assets (see log from Kokoro init) or set a valid GEMINI_API_KEY for cloud TTS.',
    );
  }

  Future<void> _playPcmBytes(Uint8List bytes) async {
    await _audioPlayer.stop();
    await _audioPlayer.setVolume(1.0);
    await _audioPlayer.play(
      BytesSource(bytes),
      ctx: _bytesPlaybackContext,
      mode: PlayerMode.mediaPlayer,
    );
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
    debugPrint('TTS_ENGINE: Commencing speak cycle for text: "${text.substring(0, text.length > 30 ? 30 : text.length)}..."');
    debugPrint('TTS_ENGINE: Active Gender Toggle -> ${_isMale ? "MALE" : "FEMALE"}');
    final prefs = await SharedPreferences.getInstance();
    // Full offline skips cloud TTS; natural voice + gender come from Kokoro
    // (af_bella / bm_george, with am_adam fallback). If Kokoro failed init, flutter_tts is used.
    final useOfflineOnly = prefs.getBool('use_offline_only') ?? false;

    if (!useOfflineOnly && await _cloudTts.isOnline()) {
      try {
        debugPrint('TTS: Speaking with Gemini Flash TTS (online)');
        final bytes = await _cloudTts.generateAudio(text, isMale: _isMale);
        await _playPcmBytes(bytes);
        return;
      } catch (e) {
        debugPrint('TTS: Gemini cloud failed ($e) — falling back to Kokoro');
      }
    }

    final kokoro = _kokoro;
    if (kokoro != null) {
      try {
        final voice = currentVoiceProfile;
        debugPrint('TTS: Speaking with Kokoro ($voice)');
        final result = await kokoro.createTTS(text: text, voice: voice);
        await _playPcmBytes(
          Uint8List.fromList(result.audio.map((e) => e.toInt()).toList()),
        );
        return;
      } catch (e) {
        if (_isMale && currentVoiceProfile == _kokoroMale) {
          try {
            debugPrint('TTS: Kokoro primary male voice missing — retrying $_kokoroMaleFallback');
            final result = await kokoro.createTTS(
              text: text,
              voice: _kokoroMaleFallback,
            );
            await _playPcmBytes(
              Uint8List.fromList(result.audio.map((e) => e.toInt()).toList()),
            );
            return;
          } catch (_) {}
        }
        debugPrint('TTS: Kokoro failed ($e) — falling back to system TTS');
      }
    } else {
      _warnKokoroSkippedOnce();
    }

    debugPrint('TTS: Speaking with system flutter_tts (Fallback)');
    try {
      final targetPitch = _isMale ? 0.80 : 1.15;
      final targetRate = _isMale ? 0.42 : 0.56;
      await _flutterTts.setPitch(targetPitch);
      await _flutterTts.setSpeechRate(targetRate);

      final voices = await _flutterTts.getVoices;
      final chosen = _pickSystemTtsVoice(voices, _isMale);
      if (chosen != null) {
        await _flutterTts.setVoice({
          'name': chosen['name'],
          'locale': chosen['locale'],
        });
        debugPrint('TTS Fallback: voice=${chosen['name']} locale=${chosen['locale']}');
      } else {
        debugPrint('TTS Fallback: no matching system voice; using pitch/rate only');
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
