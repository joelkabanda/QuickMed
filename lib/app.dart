import 'package:flutter/material.dart';
import 'package:quickmed/constants/app_theme.dart';
import 'package:quickmed/routes/app_routes.dart';
import 'package:quickmed/routes/route_generator.dart';

class QuickMedApp extends StatelessWidget {
  const QuickMedApp({super.key});

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
