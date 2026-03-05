class AppConstants {
  // App Info
  static const String appName = 'VoiceBridge';
  static const String appVersion = '1.0.0';
  
  // Recording Constraints
  static const int minRecordingDurationSeconds = 15;
  static const int maxRecordingDurationSeconds = 90;
  static const int baselineRecordingDurationSeconds = 45;
  
  // Audio Settings
  static const int audioSampleRate = 16000;
  static const int audioBitRate = 128000;
  
  // Scoring Weights
  static const double fluencyWeight = 0.40;
  static const double grammarWeight = 0.35;
  static const double pronunciationWeight = 0.25;
  
  // Speaking Band Mapping (5-bracket scale)
  static const Map<int, double> bandMapping = {
    91: 9.0,
    76: 8.0,
    61: 7.0,
    46: 6.0,
    31: 5.0,
    0:  4.0,
  };
  
  // Disclaimers
  static const String bandDisclaimer =
      'This is an estimated speaking band score for practice purposes only. '
      'It should be used solely for tracking your speaking improvement.';
  
  // Processing Timeouts
  static const int uploadTimeoutSeconds = 30;
  static const int processingTimeoutSeconds = 60;
  
  // Sync Settings
  static const int maxSyncRetries = 3;
  static const int syncRetryBackoffMs = 1000;
}

class RouteConstants {
  static const String welcome = '/welcome';
  static const String signup = '/signup';
  static const String login = '/login';
  static const String baselineAssessment = '/baseline';
  static const String home = '/home';
  static const String practice = '/practice';
  static const String recording = '/recording';
  static const String feedback = '/feedback';
  static const String progress = '/progress';
  static const String history = '/history';
  static const String settings = '/settings';
}
