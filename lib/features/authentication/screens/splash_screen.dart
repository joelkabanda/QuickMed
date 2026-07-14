import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quickmed/routes/index.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthenticationState();
  }

  Future<void> _checkAuthenticationState() async {
    try {
      debugPrint('Starting auth check...');
      // Wait a minimum of 2 seconds for better UX
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      debugPrint('Checking Firebase current user...');
      final user = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      if (user != null) {
        // User is logged in, navigate to dashboard
        debugPrint('User authenticated: ${user.email}, navigating to dashboard');
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      } else {
        // User is not logged in, navigate to login
        debugPrint('No user authenticated, navigating to login');
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    } catch (e) {
      debugPrint('Auth check error: $e');
      if (mounted) {
        // On error, default to login screen
        debugPrint('Error occurred, defaulting to login');
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Container
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.15),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.medication_rounded,
                    size: 65,
                    color: Color(0xFF1565C0),
                  ),
                ),

                const SizedBox(height: 35),

                const Text(
                  "Quick Med",
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Your Smart Medication Companion",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    letterSpacing: .5,
                  ),
                ),

                const SizedBox(height: 60),

                const SizedBox(
                  height: 35,
                  width: 35,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
