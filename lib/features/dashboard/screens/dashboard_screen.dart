// // lib/features/dashboard/screens/dashboard_screen.dart
// //Widgets
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'dart:async';
// import '../../authentication/screens/login_screen.dart';
// import '../../../constants/app_colors.dart';
// import '../widgets/greeting_header.dart';
// import '../widgets/quick_action_card.dart';
// import '../widgets/med_wallet.dart';
// import '../widgets/reminder_tile.dart';
// import '../widgets/section_title.dart';
// import '../widgets/bottom_nav.dart';
// import '../widgets/settings.dart';

// //screens
// import 'add_medication_screen.dart';
// import 'add_reminder_screen.dart';
// import 'location_picker_screen.dart';
// import 'medications_screen.dart';
// import 'health_profile_screen.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import '../../../services/notification_service.dart';
// import '../../../models/medication_model.dart';
// import '../../../models/reminder_model.dart';
// import '../../../services/database_service.dart';
// import 'package:intl/intl.dart';

// class DashboardScreen extends StatefulWidget {
//   const DashboardScreen({super.key});

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   int _navIndex = 0;
//   late DatabaseService _dbService;
//   Stream<List<Medication>>? _medicationsStream;
//   Stream<List<Reminder>>? _remindersStream;
//   Timer? _refreshTimer;

//   User? get _currentUser => FirebaseAuth.instance.currentUser;

//   String get _username {
//     final user = _currentUser;
//     if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
//       return user.displayName!.split(' ').first; // first name only
//     }
//     if (user?.email != null) {
//       return user!.email!.split('@').first; // fallback: local part of email
//     }
//     return "there";
//   }

//   String get _email => _currentUser?.email ?? "No email on file";

//   bool _showPermissionWarning = false;

//   @override
//   void initState() {
//     super.initState();
//     _dbService = DatabaseService();
//     _loadData();
//     _checkPermissions();

//     // Auto-update dashboard every minute to refresh "Next Dose" based on current time
//     _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
//       if (mounted) setState(() {});
//     });
//   }

//   @override
//   void dispose() {
//     _refreshTimer?.cancel();
//     super.dispose();
//   }

//   void _loadData() {
//     final userId = _currentUser?.uid;
//     if (userId != null) {
//       _medicationsStream = _dbService.streamUserMedications(userId);
//       _remindersStream = _dbService.streamUserReminders(userId);
//     }
//   }

//   Future<void> _checkPermissions() async {
//     final alarmsPlugin = FlutterLocalNotificationsPlugin()
//         .resolvePlatformSpecificImplementation<
//             AndroidFlutterLocalNotificationsPlugin>();
    
//     if (alarmsPlugin != null) {
//       final bool? hasAlarms = await alarmsPlugin.canScheduleExactNotifications();
//       if (hasAlarms == false && mounted) {
//         setState(() => _showPermissionWarning = true);
//       }
//     }
//   }

//   void _navigateTo(Widget screen) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => screen),
//     );
//   }

//   Future<void> _takeMedication(Reminder reminder, String medName) async {
//     final confirmed = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Confirm'),
//         content: Text('Did you take your $medName?'),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
//           TextButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: TextButton.styleFrom(foregroundColor: Colors.green),
//             child: const Text('Yes, Taken'),
//           ),
//         ],
//       ),
//     );

//     if (confirmed == true) {
//       try {
//         await _dbService.updateReminderStatus(reminder.id, ReminderStatus.taken);
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Great! $medName marked as taken.')),
//           );
//         }
//       } catch (e) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Error: $e')),
//           );
//         }
//       }
//     }
//   }

//   Future<void> _triggerTestNotifications() async {
//     debugPrint("DashboardScreen: _triggerTestNotifications called");
//     try {
//       final service = NotificationService();
      
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Testing: Initializing and scheduling...'),
//           duration: Duration(seconds: 4),
//         ),
//       );

//       await service.init(); // Ensure permissions are requested and timezone is set
//       debugPrint("DashboardScreen: Service init finished");
      
//       final now = DateTime.now();

//       // 1. Immediate Notification
//       debugPrint("DashboardScreen: Sending immediate notification");
//       await service.showNotification(
//         id: 999,
//         title: 'QuickMed Active!',
//         body: 'Notifications are working! Scheduled ones will follow.',
//       );

//       // 2. Scheduled Notifications
//       debugPrint("DashboardScreen: Scheduling 5 notifications...");
//       for (int i = 1; i <= 5; i++) {
//         await service.scheduleNotification(
//           id: 1000 + i,
//           title: 'Scheduled Test #$i',
//           body: 'Reminder $i of 5. The app is working in the background!',
//           scheduledDate: now.add(Duration(seconds: i * 10)),
//         );
//       }
//       debugPrint("DashboardScreen: All test notifications scheduled");
//     } catch (e) {
//       debugPrint("DashboardScreen ERROR: $e");
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Test failed: $e')),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_medicationsStream == null || _remindersStream == null) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     return StreamBuilder<List<Medication>>(
//       stream: _medicationsStream,
//       builder: (context, medSnapshot) {
//         return StreamBuilder<List<Reminder>>(
//           stream: _remindersStream,
//           builder: (context, reminderSnapshot) {
//             if (!medSnapshot.hasData || !reminderSnapshot.hasData) {
//               return const Scaffold(body: Center(child: CircularProgressIndicator()));
//             }

//             final medications = medSnapshot.data!;
//             final reminders = reminderSnapshot.data!;
            
//             debugPrint("Dashboard: Processing ${medications.length} meds and ${reminders.length} reminders");

//             // Calculate Dashboard Data
//             final now = DateTime.now();
//             final todayStart = DateTime(now.year, now.month, now.day);
//             final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

//             // Filter pending reminders regardless of time (show missed ones as priority)
//             final pendingReminders = reminders.where((r) => r.status == ReminderStatus.pending).toList();
//             pendingReminders.sort((a, b) => a.reminderTime.compareTo(b.reminderTime));

//             // Today's total and completed count
//             final todayReminders = reminders.where((r) => 
//               r.reminderTime.isAfter(todayStart) && r.reminderTime.isBefore(todayEnd)
//             ).toList();

//             final totalToday = todayReminders.length;
//             final completedToday = todayReminders.where((r) => r.status == ReminderStatus.taken).length;

//             // The absolute "Next" (or Overdue) dose
//             final nextReminder = pendingReminders.isNotEmpty ? pendingReminders.first : null;
//             Medication? nextMed;
//             if (nextReminder != null) {
//               nextMed = medications.firstWhere(
//                 (m) => m.id == nextReminder.medicationId,
//                 orElse: () => Medication(id: '', userId: '', name: 'Medication', type: '', dosage: '', frequency: '', scheduleTimes: [], reminderTimes: [], isActive: true, createdAt: DateTime.now(), startDate: DateTime.now()),
//               );
//             }

//             final upcomingForList = reminders.where((r) => 
//               r.reminderTime.isAfter(now) && r.status == ReminderStatus.pending
//             ).toList();
//             upcomingForList.sort((a, b) => a.reminderTime.compareTo(b.reminderTime));

//             final nextDoseText = nextReminder != null 
//                 ? (nextReminder.reminderTime.day == now.day 
//                     ? DateFormat('h:mm a').format(nextReminder.reminderTime)
//                     : DateFormat('MMM d, h:mm a').format(nextReminder.reminderTime))
//                 : "";

//             return Scaffold(
//               backgroundColor: AppColors.background,
//               body: SafeArea(
//                 bottom: false,
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       if (_showPermissionWarning)
//                         _buildPermissionWarning(),

//                       GreetingHeader(
//                         username: _username,
//                         onSettingsTap: () => Settings.show(
//                           context,
//                           username: _username,
//                           email: _email,
//                           bloodGroup: "O+", // TODO: pull from health profile data
//                           activeMedicationsCount: medications.length,
//                           onViewFullProfile: () =>
//                               _navigateTo(const HealthProfileScreen()),
//                           onTriggerTestNotifications: _triggerTestNotifications,
//                           onSignOut: () async {
//                             await FirebaseAuth.instance.signOut();
//                             if (context.mounted) {
//                               Navigator.of(context).pushAndRemoveUntil(
//                                 MaterialPageRoute(builder: (_) => const LoginScreen()),
//                                 (route) => false,
//                               );
//                             }
//                           },
//                         ),
//                       ),
//                       const SizedBox(height: 22),

//                       GestureDetector(
//                         onTap: nextReminder != null && nextMed != null
//                             ? () => _takeMedication(nextReminder, nextMed!.name)
//                             : null,
//                         child: MedWalletCard(
//                           patientName: _username,
//                           nextMedicationName: nextMed?.name ?? "All Caught Up",
//                           nextDoseTime: nextReminder != null ? nextDoseText : "Good Job!",
//                           completedToday: completedToday,
//                           totalToday: totalToday,
//                         ),
//                       ),

//                       const SizedBox(height: 26),
//                       const SectionTitle(title: "Quick Actions"),
//                       const SizedBox(height: 16),

//                       _buildQuickActionsGrid(),

//                       const SizedBox(height: 26),
//                       const SectionTitle(title: "Upcoming Reminders"),
//                       const SizedBox(height: 12),

//                       if (upcomingForList.isEmpty)
//                         const Center(
//                           child: Padding(
//                             padding: EdgeInsets.symmetric(vertical: 20),
//                             child: Text("No more reminders today", style: TextStyle(color: Colors.grey)),
//                           ),
//                         )
//                       else
//                         ...upcomingForList.take(5).map((r) {
//                           final med = medications.firstWhere(
//                             (m) => m.id == r.medicationId, 
//                             orElse: () => nextMed ?? Medication(id: '', userId: '', name: 'Medication', type: '', dosage: '', frequency: '', scheduleTimes: [], reminderTimes: [], isActive: true, createdAt: DateTime.now(), startDate: DateTime.now()),
//                           );
//                           return Padding(
//                             padding: const EdgeInsets.only(bottom: 10),
//                             child: ReminderTile(
//                               medicineName: med.name,
//                               dosage: med.dosage,
//                               time: DateFormat('MMM d, h:mm a').format(r.reminderTime),
//                               status: "Pending",
//                               onTap: () => _takeMedication(r, med.name),
//                             ),
//                           );
//                         }),

//                       const SizedBox(height: 100), // clears the floating bottom nav
//                     ],
//                   ),
//                 ),
//               ),
//               bottomNavigationBar: MedBottomNav(
//                 currentIndex: _navIndex,
//                 onTap: (i) => setState(() => _navIndex = i),
//                 onScanTap: () {},
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildPermissionWarning() {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 20),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.orange.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: Colors.orange.withOpacity(0.5)),
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.warning_amber_rounded, color: Colors.orange),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Reminders are Restricted',
//                   style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
//                 ),
//                 const Text(
//                   'Please enable "Alarms & Reminders" in system settings to receive on-time notifications.',
//                   style: TextStyle(fontSize: 12, color: Colors.black87),
//                 ),
//                 TextButton(
//                   onPressed: () async {
//                     final alarmsPlugin = FlutterLocalNotificationsPlugin()
//                         .resolvePlatformSpecificImplementation<
//                             AndroidFlutterLocalNotificationsPlugin>();
//                     await alarmsPlugin?.requestExactAlarmsPermission();
//                     _checkPermissions();
//                   },
//                   style: TextButton.styleFrom(
//                     padding: EdgeInsets.zero,
//                     minimumSize: const Size(0, 0),
//                     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                   ),
//                   child: const Text('Open Settings'),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildMissedDosesAlert(int count) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 20),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: BoxDecoration(
//         color: Colors.red.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: Colors.red.withOpacity(0.3)),
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.history_toggle_off_rounded, color: Colors.red),
//           const SizedBox(width: 12),
//           Text(
//             'You have $count missed dose${count > 1 ? 's' : ''} from earlier.',
//             style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildQuickActionsGrid() {
//     return GridView.count(
//       crossAxisCount: 3,
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       mainAxisSpacing: 18,
//       crossAxisSpacing: 8,
//       children: [
//         DashboardActionTile(
//           label: "Track Routes",
//           icon: Icons.local_pharmacy_outlined,
//           color: AppColors.primary,
//           onTap: () => _navigateTo(const LocationPickerScreen()),
//         ),
//         DashboardActionTile(
//           label: "Medication\nSchedule",
//           icon: Icons.calendar_month_outlined,
//           color: AppColors.accent,
//           onTap: () => _navigateTo(const MedicationsScreen()),
//         ),
//         DashboardActionTile(
//           label: "Add\nMedication",
//           icon: Icons.medication_outlined,
//           color: AppColors.success,
//           onTap: () => _navigateTo(const AddMedicationScreen()),
//         ),
//         DashboardActionTile(
//           label: "Add\nReminder",
//           icon: Icons.alarm_add_outlined,
//           color: AppColors.warning,
//           onTap: () => _navigateTo(const AddReminderScreen()),
//         ),
//         DashboardActionTile(
//           label: "Refill\nTracker",
//           icon: Icons.inventory_2_outlined,
//           color: AppColors.primaryDark,
//           onTap: () {},
//         ),
//         DashboardActionTile(
//           label: "My Health\nProfile",
//           icon: Icons.person_outline_rounded,
//           color: AppColors.primary,
//           onTap: () => _navigateTo(const HealthProfileScreen()),
//         ),
//       ],
//     );
//   }
// }
// lib/features/dashboard/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/dashboard_home_content.dart';

import 'location_picker_screen.dart';
import 'medications_screen.dart';
import 'health_profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;

  // Index 0 = Home (your dashboard content).
  // 1 = Pharmacy, 2 = History, 3 = More — mapped to bottom nav taps.
  final List<Widget> _pages = const [
    DashboardHomeContent(),
    LocationPickerScreen(),
    MedicationsScreen(),      // "History" tab — swap for a real history screen if you have one
    HealthProfileScreen(),    // "More" tab
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _navIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: MedBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        onScanTap: () {},
      ),
    );
  }
}
