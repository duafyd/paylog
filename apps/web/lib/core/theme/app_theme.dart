import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF4F5F1);
  static const surface = Colors.white;
  static const dark = Color(0xFF24382F);
  static const lime = Color(0xFFDBEDAB);
  static const sand = Color(0xFFF1EBDC);
  static const ink = Color(0xFF202923);
  static const muted = Color(0xFF70776F);
  static const teal = Color(0xFF356653);
  static const tealSoft = Color(0xFFE4EDDE);
  static const expense = Color(0xFFAA4F45);
  static const border = Color(0xFFE6E9E1);
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
            fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1.5),
        headlineSmall: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -1.0),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 16, height: 1.6),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF6F7F3),
        contentPadding: const EdgeInsets.all(Space.lg),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        backgroundColor: AppColors.dark,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      )),
      chipTheme: ChipThemeData(
          side: BorderSide.none,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      listTileTheme: const ListTileThemeData(
          iconColor: AppColors.teal, contentPadding: EdgeInsets.zero),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: AppColors.tealSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerColor: AppColors.border,
    );
  }

  static const numberStyle =
      TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
}
