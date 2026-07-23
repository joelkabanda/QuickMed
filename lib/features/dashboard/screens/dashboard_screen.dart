// lib/features/dashboard/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/dashboard_home_content.dart';

import 'location_picker_screen.dart';
import 'reminders_screen.dart';
import 'health_profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;

  // Index 0 = Home dashboard content.
  // 1 = Pharmacy, 2 = History, 3 = More — mapped to bottom nav taps.
  final List<Widget> _pages = const [
    DashboardHomeContent(),
    LocationPickerScreen(),
    RemindersScreen(), 
    HealthProfileScreen(),// "More" tab
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _navIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: MedBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        onScanTap: () {},
      ),
    );
  }
}
