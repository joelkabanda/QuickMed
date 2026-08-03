import 'package:flutter_test/flutter_test.dart';
import 'package:quickmed/models/medication_model.dart';
import 'package:quickmed/models/reminder_model.dart';
import 'package:quickmed/services/google_routes_service.dart';
import 'package:quickmed/services/reminder_service.dart';

void main() {
  test('stores reminder records at the actual medicine times', () {
    final medication = Medication(
      id: 'med-1',
      userId: 'user-1',
      name: 'Paracetamol',
      type: 'Tablet',
      dosage: '500mg',
      frequency: 'Twice daily',
      scheduleTimes: ['08:00', '20:30'],
      reminderTimes: const [],
      isActive: true,
      createdAt: DateTime(2098, 1, 1),
      startDate: DateTime(2098, 1, 1),
    );

    final reminders = ReminderService.buildRemindersForMedication(
      userId: 'user-1',
      medication: medication,
      startDate: DateTime(2099, 8, 1),
      daysCount: 1,
    );

    expect(reminders, hasLength(2));
    expect(reminders.first.reminderTime, DateTime(2099, 8, 1, 8));
    expect(reminders.first.medicationTime, DateTime(2099, 8, 1, 8));
    expect(reminders.last.reminderTime, DateTime(2099, 8, 1, 20, 30));
    expect(reminders.last.medicationTime, DateTime(2099, 8, 1, 20, 30));
  });

  test('creates the requested ordered five-stage route reminder sequence', () {
    const estimates = <TravelEstimate>[
      TravelEstimate(
        mode: TravelMode.walking,
        duration: Duration(minutes: 60),
        distanceMeters: 5000,
      ),
      TravelEstimate(
        mode: TravelMode.driving,
        duration: Duration(minutes: 20),
        distanceMeters: 6400,
      ),
      TravelEstimate(
        mode: TravelMode.twoWheeler,
        duration: Duration(minutes: 10),
        distanceMeters: 6100,
      ),
    ];

    final medicationTime = DateTime(2099, 8, 1, 12);
    final alerts = ReminderService.buildTravelReminderAlerts(
      medicationTime: medicationTime,
      medicationName: 'Paracetamol',
      medicationDosage: '500mg',
      destinationName: 'City Pharmacy',
      estimates: estimates,
      now: DateTime(2099, 8, 1, 8),
    );

    expect(alerts, hasLength(5));
    expect(
      alerts.map((item) => item.type).toList(),
      <String>[
        'prepare_slowest',
        'prepare_fastest',
        'leave_slowest',
        'leave_fastest',
        'dose',
      ],
    );
    expect(alerts[0].time, DateTime(2099, 8, 1, 10, 30));
    expect(alerts[1].time, DateTime(2099, 8, 1, 10, 59));
    expect(alerts[2].time, DateTime(2099, 8, 1, 11));
    expect(alerts[3].time, DateTime(2099, 8, 1, 11, 50));
    expect(alerts[4].time, medicationTime);

    expect(alerts[0].title, 'Prepare to walk for your medicine');
    expect(alerts[0].body, contains('finish what you are doing now'));
    expect(alerts[0].body, contains('Walking'));
    expect(alerts[1].body, contains('Boda'));
    expect(alerts[2].title, 'Start walking now');
    expect(alerts[3].body, contains('Leave now using Boda'));
    expect(alerts[4].body, contains('Paracetamol (500mg) is due now'));
  });

  test('uses walking as the slow option even if another mode is longer', () {
    const estimates = <TravelEstimate>[
      TravelEstimate(
        mode: TravelMode.walking,
        duration: Duration(minutes: 45),
        distanceMeters: 3600,
      ),
      TravelEstimate(
        mode: TravelMode.transit,
        duration: Duration(minutes: 55),
        distanceMeters: 8200,
      ),
      TravelEstimate(
        mode: TravelMode.driving,
        duration: Duration(minutes: 12),
        distanceMeters: 5100,
      ),
    ];

    final alerts = ReminderService.buildTravelReminderAlerts(
      medicationTime: DateTime(2099, 8, 1, 12),
      medicationName: 'Medicine',
      medicationDosage: '1 tablet',
      destinationName: 'Pharmacy',
      estimates: estimates,
      now: DateTime(2099, 8, 1, 8),
    );

    expect(alerts.first.type, 'prepare_slowest');
    expect(alerts.first.title, 'Prepare to walk for your medicine');
    expect(alerts.first.time, DateTime(2099, 8, 1, 10, 45));
  });

  test('uses one preparation and one departure alert when boundaries match', () {
    const estimates = <TravelEstimate>[
      TravelEstimate(
        mode: TravelMode.driving,
        duration: Duration(minutes: 15),
        distanceMeters: 4000,
      ),
    ];

    final alerts = ReminderService.buildTravelReminderAlerts(
      medicationTime: DateTime(2099, 8, 1, 12),
      medicationName: 'Medicine',
      medicationDosage: '1 tablet',
      destinationName: 'Pharmacy',
      estimates: estimates,
      now: DateTime(2099, 8, 1, 8),
    );

    expect(
      alerts.map((item) => item.type).toList(),
      <String>['prepare_slowest', 'leave_slowest', 'dose'],
    );
  });

  test('reads explicit medication time from a reminder', () {
    final reminder = Reminder(
      id: 'r1',
      userId: 'u1',
      medicationId: 'm1',
      reminderTime: DateTime(2099, 8, 1, 9, 30),
      medicationTime: DateTime(2099, 8, 1, 11),
      status: ReminderStatus.pending,
      isNotificationSent: false,
      createdAt: DateTime(2099, 7, 1),
    );

    expect(
      ReminderService.medicationTimeForReminder(reminder),
      DateTime(2099, 8, 1, 11),
    );
  });

  test('formats multi-mode travel estimates for notification body', () {
    const estimates = [
      TravelEstimate(
        mode: TravelMode.driving,
        duration: Duration(minutes: 18),
        distanceMeters: 7400,
      ),
      TravelEstimate(
        mode: TravelMode.walking,
        duration: Duration(minutes: 72),
        distanceMeters: 5100,
      ),
    ];

    expect(
      ReminderService.formatRouteSummary('City Pharmacy', estimates),
      'Destination: City Pharmacy\nTime to reach by:\nDriving: 18 min\nWalking: 1 hr 12 min',
    );
  });

  test('stable notification IDs are repeatable and positive', () {
    final first = ReminderService.stableNotificationId(
      'reminder-1:leave_fastest',
    );
    final second = ReminderService.stableNotificationId(
      'reminder-1:leave_fastest',
    );

    expect(first, second);
    expect(first, greaterThanOrEqualTo(0));
  });
}
