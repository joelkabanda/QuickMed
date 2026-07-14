import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:quickmed/models/index.dart';
import 'package:quickmed/services/database_service.dart';

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final DatabaseService _databaseService = DatabaseService();

  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _auth.currentUser != null;

  // Actual Firebase Registration
  Future<User?> registerUser({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        _currentUser = User(
          id: credential.user!.uid,
          email: email,
          fullName: fullName,
          phoneNumber: phone,
          createdAt: DateTime.now(),
        );

        // Save to Firestore collection automatically
        await _databaseService.saveUser(_currentUser!);
        return _currentUser;
      }
      return null;
    } catch (e) {
      print("Registration error: $e");
      rethrow;
    }
  }

  // Actual Firebase Login
  Future<bool> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Here you would usually fetch the full profile from Firestore
        _currentUser = User(
          id: credential.user!.uid,
          email: email,
          fullName: credential.user!.displayName ?? 'User',
          createdAt: DateTime.now(),
        );
        return true;
      }
      return false;
    } catch (e) {
      print("Login error: $e");
      rethrow;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
  }

  // Actual Firebase Password Reset
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print("Password reset error: $e");
      rethrow;
    }
  }
}
