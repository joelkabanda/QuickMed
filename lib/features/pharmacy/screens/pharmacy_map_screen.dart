import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quickmed/models/pharmacy_model.dart';
import 'package:quickmed/models/user_profile_model.dart';
import 'package:quickmed/features/dashboard/widgets/pharmacy_stat_card.dart';
import 'package:quickmed/services/database_service.dart';

class PharmacyMapScreen extends StatefulWidget {
  const PharmacyMapScreen({super.key});

  @override
  State<PharmacyMapScreen> createState() => _PharmacyMapScreenState();
}

class _PharmacyMapScreenState extends State<PharmacyMapScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Find Medication',
          style: TextStyle(color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estimated locations',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Find and save your preferred drug store location',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              PharmacyStatCard(
                pharmacy: Pharmacy(
                  id: 'pharmacy_1',
                  name: 'Drug Store location',
                  address: '123 Main St, Downtown',
                  latitude: -1.2921,
                  longitude: 36.8219,
                  phoneNumber: '+254 712 345 678',
                  availableMedications: ['Aspirin', 'Ibuprofen', 'Paracetamol'],
                  isOpen: true,
                  createdAt: DateTime.now(),
                  rating: 4.5,
                  reviewCount: 120,
                ),
                savedLocation: _savedPharmacyLocation,
                onSaveLocation: _handleSavePharmacyLocation,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
