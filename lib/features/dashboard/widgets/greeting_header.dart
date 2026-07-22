// lib/features/dashboard/widgets/greeting_header.dart

import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../utils/greeting_utils.dart';

class GreetingHeader extends StatelessWidget {
  /// Pass the signed-in user's display name / username here —
  /// e.g. FirebaseAuth.instance.currentUser?.displayName,
  /// or a value pulled from your UserProvider / AuthController.
  final String username;
  final VoidCallback? onSettingsTap;

  const GreetingHeader({
    super.key,
    required this.username,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final greeting = GreetingUtils.getGreeting();
    final emoji = GreetingUtils.getGreetingEmoji();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$greeting, $username $emoji",
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                "Let's keep your health on track today",
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: onSettingsTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.settings_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    height: 8,
                    width: 8,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}