import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF5F6F8);
  static const surface = Colors.white;
  static const dark = Color(0xFF20242C);
  static const highlight = Color(0xFFFFFFFF);
  static const secondarySurface = Color(0xFFF0F2F6);
  static const ink = Color(0xFF20242C);
  static const muted = Color(0xFF667085);
  static const accent = Color(0xFF365EDC);
  static const accentSoft = Color(0xFFECF0FF);
  static const expense = Color(0xFFBA4853);
  static const border = Color(0xFFE6E8EE);
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
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.accent).copyWith(
      primary: AppColors.accent,
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
        fillColor: const Color(0xFFF7F8FA),
        contentPadding: const EdgeInsets.all(Space.lg),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        backgroundColor: AppColors.dark,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
            fontFamily: 'NotoSansKR',
            fontSize: 14,
            fontWeight: FontWeight.w600),
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
          iconColor: AppColors.accent, contentPadding: EdgeInsets.zero),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: AppColors.accentSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerColor: AppColors.border,
    );
  }

  static const numberStyle =
      TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
}
