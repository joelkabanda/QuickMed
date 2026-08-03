import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quickmed/constants/app_theme.dart';
import 'package:quickmed/routes/app_routes.dart';
import 'package:quickmed/routes/route_generator.dart';
import 'package:quickmed/services/reminder_service.dart';

class QuickMedApp extends StatefulWidget {
  const QuickMedApp({super.key});

  @override
  State<QuickMedApp> createState() => _QuickMedAppState();
}

class _QuickMedAppState extends State<QuickMedApp>
    with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSubscription;
  Timer? _routeReminderTimer;
  bool _refreshingRouteReminders = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      _authSubscription =
          FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          _refreshRouteReminders();
        }
      });
    } catch (error) {
      debugPrint('Route reminder auth listener unavailable: $error');
    }
    _routeReminderTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _refreshRouteReminders(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshRouteReminders();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshRouteReminders();
    }
  }

  Future<void> _refreshRouteReminders() async {
    if (_refreshingRouteReminders) return;

    String? userId;
    try {
      userId = FirebaseAuth.instance.currentUser?.uid;
    } catch (error) {
      debugPrint('Route reminder refresh skipped: $error');
      return;
    }
    if (userId == null) return;

    _refreshingRouteReminders = true;
    try {
      await ReminderService
          .refreshUpcomingMedicationNotificationsFromCurrentLocation(
        userId: userId,
      );
    } finally {
      _refreshingRouteReminders = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _routeReminderTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quick Med',
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouteGenerator.generateRoute,
    );
  }
}
