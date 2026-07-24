import 'package:flutter/foundation.dart';
import 'package:quickmed/models/medication_model.dart';
import 'package:quickmed/models/reminder_model.dart';
import 'package:quickmed/services/location_service.dart';
import 'package:quickmed/services/notification_service.dart';

class ReminderService {
  static const int defaultLeadTimeMinutes = 0; // Reminder at the exact time
  static const int nearLocationLeadTimeMinutes = 15;
  static const int farLocationLeadTimeMinutes = 60;

  static List<Reminder> buildRemindersForMedication({
    required String userId,
    required Medication medication,
    DateTime? startDate,
    int daysCount = 7,
    int? leadTimeMinutes,
  }) {
    final start = startDate ?? DateTime.now();
    final reminders = <Reminder>[];

    for (int i = 0; i < daysCount; i++) {
      final date = start.add(Duration(days: i));
      
      for (final timeText in medication.scheduleTimes) {
        final parts = timeText.split(':');
        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        
        DateTime scheduledTime = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );

        // Don't create reminders in the past for the first day
        if (i == 0 && scheduledTime.isBefore(DateTime.now().subtract(const Duration(minutes: 5)))) {
          continue;
        }

        final reminderTime = scheduledTime.subtract(
          Duration(minutes: leadTimeMinutes ?? 0),
        );

        // Unique ID including date to allow history and future occurrences
        final dateId = "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
        final timeId = timeText.replaceAll(':', '');
        final reminderId = 'rem_${medication.id}_${dateId}_$timeId';

        reminders.add(
          Reminder(
            id: reminderId,
            userId: userId,
            medicationId: medication.id,
            reminderTime: reminderTime,
            status: ReminderStatus.pending,
            isNotificationSent: false,
            notes: 'Time to take your ${medication.name} (${medication.dosage})',
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    return reminders;
  }

  static Future<void> scheduleSystemNotifications(List<Reminder> reminders) async {
    final notifService = NotificationService();
    for (final reminder in reminders) {
      // For medication reminders, we schedule them for the time specified.
      // Even if it's slightly in the past, zonedSchedule with matchDateTimeComponents.time
      // will handle it for the next occurrence (e.g., tomorrow).
      await notifService.scheduleNotification(
        id: reminder.id.hashCode & 0x7fffffff,
        title: 'Medication Reminder',
        body: reminder.notes ?? 'Time for your medication',
        scheduledDate: reminder.reminderTime,
        repeatDaily: true,
      );
    }
  }

  static int estimateLeadTimeMinutes({double? distanceKm}) {
    if (distanceKm == null) {
      return defaultLeadTimeMinutes;
    }

    if (distanceKm <= 1.0) {
      return nearLocationLeadTimeMinutes;
    }

    if (distanceKm <= 5.0) {
      return defaultLeadTimeMinutes;
    }

    return farLocationLeadTimeMinutes;
  }

  static Future<int> estimateLeadTimeMinutesFromLocation({
    double? latitude,
    double? longitude,
  }) async {
    try {
      if (latitude == null || longitude == null) {
        return defaultLeadTimeMinutes;
      }

      final position = await LocationService.getCurrentLocation();
      final distanceKm = LocationService.calculateDistance(
        position.latitude,
        position.longitude,
        latitude,
        longitude,
      );
      return estimateLeadTimeMinutes(distanceKm: distanceKm);
    } catch (e) {
      debugPrint('Unable to estimate reminder lead time: $e');
      return defaultLeadTimeMinutes;
    }
  }

  static Future<int> estimateLeadTimeMinutesForAddress(String? address) async {
    if (address == null || address.trim().isEmpty) {
      return defaultLeadTimeMinutes;
    }

    try {
      final coordinates = await LocationService.getCoordinatesFromAddress(address);
      if (coordinates.isEmpty) {
        return defaultLeadTimeMinutes;
      }

      final position = await LocationService.getCurrentLocation();
      final distanceKm = LocationService.calculateDistance(
        position.latitude,
        position.longitude,
        coordinates.first.latitude,
        coordinates.first.longitude,
      );
      return estimateLeadTimeMinutes(distanceKm: distanceKm);
    } catch (e) {
      debugPrint('Unable to estimate reminder lead time from address: $e');
      return defaultLeadTimeMinutes;
    }
  }
}
