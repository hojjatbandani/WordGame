// اختيار قطاع عجلة الحظ الفائز — منطق صرف بالكامل، بلا استيراد Flutter.
// [rng] يُمرَّر صراحة (بدل Random() داخلي) كي يُختبر حتميا بقيم بذرة
// معروفة، تماما كنمط economy/chapter_chest.dart.

import 'dart:math';

import 'wheel_models.dart';

class WheelEngine {
  const WheelEngine._();

  /// يختار فهرس قطاع بحسب أوزانه النسبية. الأوزان لا يلزم أن تجمع إلى
  /// 100 بالضبط — تُقسَم على مجموعها الفعلي دوما.
  static int pickSegmentIndex(List<WheelSegmentDef> segments, Random rng) {
    final totalWeight = segments.fold<int>(0, (sum, s) => sum + s.weight);
    var roll = rng.nextInt(totalWeight);
    for (var i = 0; i < segments.length; i++) {
      if (roll < segments[i].weight) return i;
      roll -= segments[i].weight;
    }
    // احتياط رياضي بحت (roll دوما < totalWeight بحكم nextInt) — لا يُفترض
    // الوصول إليه أبدا، لكن أفضل من رمي استثناء لو تغيّر شيء لاحقا
    return segments.length - 1;
  }
}
