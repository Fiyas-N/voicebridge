import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_llm_service.dart';

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
  // ▼▼ MODEL CONFIGURATION — only these two lines ever need to change ▼▼
  // --------------------------------------------------------------------------

  /// Current model: Qwen3 0.6B — 614 MB on-device GPU.
  /// Direct from litert-community.
  static const String _modelBaseUrl =
      'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/'
      'Qwen3-0.6B.litertlm';

  /// Context window — 512 tokens is enough for VoiceBridge coaching turns.
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
  /// No-ops silently if model is already installed.
  Stream<int> downloadWithProgress() async* {
    final isInstalled = await isModelInstalled();
    if (isInstalled) return;

    final token = _hfToken;
    final urlStr = _modelBaseUrl; // DO NOT append ?token=, HF rejects it

    final httpClient = HttpClient();
    try {
      // Follow redirects to the S3 bucket
      final request = await httpClient.getUrl(Uri.parse(urlStr));
      if (token.isNotEmpty) {
        request.headers.add('Authorization', 'Bearer $token');
      }
      final response = await request.close();

      if (response.statusCode != 200 && response.statusCode != 302) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      // Handle redirect manually if dart:io doesn't follow Authorization correctly across domains
      HttpClientResponse finalResponse = response;
      if (response.isRedirect && response.headers.value('location') != null) {
        final redirectUrl = response.headers.value('location')!;
        final redirectReq = await httpClient.getUrl(Uri.parse(redirectUrl));
        // Do not send Bearer token to S3, it will cause 400 Bad Request
        finalResponse = await redirectReq.close();
      }

      if (finalResponse.statusCode != 200) {
        throw Exception('Download failed on redirect: HTTP ${finalResponse.statusCode}');
      }

      final contentLength = finalResponse.contentLength;
      final dir = await getApplicationDocumentsDirectory();
      final modelFileName = Uri.parse(urlStr).pathSegments.last;
      final file = File('${dir.path}/$modelFileName');
      final sink = file.openWrite();

      int receivedBytes = 0;
      await for (var chunk in finalResponse) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (contentLength > 0) {
          final progress = ((receivedBytes / contentLength) * 100).toInt();
          yield progress;
        }
      }
      await sink.close();

      // Register with flutter_gemma's internal storage tracking
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('installed_model_file_name', modelFileName);
      
      _isInitialized = true;
    } finally {
      httpClient.close();
    }
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
        debugPrint('LLM: Qwen not on device — starting custom download…');
        await downloadWithProgress().last;
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
      _model = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.general,
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
  // Smart routing — cloud (online) → on-device (offline)
  // --------------------------------------------------------------------------

  /// Streams tokens using the best available provider:
  ///   Online  → Gemini 2.0 Flash  (primary — fastest & most generous free tier)
  ///          → Groq Llama 3.3 70B (secondary — fastest GPU inference)
  ///   Offline → Qwen 0.5B on-device (zero-dependency fallback)
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
    return generateResponseStream(prompt);
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
