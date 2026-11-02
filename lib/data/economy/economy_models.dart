// أنواع صرفة لمحرّك اقتصاد العملات. بلا استيراد Flutter، قابلة للاختبار
// كوحدة دون أي شجرة ودجات.

/// نتيجة عملية قد تفشل (نفاد رصيد مثلا) بدل رمي استثناء لحالة متوقّعة
/// تماما في تدفّق اللعب العادي — الاستثناء يبقى لأخطاء برمجية حقيقية
/// (مبلغ سالب مثلا)، لا لـ"لا يملك اللاعب مالا كافيا".
class Result<T> {
  final bool isSuccess;
  final T? value;
  final String? errorMessage;

  const Result._(this.isSuccess, this.value, this.errorMessage);

  factory Result.ok([T? value]) => Result._(true, value, null);
  factory Result.fail(String message) => Result._(false, null, message);

  bool get isFailure => !isSuccess;
}

/// أنواع التلميح — "أي مرحلة تصعيد" (أول/ثانٍ/ثالث..) ليست جزءا من هذا
/// التعداد بقصد: هي عدد صحيح (hintsUsedThisStage) يُمرَّر كمعامل منفصل،
/// لا نوعا مستقلا — راجع EconomyService.quoteHintCost.
enum HintType {
  /// كشف أول حرف من كلمة يختارها اللاعب
  revealFirstLetter,

  /// كشف حرف عشوائي من كلمة غير محلولة
  revealRandomLetter,

  /// كشف الكلمة كاملة — متاح من التلميح الثاني فصاعدا فقط
  revealEntireWord,
}

enum SpendReason {
  hint,
  revealEntireWord,
  skipStage,
  streakFreeze,
  jarBooster,
  cosmetic,

  /// إنفاق من سطح لم يُصنَّف بعد. موجود لأن كل إنفاق يمرّ بالمحرّك منذ
  /// ربطه بالواجهة، ومنفذٌ جديد بلا تصنيف يجب أن يُسجَّل لا أن يُمنع.
  other,
}

enum EarnReason {
  stageClear,
  coreWord,
  bonusWord,
  perfectStageBonus,
  bossStageBonus,
  chapterComplete,
  chapterChest,
  worldComplete,
  safetyModeAd,
  safetyModeMiniChallenge,
  safetyModeFreeGrant,

  /// مصادر الكسب خارج حلقة اللعب الأساسية: المكافأة اليومية، عجلة
  /// الحظ، الإعلان الجائزي، المهمات، الدعوة، المشاركة، الإنجازات،
  /// حزمة البداية، الشراء. اسمها الدقيق يُسجَّل في التحليلات نصّا
  /// (`reason`) — التعداد هنا يصنّف أثر الاقتصاد لا مصدر الحدث.
  other,
}
