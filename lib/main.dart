import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
    debugPrint("Firebase initialized successfully");
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      debugPrint("Firebase initialization error: $e");
    }
  }

  runApp(const QuickMedApp());
}
