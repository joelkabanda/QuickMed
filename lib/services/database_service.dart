import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/user_profile_model.dart';
import '../models/medication_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Save user data to 'users' collection
  Future<void> saveUser(User user) async {
    try {
      await _db.collection('users').doc(user.id).set(user.toMap());
      debugPrint("User saved to Firestore successfully");
    } catch (e) {
      debugPrint("Error saving user: $e");
      rethrow;
    }
  }

  // Example: Save medical record
  Future<void> saveMedication(String userId, Medication medication) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('medications')
          .doc(medication.id)
          .set(medication.toMap());
      debugPrint("Medication saved to Firestore successfully");
    } catch (e) {
      debugPrint("Error saving medication: $e");
      rethrow;
    }
  }

  /// Get all medications for a user
  Future<List<Medication>> getUserMedications(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('medications')
          .get();

      return snapshot.docs
          .map((doc) => Medication.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint("Error fetching medications: $e");
      rethrow;
    }
  }

  /// Get a single medication
  Future<Medication?> getMedication(String userId, String medicationId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('medications')
          .doc(medicationId)
          .get();

      if (doc.exists) {
        return Medication.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching medication: $e");
      rethrow;
    }
  }

  /// Delete a medication
  Future<void> deleteMedication(String userId, String medicationId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('medications')
          .doc(medicationId)
          .delete();
      debugPrint("Medication deleted successfully");
    } catch (e) {
      debugPrint("Error deleting medication: $e");
      rethrow;
    }
  }

  /// Save pharmacy location to user profile
  Future<void> saveSavedPharmacyLocation(
    String userId,
    SavedPharmacyLocation location,
  ) async {
    try {
      await _db.collection('users').doc(userId).update({
        'savedPharmacyLocation': location.toMap(),
      });
      debugPrint("Pharmacy location saved successfully");
    } catch (e) {
      debugPrint("Error saving pharmacy location: $e");
      rethrow;
    }
  }

  /// Remove saved pharmacy location
  Future<void> removeSavedPharmacyLocation(String userId) async {
    try {
      await _db.collection('users').doc(userId).update({
        'savedPharmacyLocation': FieldValue.delete(),
      });
      debugPrint("Pharmacy location removed successfully");
    } catch (e) {
      debugPrint("Error removing pharmacy location: $e");
      rethrow;
    }
  }

  /// Get saved pharmacy location for user
  Future<SavedPharmacyLocation?> getSavedPharmacyLocation(
    String userId,
  ) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists && doc['savedPharmacyLocation'] != null) {
        return SavedPharmacyLocation.fromMap(
          doc['savedPharmacyLocation'] as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      debugPrint("Error getting saved pharmacy location: $e");
      return null;
    }
  }

  /// Stream saved pharmacy location updates
  Stream<SavedPharmacyLocation?> streamSavedPharmacyLocation(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists && doc['savedPharmacyLocation'] != null) {
        return SavedPharmacyLocation.fromMap(
          doc['savedPharmacyLocation'] as Map<String, dynamic>,
        );
      }
      return null;
    });
  }
}
