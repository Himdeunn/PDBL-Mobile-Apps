import 'package:flutter/material.dart';

class AppColors {
  // Primary & Backgrounds
  static const Color primary = Color(0xFF3D1C3B);
  static const Color primaryDark = Color(0xFF2A1329);
  static const Color background = Color(0xFFF3EDE6);
  static const Color surface = Color(0xFFE8DDD0);
  static const Color surfaceDark = Color(0xFF332736);
  static const Color white = Colors.white;

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF555555);
  static const Color textTertiary = Color(0xFF888888);
  static const Color textPlaceholder = Color(0xFF999999);
  static const Color textLight = Colors.white70;

  // Accents & Components
  static const Color iconAccent = Color(0xFFA79D9E);
  static const Color calendarSelected = Color(0xFF632E5E);
  static const Color calendarBorder = Color(0xFF632E5E);
  static const Color calendarOtherMonth = Color(0xFFB0B0B0);
  static const Color calendarEmptyIcon = Color(0xFF632E5E);
  static const Color calendarEmptyText = Color(0xFF332736);

  // Task Timeline
  static const Color timelineDot = Color(0xFF632E5E);
  static const Color timelineLine = Color(0xFF632E5E);

  // Text Fields
  static const Color inputDarkBg = Color(0xFF2F2235);

  // Errors
  static const Color errorBg = Color(0xFFFFEBEE);
  static const Color errorText = Color(0xFFC62828);
}

class AppTextStyles {
  static const TextStyle titleLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      fontFamily: 'Sans',
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.background,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
          textStyle: AppTextStyles.bodyLarge,
        ),
      ),
    );
  }
}
