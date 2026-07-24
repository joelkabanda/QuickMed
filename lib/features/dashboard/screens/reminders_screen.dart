import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:quickmed/constants/app_colors.dart';
import 'package:quickmed/models/reminder_model.dart';
import 'package:quickmed/services/database_service.dart';
import 'package:quickmed/services/notification_service.dart';
import 'package:quickmed/services/location_service.dart';
import 'package:quickmed/routes/app_routes.dart';
import 'package:intl/intl.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late DatabaseService _dbService;
  late Stream<List<Reminder>> _remindersStream;
  final Set<String> _notifiedReminders = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _dbService = DatabaseService();
    _loadReminders();
    NotificationService().init();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadReminders() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _remindersStream = _dbService.streamUserReminders(userId);
    } else {
      _remindersStream = Stream.error('User not authenticated');
    }
  }

  Future<void> _deleteReminder(String reminderId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('Are you sure you want to remove this reminder?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbService.deleteReminder(userId, reminderId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  String _getReminderTitle(Reminder reminder) {
    if (reminder.notes != null && reminder.notes!.contains('Scheduled for')) {
      final match = RegExp(r'Scheduled for (.+) at').firstMatch(reminder.notes!);
      if (match != null) return match.group(1)!.trim();
    }
    return 'Medication Reminder';
  }

  Widget _buildReminderCard(Reminder reminder) {
    final now = DateTime.now();
    final isOverdue = reminder.reminderTime.isBefore(now) && reminder.status == ReminderStatus.pending;
    final isTaken = reminder.status == ReminderStatus.taken;

    Color statusColor = AppColors.primary;
    String statusLabel = "Upcoming";

    if (isTaken) {
      statusColor = AppColors.success;
      statusLabel = "Taken";
    } else if (isOverdue) {
      statusColor = AppColors.danger;
      statusLabel = "Missed";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _getReminderTitle(reminder),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          _buildStatusBadge(statusLabel, statusColor),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('EEEE, MMM d • h:mm a').format(reminder.reminderTime),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (reminder.notes?.isNotEmpty == true && !reminder.notes!.contains('Scheduled for')) ...[
                        const SizedBox(height: 10),
                        Text(
                          reminder.notes!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 22),
                onPressed: () => _deleteReminder(reminder.id),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _maybeTriggerLocationNotifications(List<Reminder> reminders) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      final savedLocation = await DatabaseService().getSavedPharmacyLocation(userId);
      if (savedLocation == null) return;
      final position = await LocationService.getCurrentLocation();
      final distanceKm = LocationService.calculateDistance(position.latitude, position.longitude, savedLocation.latitude, savedLocation.longitude);
      if (distanceKm <= 1.5) {
        final upcoming = reminders.where((r) => r.reminderTime.isAfter(DateTime.now()));
        for (final r in upcoming) {
          if (_notifiedReminders.contains(r.id)) continue;
          await NotificationService().showNotification(
            id: r.id.hashCode & 0x7fffffff,
            title: _getReminderTitle(r),
            body: r.notes ?? 'Time to take your medication',
          );
          _notifiedReminders.add(r.id);
        }
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Health Reminders',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.addReminder),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Reminder>>(
        stream: _remindersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reminders = snapshot.data ?? [];
          _maybeTriggerLocationNotifications(reminders);

          if (reminders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text('No reminders yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          reminders.sort((a, b) => b.reminderTime.compareTo(a.reminderTime));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 20),
            itemCount: reminders.length,
            itemBuilder: (context, index) => _buildReminderCard(reminders[index]),
          );
        },
      ),
    );
  }
}
