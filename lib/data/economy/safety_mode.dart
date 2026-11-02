// وضع الأمان (أرضية العملات). منطق صرف — لا يقرأ الساعة ولا يخزّن شيئا؛
// [DateTime now] و[lastFreeGrantDateKey] معاملات صريحة بنفس فلسفة
// progression_engine.dart، فيبقى قابلا للاختبار بمدخلات ثابتة. تخزين
// [lastFreeGrantDateKey] فعليا (SharedPreferences) مسؤولية طبقة تخزين
// لاحقة، تماما كما فُصلت progression_repository.dart عن منطقها الصرف.

import '../../config/balance_config.dart';

/// عمدا لا يوجد أي حقل "شراء" هنا — هذا هو التطبيق الفعلي لقاعدة "لا زر
/// شراء في هذه الورقة أبدا": واجهة تُبنى حصرا من هذا الكائن لا تملك حتى
/// خيار عرض زر كهذا، لا مجرد اتفاق يمكن نسيانه لاحقا في مكان آخر.
class SafetyModeSheetOffer {
  final bool canWatchAd; // يخضع أيضا لميزانية الإعلانات اليومية (Prompt 10)
  final bool canPlayMiniChallenge;
  final bool canClaimFreeGrant;

  const SafetyModeSheetOffer({
    required this.canWatchAd,
    required this.canPlayMiniChallenge,
    required this.canClaimFreeGrant,
  });
}

class SafetyMode {
  const SafetyMode._();

  /// الشرطان معا (AND): عملات أقل من العتبة، وفشل/تخلٍّ عن المرحلة
  /// الحالية بالحد الأدنى المطلوب من المرات
  static bool shouldTrigger({
    required int coins,
    required int failedOrAbandonedAttemptsThisStage,
  }) =>
      coins < BalanceConfig.safetyModeCoinThreshold &&
      failedOrAbandonedAttemptsThisStage >=
          BalanceConfig.safetyModeMinFailedAttempts;

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// خيار "منحة مجانية" متاح مرة واحدة فقط في اليوم التقويمي الواحد.
  /// مشاهدة الإعلان تخضع لميزانية إعلانات لم تُبنَ بعد (Prompt 10) —
  /// [adBudgetRemaining] معامل يمرّره المستدعي من تلك الميزانية حين
  /// تُبنى؛ true افتراضيا الآن فلا يُحجَب الخيار الأول بلا سبب.
  static SafetyModeSheetOffer buildOffer({
    required String? lastFreeGrantDateKey,
    required DateTime now,
    bool adBudgetRemaining = true,
  }) {
    final today = dateKey(now);
    return SafetyModeSheetOffer(
      canWatchAd: adBudgetRemaining,
      canPlayMiniChallenge: true,
      canClaimFreeGrant: lastFreeGrantDateKey != today,
    );
  }
}
