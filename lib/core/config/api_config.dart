/// App configuration — all inference runs on-device (Gemma 3 1B + Whisper + Kokoro).
/// No cloud API keys are required for core functionality.
class ApiConfig {
  /// Returns true if the app is ready to process recordings.
  /// Always true since all models are local.
  static bool get isReady => true;
}
