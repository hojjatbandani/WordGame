import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// تم «ليل الصحراء» — الهوية البصرية الافتراضية
class HurufTheme {
  static const Color bgTop = Color(0xFF0A0E27);
  static const Color bgBottom = Color(0xFF1A1F3A);
  static const Color gold = Color(0xFFF4C430);
  static const Color goldDark = Color(0xFFC99A10);
  static const Color surface = Color(0xFF171C36);
  static const Color tileEmpty = Color(0xFF232A4D);
  static const Color textPrimary = Color(0xFFF2F1EC);
  static const Color textSecondary = Color(0xFF9AA0BE);
  static const Color success = Color(0xFF34E89E);
  static const Color error = Color(0xFFFF6B6B);

  static const Gradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgBottom],
  );

  static const Gradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE082), gold, goldDark],
  );

  static ThemeData build() {
    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgTop,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: success,
        surface: surface,
        error: error,
      ),
      useMaterial3: true,
    );
    return base.copyWith(
      textTheme: GoogleFonts.cairoTextTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }

  // مقياس المسافات: 4, 8, 12, 16, 24, 32, 48, 64
  static const double s1 = 4, s2 = 8, s3 = 12, s4 = 16;
  static const double s5 = 24, s6 = 32, s7 = 48, s8 = 64;

  // أنصاف الأقطار
  static const double rCard = 24, rButton = 16, rTile = 12;
}
