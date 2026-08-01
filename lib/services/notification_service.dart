import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  if (response.actionId != 'quickmed_moving') return;
  final payload = response.payload ?? '';
  if (!payload.startsWith('cancel:')) return;
  final id = int.tryParse(payload.substring('cancel:'.length));
  if (id == null) return;
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.cancel(id);
}

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
        onDidReceiveNotificationResponse: _handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      debugPrint("NotificationService: Plugin initialized: $initialized");

      const channel = AndroidNotificationChannel(
        'quickmed_reminders',
        'Reminders',
        description: 'Reminder notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);

      const liveRouteChannel = AndroidNotificationChannel(
        'quickmed_live_route',
        'Live travel updates',
        description: 'Real-time route and travel-time updates',
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
      );
      await androidPlugin?.createNotificationChannel(liveRouteChannel);
      debugPrint("NotificationService: Notification channels created");

      debugPrint("NotificationService: Requesting notification permissions...");
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      debugPrint("NotificationService: Notification permission granted: $granted");
      
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
      
      await cancelLegacyTestNotifications();
      debugPrint("NotificationService: Initialization complete");
      _isInitialized = true;
    } catch (e, stack) {
      debugPrint("NotificationService ERROR during init: $e");
      debugPrint(stack.toString());
    }
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    if (response.actionId != 'quickmed_moving') return;
    final payload = response.payload ?? '';
    if (!payload.startsWith('cancel:')) return;
    final id = int.tryParse(payload.substring('cancel:'.length));
    if (id != null) await _plugin.cancel(id);
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'quickmed_reminders',
      'Reminders',
      channelDescription: 'Reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
    );

    const iOSDetails = DarwinNotificationDetails();

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iOSDetails),
    );
  }


  Future<void> showLiveTravelNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();
    final androidDetails = AndroidNotificationDetails(
      'quickmed_live_route',
      'Live travel updates',
      channelDescription: 'Real-time route and travel-time updates',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: true,
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      styleInformation: BigTextStyleInformation(body),
    );

    const iOSDetails = DarwinNotificationDetails(
      presentSound: false,
    );

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iOSDetails),
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool allowWhileIdle = true,
    bool repeatDaily = true,
    String? payload,
    bool showMovingAction = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'quickmed_reminders',
      'Reminders',
      channelDescription: 'Reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      styleInformation: BigTextStyleInformation(body),
      actions: showMovingAction
          ? const <AndroidNotificationAction>[
              AndroidNotificationAction(
                'quickmed_moving',
                "I'm moving",
                cancelNotification: true,
              ),
            ]
          : const <AndroidNotificationAction>[],
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
      payload: payload,
      androidScheduleMode: allowWhileIdle
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.exact,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
    );
  }

  Future<void> cancelLegacyTestNotifications() async {
    const legacyTestIds = [999, 1001, 1002, 1003, 1004, 1005];
    for (final id in legacyTestIds) {
      await _plugin.cancel(id);
    }
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
