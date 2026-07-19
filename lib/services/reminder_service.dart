import 'package:flutter/foundation.dart';
import 'package:quickmed/models/medication_model.dart';
import 'package:quickmed/models/reminder_model.dart';
import 'package:quickmed/services/location_service.dart';

class ReminderService {
  static const int defaultLeadTimeMinutes = 30;
  static const int nearLocationLeadTimeMinutes = 15;
  static const int farLocationLeadTimeMinutes = 60;

  static List<Reminder> buildRemindersForMedication({
    required String userId,
    required Medication medication,
    DateTime? baseDate,
    int? leadTimeMinutes,
  }) {
    final date = baseDate ?? DateTime.now();
    final reminders = <Reminder>[];

    for (final timeText in medication.scheduleTimes) {
      final parts = timeText.split(':');
      if (parts.length != 2) {
        continue;
      }

      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final scheduledTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );

      final reminderTime = scheduledTime.subtract(
        Duration(minutes: leadTimeMinutes ?? defaultLeadTimeMinutes),
      );

      reminders.add(
        Reminder(
          id: '${medication.id}-${timeText.replaceAll(':', '')}-${reminders.length}',
          userId: userId,
          medicationId: medication.id,
          reminderTime: reminderTime,
          status: ReminderStatus.pending,
          isNotificationSent: false,
          notes: 'Scheduled for ${medication.name} at $timeText',
          createdAt: DateTime.now(),
        ),
      );
    }

    return reminders;
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
