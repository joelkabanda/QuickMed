import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/user_profile_model.dart';
import '../models/medication_model.dart';
import '../models/reminder_model.dart';
import 'notification_service.dart';

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
          .collection('medications')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs
          .map((doc) => Medication.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint("Error fetching medications: $e");
      rethrow;
    }
  }

  /// Save reminder record
  Future<void> saveReminder(Reminder reminder) async {
    try {
      await _db.collection('reminders').doc(reminder.id).set(reminder.toMap());
      debugPrint("Reminder saved to Firestore successfully");

      // Schedule local notification for this reminder (best-effort)
      try {
        // Avoid bringing flutter_local_notifications into a heavy dependency here
        // import lazily
        final ns = NotificationService();
        await ns.scheduleReminder(reminder);
      } catch (notifyErr) {
        debugPrint('Failed to schedule local notification: $notifyErr');
      }

    } catch (e) {
      debugPrint("Error saving reminder: $e");
      rethrow;
    }
  }

  /// Get all reminders for a user
  Future<List<Reminder>> getUserReminders(String userId) async {
    try {
      final snapshot = await _db
          .collection('reminders')
          .where('userId', isEqualTo: userId)
          .get();

      final reminders = snapshot.docs
          .map((doc) => Reminder.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      reminders.sort((a, b) => a.reminderTime.compareTo(b.reminderTime));
      return reminders;
    } catch (e) {
      debugPrint("Error fetching reminders: $e");
      rethrow;
    }
  }

  /// Delete a reminder
  Future<void> deleteReminder(String userId, String reminderId) async {
    try {
      final docRef = _db.collection('reminders').doc(reminderId);
      final doc = await docRef.get();
      if (doc.exists && doc.data()?['userId'] == userId) {
        await docRef.delete();
        debugPrint("Reminder deleted successfully");
        try {
          await NotificationService().cancelReminder(reminderId);
        } catch (cancelErr) {
          debugPrint('Failed to cancel scheduled notification: $cancelErr');
        }
      } else {
        throw Exception('Reminder not found or unauthorized');
      }
    } catch (e) {
      debugPrint("Error deleting reminder: $e");
      rethrow;
    }
  }

  /// Get a single medication
  Future<Medication?> getMedication(String userId, String medicationId) async {
    try {
      final doc = await _db.collection('medications').doc(medicationId).get();

      if (doc.exists) {
        final medication = Medication.fromMap({...doc.data()!, 'id': doc.id});
        return medication.userId == userId ? medication : null;
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
      final docRef = _db.collection('medications').doc(medicationId);
      final doc = await docRef.get();
      if (doc.exists && doc.data()?['userId'] == userId) {
        await docRef.delete();
        debugPrint("Medication deleted successfully");
      } else {
        throw Exception('Medication not found or unauthorized');
      }
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
