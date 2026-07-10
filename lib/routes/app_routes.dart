/// Application Routes Configuration
library;

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';

  static const String login = '/authentication/login';
  static const String register = '/authentication/register';
  static const String forgotPassword = '/authentication/forgot-password';
  static const String resetPassword = '/authentication/reset-password';

  static const String dashboard = '/dashboard';

  static const String medications = '/medications';
  static const String medicationDetails = '/medications/:id';
  static const String addMedication = '/medications/add';
  static const String editMedication = '/medications/:id/edit';

  static const String reminders = '/reminders';
  static const String reminderDetails = '/reminders/:id';
  static const String addReminder = '/reminders/add';
  static const String editReminder = '/reminders/:id/edit';

  static const String pharmacies = '/pharmacies';
  static const String pharmacyDetails = '/pharmacies/:id';
  static const String pharmacyMap = '/pharmacies/map';

  static const String maps = '/maps';
  static const String directions = '/maps/directions/:pharmacyId';

  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String medicalHistory = '/profile/medical-history';

  static const String settings = '/settings';
  static const String notifications = '/settings/notifications';
  static const String privacy = '/settings/privacy';
  static const String about = '/settings/about';
}

class RouteNames {
  static const String login = 'login';
  static const String register = 'register';
  static const String forgotPassword = 'forgotPassword';

  static const String dashboard = 'dashboard';
  static const String medications = 'medications';
  static const String reminders = 'reminders';
  static const String pharmacies = 'pharmacies';
  static const String maps = 'maps';
  static const String profile = 'profile';
  static const String settings = 'settings';
}
