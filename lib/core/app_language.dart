import 'package:flutter/material.dart';

/// لغة واجهة التطبيق (القوائم وما حولها فقط — شاشة اللعب تبقى عربية دوما)
enum AppLanguage {
  ar,
  en;

  bool get isRtl => this == AppLanguage.ar;

  TextDirection get textDirection =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

  /// يختار النص المناسب حسب اللغة الحالية
  String t(String ar, String en) => this == AppLanguage.ar ? ar : en;
}
