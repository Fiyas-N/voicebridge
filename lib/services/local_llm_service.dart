import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/pigeon.g.dart' show PreferredBackend;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_llm_service.dart';

/// On-device LLM service backed by LiteRT / flutter_gemma (Qwen3 0.6B).
///
/// Architecture:
///   - Model is downloaded ONCE on first launch (or pre-installed via ADB).
///   - Cached in app documents storage — subsequent launches skip the download.
///   - Uses flutter_gemma's [ModelFileManager] for downloads so install state
///     always matches what [createModel] expects.
///   - Preferred backend is null so native code picks a working GPU/CPU path;
///     forcing GPU can fail on emulators and bricks the plugin singleton.
///   - No internet needed after first install.
class LocalLlmService {
  static final LocalLlmService _instance = LocalLlmService._internal();
  factory LocalLlmService() => _instance;
  LocalLlmService._internal();

  // --------------------------------------------------------------------------
  // Model configuration
  // --------------------------------------------------------------------------
  // ▼▼ MODEL CONFIGURATION — only these two lines ever need to change ▼▼
  // --------------------------------------------------------------------------

  /// Current model: Qwen3 0.6B — on-device via litert-community.
  static const String _modelBaseUrl =
      'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/'
      'Qwen3-0.6B.litertlm';

  /// Context window — 512 tokens is enough for VoiceBridge coaching turns.
  static const int _maxTokens = 512;

  /// Approximate download size for UI/file-poll progress (matches setup screen).
  static const int _expectedModelBytes = 620000000;

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
  /// Performs automatic cache invalidation if the target URL has changed.
  Future<bool> isModelInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    final currentName = Uri.parse(_modelBaseUrl).pathSegments.last;
    final installedName = prefs.getString('installed_model_file_name');

    if (installedName != null && installedName != currentName) {
      debugPrint('LLM: Mismatched model detected ($installedName vs $currentName). Clearing legacy cache…');
      await FlutterGemmaPlugin.instance.modelManager.deleteModel();
      await prefs.remove('installed_model_file_name'); // ensure absolute clean slate
      return false; // needs clean install
    }

    return FlutterGemmaPlugin.instance.modelManager.isModelInstalled;
  }

  /// Streams download progress (0–100). Completes when done.
  /// Yields 100 immediately when the model is already installed so UI progress
  /// does not sit at 0% with an empty stream.
  ///
  /// If the model is missing and the device has **no network**, throws immediately
  /// (otherwise the native downloader can hang with no progress events).
  Stream<int> downloadWithProgress() async* {
    final isInstalled = await isModelInstalled();
    if (isInstalled) {
      yield 100;
      return;
    }

    final cloud = CloudLlmService();
    if (!await cloud.isOnline()) {
      throw Exception(
        'Internet required once to download the on-device tutor model (~600 MB). '
        'Connect to Wi‑Fi or mobile data, then tap RETRY_QUEUE.',
      );
    }

    yield 0;

    final modelFileName = Uri.parse(_modelBaseUrl).pathSegments.last;
    final pluginStream = FlutterGemmaPlugin.instance.modelManager
        .downloadModelFromNetworkWithProgress(_modelBaseUrl)
        .timeout(
      const Duration(seconds: 120),
      onTimeout: (sink) {
        sink.addError(
          Exception(
            'Download stalled (no progress for 2 minutes). Check your connection or VPN, then tap RETRY_QUEUE.',
          ),
        );
      },
    );

    yield* _mergePluginDownloadWithFilePoll(pluginStream, modelFileName);
  }

  /// Merges native plugin progress with partial file size on disk (plugin often
  /// stays silent for long stretches while bytes are still downloading).
  Stream<int> _mergePluginDownloadWithFilePoll(
    Stream<int> pluginStream,
    String modelFileName,
  ) {
    final controller = StreamController<int>();
    var maxProgress = 0;
    var active = true;

    void push(int v) {
      final n = v.clamp(0, 100);
      if (n <= maxProgress) return;
      maxProgress = n;
      if (!controller.isClosed) {
        controller.add(maxProgress);
      }
    }

    Future<void> pollOnce() async {
      if (!active) return;
      try {
        final dir = await getApplicationDocumentsDirectory();
        final f = File('${dir.path}/$modelFileName');
        if (await f.exists()) {
          final len = await f.length();
          final est = ((len * 99) ~/ _expectedModelBytes).clamp(0, 99);
          push(est);
        }
      } catch (_) {}
    }

    final timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      pollOnce();
    });

    StreamSubscription<int>? pluginSub;
    controller.onCancel = () {
      active = false;
      timer.cancel();
      pluginSub?.cancel();
    };

    pluginSub = pluginStream.listen(
      push,
      onError: (Object e, StackTrace st) {
        active = false;
        timer.cancel();
        if (!controller.isClosed) {
          controller.addError(e, st);
        }
      },
      onDone: () async {
        active = false;
        timer.cancel();
        await pollOnce();
        push(100);
        if (!controller.isClosed) {
          await controller.close();
        }
      },
      cancelOnError: true,
    );

    return controller.stream;
  }

  // --------------------------------------------------------------------------
  // Lifecycle
  // --------------------------------------------------------------------------

  /// Ensures model is installed. Downloads if not already on device.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final isInstalled = await isModelInstalled();

      if (!isInstalled) {
        debugPrint('LLM: Qwen not on device — downloading via Gemma plugin…');
        await for (final _ in downloadWithProgress()) {}
        debugPrint('LLM: Download complete.');
      } else {
        debugPrint('LLM: Qwen already installed — skipping.');
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
      debugPrint('LLM: Loading Qwen3 0.6B into memory…');
      // Single backend choice: LiteRT leaves the plugin completer wedged after a
      // failed createModel, so a second createModel() cannot retry. CPU is the
      // most compatible path for TFLite on diverse Android GPUs.
      _model = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.general,
        maxTokens: _maxTokens,
        preferredBackend: PreferredBackend.cpu,
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
    debugPrint('LLM: Warm-loading Qwen in background…');
    loadModel().catchError((e) {
      debugPrint('LLM warm-load error (non-fatal): $e');
    });
  }

  // --------------------------------------------------------------------------
  // Inference
  // --------------------------------------------------------------------------

  /// Returns the full response string (blocks until generation completes).
  Future<String> generateResponse(String prompt) async {
    try {
      await loadModel();
    } catch (e) {
      debugPrint('LLM generateResponse: loadModel failed — $e');
      return '';
    }
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
  /// Set [skipLoad] true when [loadModel] was already awaited (avoids duplicate work).
  Future<Stream<String>> generateResponseStream(String prompt, {bool skipLoad = false}) async {
    if (!skipLoad) {
      try {
        await loadModel();
      } catch (e, st) {
        debugPrint('LLM generateResponseStream: loadModel failed — $e');
        debugPrint(st.toString());
        return Stream.value(
          "I'm sorry — the offline tutor model could not start on this device. "
          'Try a reboot or free storage. If you use full offline mode, you can still '
          'practice; when you have internet, turn off full offline to use cloud replies.',
        );
      }
    }
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
  // Smart routing — cloud (online) → on-device (offline)
  // --------------------------------------------------------------------------

  /// Streams tokens using the best available provider:
  ///   Online  → Gemini 2.0 Flash  (primary — fastest & most generous free tier)
  ///          → Groq Llama 3.3 70B (secondary — fastest GPU inference)
  ///   Offline → Qwen on-device
  Future<Stream<String>> smartStream(String prompt) async {
    final cloud = CloudLlmService();

    final prefs = await SharedPreferences.getInstance();
    final useOfflineOnly = prefs.getBool('use_offline_only') ?? false;

    if (!useOfflineOnly && await cloud.isOnline()) {
      // ── Try Gemini first ────────────────────────────────────────────────
      try {
        debugPrint('LLM: Attempting Gemini 2.0 Flash (online)');
        return await cloud.streamGemini(prompt);
      } catch (e) {
        debugPrint('LLM: Gemini unavailable — $e');
      }

      // ── Groq fallback ───────────────────────────────────────────────────
      try {
        debugPrint('LLM: Routing to Groq Llama 3.3 70B (online fallback)');
        return await cloud.streamGroq(prompt);
      } catch (e) {
        debugPrint('LLM: Groq unavailable — $e');
      }
    }
    // ── Offline: on-device Qwen ─────────────────────────────────────────
    debugPrint('LLM: Routing to Qwen3 0.6B on-device (offline)');
    try {
      return await generateResponseStream(prompt);
    } catch (e, st) {
      debugPrint('LLM smartStream local path failed — $e');
      debugPrint(st.toString());
      return Stream.value(
        "I'm having trouble running the offline tutor on this phone right now. "
        'Try again after a reboot, or connect to the internet and turn off full offline for cloud replies.',
      );
    }
  }

  /// Non-streaming version of smartStream — collects full response.
  Future<String> smartGenerate(String prompt) async {
    final stream = await smartStream(prompt);
    final buffer = StringBuffer();
    await for (final token in stream) {
      buffer.write(token);
    }
    return buffer.toString().trim();
  }
}
