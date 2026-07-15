import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickmed/features/authentication/services/auth_service.dart';
import 'package:quickmed/routes/app_routes.dart';
import 'package:quickmed/models/pharmacy_model.dart';
import 'package:quickmed/models/user_profile_model.dart';
import 'package:quickmed/features/dashboard/widgets/pharmacy_stat_card.dart';
import 'package:quickmed/services/database_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  SavedPharmacyLocation? _savedPharmacyLocation;
  late DatabaseService _dbService;

  @override
  void initState() {
    super.initState();
    _dbService = DatabaseService();
    _loadSavedPharmacyLocation();
  }

  Future<void> _loadSavedPharmacyLocation() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final saved = await _dbService.getSavedPharmacyLocation(userId);
      if (mounted) {
        setState(() {
          _savedPharmacyLocation = saved;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved pharmacy location: $e');
    }
  }

  Future<void> _handleSavePharmacyLocation(SavedPharmacyLocation location) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      setState(() {
        if (location.pharmacyId.isEmpty) {
          _savedPharmacyLocation = null;
        } else {
          _savedPharmacyLocation = location;
        }
      });

      if (location.pharmacyId.isEmpty) {
        await _dbService.removeSavedPharmacyLocation(userId);
      } else {
        await _dbService.saveSavedPharmacyLocation(userId, location);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving location: $e')),
        );
      }
      debugPrint('Error saving pharmacy location: $e');
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
    required Color color,
    String? route,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap:
            route == null ? null : () => Navigator.of(context).pushNamed(route),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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
        borderRadius: BorderRadius.circular(18),
        onTap: route == null
            ? null
            : () => Navigator.of(context).pushNamed(route),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
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
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            context,
            icon: Icons.medication_liquid,
            title: 'Medications',
            value: '4 active',
            color: const Color(0xFF1565C0),
            route: AppRoutes.medications,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            context,
            icon: Icons.access_time,
            title: 'Reminders',
            value: '2 upcoming',
            color: const Color(0xFF2E7D32),
            route: AppRoutes.reminders,
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveFeatureTiles(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildFeatureTile(
            context: context,
            icon: Icons.add_circle_outline,
            title: 'Add Medication',
            subtitle: 'Quickly add a new dose',
            color: const Color(0xFF1E88E5),
            route: AppRoutes.addMedication,
            isExpanded: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFeatureTile(
            context: context,
            icon: Icons.location_on_outlined,
            title: 'Estimations',
            subtitle: 'Nearby open pharmacies',
            color: const Color(0xFFD32F2F),
            route: AppRoutes.pharmacyMap,
            isExpanded: false,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
                'Welcome!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Here is your health overview for today.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              _buildResponsiveSummaryCards(context),
              const SizedBox(height: 22),
              _buildResponsiveFeatureTiles(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
