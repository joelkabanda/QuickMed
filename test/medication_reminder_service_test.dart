import 'package:flutter_test/flutter_test.dart';
import 'package:quickmed/models/medication_model.dart';
import 'package:quickmed/services/reminder_service.dart';

void main() {
  test('builds reminder entries from medication schedule times', () {
    final medication = Medication(
      id: 'med-1',
      userId: 'user-1',
      name: 'Paracetamol',
      type: 'Tablet',
      dosage: '500mg',
      frequency: 'Twice daily',
      scheduleTimes: ['08:00', '20:30'],
      reminderTimes: [],
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      startDate: DateTime(2026, 1, 1),
    );

    final reminders = ReminderService.buildRemindersForMedication(
      userId: 'user-1',
      medication: medication,
    );

    expect(reminders.length, 2);
    expect(reminders.first.reminderTime.hour, 8);
    expect(reminders.first.reminderTime.minute, 0);
    expect(reminders.last.reminderTime.hour, 20);
    expect(reminders.last.reminderTime.minute, 30);
  });

  test('uses a larger lead time when the user is away from the saved location', () {
    final leadTime = ReminderService.estimateLeadTimeMinutes(distanceKm: 3.2);
    expect(leadTime, 60);
  });
}
