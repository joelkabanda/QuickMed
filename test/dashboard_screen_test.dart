import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickmed/features/dashboard/screens/dashboard_screen.dart';

void main() {
  testWidgets('Dashboard screen shows summary and doughnut chart', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));

    expect(find.text('QuickMed Dashboard'), findsOneWidget);
    expect(find.text('Medication Progress'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
