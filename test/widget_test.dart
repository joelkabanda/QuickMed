import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickmed/features/dashboard/widgets/medication_schedule_card.dart';

void main() {
  testWidgets('Medication schedule card shows dose times and dosage', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MedicationScheduleCard(
            frequency: 'Twice daily',
            scheduleTimes: ['08:00', '20:00'],
            dosage: '500 mg',
          ),
        ),
      ),
    );

    expect(find.text('Medicine Schedule'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('500 mg'), findsNWidgets(2));
  });
}
