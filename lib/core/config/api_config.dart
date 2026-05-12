/// App configuration — hybrid inference (cloud + on-device).
/// Core practice can run fully offline when models and prefs are present; cloud
/// improves quality when `GEMINI_API_KEY` / Groq / TTS keys are configured.
class ApiConfig {
  /// Returns true when the app build is structurally ready to run.
  /// Individual subsystems (Whisper bundle, Kokoro ONNX, downloaded LLM) are
  /// validated at runtime — see `LocalSttService`, `TtsService`, `LocalLlmService`.
  static bool get isReady => true;
}
