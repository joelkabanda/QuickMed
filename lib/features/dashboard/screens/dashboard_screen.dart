// lib/features/dashboard/screens/dashboard_screen.dart
//Widgets
import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../widgets/greeting_header.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/med_wallet.dart';
import '../widgets/reminder_tile.dart';
import '../widgets/section_title.dart';
import '../widgets/bottom_nav.dart';

//screens
import 'add_medication_screen.dart';
import 'add_reminder_screen.dart';
import 'location_picker_screen.dart';
import 'reminders_screen.dart';
import 'medications_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;

  // TODO: replace with the real signed-in user, e.g. from FirebaseAuth
  // or your AuthProvider — this is just a placeholder wiring point.
  final String _username = "Precious";
  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GreetingHeader(
                username: _username,
                onNotificationTap: () {},
              ),
              const SizedBox(height: 22),

              MedWalletCard(
                patientName: _username,
                nextMedicationName: "Amoxicillin",
                nextDoseTime: "2:00 PM",
                completedToday: 4,
                totalToday: 6,
              ),

              const SizedBox(height: 26),
              const SectionTitle(title: "Quick Actions"),
              const SizedBox(height: 16),

              // 3x2 grid, mirrors the wallet app's action layout
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 18,
                crossAxisSpacing: 8,
                children: [
                  DashboardActionTile(
                    label: "Track Routes",
                    icon: Icons.local_pharmacy_outlined,
                    color: AppColors.primary,
                    onTap: () => _navigateTo(const LocationPickerScreen()),
                  ),
                  DashboardActionTile(
                    label: "Medication\nSchedule",
                    icon: Icons.calendar_month_outlined,
                    color: AppColors.accent,
                    onTap: () => _navigateTo(const MedicationsScreen()),
                  ),
                  DashboardActionTile(
                    label: "Add\nMedication",
                    icon: Icons.medication_outlined,
                    color: AppColors.success,
                    onTap: () => _navigateTo(const AddMedicationScreen()),
                  ),
                  DashboardActionTile(
                    label: "Add\nReminder",
                    icon: Icons.alarm_add_outlined,
                    color: AppColors.warning,
                    onTap: () => _navigateTo(const AddReminderScreen()),
                  ),
                  DashboardActionTile(
                    label: "Refill\nTracker",
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.primaryDark,
                    onTap: () {},
                  ),
                  DashboardActionTile(
                    label: "My Health\nProfile",
                    icon: Icons.person_outline_rounded,
                    color: AppColors.primary,
                    onTap: () {},
                  ),
                ],
              ),

              const SizedBox(height: 26),
              const SectionTitle(title: "Upcoming Reminders"),
              const SizedBox(height: 12),

              const ReminderTile(
                medicineName: "Amoxicillin",
                dosage: "500mg",
                time: "08:00 AM",
                status: "Pending",
              ),
              const SizedBox(height: 10),
              const ReminderTile(
                medicineName: "Vitamin D",
                dosage: "1 tablet",
                time: "06:00 PM",
                status: "Completed",
              ),

              const SizedBox(height: 100), // clears the floating bottom nav
            ],
          ),
        ),
      ),
      bottomNavigationBar: MedBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        onScanTap: () {},
      ),
    );
  }
}
