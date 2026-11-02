// تسليم حزمة البداية على أقساط. Dart صرف — بلا Flutter وبلا ساعة
// داخلية: [now] والتاريخ المحفوظ معاملان صريحان، كبقية منطق الصرف في
// المشروع (login_calendar، rewarded_ads، ad_pacing).
//
// ═══ القاعدة الحاكمة: القسط لا يسقط أبدا ═══
//
// جدول التسليم موعدٌ لا مهلة. من اشترى ثم غاب أسبوعا يجد قسطيه
// بانتظاره، لا «فاتك». الفرق ليس لطفا بل حقّا: هذه أقساط سلعة دُفع
// ثمنها بمال حقيقي، وإسقاطها لغياب يوم استردادٌ مطلوب وتقييم نجمة
// واحدة — وهو أيضا ما يفصل هذا الجدول عن تقويم الدخول اليومي
// (login_calendar.dart) الذي يكافئ عادة مجانية.
//
// وحدّ اليوم الواحد يبقى: قسط واحد في اليوم التقويمي مهما تأخّر
// اللاعب. بلا هذا الحدّ يُقبض الثلاثة في جلسة واحدة، فيصير التقسيط
// دفعة واحدة بثلاث نقرات — ويسقط السبب الوحيد لوجوده.

import 'store_catalog.dart';

/// قسط واحد: ترتيبه، وما يحمله
class StarterPackInstallment {
  /// 1-based — رقم القسط لا رقم اليوم التقويمي
  final int number;

  final int coins;
  final int hintCharges;

  const StarterPackInstallment({
    required this.number,
    required this.coins,
    required this.hintCharges,
  });

  /// أول قسط: يُمنح لحظة الشراء بلا مطالبة
  bool get isFirst => number == 1;
}

/// لماذا لا قسط الآن — يُقرأ في الواجهة وفي التحليلات، فلا يُخمَّن
/// «لماذا لا يظهر الزر»
enum StarterPackBlock {
  /// لم يشترِ الحزمة
  notOwned,

  /// قُبضت الأقساط كلها
  fullyDelivered,

  /// قُبض قسط اليوم — التالي غدا (وهو محفوظ، لا يسقط)
  claimedToday,
}

/// نتيجة السؤال «هل هناك قسط الآن؟»
class StarterPackStatus {
  /// القسط المتاح الآن، أو null
  final StarterPackInstallment? claimable;

  /// سبب المنع حين لا قسط
  final StarterPackBlock? block;

  /// كم قسطا بقي بعد الحالي (للعرض: «٢ من ٣»)
  final int remaining;

  const StarterPackStatus({
    required this.claimable,
    required this.block,
    required this.remaining,
  });

  bool get hasClaimable => claimable != null;

  /// انتهت الحزمة تماما — لا بطاقة ولا شارة بعد اليوم
  bool get isFullyDelivered => block == StarterPackBlock.fullyDelivered;
}

class StarterPackDelivery {
  const StarterPackDelivery._();

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static int get totalInstallments => StoreCatalog.starterPackDays;

  /// القسط رقم [number] (1-based). التلميحات كلها في الأول.
  static StarterPackInstallment installment(int number) {
    if (number < 1 || number > totalInstallments) {
      throw ArgumentError('رقم القسط خارج المدى: $number');
    }
    return StarterPackInstallment(
      number: number,
      coins: StoreCatalog.starterPackDailyCoins[number - 1],
      hintCharges: number == 1 ? StoreCatalog.starterPackHintCharges : 0,
    );
  }

  static List<StarterPackInstallment> get all => [
    for (var i = 1; i <= totalInstallments; i++) installment(i),
  ];

  /// حالة التسليم الآن.
  ///
  /// [claimedCount] كم قسطا قُبض (0..[totalInstallments])،
  /// [lastClaimDate] مفتاح يوم آخر قبض (yyyy-MM-dd) أو null.
  ///
  /// لا يقارن هذا التابع تاريخ الشراء بشيء ولا يحسب «كم يوما مضى»:
  /// الموضع يتقدّم بالقبض وحده. حسابُ الأيام كان سيسقط أقساط الغائب
  /// أو يمنحه ثلاثة دفعة واحدة عند عودته — وكلاهما خطأ.
  static StarterPackStatus status({
    required bool owned,
    required int claimedCount,
    required String? lastClaimDate,
    required DateTime now,
  }) {
    final claimed = claimedCount.clamp(0, totalInstallments);
    final remaining = totalInstallments - claimed;

    if (!owned) {
      return StarterPackStatus(
        claimable: null,
        block: StarterPackBlock.notOwned,
        remaining: remaining,
      );
    }
    if (remaining <= 0) {
      return const StarterPackStatus(
        claimable: null,
        block: StarterPackBlock.fullyDelivered,
        remaining: 0,
      );
    }
    // القسط الأول يُمنح مع الشراء؛ لو بقي غير مقبوض (فشلت الكتابة، أو
    // أُغلق التطبيق بينهما) فهو مستحقّ الآن مهما كان تاريخ اليوم
    if (claimed > 0 && lastClaimDate == dateKey(now)) {
      return StarterPackStatus(
        claimable: null,
        block: StarterPackBlock.claimedToday,
        remaining: remaining,
      );
    }
    return StarterPackStatus(
      claimable: installment(claimed + 1),
      block: null,
      remaining: remaining,
    );
  }
}
