import 'package:flutter_test/flutter_test.dart';
import 'package:quickmed/models/medication_model.dart';
import 'package:quickmed/services/google_routes_service.dart';
import 'package:quickmed/services/reminder_service.dart';

void main() {
  test('builds reminders 30 minutes before medication times', () {
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
      createdAt: DateTime(2026, 1, 1),
      startDate: DateTime(2026, 1, 1),
    );

    final reminders = ReminderService.buildRemindersForMedication(
      userId: 'user-1',
      medication: medication,
      startDate: DateTime(2026, 8, 1),
      daysCount: 1,
    );

    expect(reminders, hasLength(2));
    expect(reminders.first.reminderTime, DateTime(2026, 8, 1, 7, 30));
    expect(reminders.last.reminderTime, DateTime(2026, 8, 1, 20));
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
}
