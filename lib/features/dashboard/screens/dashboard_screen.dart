import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickmed/constants/app_colors.dart';
import 'package:quickmed/features/authentication/services/auth_service.dart';
import 'package:quickmed/routes/app_routes.dart';
import 'package:quickmed/models/reminder_model.dart';
import 'package:quickmed/services/database_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DatabaseService _dbService;
  int? _activeMedicationsCount;
  int? _upcomingRemindersCount;

  @override
  void initState() {
    super.initState();
    _dbService = DatabaseService();
    _loadDashboardCounts();
  }

  Future<void> _loadDashboardCounts() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final medications = await _dbService.getUserMedications(userId);
      final reminders = await _dbService.getUserReminders(userId);
      final upcomingReminders = reminders.where((reminder) {
        return reminder.status == ReminderStatus.pending &&
            reminder.reminderTime.isAfter(DateTime.now());
      }).length;

      if (mounted) {
        setState(() {
          _activeMedicationsCount = medications.length;
          _upcomingRemindersCount = upcomingReminders;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard counts: $e');
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AuthService().logout();
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.login,
            (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout error: $e')),
          );
        }
      }
    }
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required List<Color> gradient,
    Color? backgroundColor,
    required Color textColor,
    String? route,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap ??
            (route == null
                ? null
                : () => Navigator.of(context).pushNamed(route)),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: gradient.isNotEmpty
                ? LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: gradient.isEmpty ? backgroundColor : null,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.08),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.22),
                child: Icon(icon, color: textColor, size: 20),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  color: textColor.withOpacity(0.85),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    String? route,
    bool isExpanded = true,
  }) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap:
            route == null ? null : () => Navigator.of(context).pushNamed(route),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.08),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isExpanded) {
      return Expanded(child: child);
    }
    return child;
  }

  Widget _buildResponsiveSummaryCards(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 640;
        final summaryCards = [
          _buildSummaryCard(
            context,
            icon: Icons.medication_liquid,
            title: 'Medication Schedules',
            value: _activeMedicationsCount != null
                ? '${_activeMedicationsCount!} active'
                : 'Loading...',
            gradient: const [Color(0xFF5B67F1), Color(0xFF4A56E2)],
            textColor: Colors.white,
            onTap: () {
              Navigator.of(context)
                  .pushNamed(AppRoutes.medications)
                  .then((_) => _loadDashboardCounts());
            },
          ),
          _buildSummaryCard(
            context,
            icon: Icons.access_time,
            title: 'Reminders',
            value: _upcomingRemindersCount != null
                ? '${_upcomingRemindersCount!} upcoming'
                : 'Loading...',
            gradient: const [Color(0xFF2BBF7B), Color(0xFF1D9D5A)],
            textColor: Colors.white,
            onTap: () {
              Navigator.of(context)
                  .pushNamed(AppRoutes.reminders)
                  .then((_) => _loadDashboardCounts());
            },
          ),
        ];

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: summaryCards[0]),
              const SizedBox(width: 16),
              Expanded(child: summaryCards[1]),
            ],
          );
        }

        return Column(
          children: [
            summaryCards[0],
            const SizedBox(height: 16),
            summaryCards[1],
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Good Morning 👋',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Today\'s Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              _buildResponsiveSummaryCards(context),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFeatureTile(
                      context: context,
                      icon: Icons.add_circle_outline,
                      title: 'Add Medication',
                      subtitle: 'Quickly add a new dose',
                      color: AppColors.primary,
                      route: AppRoutes.addMedication,
                      isExpanded: false,
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureTile(
                      context: context,
                      icon: Icons.access_time,
                      title: 'Schedule Reminder',
                      subtitle: 'Create your next alert',
                      color: AppColors.success,
                      route: AppRoutes.addReminder,
                      isExpanded: false,
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureTile(
                      context: context,
                      icon: Icons.location_on_outlined,
                      title: 'Find Pharmacy',
                      subtitle: 'Nearby open pharmacies',
                      color: AppColors.primary,
                      route: AppRoutes.pharmacyMap,
                      isExpanded: false,
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureTile(
                      context: context,
                      icon: Icons.show_chart,
                      title: 'History',
                      subtitle: 'View medical records',
                      color: AppColors.accent,
                      route: AppRoutes.medicalHistory,
                      isExpanded: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed(AppRoutes.addMedication);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
