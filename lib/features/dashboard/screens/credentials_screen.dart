import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickmed/models/medication_model.dart';
import 'package:quickmed/services/database_service.dart';
import 'package:quickmed/constants/app_colors.dart';

class CredentialsScreen extends StatefulWidget {
  const CredentialsScreen({super.key});

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  late DatabaseService _dbService;
  Stream<List<Medication>>? _medicationsStream;

  @override
  void initState() {
    super.initState();
    _dbService = DatabaseService();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _medicationsStream = _dbService.streamUserMedications(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pharmacy & Doctors', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
      ),
      body: _medicationsStream == null
          ? const Center(child: Text('Please login to view credentials'))
          : StreamBuilder<List<Medication>>(
              stream: _medicationsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final medications = snapshot.data ?? [];
                
                // Extract unique doctors and pharmacies
                final doctors = medications
                    .where((m) => m.prescribedBy != null && m.prescribedBy!.isNotEmpty)
                    .map((m) => m.prescribedBy!)
                    .toSet()
                    .toList();
                
                final pharmacies = medications
                    .where((m) => m.pharmacyAddress != null && m.pharmacyAddress!.isNotEmpty)
                    .map((m) => m.pharmacyAddress!)
                    .toSet()
                    .toList();

                if (doctors.isEmpty && pharmacies.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.contact_emergency_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          const Text(
                            'No credentials found',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add medication details in your schedule to see pharmacy and doctor information here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (doctors.isNotEmpty) ...[
                      _buildHeader('Prescribing Doctors', Icons.person_outline),
                      ...doctors.map((doctor) => _buildCredentialCard(doctor, Icons.medical_services_outlined, AppColors.primary)),
                      const SizedBox(height: 24),
                    ],
                    if (pharmacies.isNotEmpty) ...[
                      _buildHeader('Captured Pharmacies', Icons.local_pharmacy_outlined),
                      ...pharmacies.map((pharmacy) => _buildCredentialCard(pharmacy, Icons.location_on_outlined, AppColors.success)),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _buildHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialCard(String text, IconData icon, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accentColor, size: 22),
        ),
        title: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary.withOpacity(0.5)),
        onTap: () {
          // Future: Search or details
        },
      ),
    );
  }
}
