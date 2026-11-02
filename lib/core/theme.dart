import 'package:flutter/material.dart';

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

  static const String fontFamily = 'IRANSans';

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
      fontFamily: fontFamily,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      // لون نصّ الرسائل المنبثقة صراحة: الافتراضي في Material 3 هو
      // onInverseSurface، وهو لون *داكن* في سمة داكنة. كل رسائل التطبيق
      // تُمرّر خلفية داكنة (HurufTheme.surface) وتترك لون النصّ
      // للافتراضي، فكانت تظهر لوحا داكنا فارغا بلا كلمة واحدة مقروءة.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: gold,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rButton),
        ),
      ),
    );
  }

  // مقياس المسافات: 4, 8, 12, 16, 24, 32, 48, 64
  static const double s1 = 4, s2 = 8, s3 = 12, s4 = 16;
  static const double s5 = 24, s6 = 32, s7 = 48, s8 = 64;

  // أنصاف الأقطار
  static const double rCard = 24, rButton = 16, rTile = 12;

  // مقاسات الأيقونات كرموز تصميم (بدل قيم عشوائية)
  static const double iconSm = 20, iconMd = 24, iconLg = 32;

  /// أدنى مساحة لمس مقبولة (Apple 44pt / Material 48dp)
  static const double minTouch = 48;

  // رموز الحركة: مدّة واحدة موحّدة لكل التطبيق
  static const Duration durFast = Duration(milliseconds: 150);
  static const Duration durBase = Duration(milliseconds: 220);
  static const Duration durSlow = Duration(milliseconds: 320);

  /// الدخول يبطئ في النهاية، والخروج يسرّع — قاعدة Material
  static const Curve curveEnter = Curves.easeOutCubic;
  static const Curve curveExit = Curves.easeInCubic;
}

/// اختصارات سياقية للوصولية وتقليل الحركة
extension HurufContext on BuildContext {
  /// هل طلب المستخدم تقليل الحركة من إعدادات النظام؟
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}
