import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API Configuration — only GROQ_API_KEY is required.
/// Firebase reads its config from google-services.json automatically.
class ApiConfig {
  // Groq AI (powers STT, grammar analysis, and feedback generation)
  static String get groqApiKey =>
      dotenv.env['GROQ_API_KEY'] ?? '';

  static bool get isGroqConfigured => groqApiKey.isNotEmpty;

  /// Returns true if the app is ready to process recordings.
  static bool get isReady => isGroqConfigured;

  /// Returns a human-readable message if the key is missing.
  static String? get missingKeyMessage =>
      isGroqConfigured ? null : 'GROQ_API_KEY not set in .env';
}
