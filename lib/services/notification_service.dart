import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(
      android: android,
      iOS: ios,
    ));
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
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'quickmed_reminders',
      'Reminders',
      channelDescription: 'Reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    final iOSDetails = DarwinNotificationDetails();

    await _plugin.schedule(
      id,
      title,
      body,
      scheduledDate,
      NotificationDetails(android: androidDetails, iOS: iOSDetails),
      androidAllowWhileIdle: allowWhileIdle,
    );
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }
}
