import 'package:flutter/foundation.dart';
import 'package:quickmed/models/app_notification_model.dart';
import 'package:quickmed/models/medication_model.dart';
import 'package:quickmed/models/reminder_model.dart';
import 'package:quickmed/models/user_profile_model.dart';
import 'package:quickmed/services/database_service.dart';
import 'package:quickmed/services/google_routes_service.dart';
import 'package:quickmed/services/location_service.dart';
import 'package:quickmed/services/notification_service.dart';

class ReminderService {
  static const int defaultLeadTimeMinutes = 30;
  static const Duration preparationWindow = Duration(minutes: 30);

  static const List<String> _managedAlertTypes = <String>[
    'prepare_slowest',
    'prepare_fastest',
    'leave_slowest',
    'leave_fastest',
    'route_unavailable',
    'dose',
  ];

  static List<Reminder> buildRemindersForMedication({
    required String userId,
    required Medication medication,
    DateTime? startDate,
    int daysCount = 7,
    int leadTimeMinutes = defaultLeadTimeMinutes,
  }) {
    assert(leadTimeMinutes >= 0);
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
        final now = DateTime.now();
        final reminderTime = medicationTime;

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
            medicationTime: medicationTime,
            status: ReminderStatus.pending,
            isNotificationSent: false,
            notes:
                '${medication.name} (${medication.dosage}) is due at $timeText.',
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
    List<TravelEstimate>? travelEstimates,
    String? destinationName,
    bool persistNotificationRecords = true,
  }) async {
    final suppliedEstimates = travelEstimates ?? const <TravelEstimate>[];
    final suppliedDestination = destinationName?.trim() ?? '';
    final routeData = suppliedEstimates.isNotEmpty && suppliedDestination.isNotEmpty
        ? _RouteData(
            destinationName: suppliedDestination,
            estimates: suppliedEstimates,
          )
        : await _loadRouteDataForUser(
            userId: userId,
            medicationDestinationAddress: medication.pharmacyAddress,
            routesService: routesService,
          );

    await _scheduleMedicationNotificationsWithRouteData(
      userId: userId,
      medication: medication,
      reminders: reminders,
      routeData: routeData,
      persistNotificationRecords: persistNotificationRecords,
    );
  }

  static Future<void> refreshUpcomingMedicationNotificationsFromCurrentLocation({
    required String userId,
  }) async {
    final routeData = await _loadRouteDataForUser(userId: userId);
    if (routeData == null) return;
    await refreshUpcomingMedicationNotificationsForUser(
      userId: userId,
      destinationName: routeData.destinationName,
      travelEstimates: routeData.estimates,
    );
  }

  static Future<void> refreshUpcomingMedicationNotificationsForUser({
    required String userId,
    required String destinationName,
    required List<TravelEstimate> travelEstimates,
    Duration horizon = const Duration(hours: 24),
  }) async {
    if (travelEstimates.isEmpty) return;

    try {
      final database = DatabaseService();
      final medications = await database.getUserMedications(userId);
      final reminders = await database.getUserReminders(userId);
      final now = DateTime.now();
      final limit = now.add(horizon);

      for (final medication in medications.where((item) => item.isActive)) {
        final upcoming = reminders.where((reminder) {
          if (reminder.medicationId != medication.id) return false;
          final medicationTime = medicationTimeForReminder(reminder);
          return medicationTime.isAfter(now) && !medicationTime.isAfter(limit);
        }).toList();
        if (upcoming.isEmpty) continue;

        await scheduleMedicationNotifications(
          userId: userId,
          medication: medication,
          reminders: upcoming,
          travelEstimates: travelEstimates,
          destinationName: destinationName,
          persistNotificationRecords: false,
        );
      }
    } catch (error) {
      debugPrint('Could not refresh live route reminders: $error');
    }
  }

  static Future<void> _scheduleMedicationNotificationsWithRouteData({
    required String userId,
    required Medication medication,
    required List<Reminder> reminders,
    required _RouteData? routeData,
    required bool persistNotificationRecords,
  }) async {
    final notifications = NotificationService();
    final database = DatabaseService();
    await notifications.init();

    for (final reminder in reminders) {
      final medicationTime = medicationTimeForReminder(reminder);
      final now = DateTime.now();
      if (!medicationTime.isAfter(now)) continue;

      if (persistNotificationRecords) {
        await _cancelManagedAlerts(notifications, reminder.id);
      }

      final alerts = routeData != null && routeData.estimates.isNotEmpty
          ? buildTravelReminderAlerts(
              medicationTime: medicationTime,
              medicationName: medication.name,
              medicationDosage: medication.dosage,
              destinationName: routeData.destinationName,
              estimates: routeData.estimates,
              now: now,
            )
          : buildFallbackReminderAlerts(
              medicationTime: medicationTime,
              medicationName: medication.name,
              medicationDosage: medication.dosage,
              now: now,
            );

      for (final alert in alerts) {
        final numericId = stableNotificationId('${reminder.id}:${alert.type}');
        await notifications.scheduleNotification(
          id: numericId,
          title: alert.title,
          body: alert.body,
          scheduledDate: alert.time,
          repeatDaily: false,
        );

        // Keep the in-app Notifications history synchronized with the
        // latest route-based trigger time. The screen reveals the record only
        // after scheduledAt is reached.
        final recordId = '${reminder.id}_${alert.type}';
        await database.saveAppNotification(
          AppNotificationRecord(
            id: recordId,
            userId: userId,
            title: alert.title,
            body: alert.body,
            scheduledAt: alert.time,
            createdAt: DateTime.now(),
            type: alert.type,
          ),
        );
      }
    }
  }

  @visibleForTesting
  static List<MedicationTravelAlert> buildTravelReminderAlerts({
    required DateTime medicationTime,
    required String medicationName,
    required String medicationDosage,
    required String destinationName,
    required List<TravelEstimate> estimates,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final usable = estimates
        .where((item) => item.duration.inSeconds > 0)
        .toList()
      ..sort((a, b) => a.duration.compareTo(b.duration));

    if (usable.isEmpty) {
      return buildFallbackReminderAlerts(
        medicationTime: medicationTime,
        medicationName: medicationName,
        medicationDosage: medicationDosage,
        now: current,
      );
    }

    final fastest = usable.first;
    final walkingOptions = usable
        .where((item) => item.mode == TravelMode.walking)
        .toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));
    final slowest = walkingOptions.isNotEmpty ? walkingOptions.first : usable.last;
    final sameBoundary = fastest.duration == slowest.duration;

    final prepareSlowestAt =
        medicationTime.subtract(slowest.duration + preparationWindow);
    final leaveSlowestAt = medicationTime.subtract(slowest.duration);
    final leaveFastestAt = medicationTime.subtract(fastest.duration);
    var prepareFastestAt =
        medicationTime.subtract(fastest.duration + preparationWindow);

    // Keep the five alerts in the requested human sequence. On longer walking
    // routes, the normal fastest-mode preparation threshold can fall after the
    // walking departure threshold. Move that preparation alert just before the
    // walking departure so the person first prepares both options, then leaves.
    if (!sameBoundary && !prepareFastestAt.isBefore(leaveSlowestAt)) {
      prepareFastestAt = leaveSlowestAt.subtract(const Duration(minutes: 1));
    }
    if (!sameBoundary && !prepareFastestAt.isAfter(prepareSlowestAt)) {
      prepareFastestAt = prepareSlowestAt.add(const Duration(minutes: 1));
    }

    final alerts = <MedicationTravelAlert>[];

    void addAlert(MedicationTravelAlert alert) {
      if (!alert.time.isAfter(current)) return;
      alerts.add(alert);
    }

    addAlert(
      MedicationTravelAlert(
        time: prepareSlowestAt,
        title: slowest.mode == TravelMode.walking
            ? 'Prepare to walk for your medicine'
            : 'Prepare for the slower journey',
        body: 'If you will use ${slowest.mode.label} to $destinationName, '
            'finish what you are doing now. Prepare for 30 minutes, then '
            'start your journey. Travel time: ${slowest.durationText}.',
        type: 'prepare_slowest',
      ),
    );

    if (!sameBoundary) {
      addAlert(
        MedicationTravelAlert(
          time: prepareFastestAt,
          title: 'Prepare for the quickest journey',
          body: 'Prepare now for ${fastest.mode.label}, the quickest '
              'current option to $destinationName for $medicationName. '
              'QuickMed will remind you again when it is time to leave. '
              'Travel time: ${fastest.durationText}.',
          type: 'prepare_fastest',
        ),
      );
    }

    addAlert(
      MedicationTravelAlert(
        time: leaveSlowestAt,
        title: slowest.mode == TravelMode.walking
            ? 'Start walking now'
            : 'Start the slower journey now',
        body: 'Start moving now using ${slowest.mode.label} so you reach '
            '$destinationName by the medicine time. Travel time: '
            '${slowest.durationText}.',
        type: 'leave_slowest',
      ),
    );

    if (!sameBoundary) {
      addAlert(
        MedicationTravelAlert(
          time: leaveFastestAt,
          title: 'Start the quickest journey now',
          body: 'Leave now using ${fastest.mode.label}, the quickest current '
              'option to $destinationName. Travel time: '
              '${fastest.durationText}.',
          type: 'leave_fastest',
        ),
      );
    }

    addAlert(
      MedicationTravelAlert(
        time: medicationTime,
        title: 'Take $medicationName now',
        body: '$medicationName ($medicationDosage) is due now.',
        type: 'dose',
      ),
    );

    alerts.sort((a, b) => a.time.compareTo(b.time));
    return alerts;
  }

  @visibleForTesting
  static List<MedicationTravelAlert> buildFallbackReminderAlerts({
    required DateTime medicationTime,
    required String medicationName,
    required String medicationDosage,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final alerts = <MedicationTravelAlert>[];
    final routeRefreshAt = medicationTime.subtract(preparationWindow);

    if (routeRefreshAt.isAfter(current)) {
      alerts.add(
        MedicationTravelAlert(
          time: routeRefreshAt,
          title: 'Route update needed',
          body: 'Open QuickMed to refresh the current travel time before '
              'leaving for $medicationName.',
          type: 'route_unavailable',
        ),
      );
    }
    if (medicationTime.isAfter(current)) {
      alerts.add(
        MedicationTravelAlert(
          time: medicationTime,
          title: 'Take $medicationName now',
          body: '$medicationName ($medicationDosage) is due now.',
          type: 'dose',
        ),
      );
    }
    return alerts;
  }

  @visibleForTesting
  static DateTime medicationTimeForReminder(Reminder reminder) {
    if (reminder.medicationTime != null) return reminder.medicationTime!;

    // Generated medication reminders historically stored the time 30 minutes
    // before the dose. Older manually-created reminders stored the dose time
    // directly, so preserve both formats during migration.
    if (reminder.id.startsWith('rem_')) {
      return reminder.reminderTime.add(
        const Duration(minutes: defaultLeadTimeMinutes),
      );
    }
    return reminder.reminderTime;
  }

  @visibleForTesting
  static int stableNotificationId(String value) {
    var hash = 0x811C9DC5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  /// Cancels every pending QuickMed alert linked to these medicine
  /// reminder records. Used when all medication schedules are deleted.
  static Future<void> cancelMedicationNotifications(
    Iterable<Reminder> reminders,
  ) async {
    final notifications = NotificationService();
    await notifications.init();
    for (final reminder in reminders) {
      await _cancelManagedAlerts(notifications, reminder.id);
    }
  }

  static Future<void> _cancelManagedAlerts(
    NotificationService notifications,
    String reminderId,
  ) async {
    for (final type in _managedAlertTypes) {
      await notifications.cancel(stableNotificationId('$reminderId:$type'));
    }
  }

  /// Retained for screens that need one recommendation rather than the full
  /// five-stage reminder sequence.
  @visibleForTesting
  static TravelEstimate proposeTransport(
    List<TravelEstimate> estimates, {
    required Duration timeAvailable,
  }) {
    if (estimates.isEmpty) {
      throw ArgumentError.value(estimates, 'estimates', 'Must not be empty');
    }

    const preference = <TravelMode>[
      TravelMode.walking,
      TravelMode.bicycling,
      TravelMode.transit,
      TravelMode.driving,
      TravelMode.twoWheeler,
    ];
    const arrivalBuffer = Duration(minutes: 5);

    for (final mode in preference) {
      final candidates = estimates.where((item) => item.mode == mode).toList()
        ..sort((a, b) => a.duration.compareTo(b.duration));
      if (candidates.isEmpty) continue;
      final candidate = candidates.first;
      if (candidate.duration + arrivalBuffer <= timeAvailable) {
        return candidate;
      }
    }

    final fastest = [...estimates]
      ..sort((a, b) => a.duration.compareTo(b.duration));
    return fastest.first;
  }

  @visibleForTesting
  static String proposedTravelNotificationLine(
    String destination,
    TravelEstimate estimate,
  ) {
    return '${estimate.mode.label}: ${estimate.durationText} to $destination';
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
      final proposed = proposeTransport(
        estimates,
        timeAvailable: const Duration(minutes: defaultLeadTimeMinutes),
      );
      return proposedTravelNotificationLine(destination.name, proposed);
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

class MedicationTravelAlert {
  const MedicationTravelAlert({
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
  });

  final String destinationName;
  final List<TravelEstimate> estimates;
}
