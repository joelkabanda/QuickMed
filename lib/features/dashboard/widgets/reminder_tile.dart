// lib/features/dashboard/widgets/reminder_tile.dart

import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

class ReminderTile extends StatelessWidget {
  final String medicineName;
  final String dosage;
  final String time;
  final String status;
  final VoidCallback? onTap;

  const ReminderTile({
    super.key,
    required this.medicineName,
    required this.dosage,
    required this.time,
    required this.status,
    this.onTap,
  });

  Color get _statusColor {
    switch (status) {
      case "Completed":
      case "taken":
        return AppColors.success;
      case "Missed":
        return AppColors.danger;
      case "Skipped":
        return AppColors.textSecondary;
      case "Pending":
      default:
        return AppColors.warning;
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case "Completed":
      case "taken":
        return Icons.check_circle_outline;
      case "Missed":
        return Icons.cancel_outlined;
      case "Skipped":
        return Icons.skip_next_outlined;
      case "Pending":
      default:
        return Icons.access_time_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_statusIcon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicineName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "$dosage • $time",
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}