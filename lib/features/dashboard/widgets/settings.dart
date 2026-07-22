// lib/features/dashboard/widgets/settings_sheet.dart

import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

class Settings extends StatelessWidget {
  final String username;
  // Wire these up to your real data source / auth service.
  final String email;
  final String bloodGroup;
  final int activeMedicationsCount;
  final VoidCallback onViewFullProfile;
  final VoidCallback onTriggerTestNotifications;
  final VoidCallback onSignOut;

  const Settings({
    super.key,
    required this.username,
    required this.email,
    required this.bloodGroup,
    required this.activeMedicationsCount,
    required this.onViewFullProfile,
    required this.onTriggerTestNotifications,
    required this.onSignOut,
  });

  static Future<void> show(
    BuildContext context, {
    required String username,
    required String email,
    required String bloodGroup,
    required int activeMedicationsCount,
    required VoidCallback onViewFullProfile,
    required VoidCallback onTriggerTestNotifications,
    required VoidCallback onSignOut,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Settings(
        username: username,
        email: email,
        bloodGroup: bloodGroup,
        activeMedicationsCount: activeMedicationsCount,
        onViewFullProfile: onViewFullProfile,
        onTriggerTestNotifications: onTriggerTestNotifications,
        onSignOut: onSignOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Profile summary row
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryTint,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : "?",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Quick health overview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _overviewStat(
                  icon: Icons.bloodtype_outlined,
                  label: "Blood Group",
                  value: bloodGroup,
                  color: AppColors.warning,
                ),
                Container(height: 34, width: 1, color: AppColors.border),
                _overviewStat(
                  icon: Icons.medication_outlined,
                  label: "Active Meds",
                  value: "$activeMedicationsCount",
                  color: AppColors.primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_outline_rounded, color: AppColors.primary),
            title: const Text("View full health profile"),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.pop(context);
              onViewFullProfile();
            },
          ),

          const Divider(height: 1),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.notification_important_outlined, color: AppColors.accent),
            title: const Text("Test Notifications (Next 60s)"),
            trailing: const Icon(Icons.play_arrow_rounded),
            onTap: () {
              Navigator.pop(context);
              onTriggerTestNotifications();
            },
          ),

          const Divider(height: 1),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text(
              "Sign out",
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(context);
              onSignOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _overviewStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}