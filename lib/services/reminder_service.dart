import 'package:flutter/foundation.dart';
import 'package:quickmed/models/medication_model.dart';
import 'package:quickmed/models/reminder_model.dart';
import 'package:quickmed/models/user_profile_model.dart';
import 'package:quickmed/models/app_notification_model.dart';
import 'package:quickmed/services/database_service.dart';
import 'package:quickmed/services/google_routes_service.dart';
import 'package:quickmed/services/location_service.dart';
import 'package:quickmed/services/notification_service.dart';

class ReminderService {
  static const int defaultLeadTimeMinutes = 30;

  static List<Reminder> buildRemindersForMedication({
    required String userId,
    required Medication medication,
    DateTime? startDate,
    int daysCount = 7,
    int leadTimeMinutes = defaultLeadTimeMinutes,
  }) {
    final start = startDate ?? DateTime.now();
    final reminders = <Reminder>[];

    for (var dayIndex = 0; dayIndex < daysCount; dayIndex++) {
      final date = start.add(Duration(days: dayIndex));

      for (final timeText in medication.scheduleTimes) {
        final parts = timeText.split(':');
        if (parts.length != 2) continue;

        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;

        final medicationTime =
            DateTime(date.year, date.month, date.day, hour, minute);
        final plannedReminderTime = medicationTime.subtract(
          Duration(minutes: leadTimeMinutes),
        );
        final now = DateTime.now();
        final reminderTime = plannedReminderTime.isBefore(now)
            ? now.add(const Duration(seconds: 5))
            : plannedReminderTime;

        if (medicationTime.isBefore(now)) continue;
        if (medicationTime.isBefore(medication.startDate)) continue;
        if (medication.endDate != null &&
            medicationTime.isAfter(medication.endDate!)) {
          continue;
        }

        final dateId =
            '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
        final timeId = timeText.replaceAll(':', '');

        reminders.add(
          Reminder(
            id: 'rem_${medication.id}_${dateId}_$timeId',
            userId: userId,
            medicationId: medication.id,
            reminderTime: reminderTime,
            status: ReminderStatus.pending,
            isNotificationSent: false,
            notes:
                '${medication.name} (${medication.dosage}) is due in $leadTimeMinutes minutes.',
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    return reminders;
  }

  static Future<void> scheduleMedicationNotifications({
    required String userId,
    required Medication medication,
    required List<Reminder> reminders,
    GoogleRoutesService? routesService,
  }) async {
    final notifications = NotificationService();
    final database = DatabaseService();
    final routeData = await _loadRouteDataForUser(
      userId: userId,
      medicationDestinationAddress: medication.pharmacyAddress,
      routesService: routesService,
    );

    for (final reminder in reminders) {
      final medicationTime = reminder.reminderTime.add(
        const Duration(minutes: defaultLeadTimeMinutes),
      );
      final now = DateTime.now();
      if (!medicationTime.isAfter(now)) continue;

      final events = <_ScheduledAlert>[];

      if (routeData != null && routeData.estimates.isNotEmpty) {
        final ordered = [...routeData.estimates]
          ..sort((a, b) => a.duration.compareTo(b.duration));
        final fastest = ordered.first;
        final slowest = ordered.last;

        // 1) Preparation alert: 30 minutes before the patient must leave
        // using the slowest available means of transport.
        final slowestPrepareAt = medicationTime
            .subtract(slowest.duration)
            .subtract(const Duration(minutes: 30));
        if (slowestPrepareAt.isAfter(now)) {
          events.add(_ScheduledAlert(
            time: slowestPrepareAt,
            title: 'Prepare for your medication journey',
            body: _travelBody(
              medication: medication,
              routeData: routeData,
              notificationTime: slowestPrepareAt,
              message: 'Your medication is approaching. In 30 minutes, start '
                  'travelling by ${slowest.mode.label} so you can reach the destination on time.',
            ),
            type: 'slowest_prepare',
          ));
        }

        // 2) Preparation alert: 30 minutes before the patient must leave
        // using the fastest available means of transport.
        final fastestPrepareAt = medicationTime
            .subtract(fastest.duration)
            .subtract(const Duration(minutes: 30));
        if (fastestPrepareAt.isAfter(now)) {
          events.add(_ScheduledAlert(
            time: fastestPrepareAt,
            title: 'Get ready to travel',
            body: _travelBody(
              medication: medication,
              routeData: routeData,
              notificationTime: fastestPrepareAt,
              message: 'If you plan to use the quickest option, get ready  '
                  'In 30 minutes, you should start travelling by ${fastest.mode.label}.',
            ),
            type: 'fastest_prepare',
          ));
        }

        // 3) Leave-now alert when time remaining equals the slowest journey.
        final slowestLeaveAt = medicationTime.subtract(slowest.duration);
        if (slowestLeaveAt.isAfter(now)) {
          events.add(_ScheduledAlert(
            time: slowestLeaveAt,
            title: 'Start moving now',
            body: _travelBody(
              medication: medication,
              routeData: routeData,
              notificationTime: slowestLeaveAt,
              message: 'It is time to start moving by ${slowest.mode.label}. '
                  'The journey takes ${slowest.durationText}, which now matches the time left before your medication.',
            ),
            type: 'slowest_departure',
          ));
        }

        // 4) Escalation alert at the latest safe departure time using the
        // fastest available means. This is scheduled as the fallback when the
        // earlier reminder has not led to departure.
        final fastestLeaveAt = medicationTime.subtract(fastest.duration);
        if (fastestLeaveAt.isAfter(now)) {
          events.add(_ScheduledAlert(
            time: fastestLeaveAt,
            title: 'Use the quickest transport now',
            body: _travelBody(
              medication: medication,
              routeData: routeData,
              notificationTime: fastestLeaveAt,
              message: 'You are at the latest safe departure time. Move to '
                  '${routeData.destinationName} now using ${fastest.mode.label} '
                  '(${fastest.durationText}).',
            ),
            type: 'fastest_departure',
          ));
        }
      } else {
        // Route data is required for the first four reminder stages. If it is
        // unavailable, keep a single preparation alert rather than creating
        // misleading travel-time notifications.
        final fallbackAt = medicationTime.subtract(const Duration(minutes: 30));
        if (fallbackAt.isAfter(now)) {
          events.add(_ScheduledAlert(
            time: fallbackAt,
            title: 'Medication due in 30 minutes',
            body: '${medication.name} (${medication.dosage}) is due in 30 minutes. '
                'Open QuickMed to refresh your destination and travel times.',
            type: 'route_unavailable',
          ));
        }
      }

      // 5) Final medication alert. Per the requested format, this one does not
      // include travel details.
      events.add(_ScheduledAlert(
        time: medicationTime,
        title: 'Take ${medication.name} now',
        body: '${medication.name} (${medication.dosage}) is due now.',
        type: 'dose',
      ));

      events.sort((a, b) => a.time.compareTo(b.time));
      final unique = <String, _ScheduledAlert>{};
      for (final event in events) {
        // If two rules resolve to the same instant, keep both only when their
        // purpose differs; their IDs remain deterministic.
        final key = '${event.time.millisecondsSinceEpoch}_${event.type}';
        unique[key] = event;
      }

      final scheduled = <({String id, int numericId, _ScheduledAlert event})>[];
      var index = 0;
      for (final event in unique.values) {
        final id = '${reminder.id}_${event.type}_${event.time.millisecondsSinceEpoch}';
        final numericId = (id.hashCode + index++) & 0x7fffffff;
        scheduled.add((id: id, numericId: numericId, event: event));
      }

      int? fastestEscalationId;
      for (final item in scheduled) {
        if (item.event.type == 'fastest_departure') {
          fastestEscalationId = item.numericId;
          break;
        }
      }

      for (final item in scheduled) {
        final canConfirmMovement = fastestEscalationId != null &&
            item.event.type != 'fastest_departure' &&
            item.event.type != 'dose';
        await notifications.scheduleNotification(
          id: item.numericId,
          title: item.event.title,
          body: item.event.body,
          scheduledDate: item.event.time,
          repeatDaily: false,
          payload: canConfirmMovement ? 'cancel:$fastestEscalationId' : null,
          showMovingAction: canConfirmMovement,
        );
        await database.saveAppNotification(AppNotificationRecord(
          id: item.id,
          userId: userId,
          title: item.event.title,
          body: item.event.body,
          scheduledAt: item.event.time,
          createdAt: DateTime.now(),
          type: item.event.type,
        ));
      }
    }
  }

  static String _travelBody({
    required Medication medication,
    required _RouteData routeData,
    required DateTime notificationTime,
    required String message,
  }) {
    return '$message\n'
        'Medication: ${medication.name} (${medication.dosage})\n'
        '${routeData.summary}\n'
        'Notification time: ${_formatDateTime(notificationTime)}';
  }

  static String _formatDateTime(DateTime value) {
    final hour = value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute $period';
  }

  static Future<_RouteData?> _loadRouteDataForUser({
    required String userId,
    String? medicationDestinationAddress,
    GoogleRoutesService? routesService,
  }) async {
    try {
      final savedDestination =
          await DatabaseService().getSavedPharmacyLocation(userId);
      final destination = await _resolveDestination(
        savedDestination: savedDestination,
        medicationDestinationAddress: medicationDestinationAddress,
      );
      if (destination == null) return null;
      final current = await LocationService.getCurrentLocation();
      final estimates = await (routesService ?? GoogleRoutesService())
          .getTravelEstimates(
        originLatitude: current.latitude,
        originLongitude: current.longitude,
        destinationLatitude: destination.latitude,
        destinationLongitude: destination.longitude,
      );
      if (estimates.isEmpty) return null;
      return _RouteData(
        destinationName: destination.name,
        estimates: estimates,
        summary: formatRouteSummary(destination.name, estimates),
      );
    } catch (error) {
      debugPrint('Could not prepare travel-aware reminders: $error');
      return null;
    }
  }

  static Future<String?> buildLocationRouteSummaryForUser({
    required String userId,
    String? medicationDestinationAddress,
    GoogleRoutesService? routesService,
  }) async {
    try {
      final savedDestination =
          await DatabaseService().getSavedPharmacyLocation(userId);
      final destination = await _resolveDestination(
        savedDestination: savedDestination,
        medicationDestinationAddress: medicationDestinationAddress,
      );
      if (destination == null) return null;

      final current = await LocationService.getCurrentLocation();
      final estimates = await (routesService ?? GoogleRoutesService())
          .getTravelEstimates(
        originLatitude: current.latitude,
        originLongitude: current.longitude,
        destinationLatitude: destination.latitude,
        destinationLongitude: destination.longitude,
      );

      if (estimates.isEmpty) {
        return 'Destination: ${destination.name}';
      }
      return formatRouteSummary(destination.name, estimates);
    } catch (error) {
      debugPrint('Could not add Google Maps travel estimates: $error');
      return null;
    }
  }

  static Future<_ReminderDestination?> _resolveDestination({
    SavedPharmacyLocation? savedDestination,
    String? medicationDestinationAddress,
  }) async {
    if (savedDestination != null) {
      final name = savedDestination.pharmacyName.trim().isNotEmpty
          ? savedDestination.pharmacyName.trim()
          : savedDestination.address.trim();
      return _ReminderDestination(
        name: name.isEmpty ? 'Saved destination' : name,
        latitude: savedDestination.latitude,
        longitude: savedDestination.longitude,
      );
    }

    final address = medicationDestinationAddress?.trim() ?? '';
    if (address.isEmpty) return null;
    final locations = await LocationService.getCoordinatesFromAddress(address);
    if (locations.isEmpty) return null;
    return _ReminderDestination(
      name: address,
      latitude: locations.first.latitude,
      longitude: locations.first.longitude,
    );
  }

  @visibleForTesting
  static String formatRouteSummary(
    String destination,
    List<TravelEstimate> estimates,
  ) {
    final lines = estimates.map((item) => item.notificationLine).join('\n');
    return 'Destination: $destination\nTime to reach by:\n$lines';
  }
}

class _ReminderDestination {
  const _ReminderDestination({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
}


class _RouteData {
  const _RouteData({
    required this.destinationName,
    required this.estimates,
    required this.summary,
  });
  final String destinationName;
  final List<TravelEstimate> estimates;
  final String summary;
}

class _ScheduledAlert {
  const _ScheduledAlert({
    required this.time,
    required this.title,
    required this.body,
    required this.type,
  });
  final DateTime time;
  final String title;
  final String body;
  final String type;
}
