import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF7F8FA);
  static const surface = Colors.white;
  static const ink = Color(0xFF202733);
  static const muted = Color(0xFF606B7A);
  static const teal = Color(0xFF207A75);
  static const tealSoft = Color(0xFFE7F4F1);
  static const expense = Color(0xFFB9414A);
  static const border = Color(0xFFE9EDF0);
}

abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.teal).copyWith(
      primary: AppColors.teal,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.expense,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'NotoSansKR',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.2),
        headlineSmall: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -.7),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 16, height: 1.6),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.all(Space.lg),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      )),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.tealSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerColor: AppColors.border,
    );
  }

  static const numberStyle =
      TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
}
