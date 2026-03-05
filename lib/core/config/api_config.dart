import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API Configuration
/// Loads API keys and configuration from environment variables
class ApiConfig {
  // Firebase
  static String get firebaseApiKey => 
      dotenv.env['FIREBASE_API_KEY'] ?? '';
  
  static String get firebaseProjectId => 
      dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  
  static String get firebaseAppId => 
      dotenv.env['FIREBASE_APP_ID'] ?? '';
  
  // Google Cloud Speech-to-Text
  static String get googleCloudApiKey => 
      dotenv.env['GOOGLE_CLOUD_API_KEY'] ?? '';
  
  // OpenAI (for grammar analysis and feedback)
  static String get openaiApiKey => 
      dotenv.env['OPENAI_API_KEY'] ?? '';
  
  // Azure Speech Service (for pronunciation assessment)
  static String get azureSpeechKey => 
      dotenv.env['AZURE_SPEECH_KEY'] ?? '';
  
  static String get azureSpeechRegion => 
      dotenv.env['AZURE_SPEECH_REGION'] ?? 'eastus';
  
  // Feature Flags
  static bool get enableOfflineMode => 
      dotenv.env['ENABLE_OFFLINE_MODE']?.toLowerCase() == 'true';
  
  static bool get enableAnalytics => 
      dotenv.env['ENABLE_ANALYTICS']?.toLowerCase() == 'true';
  
  static int get maxAudioRetentionDays => 
      int.tryParse(dotenv.env['MAX_AUDIO_RETENTION_DAYS'] ?? '30') ?? 30;
  
  // Validation
  static bool validateFirebase() {
    return firebaseApiKey.isNotEmpty && 
           firebaseProjectId.isNotEmpty;
  }
  
  static bool validateAIServices() {
    return googleCloudApiKey.isNotEmpty &&
           openaiApiKey.isNotEmpty &&
           azureSpeechKey.isNotEmpty;
  }
  
  static bool validateAll() {
    return validateFirebase() && validateAIServices();
  }
  
  // Get missing keys for debugging
  static List<String> getMissingKeys() {
    final missing = <String>[];
    
    if (firebaseApiKey.isEmpty) missing.add('FIREBASE_API_KEY');
    if (firebaseProjectId.isEmpty) missing.add('FIREBASE_PROJECT_ID');
    if (googleCloudApiKey.isEmpty) missing.add('GOOGLE_CLOUD_API_KEY');
    if (openaiApiKey.isEmpty) missing.add('OPENAI_API_KEY');
    if (azureSpeechKey.isEmpty) missing.add('AZURE_SPEECH_KEY');
    
    return missing;
  }
}
