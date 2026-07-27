import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand — single primary, used deliberately
  static const Color primary = Color(0xFF3B5FE0);
  static const Color primaryDark = Color(0xFF2A46B8);
  static const Color primaryTint = Color(0xFFEDF1FD);

  // Neutrals
  static const Color background = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE7E9F0);
  static const Color textPrimary = Color(0xFF1B1F2A);
  static const Color textSecondary = Color(0xFF6B7280);

  // Status colors
  static const Color success = Color(0xFF2E9E5B); //  dose taken
  static const Color successTint = Color(0xFFE9F7EF);
  static const Color warning = Color(0xFFDB9A2C); // dose due soon
  static const Color warningTint = Color(0xFFFBF1E0);
  static const Color danger = Color(0xFFD6455A); // missed/overdue
  static const Color dangerTint = Color(0xFFFCEAEC);

  // A secondary accent for non-alert, non-primary highlights
  // (used for Estimations
  static const Color accent = Color(0xFF0F9B8E); // teal
  static const Color accentTint = Color(0xFFE4F6F4);
}
