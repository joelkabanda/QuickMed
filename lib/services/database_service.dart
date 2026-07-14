import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Save user data to 'users' collection
  Future<void> saveUser(User user) async {
    try {
      await _db.collection('users').doc(user.id).set(user.toMap());
      print("User saved to Firestore successfully");
    } catch (e) {
      print("Error saving user: $e");
      rethrow;
    }
  }

  // Example: Save medical record
  Future<void> saveMedication(String userId, Map<String, dynamic> data) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('medications')
          .add({
        ...data,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error saving medication: $e");
      rethrow;
    }
  }
}
