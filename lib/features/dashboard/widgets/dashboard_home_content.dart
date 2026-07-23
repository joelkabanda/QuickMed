// lib/features/dashboard/widgets/dashboard_home_content.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../authentication/screens/login_screen.dart';
import '../../../constants/app_colors.dart';
import '../../../models/reminder_model.dart';
import '../../../models/medication_model.dart';
import '../../../services/database_service.dart';
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

  String _statusLabel(ReminderStatus status) {
    switch (status) {
      case ReminderStatus.taken:
        return "Completed";
      case ReminderStatus.missed:
        return "Missed";
      case ReminderStatus.skipped:
        return "Skipped";
      case ReminderStatus.pending:
        return "Pending";
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final userId = _currentUser?.uid;
    final dbService = DatabaseService();

    if (userId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Sign in to see your dashboard.",
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return StreamBuilder<List<Medication>>(
      stream: dbService.streamUserMedications(userId),
      builder: (context, medSnapshot) {
        final medications = medSnapshot.data ?? <Medication>[];
        final medById = <String, Medication>{
          for (final m in medications) m.id: m,
        };
        final activeMedicationsCount =
            medications.where((m) => m.isActive).length;

        return StreamBuilder<List<Reminder>>(
          stream: dbService.streamUserReminders(userId),
          builder: (context, remSnapshot) {
            final now = DateTime.now();
            final allReminders = remSnapshot.data ?? <Reminder>[];

            // Today's reminders drive the wallet card.
            final todaysReminders =
                allReminders.where((r) => _isSameDay(r.reminderTime, now)).toList();
            final completedToday =
                todaysReminders.where((r) => r.status == ReminderStatus.taken).length;
            final totalToday = todaysReminders.length;

            // Next upcoming pending reminder, for the wallet card headline.
            final upcomingPending = allReminders
                .where((r) =>
                    r.status == ReminderStatus.pending &&
                    r.reminderTime.isAfter(now))
                .toList()
              ..sort((a, b) => a.reminderTime.compareTo(b.reminderTime));

            final nextReminder = upcomingPending.isNotEmpty ? upcomingPending.first : null;
            final nextMedName = nextReminder != null
                ? (medById[nextReminder.medicationId]?.name ?? "Medication")
                : "No upcoming doses";
            final nextDoseTime =
                nextReminder != null ? _formatTime(nextReminder.reminderTime) : "--";

            // Preview list: soonest 3 upcoming reminders overall (any status).
            final upcoming = allReminders
                .where((r) => r.reminderTime.isAfter(now))
                .toList()
              ..sort((a, b) => a.reminderTime.compareTo(b.reminderTime));
            final preview = upcoming.take(3).toList();

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
                      activeMedicationsCount: activeMedicationsCount,
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
                    nextMedicationName: nextMedName,
                    nextDoseTime: nextDoseTime,
                    completedToday: completedToday,
                    totalToday: totalToday,
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
                        onTap: () =>
                            _navigateTo(context, const MedicationsScreen()),
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
                        onTap: () =>
                            _navigateTo(context, const AddReminderScreen()),
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

                  if (remSnapshot.connectionState == ConnectionState.waiting &&
                      !remSnapshot.hasData)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (remSnapshot.hasError)
                    Text(
                      "Couldn't load reminders.",
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  else if (preview.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        "No upcoming reminders. You're all caught up.",
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (final reminder in preview) ...[
                          ReminderTile(
                            medicineName:
                                medById[reminder.medicationId]?.name ??
                                    "Medication",
                            dosage: medById[reminder.medicationId]?.dosage ?? "",
                            time: _formatTime(reminder.reminderTime),
                            status: _statusLabel(reminder.status),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),

                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        );
      },
    );
  }
}