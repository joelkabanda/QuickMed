import 'package:flutter/material.dart';

import '../features/authentication/screens/forgot_password.dart';
import '../features/authentication/screens/login_screen.dart';
import '../features/authentication/screens/register_screen.dart';
import '../features/authentication/screens/splash_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/dashboard/screens/location_picker_screen.dart';
import '../features/dashboard/screens/location_comparison_map_view.dart';
import '../features/dashboard/screens/add_medication_screen.dart';
import '../features/dashboard/screens/medications_screen.dart';
import '../features/pharmacy/screens/pharmacy_map_screen.dart';
import '../models/user_profile_model.dart';
import '../models/medication_model.dart';
import 'app_routes.dart';

class AppRouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case AppRoutes.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case AppRoutes.forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case AppRoutes.dashboard:
        return MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
        );
      case AppRoutes.medications:
        return MaterialPageRoute(
          builder: (_) => const MedicationsScreen(),
        );
      case AppRoutes.addMedication:
        final medication = settings.arguments as Medication?;
        return MaterialPageRoute(
          builder: (_) => AddMedicationScreen(medication: medication),
        );
      case AppRoutes.editMedication:
        final medication = settings.arguments as Medication?;
        return MaterialPageRoute(
          builder: (_) => AddMedicationScreen(medication: medication),
        );
      case AppRoutes.reminders:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Reminders'))),
        );
      case AppRoutes.pharmacies:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Pharmacies'))),
        );
      case AppRoutes.pharmacyMap:
        return MaterialPageRoute(
          builder: (_) => const PharmacyMapScreen(),
        );
      case AppRoutes.locationPicker:
        return MaterialPageRoute(
          builder: (_) => const LocationPickerScreen(),
        );
      case AppRoutes.locationComparison:
        final args = settings.arguments as SavedPharmacyLocation;
        return MaterialPageRoute(
          builder: (_) => LocationComparisonMapView(
            savedLocation: args,
          ),
        );
      case AppRoutes.maps:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: Center(child: Text('Maps'))),
        );
      case AppRoutes.profile:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: Center(child: Text('Profile'))),
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: Center(child: Text('Settings'))),
        );
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }

  static String medicationRoute(String id) => '${AppRoutes.medications}/$id';

  static String reminderRoute(String id) => '${AppRoutes.reminders}/$id';

  static String pharmacyRoute(String id) => '${AppRoutes.pharmacies}/$id';

  static String directionsRoute(String pharmacyId) =>
      '${AppRoutes.maps}/directions/$pharmacyId';
}
