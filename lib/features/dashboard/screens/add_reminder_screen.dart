import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickmed/constants/app_colors.dart';
import 'package:quickmed/models/reminder_model.dart';
import 'package:quickmed/services/database_service.dart';
import 'package:quickmed/services/location_service.dart';
import 'package:quickmed/services/notification_service.dart';

class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final TextEditingController _medicationIdController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _reminderTime;
  ReminderStatus _status = ReminderStatus.pending;
  bool _isSaving = false;

  Future<void> _selectReminderDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _reminderTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _saveReminder() async {
    if (_medicationIdController.text.isEmpty || _reminderTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Medication ID and reminder time are required')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final reminder = Reminder(
        id: id,
        userId: userId,
        medicationId: _medicationIdController.text.trim(),
        reminderTime: _reminderTime!,
        status: _status,
        notificationId: null,
        isNotificationSent: false,
        createdAt: DateTime.now(),
      );

      // Save to Firestore first
      await DatabaseService().saveReminder(reminder);

      final notificationDate = await _calculateTravelAlarmTime(reminder);

      // Schedule local notification based on travel time or reminder time.
      try {
        if (notificationDate.isAfter(DateTime.now())) {
          final notifId = id.hashCode & 0x7fffffff;
          await NotificationService().scheduleNotification(
            id: notifId,
            title: 'Medication reminder',
            body: _notesController.text.isNotEmpty
                ? _notesController.text
                : 'Time to take your medication',
            scheduledDate: notificationDate,
          );

          // update reminder with notification id
          final updated = reminder.copyWith(notificationId: notifId.toString());
          await DatabaseService().saveReminder(updated);
        }
      } catch (e) {
        // scheduling failed - continue silently
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving reminder: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<DateTime> _calculateTravelAlarmTime(Reminder reminder) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return reminder.reminderTime;

      final savedLocation = await DatabaseService().getSavedPharmacyLocation(userId);
      if (savedLocation == null) return reminder.reminderTime;

      final position = await LocationService.getCurrentLocation();
      final distanceKm = LocationService.calculateDistance(
        position.latitude,
        position.longitude,
        savedLocation.latitude,
        savedLocation.longitude,
      );

      final travelMinutes = LocationService.calculateEstimatedTimeMinutes(distanceKm);
      final bufferMinutes = 10; // give extra time for traffic and delays
      final travelAlarmTime = reminder.reminderTime.subtract(Duration(minutes: travelMinutes + bufferMinutes));

      if (travelAlarmTime.isBefore(DateTime.now())) {
        return DateTime.now().add(const Duration(seconds: 10));
      }
      return travelAlarmTime;
    } catch (e) {
      return reminder.reminderTime;
    }
  }

  @override
  void dispose() {
    _medicationIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    NotificationService().init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title:
            const Text('Add Reminder', style: TextStyle(color: Colors.black87)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Medication ID',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _medicationIdController,
              decoration: InputDecoration(
                hintText: 'Enter medication ID',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Reminder Time',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectReminderDateTime(context),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  color: AppColors.surface,
                ),
                child: Text(
                  _reminderTime != null
                      ? '${_reminderTime!.year}-${_reminderTime!.month.toString().padLeft(2, '0')}-${_reminderTime!.day.toString().padLeft(2, '0')} ${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
                      : 'Select reminder date and time',
                  style: TextStyle(
                    color: _reminderTime != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<ReminderStatus>(
              initialValue: _status,
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: AppColors.surface,
              ),
              items: ReminderStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.name.replaceFirst(
                      status.name[0], status.name[0].toUpperCase())),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _status = value;
                  });
                }
              },
            ),
            const SizedBox(height: 20),
            const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Optional reminder notes',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveReminder,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save Reminder',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
