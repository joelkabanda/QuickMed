import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickmed/features/dashboard/widgets/medication_schedule_card.dart';

void main() {
  testWidgets('Empty medicine schedule has a clear empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MedicationScheduleCard(
            frequency: 'As directed',
            scheduleTimes: [],
            dosage: '',
          ),
        ),
      ),
    );

    expect(
      find.text('No times set for this medication.'),
      findsOneWidget,
    );
    expect(find.byType(MedicationScheduleCard), findsOneWidget);
  });
}
