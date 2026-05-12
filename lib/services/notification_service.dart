import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local daily reminder aligned with PUSH_NOTIFICATIONS / notifications_enabled.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const int _dailyId = 9001;
  static const String _channelId = 'voicebridge_daily';

  bool _initialized = false;

  bool get _supportsScheduled {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  Future<void> init() async {
    if (kIsWeb || !_supportsScheduled) return;

    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(settings: initSettings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      const channel = AndroidNotificationChannel(
        _channelId,
        'Daily practice',
        description: 'Daily VoiceBridge cycle reminders',
        importance: Importance.defaultImportance,
      );
      await androidImpl.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  tz.TZDateTime _nextDailyAtNine() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> scheduleDailyReminder() async {
    if (!_initialized || !_supportsScheduled) return;

    await _plugin.zonedSchedule(
      id: _dailyId,
      scheduledDate: _nextDailyAtNine(),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Daily practice',
          channelDescription: 'Daily VoiceBridge cycle reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'VoiceBridge',
      body: 'Daily cycle — time to practice.',
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    if (kIsWeb) return;
    await _plugin.cancel(id: _dailyId);
  }

  /// Requests POST_NOTIFICATIONS where applicable. Returns true if granted.
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return false;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> isNotificationPermissionGranted() async {
    if (kIsWeb) return false;
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Applies [notifications_enabled] and OS permission: schedules or cancels.
  Future<void> syncWithStoredPreference() async {
    if (!_initialized || !_supportsScheduled) return;

    final prefs = await SharedPreferences.getInstance();
    final want = prefs.getBool('notifications_enabled') ?? true;
    if (!want) {
      await cancelDailyReminder();
      return;
    }
    if (await isNotificationPermissionGranted()) {
      await scheduleDailyReminder();
    }
  }
}
