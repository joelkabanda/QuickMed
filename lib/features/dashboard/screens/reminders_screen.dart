import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:quickmed/constants/app_colors.dart';
import 'package:quickmed/models/reminder_model.dart';
import 'package:quickmed/services/database_service.dart';
import 'package:quickmed/services/notification_service.dart';
import 'package:quickmed/services/location_service.dart';
import 'package:quickmed/routes/app_routes.dart';

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
    // Periodically refresh UI so time-until labels update in real-time
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

    try {
      // Cancel any scheduled notification for this reminder
      try {
        final notifId = reminderId.hashCode & 0x7fffffff;
        await NotificationService().cancel(notifId);
      } catch (e) {
        // ignore
      }

      await _dbService.deleteReminder(userId, reminderId);
      if (mounted) {
        setState(() {
          _loadReminders();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting reminder: $e')),
        );
      }
    }
  }

  String _getReminderTitle(Reminder reminder) {
    final note = reminder.notes ?? '';
    final match = RegExp(r'Scheduled for (.+) at').firstMatch(note);
    return match?.group(1)?.trim() ?? 'Medication reminder';
  }

  Widget _buildReminderCard(Reminder reminder) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.notifications_active,
                      color: AppColors.success),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getReminderTitle(reminder),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reminder.notes?.isNotEmpty == true
                            ? reminder.notes!
                            : 'No additional notes',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteReminder(reminder.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildInfoChip('Time', _timeUntilText(reminder.reminderTime),
                    AppColors.primary),
                _buildInfoChip(
                    'Status', reminder.status.name, AppColors.success),
                _buildInfoChip('Created', _formatDateTime(reminder.createdAt),
                    AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Chip(
      backgroundColor: color.withValues(alpha: 0.14),
      label: Text(
        '$label: $value',
        style: TextStyle(
          color: color.computeLuminance() > 0.5
              ? AppColors.textPrimary
              : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _timeUntilText(DateTime dateTime) {
    final diff = dateTime.difference(DateTime.now());
    if (diff.inSeconds <= 0) return 'Now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  Future<void> _maybeTriggerLocationNotifications(List<Reminder> reminders) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final savedLocation = await DatabaseService().getSavedPharmacyLocation(userId);
      if (savedLocation == null) return;

      final position = await LocationService.getCurrentLocation();
      final distanceKm = LocationService.calculateDistance(
        position.latitude,
        position.longitude,
        savedLocation.latitude,
        savedLocation.longitude,
      );

      // Trigger when within 1.5 km
      const triggerDistanceKm = 1.5;

      if (distanceKm <= triggerDistanceKm) {
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
    } catch (e) {
      // ignore - non-critical
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reminders'),
        centerTitle: false,
        surfaceTintColor: AppColors.surface,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed(AppRoutes.addReminder).then((value) {
            if (value == true) {
              setState(() {
                _loadReminders();
              });
            }
          });
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Reminder>>(
        stream: _remindersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Unable to load reminders. ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final reminders = snapshot.data ?? [];

          // Try to trigger location-based notifications for nearby reminders.
          _maybeTriggerLocationNotifications(reminders);

          if (reminders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off,
                        size: 64, color: AppColors.textSecondary),
                    const SizedBox(height: 24),
                    const Text(
                      'No reminders yet',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create reminders to stay on top of your medications.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context)
                            .pushNamed(AppRoutes.addReminder)
                            .then((value) {
                          if (value == true) {
                            setState(() {
                              _loadReminders();
                            });
                          }
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Reminder'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final upcomingReminders = reminders
              .where(
                  (reminder) => reminder.reminderTime.isAfter(DateTime.now()))
              .toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 100, top: 16),
            children: [
              if (upcomingReminders.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppColors.success),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${upcomingReminders.length} upcoming reminders are scheduled soon. Keep your medication plan on track.',
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ...reminders
                  .map((reminder) => _buildReminderCard(reminder))
                  ,
            ],
          );
        },
      ),
    );
  }
}
