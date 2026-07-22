// lib/features/dashboard/screens/dashboard_screen.dart
//Widgets
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../authentication/screens/login_screen.dart';
import '../../../constants/app_colors.dart';
import '../widgets/greeting_header.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/med_wallet.dart';
import '../widgets/reminder_tile.dart';
import '../widgets/section_title.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/settings.dart';

//screens
import 'add_medication_screen.dart';
import 'add_reminder_screen.dart';
import 'location_picker_screen.dart';
import 'reminders_screen.dart';
import 'medications_screen.dart';
import 'health_profile_screen.dart';
import '../../../services/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  String get _username {
    final user = _currentUser;
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      return user.displayName!.split(' ').first; // first name only
    }
    if (user?.email != null) {
      return user!.email!.split('@').first; // fallback: local part of email
    }
    return "there";
  }

  String get _email => _currentUser?.email ?? "No email on file";

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _triggerTestNotifications() async {
    debugPrint("DashboardScreen: _triggerTestNotifications called");
    try {
      final service = NotificationService();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Testing: Initializing and scheduling...'),
          duration: Duration(seconds: 4),
        ),
      );

      await service.init(); // Ensure permissions are requested and timezone is set
      debugPrint("DashboardScreen: Service init finished");
      
      final now = DateTime.now();

      // 1. Immediate Notification
      debugPrint("DashboardScreen: Sending immediate notification");
      await service.showNotification(
        id: 999,
        title: 'QuickMed Active!',
        body: 'Notifications are working! Scheduled ones will follow.',
      );

      // 2. Scheduled Notifications
      debugPrint("DashboardScreen: Scheduling 5 notifications...");
      for (int i = 1; i <= 5; i++) {
        await service.scheduleNotification(
          id: 1000 + i,
          title: 'Scheduled Test #$i',
          body: 'Reminder $i of 5. The app is working in the background!',
          scheduledDate: now.add(Duration(seconds: i * 10)),
        );
      }
      debugPrint("DashboardScreen: All test notifications scheduled");
    } catch (e) {
      debugPrint("DashboardScreen ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test failed: $e')),
        );
      }
    }
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
              // only the changed pieces

              GreetingHeader(
                username: _username,
                onSettingsTap: () => Settings.show(
                  context,
                  username: _username,
                  email: _email,
                  bloodGroup: "O+", // TODO: pull from health profile data
                  activeMedicationsCount:
                      6, // TODO: pull from medications state
                  onViewFullProfile: () =>
                      _navigateTo(const HealthProfileScreen()),
                  onTriggerTestNotifications: _triggerTestNotifications,
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
                    onTap: () => _navigateTo(const HealthProfileScreen()),
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
