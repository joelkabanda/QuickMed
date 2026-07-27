import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quickmed/constants/app_colors.dart';
import 'package:quickmed/models/app_notification_model.dart';
import 'package:quickmed/services/database_service.dart';

class AppNotificationsScreen extends StatefulWidget {
  const AppNotificationsScreen({super.key});
  @override
  State<AppNotificationsScreen> createState() => _AppNotificationsScreenState();
}

class _AppNotificationsScreenState extends State<AppNotificationsScreen> {
  Timer? _timer;
  final _database = DatabaseService();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _delete(String uid, AppNotificationRecord item) async {
    await _database.deleteAppNotification(uid, item.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted')),
      );
    }
  }

  Color _cardColor(BuildContext context, String title) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lower = title.toLowerCase();
    if (lower.contains('quick') || lower.contains('move')) {
      return dark ? const Color(0xFF332D1C) : const Color(0xFFFFF2CD);
    }
    if (lower.contains('time') || lower.contains('medicine')) {
      return dark ? const Color(0xFF17352F) : const Color(0xFFDFF7EF);
    }
    return dark ? const Color(0xFF172A45) : const Color(0xFFE6F1FF);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: uid == null
          ? const Center(child: Text('Sign in to view notifications.'))
          : StreamBuilder<List<AppNotificationRecord>>(
              stream: _database.streamAppNotifications(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final now = DateTime.now();
                final items = (snapshot.data ?? const <AppNotificationRecord>[])
                    .where((item) => !item.scheduledAt.isAfter(now))
                    .toList();
                if (items.isEmpty) {
                  return const Center(child: Text('No received app notifications yet.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete notification?'),
                          content: const Text('This notification will be removed from your app history.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                          ],
                        ),
                      ),
                      onDismissed: (_) => _delete(uid, item),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 30),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _cardColor(context, item.title),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(.18)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppColors.primary.withOpacity(.13), shape: BoxShape.circle),
                              child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 7),
                                  Text(item.body, style: const TextStyle(fontSize: 14.5, height: 1.48, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 10),
                                  Text(DateFormat('EEE, MMM d • h:mm a').format(item.scheduledAt), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            IconButton(tooltip: 'Delete', onPressed: () => _delete(uid, item), icon: const Icon(Icons.delete_outline_rounded)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
