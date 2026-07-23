import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      debugPrint("NotificationService: Initializing...");
      tz.initializeTimeZones();
      debugPrint("NotificationService: Timezones initialized");

      try {
        final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
        final String timeZoneName = timeZoneInfo.identifier;
        debugPrint("NotificationService: Device timezone: $timeZoneName");
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        debugPrint("NotificationService: Local location set");
      } catch (e) {
        debugPrint("NotificationService: Could not get local timezone, falling back to UTC: $e");
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      
      bool? initialized = await _plugin.initialize(
        const InitializationSettings(
          android: android,
          iOS: ios,
        ),
      );
      debugPrint("NotificationService: Plugin initialized: $initialized");

      // Create the notification channel for Android 8.0+
      const channel = AndroidNotificationChannel(
        'quickmed_reminders',
        'Reminders',
        description: 'Reminder notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      debugPrint("NotificationService: Notification channel created");

      // Request permissions for Android 13+
      debugPrint("NotificationService: Requesting notification permissions...");
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      debugPrint("NotificationService: Notification permission granted: $granted");
      
        // Request exact alarm permission for Android 12+
      debugPrint("NotificationService: Requesting exact alarm permissions...");
      final alarmsPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (alarmsPlugin != null) {
        final bool? hasPermission = await alarmsPlugin.canScheduleExactNotifications();
        debugPrint("NotificationService: Has exact alarm permission: $hasPermission");
        
        if (hasPermission == false) {
          await alarmsPlugin.requestExactAlarmsPermission();
        }
      }
      
      debugPrint("NotificationService: Initialization complete");
      _isInitialized = true;
    } catch (e, stack) {
      debugPrint("NotificationService ERROR during init: $e");
      debugPrint(stack.toString());
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'quickmed_reminders',
      'Reminders',
      channelDescription: 'Reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iOSDetails = DarwinNotificationDetails();

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iOSDetails),
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool allowWhileIdle = true,
    bool repeatDaily = true,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'quickmed_reminders',
      'Reminders',
      channelDescription: 'Reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
    );

    final iOSDetails = DarwinNotificationDetails();

    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
    
    debugPrint("NotificationService: Scheduling '$title' (ID: $id) for $tzScheduledDate (Local: $scheduledDate)");

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      NotificationDetails(android: androidDetails, iOS: iOSDetails),
      androidScheduleMode: allowWhileIdle
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.exact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
    );
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }
}
