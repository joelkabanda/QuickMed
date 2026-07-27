// lib/features/dashboard/screens/dashboard_screen.dart
//Widgets
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../authentication/screens/login_screen.dart';
import '../../../constants/app_colors.dart';
import '../widgets/greeting_header.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/med_wallet.dart';
import '../widgets/reminder_tile.dart';
import '../widgets/section_title.dart';
import '../widgets/bottom_nav.dart';

//screens
import 'add_medication_screen.dart';
import 'add_reminder_screen.dart';
import 'reminders_screen.dart';
import 'app_notifications_screen.dart';
import 'location_picker_screen.dart';
import 'location_comparison_map_view.dart';
import 'medications_screen.dart';
import 'credentials_screen.dart';
import 'health_profile_screen.dart';
import '../../../models/medication_model.dart';
import '../../../models/reminder_model.dart';
import '../../../models/user_profile_model.dart';
import '../../../services/database_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/location_service.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;
  late DatabaseService _dbService;
  Stream<List<Medication>>? _medicationsStream;
  Stream<List<Reminder>>? _remindersStream;
  Stream<SavedPharmacyLocation?>? _locationStream;
  Timer? _refreshTimer;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  String get _username {
    final user = _currentUser;
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      return user.displayName!.split(' ').first; // first name only
    }
    if (user?.email != null) {
      return user!.email!.split('@').first; // fallback: local part of email
    }
    return "there";
  }

  String get _email => _currentUser?.email ?? "No email on file";

  bool _showPermissionWarning = false;

  @override
  void initState() {
    super.initState();
    _dbService = DatabaseService();
    _loadData();
    _checkPermissions();

    // Auto-update dashboard every minute to refresh "Next Dose" based on current time
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadData() {
    final userId = _currentUser?.uid;
    if (userId != null) {
      _medicationsStream = _dbService.streamUserMedications(userId);
      _remindersStream = _dbService.streamUserReminders(userId);
      _locationStream = _dbService.streamSavedPharmacyLocation(userId);
      _checkAndSetupLocation();
    }
  }

  Future<void> _checkAndSetupLocation() async {
    final userId = _currentUser?.uid;
    if (userId == null) return;

    final savedLocation = await _dbService.getSavedPharmacyLocation(userId);
    if (savedLocation == null && mounted) {
      // If no location saved, we can offer to capture it now
      _showLocationSetupPrompt();
    }
  }

  void _showLocationSetupPrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 34),
          title: const Text('Set your default destination'),
          content: const Text(
            'QuickMed can capture your current coordinates and save them as the destination used for medication travel reminders.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'later'), child: const Text('Later')),
            TextButton(onPressed: () => Navigator.pop(context, 'map'), child: const Text('Choose on map')),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'current'),
              icon: const Icon(Icons.gps_fixed_rounded),
              label: const Text('Use current location'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == 'current') {
        await _captureCurrentLocationAsDestination();
      } else if (choice == 'map') {
        await _chooseDestinationOnMap();
      }
    });
  }

  Future<void> _captureCurrentLocationAsDestination() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Capturing your current location…')),
        );
      }
      final position = await LocationService.getCurrentLocation();
      final address = await LocationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save these coordinates?'),
          content: SelectableText(
            '''Address: $address

Latitude: ${position.latitude.toStringAsFixed(6)}
Longitude: ${position.longitude.toStringAsFixed(6)}

Set this as your default medication destination?''',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save destination')),
          ],
        ),
      );
      if (confirmed != true) return;
      await _dbService.saveSavedPharmacyLocation(
        uid,
        SavedPharmacyLocation(
          pharmacyId: 'current_${DateTime.now().millisecondsSinceEpoch}',
          pharmacyName: 'My medication destination',
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
          savedAt: DateTime.now(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Destination saved successfully.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not capture location: $error')),
      );
    }
  }

  Future<void> _chooseDestinationOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    final uid = _currentUser?.uid;
    if (result is SavedPharmacyLocation && uid != null) {
      await _dbService.saveSavedPharmacyLocation(uid, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Destination saved successfully.')),
        );
      }
    }
  }

  Future<void> _resetDestination() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.location_off_outlined, color: Colors.deepPurple),
        title: const Text('Reset saved destination?'),
        content: const Text(
          'The current destination coordinates will be removed. You can immediately capture your current location or choose another point on the map.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _dbService.removeSavedPharmacyLocation(uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Destination reset. Please select a new destination.')),
    );
    _showLocationSetupPrompt();
  }

  Future<void> _checkPermissions() async {
    final alarmsPlugin = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (alarmsPlugin != null) {
      final bool? hasAlarms = await alarmsPlugin.canScheduleExactNotifications();
      if (hasAlarms == false && mounted) {
        setState(() => _showPermissionWarning = true);
      }
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _takeMedication(Reminder reminder, String medName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: Text('Did you take your $medName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Yes, Taken'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbService.updateReminderStatus(reminder.id, ReminderStatus.taken);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Great! $medName marked as taken.')),
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

  @override
  Widget build(BuildContext context) {
    if (_medicationsStream == null || _remindersStream == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<SavedPharmacyLocation?>(
      stream: _locationStream,
      builder: (context, locationSnapshot) {
        final savedLocation = locationSnapshot.data;

        return StreamBuilder<List<Medication>>(
          stream: _medicationsStream,
          builder: (context, medSnapshot) {
            return StreamBuilder<List<Reminder>>(
              stream: _remindersStream,
              builder: (context, reminderSnapshot) {
                if (!medSnapshot.hasData || !reminderSnapshot.hasData) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }

                final medications = medSnapshot.data!;
                final reminders = reminderSnapshot.data!;

                return Scaffold(
                  backgroundColor: AppColors.background,
                  body: IndexedStack(
                    index: _navIndex,
                    children: [
                      _buildHomeTab(context, savedLocation, medications, reminders),
                      const MedicationsScreen(), // Using MedicationsScreen as History for now
                      _buildMoreTab(),
                    ],
                  ),
                  bottomNavigationBar: MedBottomNav(
                    currentIndex: _navIndex,
                    onTap: (i) => setState(() => _navIndex = i),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHomeTab(BuildContext context, SavedPharmacyLocation? savedLocation, List<Medication> medications, List<Reminder> reminders) {
    // Calculate Dashboard Data
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd =
        DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Filter pending reminders (including overdue ones)
    final pendingReminders =
        reminders.where((r) => r.status == ReminderStatus.pending).toList();
    pendingReminders
        .sort((a, b) => a.reminderTime.compareTo(b.reminderTime));

    // The absolute "Next" (or Overdue) dose
    final nextReminder =
        pendingReminders.isNotEmpty ? pendingReminders.first : null;
    Medication? nextMed;
    if (nextReminder != null) {
      try {
        nextMed = medications.firstWhere(
          (m) => m.id == nextReminder.medicationId,
        );
      } catch (_) {
        nextMed = null;
      }
    }

    final upcomingForList = reminders
        .where((r) =>
            r.reminderTime.isAfter(now) &&
            r.reminderTime.isBefore(todayEnd) &&
            r.status == ReminderStatus.pending)
        .toList();
    upcomingForList
        .sort((a, b) => a.reminderTime.compareTo(b.reminderTime));

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showPermissionWarning) _buildPermissionWarning(),
            GreetingHeader(
              username: _username,
              onNotificationsTap: () => _navigateTo(const AppNotificationsScreen()),
            ),
            const SizedBox(height: 22),
            _buildWelcomeCard(),
            const SizedBox(height: 26),
            const SectionTitle(title: "Quick Actions"),
            const SizedBox(height: 16),
            _buildQuickActionsGrid(savedLocation),
            const SizedBox(height: 26),
            const SectionTitle(title: "Reminders"),
            const SizedBox(height: 12),
            if (upcomingForList.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text("No more reminders today", style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...upcomingForList.take(5).map((r) {
                final med = medications.firstWhere(
                  (m) => m.id == r.medicationId,
                  orElse: () => nextMed ?? Medication(id: '', userId: '', name: 'Medication', type: '', dosage: '', frequency: '', scheduleTimes: [], reminderTimes: [], isActive: true, createdAt: DateTime.now(), startDate: DateTime.now()),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ReminderTile(
                    medicineName: med.name,
                    dosage: med.dosage,
                    time: DateFormat('MMM d, h:mm a').format(r.reminderTime),
                    status: "Pending",
                    onTap: () => _takeMedication(r, med.name),
                  ),
                );
              }),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
          const SizedBox(height: 16),
          Text(
            "Welcome to QuickMed, $_username!",
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Your intelligent health companion is ready to help you track your medications and stay on top of your health journey.",
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreTab() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('More Options', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMoreItem(Icons.location_on_outlined, 'Reset Destination', _resetDestination),
          _buildMoreItem(Icons.settings_outlined, 'Settings', () {}),
          _buildMoreItem(Icons.help_outline, 'Help & Support', () {}),
          _buildMoreItem(Icons.logout, 'Sign Out', () async {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          }, isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildMoreItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : AppColors.primary),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : AppColors.textPrimary, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildPermissionWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reminders are Restricted',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                const Text(
                  'Please enable "Alarms & Reminders" in system settings to receive on-time notifications.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
                TextButton(
                  onPressed: () async {
                    final alarmsPlugin = FlutterLocalNotificationsPlugin()
                        .resolvePlatformSpecificImplementation<
                            AndroidFlutterLocalNotificationsPlugin>();
                    await alarmsPlugin?.requestExactAlarmsPermission();
                    _checkPermissions();
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissedDosesAlert(int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_toggle_off_rounded, color: Colors.red),
          const SizedBox(width: 12),
          Text(
            'You have $count missed dose${count > 1 ? 's' : ''} from earlier.',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
          ),
        ],
      ),
    );
  }


  Future<void> _resetAllReminders() async {
    final userId = _currentUser?.uid;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset all reminders?'),
        content: const Text(
          'This will permanently remove every reminder in the Reminders card and cancel all scheduled medication notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset reminders'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final deleted = await _dbService.deleteAllReminders(userId);
      await NotificationService().cancelAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$deleted reminder${deleted == 1 ? '' : 's'} removed.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reset reminders: $error')),
      );
    }
  }

  Widget _buildQuickActionsGrid(SavedPharmacyLocation? savedLocation) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 18,
      crossAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: [
        DashboardActionTile(
          label: "Track Routes",
          icon: Icons.map_outlined,
          color: AppColors.primary,
          onTap: () {
            if (savedLocation != null) {
              _navigateTo(LocationComparisonMapView(savedLocation: savedLocation));
            } else {
              _navigateTo(const LocationPickerScreen());
            }
          },
        ),
        DashboardActionTile(
          label: "Medication\nSchedule",
          icon: Icons.calendar_month_outlined,
          color: AppColors.accent,
          onTap: () => _navigateTo(const MedicationsScreen()),
        ),
        DashboardActionTile(
          label: "Add\nMedication",
          icon: Icons.medication_outlined,
          color: AppColors.success,
          onTap: () => _navigateTo(const AddMedicationScreen()),
        ),
        DashboardActionTile(
          label: "Reminders",
          icon: Icons.notifications_active_outlined,
          color: AppColors.warning,
          onTap: () => _navigateTo(const RemindersScreen()),
        ),
        DashboardActionTile(
          label: "Reset\nReminders",
          icon: Icons.delete_sweep_outlined,
          color: Colors.redAccent,
          onTap: _resetAllReminders,
        ),
        DashboardActionTile(
          label: "Pharmacy\n& Doctors",
          icon: Icons.local_pharmacy_outlined,
          color: AppColors.primary,
          onTap: () => _navigateTo(const CredentialsScreen()),
        ),
      ],
    );
  }
}
