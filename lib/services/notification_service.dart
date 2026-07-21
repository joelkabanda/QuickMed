import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'package:flutter/foundation.dart';
import '../models/reminder_model.dart';

class NotificationService {
  NotificationService._privateConstructor();
  static final NotificationService _instance = NotificationService._privateConstructor();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      // Best-effort local timezone detection without the flutter_native_timezone plugin.
      final String timeZoneName = DateTime.now().timeZoneName;
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e) {
        // Not an IANA name - fall back to UTC
        debugPrint('Timezone name not an IANA identifier: $e');
        tz.setLocalLocation(tz.UTC);
      }
    } catch (e) {
      debugPrint('Timezone init failed, falling back to UTC: $e');
      tz.setLocalLocation(tz.UTC);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Create default channel
    const androidChannel = AndroidNotificationChannel(
      'reminder_channel',
      'Reminders',
      description: 'Reminder notifications',
      importance: Importance.max,
      playSound: true,
      showBadge: true,
    );

    await _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    final id = _idFromString(reminder.id);
    final scheduled = tz.TZDateTime.from(reminder.reminderTime, tz.local);

    final androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      fullScreenIntent: true,
      ticker: 'Reminder',
    );

    final iosDetails = DarwinNotificationDetails(presentSound: true);

    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exact,
      title: 'Medication reminder',
      body: reminder.notes ?? 'Time to take your medication',
      payload: '',
      matchDateTimeComponents: null,
    );

    debugPrint('Scheduled notification $id at $scheduled');
  }

  Future<void> cancelReminder(String reminderId) async {
    final id = _idFromString(reminderId);
    await _plugin.cancel(id: id);
  }

  int _idFromString(String s) {
    // Simple stable hash to int
    var hash = 0;
    for (var i = 0; i < s.length; i++) {
      hash = (hash * 31 + s.codeUnitAt(i)) & 0x7fffffff;
    }
    return hash;
  }
}
