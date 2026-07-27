import 'package:flutter/material.dart';
import 'package:quickmed/features/authentication/services/auth_service.dart';
import 'package:quickmed/models/index.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('QuickMed Dashboard'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(user),
              const SizedBox(height: 18),
              _buildProgressCard(),
              const SizedBox(height: 18),
              _buildQuickActionsGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(User? user) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${user?.fullName ?? 'there'}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You have 3 medications due today and 2 reminders pending.',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medical_services, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medication Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: const [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: CircularProgressIndicator(
                          value: 0.72,
                          strokeWidth: 12,
                          backgroundColor: Color(0xFFE3F2FD),
                          valueColor: AlwaysStoppedAnimation(Color(0xFF1565C0)),
                        ),
                      ),
                      Text(
                        '72%',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _LegendItem(color: Color(0xFF1565C0), label: 'Taken'),
                      SizedBox(height: 8),
                      _LegendItem(color: Color(0xFF4FC3F7), label: 'Pending'),
                      SizedBox(height: 8),
                      _LegendItem(color: Color(0xFFBDBDBD), label: 'Missed'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = [
      _ActionTile(icon: Icons.medication, label: 'Medications', color: const Color(0xFF1565C0)),
      _ActionTile(icon: Icons.alarm, label: 'Reminders', color: const Color(0xFF0288D1)),
      _ActionTile(icon: Icons.local_pharmacy, label: 'Pharmacies', color: const Color(0xFF26A69A)),
      _ActionTile(icon: Icons.person, label: 'Profile', color: const Color(0xFF7E57C2)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: action.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(action.icon, color: action.color, size: 28),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    action.label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _ActionTile {
  final IconData icon;
  final String label;
  final Color color;

  const _ActionTile({required this.icon, required this.label, required this.color});
}
