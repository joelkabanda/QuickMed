// lib/features/dashboard/widgets/dashboard_home_content.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../authentication/screens/login_screen.dart';
import '../../../constants/app_colors.dart';
import 'greeting_header.dart';
import 'quick_action_card.dart';
import 'med_wallet.dart';
import 'reminder_tile.dart';
import 'section_title.dart';
import '../widgets/settings.dart';

import '../screens/add_medication_screen.dart';
import '../screens/add_reminder_screen.dart';
import '../screens/location_picker_screen.dart';
import '../screens/medications_screen.dart';
import '../screens/health_profile_screen.dart';

class DashboardHomeContent extends StatelessWidget {
  const DashboardHomeContent({super.key});

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  String get _username {
    final user = _currentUser;
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      return user.displayName!.split(' ').first;
    }
    if (user?.email != null) {
      return user!.email!.split('@').first;
    }
    return "there";
  }

  String get _email => _currentUser?.email ?? "No email on file";

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GreetingHeader(
            username: _username,
            onSettingsTap: () => Settings.show(
              context,
              username: _username,
              email: _email,
              bloodGroup: "O+", // TODO: pull from health profile data
              activeMedicationsCount: 6, // TODO: wire to real medications source
              onViewFullProfile: () =>
                  _navigateTo(context, const HealthProfileScreen()),
              onTriggerTestNotifications: () {
                // TODO: fire an actual test notification
              },
              onSignOut: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
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
                onTap: () =>
                    _navigateTo(context, const LocationPickerScreen()),
              ),
              DashboardActionTile(
                label: "Medication\nSchedule",
                icon: Icons.calendar_month_outlined,
                color: AppColors.accent,
                onTap: () => _navigateTo(context, const MedicationsScreen()),
              ),
              DashboardActionTile(
                label: "Add\nMedication",
                icon: Icons.medication_outlined,
                color: AppColors.success,
                onTap: () =>
                    _navigateTo(context, const AddMedicationScreen()),
              ),
              DashboardActionTile(
                label: "Add\nReminder",
                icon: Icons.alarm_add_outlined,
                color: AppColors.warning,
                onTap: () => _navigateTo(context, const AddReminderScreen()),
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
                onTap: () =>
                    _navigateTo(context, const HealthProfileScreen()),
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

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}