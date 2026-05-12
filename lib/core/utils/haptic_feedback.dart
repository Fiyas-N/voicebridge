import 'package:flutter/services.dart' as services;
import 'package:shared_preferences/shared_preferences.dart';

/// App haptics gated by [haptic_output_enabled] (default on).
class AppHaptics {
  AppHaptics._();

  static Future<bool> _enabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('haptic_output_enabled') ?? true;
  }

  static Future<void> lightImpact() async {
    if (!await _enabled()) return;
    await services.HapticFeedback.lightImpact();
  }

  static Future<void> mediumImpact() async {
    if (!await _enabled()) return;
    await services.HapticFeedback.mediumImpact();
  }

  static Future<void> heavyImpact() async {
    if (!await _enabled()) return;
    await services.HapticFeedback.heavyImpact();
  }

  static Future<void> selectionClick() async {
    if (!await _enabled()) return;
    await services.HapticFeedback.selectionClick();
  }

  static Future<void> success() => mediumImpact();

  static Future<void> error() => heavyImpact();

  static Future<void> buttonTap() => lightImpact();
}
