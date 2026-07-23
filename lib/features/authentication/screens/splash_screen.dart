import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quickmed/routes/index.dart';
import 'package:quickmed/services/location_service.dart';
import 'package:quickmed/features/dashboard/widgets/location_permission_dialog.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/auth_theme.dart';

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
        // User is logged in, check location permission
        debugPrint('User authenticated: ${user.email}');
        await _checkLocationPermission();
      } else {
        // User is not logged in, navigate to login
        debugPrint('No user authenticated, navigating to login');
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    } catch (e) {
      debugPrint('Auth check error: $e');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      final permission = await LocationService.checkLocationPermission();

      if (!mounted) return;

      if (permission == LocationPermission.denied) {
        // Show location permission dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => LocationPermissionDialog(
            onPermissionGranted: () {
              debugPrint('Location permission granted');
              _navigateToDashboard();
            },
            onPermissionDenied: () {
              debugPrint('Location permission denied');
              _navigateToDashboard();
            },
          ),
        );
      } else {
        // Permission already granted or in use
        _navigateToDashboard();
      }
    } catch (e) {
      debugPrint('Location permission check error: $e');
      _navigateToDashboard();
    }
  }

  void _navigateToDashboard() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AuthColors.tealDark, AuthColors.teal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative soft blobs, matching the auth header's motif
              Positioned(
                top: -40,
                right: -30,
                child: _blob(140, Colors.white.withValues(alpha: 0.06)),
              ),
              Positioned(
                top: 100,
                left: -50,
                child: _blob(100, Colors.white.withValues(alpha: 0.05)),
              ),
              Positioned(
                bottom: -60,
                right: -40,
                child: _blob(160, Colors.white.withValues(alpha: 0.06)),
              ),
              Positioned(
                bottom: 60,
                left: -30,
                child: _blob(90, Colors.white.withValues(alpha: 0.05)),
              ),
              Center(
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
                              color: Colors.black.withValues(alpha: .15),
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.medication_rounded,
                          size: 65,
                          color: AuthColors.teal,
                        ),
                      ),

                      const SizedBox(height: 35),

                      const Text(
                        "QuickMed",
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
