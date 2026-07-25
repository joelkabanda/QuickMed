import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../models/app_notification_model.dart';
import '../../../services/database_service.dart';
import '../../../utils/greeting_utils.dart';

class GreetingHeader extends StatelessWidget {
  final String username;
  final VoidCallback? onNotificationsTap;

  const GreetingHeader({
    super.key,
    required this.username,
    this.onNotificationsTap,
  });

  @override
  Widget build(BuildContext context) {
    final greeting = GreetingUtils.getGreeting();
    final emoji = GreetingUtils.getGreetingEmoji();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$greeting, $username $emoji', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, letterSpacing: -.3), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text("Let's keep your health on track today", style: TextStyle(fontSize: 13.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        StreamBuilder<List<AppNotificationRecord>>(
          stream: uid == null ? null : DatabaseService().streamAppNotifications(uid),
          builder: (context, snapshot) {
            final now = DateTime.now();
            final count = (snapshot.data ?? const <AppNotificationRecord>[])
                .where((item) => !item.scheduledAt.isAfter(now))
                .length;
            return InkWell(
              onTap: onNotificationsTap,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 48,
                width: 48,
                decoration: const BoxDecoration(color: AppColors.primaryTint, shape: BoxShape.circle),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_none_rounded, color: AppColors.primary, size: 25),
                    if (count > 0)
                      Positioned(
                        top: -2,
                        right: -3,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 21, minHeight: 21),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2)),
                          child: Text(count > 99 ? '99+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
