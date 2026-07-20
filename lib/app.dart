import 'package:flutter/material.dart';
import 'routes/app_routes.dart';
import 'routes/route_generator.dart';
import 'constants/app_theme.dart';

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
