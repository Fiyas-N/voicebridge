import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// On-device LLM service backed by Gemma 3 1B (MediaPipe / LiteRT, flutter_gemma v0.9.0).
///
/// Architecture:
///   - Model is downloaded ONCE on first launch (or pre-installed via ADB).
///   - Cached in app documents storage — subsequent launches skip the download.
///   - GPU backend preferred; falls back to CPU automatically.
///   - No internet needed after first install.
class LocalLlmService {
  static final LocalLlmService _instance = LocalLlmService._internal();
  factory LocalLlmService() => _instance;
  LocalLlmService._internal();

  // --------------------------------------------------------------------------
  // Model configuration
  // --------------------------------------------------------------------------


  /// Download URL — GPU int4 quantized Gemma 3 1B from litert-community.
  static const String _modelBaseUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/'
      'gemma3-1b-it-int4.task';

  /// Context window — 512 tokens is enough for VoiceBridge conversation turns.
  static const int _maxTokens = 512;

  // --------------------------------------------------------------------------
  // State
  // --------------------------------------------------------------------------

  InferenceModel? _model;
  bool _isInitialized = false;
  bool _isLoaded = false;

  /// True when model is loaded and ready for inference.
  bool get isLoaded => _isLoaded;

  /// In-flight load operation — prevents concurrent double-init.
  /// If warmLoad() fires loadModel() in the background and the pipeline
  /// calls loadModel() again before it completes, the second call simply
  /// awaits the same Completer instead of creating a second model instance.
  Completer<void>? _loadCompleter;

  // --------------------------------------------------------------------------
  // Model installation status
  // --------------------------------------------------------------------------

  /// Returns true if the model file has already been installed on-device.
  Future<bool> isModelInstalled() async {
    return FlutterGemmaPlugin.instance.modelManager.isModelInstalled;
  }

  /// Streams download progress (0–100). Completes when done.
  /// No-ops silently if model is already installed.
  Stream<int> downloadWithProgress() async* {
    final manager = FlutterGemmaPlugin.instance.modelManager;
    final isInstalled = await manager.isModelInstalled;
    if (isInstalled) return;

    final token = _hfToken;
    final url = token.isNotEmpty
        ? '$_modelBaseUrl?token=$token'
        : _modelBaseUrl;

    yield* manager.downloadModelFromNetworkWithProgress(url);
    _isInitialized = true;
  }

  // --------------------------------------------------------------------------
  // Lifecycle
  // --------------------------------------------------------------------------

  /// Ensures model is installed. Downloads if not already on device.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final manager = FlutterGemmaPlugin.instance.modelManager;
      final isInstalled = await manager.isModelInstalled;

      if (!isInstalled) {
        debugPrint('LLM: Gemma not on device — starting download…');
        final token = _hfToken;
        final url = token.isNotEmpty
            ? '$_modelBaseUrl?token=$token'
            : _modelBaseUrl;
        await manager.downloadModelFromNetworkWithProgress(url).last;
        debugPrint('LLM: Download complete.');
      } else {
        debugPrint('LLM: Gemma already installed — skipping.');
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('LLM init error: $e');
    }
  }

  /// Loads the Gemma model into GPU/CPU memory.
  /// Safe to call concurrently — subsequent calls block on the first load.
  Future<void> loadModel() async {
    if (_isLoaded) return;

    // If a load is already in flight (e.g. from warmLoad), await it instead
    // of starting a second one — prevents double-init and RAM waste.
    if (_loadCompleter != null) {
      debugPrint('LLM: Load already in progress — waiting…');
      return _loadCompleter!.future;
    }

    _loadCompleter = Completer<void>();
    try {
      await init();
      debugPrint('LLM: Loading Gemma 3 1B into memory…');
      _model = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        maxTokens: _maxTokens,
        preferredBackend: PreferredBackend.gpu,
      );
      _isLoaded = true;
      debugPrint('LLM: Model loaded and ready.');
      _loadCompleter!.complete();
    } catch (e) {
      debugPrint('LLM loadModel error: $e');
      _loadCompleter!.completeError(e);
      rethrow;
    } finally {
      _loadCompleter = null;
    }
  }

  /// Releases the model from GPU/CPU memory.
  Future<void> unloadModel() async {
    if (!_isLoaded || _model == null) return;
    try {
      await _model!.close();
      _model = null;
      _isLoaded = false;
      debugPrint('LLM: Model unloaded — RAM freed.');
    } catch (e) {
      debugPrint('LLM unloadModel error: $e');
    }
  }

  /// Non-blocking warm load — call this while the user is recording.
  /// Gemma loads silently in the background so it is ready the moment
  /// transcription finishes, hiding the 2–5 s GPU cold-start latency.
  void warmLoad() {
    if (_isLoaded) return; // already warm — no-op
    debugPrint('LLM: Warm-loading Gemma in background…');
    loadModel().catchError((e) {
      debugPrint('LLM warm-load error (non-fatal): $e');
    });
  }

  // --------------------------------------------------------------------------
  // Inference
  // --------------------------------------------------------------------------

  /// Returns the full response string (blocks until generation completes).
  Future<String> generateResponse(String prompt) async {
    await loadModel();
    try {
      final chat = await _model!.createChat();
      await chat.addQueryChunk(Message(text: prompt, isUser: true));
      final response = await chat.generateChatResponse();
      return response.trim();
    } catch (e) {
      debugPrint('LLM generateResponse error: $e');
      return '';
    }
  }

  /// Returns a stream of tokens as they are generated (real-time UI updates).
  Future<Stream<String>> generateResponseStream(String prompt) async {
    await loadModel();
    try {
      final chat = await _model!.createChat();
      await chat.addQueryChunk(Message(text: prompt, isUser: true));
      return chat.generateChatResponseAsync();
    } catch (e) {
      debugPrint('LLM generateResponseStream error: $e');
      return Stream.value(
          'Sorry, I had trouble generating a response. Please try again.');
    }
  }

  // --------------------------------------------------------------------------
  // Internal helpers
  // --------------------------------------------------------------------------

  String get _hfToken {
    try {
      return dotenv.env['HUGGINGFACE_TOKEN'] ?? '';
    } catch (_) {
      return '';
    }
  }
}
