import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';

import '../widgets/greeting_header.dart';
import '../widgets/hero_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/reminder_tile.dart';
import '../widgets/section_title.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GreetingHeader(),
              const SizedBox(height: 20),
              const HeroCard(),
              const SizedBox(height: 24),
              const SectionTitle(
                title: "Overview",
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: "Active Medications",
                      value: "6",
                      icon: Icons.medication_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: "Today's Reminders",
                      value: "3",
                      icon: Icons.notifications_none,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                title: "Quick Actions",
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: QuickActionCard(
                      title: "Add Medicine",
                      icon: Icons.add_circle_outline,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: QuickActionCard(
                      title: "Scan Prescription",
                      icon: Icons.document_scanner_outlined,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                title: "Upcoming Reminders",
              ),
              const SizedBox(height: 12),
              ReminderTile(
                medicineName: "Amoxicillin",
                dosage: "500mg",
                time: "08:00 AM",
                status: "Pending",
              ),
              const SizedBox(height: 10),
              ReminderTile(
                medicineName: "Vitamin D",
                dosage: "1 tablet",
                time: "06:00 PM",
                status: "Completed",
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
