import 'package:flutter/services.dart';

/// Haptic Feedback Utility
/// Provides consistent haptic feedback across the app
class HapticFeedback {
  /// Light impact for subtle interactions
  static Future<void> lightImpact() async {
    await SystemChannels.platform.invokeMethod<void>(
      'HapticFeedback.vibrate',
      'HapticFeedbackType.lightImpact',
    );
  }
  
  /// Medium impact for standard interactions
  static Future<void> mediumImpact() async {
    await SystemChannels.platform.invokeMethod<void>(
      'HapticFeedback.vibrate',
      'HapticFeedbackType.mediumImpact',
    );
  }
  
  /// Heavy impact for important interactions
  static Future<void> heavyImpact() async {
    await SystemChannels.platform.invokeMethod<void>(
      'HapticFeedback.vibrate',
      'HapticFeedbackType.heavyImpact',
    );
  }
  
  /// Selection feedback for picker/selector interactions
  static Future<void> selectionClick() async {
    await HapticFeedback.selectionClick();
  }
  
  /// Success feedback (medium impact)
  static Future<void> success() async {
    await mediumImpact();
  }
  
  /// Error feedback (heavy impact)
  static Future<void> error() async {
    await heavyImpact();
  }
  
  /// Button tap feedback (light impact)
  static Future<void> buttonTap() async {
    await lightImpact();
  }
}
