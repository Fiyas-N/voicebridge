import 'package:flutter/services.dart' as services;
import 'package:shared_preferences/shared_preferences.dart';

/// Haptic + system click for primary controls, respecting telemetry prefs.
class UiTapFeedback {
  UiTapFeedback._();

  static Future<void> play() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('haptic_output_enabled') ?? true) {
      await services.HapticFeedback.lightImpact();
    }
    if (prefs.getBool('audio_feedback_enabled') ?? true) {
      await services.SystemSound.play(services.SystemSoundType.click);
    }
  }
}
