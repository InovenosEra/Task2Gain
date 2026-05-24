import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized palette + typography. Body text uses Heebo (clean Hebrew),
/// display text (big numbers, hero titles) uses Rubik (rounded, playful).
class AppPalette {
  const AppPalette._();

  // Deep background tones
  static const bgDeep = Color(0xFF0F1030);
  static const bgViolet = Color(0xFF1F1B5C);
  static const bgPlum = Color(0xFF2A0B45);
  static const surface = Color(0xFF1A1B3A);

  // Brand accents
  static const gold = Color(0xFFFFD166);
  static const goldDeep = Color(0xFFFFA94D);
  static const pink = Color(0xFFEF476F);
  static const violet = Color(0xFF7B2CBF);
  static const green = Color(0xFF06D6A0);
  static const sky = Color(0xFF4CC9F0);

  // Difficulty gradients
  static const easyGrad = [Color(0xFF06D6A0), Color(0xFF4CC9F0)];
  static const mediumGrad = [Color(0xFFFFD166), Color(0xFFFFA94D)];
  static const epicGrad = [Color(0xFFEF476F), Color(0xFF7B2CBF)];

  // Hero text gradient (warm rainbow)
  static const heroGrad = [Color(0xFFFFD166), Color(0xFFEF476F), Color(0xFF7B2CBF)];

  // Surface gradients
  static const screenGrad = [bgViolet, bgDeep, bgPlum];
}

ThemeData buildAppTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    textTheme: GoogleFonts.heeboTextTheme(base.textTheme).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    colorScheme: const ColorScheme.dark(
      primary: AppPalette.gold,
      secondary: AppPalette.green,
      surface: AppPalette.surface,
    ),
    scaffoldBackgroundColor: AppPalette.bgDeep,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}

TextStyle displayFont({
  double size = 24,
  FontWeight weight = FontWeight.w800,
  Color color = Colors.white,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.rubik(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

TextStyle bodyFont({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = Colors.white,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.heebo(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

TextStyle monoFont({double size = 14, Color color = Colors.white}) {
  return GoogleFonts.firaCode(
    fontSize: size,
    color: color,
    fontWeight: FontWeight.w700,
  );
}
