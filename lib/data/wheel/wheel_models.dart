/// أنواع جوائز عجلة الحظ. `coins`/`hintCharge`/`jarBooster` — كل نوع غير
/// coins يُمنح فعليا ويُحفَظ (لا يُفقَد)، لكن لا مسار لعب حي بعد يستهلكه:
/// شحنات التلميح المصرفية (hintCharge) لا يفحصها أي زر تلميح حالي في
/// GameScreen (تلك الأزرار تخصم نقاطا مباشرة)،
/// ومعزّز الجرّة (jarBooster) يضاعف مضاعِفا على جمع كلمات إضافية حقيقي
/// لا يزال صفرا (راجع الجسر المؤقت في progression_repository.dart). هذا
/// نفس الفجوة الموثَّقة مرارا عبر هذه الجلسة (محتوى المراحل الجديدة لم
/// يُؤلَّف بعد)، لا فجوة جديدة.
enum WheelPrizeType { coins, hintCharge, jarBooster }

/// قطاع واحد من قطاعات عجلة الحظ الثمانية.
class WheelSegmentDef {
  final WheelPrizeType type;

  /// للعملات: المبلغ الممنوح. لغيرها: عدد الوحدات (1 لكليهما حاليا).
  final int value;

  /// وزن نسبي — يُقسَم على مجموع كل الأوزان ليعطي الاحتمال الفعلي
  final int weight;

  const WheelSegmentDef({
    required this.type,
    required this.value,
    required this.weight,
  });
}
