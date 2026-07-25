// lib/features/dashboard/screens/health_profile_screen.dart
import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

class HealthProfileScreen extends StatelessWidget {
  const HealthProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("My Health Profile")),
      body: const Center(child: Text("Profile & health info goes here")),
    );
  }
}