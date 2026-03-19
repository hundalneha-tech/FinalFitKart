// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppColors {
  // ── Backgrounds ──────────────────────────────
  static const scaffold      = Color(0xFFF0F4FF); // light blue-grey bg
  static const cardWhite     = Color(0xFFFFFFFF);
  static const cardLight     = Color(0xFFF8FAFF);

  // ── Primary Blue ─────────────────────────────
  static const primary       = Color(0xFF2563EB);
  static const primaryLight  = Color(0xFF3B82F6);
  static const primaryDark   = Color(0xFF1D4ED8);
  static const primaryBg     = Color(0xFFEFF6FF);

  // ── Accent Pink / Magenta ────────────────────
  static const accent        = Color(0xFFEC4899);
  static const accentLight   = Color(0xFFF472B6);

  // ── Gradient (Move screen live earnings) ─────
  static const gradStart     = Color(0xFF2563EB);
  static const gradEnd       = Color(0xFFEC4899);

  // ── Coin Gold ────────────────────────────────
  static const coin          = Color(0xFFFBBF24);
  static const coinBg        = Color(0xFFFEF3C7);

  // ── Green (positive / earnings) ─────────────
  static const green         = Color(0xFF10B981);
  static const greenBg       = Color(0xFFD1FAE5);

  // ── Red / SOS ────────────────────────────────
  static const red           = Color(0xFFEF4444);
  static const redBg         = Color(0xFFFEE2E2);

  // ── Yellow (boost / highlight) ───────────────
  static const yellow        = Color(0xFFFBBF24);
  static const yellowBg      = Color(0xFFFEF9C3);

  // ── Text ─────────────────────────────────────
  static const textPrimary   = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted     = Color(0xFF94A3B8);
  static const textWhite     = Color(0xFFFFFFFF);

  // ── Border ───────────────────────────────────
  static const border        = Color(0xFFE2E8F0);
  static const borderLight   = Color(0xFFF1F5F9);

  // ── Nav bar ──────────────────────────────────
  static const navBg         = Color(0xFFFFFFFF);
  static const navActive     = Color(0xFF2563EB);
  static const navInactive   = Color(0xFF94A3B8);

  // Challenge blue banner
  static const challengeBg   = Color(0xFF2563EB);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.scaffold,
    fontFamily: 'Poppins',
    colorScheme: const ColorScheme.light(
      primary:   AppColors.primary,
      secondary: AppColors.accent,
      surface:   AppColors.cardWhite,
      error:     AppColors.red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.scaffold,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border.withOpacity(0.5)),
      ),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      headlineMedium:TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleMedium:   TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      bodyLarge:     TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      bodyMedium:    TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      labelLarge:    TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
      labelMedium:   TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted),
    ),
  );
}

// ── Shared decoration helpers ─────────────────────────────────

BoxDecoration cardDecoration({double radius = 16, Color? color}) => BoxDecoration(
  color: color ?? AppColors.cardWhite,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: AppColors.border.withOpacity(0.5)),
  boxShadow: [
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2)),
  ],
);

BoxDecoration gradientDecoration({double radius = 16}) => BoxDecoration(
  gradient: const LinearGradient(
    colors: [AppColors.gradStart, AppColors.gradEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ),
  borderRadius: BorderRadius.circular(radius),
);
