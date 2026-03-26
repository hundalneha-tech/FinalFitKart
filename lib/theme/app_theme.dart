// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppColors {
  // ── Backgrounds ──────────────────────────────────────────────
  static const scaffold      = Color(0xFFF0F4FF);
  static const cardWhite     = Color(0xFFFFFFFF);
  static const cardLight     = Color(0xFFF8FAFF);

  // ── Primary Blue ─────────────────────────────────────────────
  static const primary       = Color(0xFF2563EB);
  static const primaryLight  = Color(0xFF3B82F6);
  static const primaryDark   = Color(0xFF1D4ED8);
  static const primaryBg     = Color(0xFFEFF6FF);

  // ── Accent Pink ───────────────────────────────────────────────
  static const accent        = Color(0xFFEC4899);
  static const accentLight   = Color(0xFFF472B6);
  static const accentBg      = Color(0xFFFFF0F7);

  // ── Coin Gold ─────────────────────────────────────────────────
  static const coin          = Color(0xFFFBBF24);
  static const coinBg        = Color(0xFFFEF3C7);
  static const yellow        = Color(0xFFFBBF24);
  static const yellowBg      = Color(0xFFFEF9C3);

  // ── Green ─────────────────────────────────────────────────────
  static const green         = Color(0xFF10B981);
  static const greenBg       = Color(0xFFD1FAE5);

  // ── Red ───────────────────────────────────────────────────────
  static const red           = Color(0xFFEF4444);
  static const redBg         = Color(0xFFFEE2E2);

  // ── Text ──────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted     = Color(0xFF94A3B8);

  // ── Border ────────────────────────────────────────────────────
  static const border        = Color(0xFFE2E8F0);
  static const borderLight   = Color(0xFFF1F5F9);

  // ── Nav ───────────────────────────────────────────────────────
  static const navInactive   = Color(0xFF94A3B8);

  // ── Aliases ───────────────────────────────────────────────────
  static const card          = cardWhite;

  // ── Gradient ──────────────────────────────────────────────────
  static const grad = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFFEC4899)]);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    fontFamily: 'Poppins',
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    scaffoldBackgroundColor: AppColors.scaffold,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.scaffold,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins', fontSize: 20,
        fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15),
      )),
    sliderTheme: const SliderThemeData(
      trackHeight: 4),
  );
}

// ── Card decoration helper ────────────────────────────────────────
BoxDecoration cardDecoration({double radius = 16}) => BoxDecoration(
  color: AppColors.card,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: AppColors.border.withOpacity(0.6)),
  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0,2))],
);

// ── Reusable widgets ──────────────────────────────────────────────
class CoinDot extends StatelessWidget {
  final double size;
  const CoinDot({super.key, this.size = 18});
  @override Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
    child: Center(child: Text('C', style: TextStyle(fontSize: size*0.5, fontWeight: FontWeight.w800, color: Colors.white))));
}
