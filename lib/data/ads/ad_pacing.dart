// وحدة القرار الوحيدة للإعلانات البينية. Dart صرف — بلا استيراد Flutter،
// بلا قراءة ساعة، بلا تخزين: كل مدخل صريح، فتُختبر كل قاعدة بمدخلات
// ثابتة.
//
// «وحدة واحدة» ليست أسلوبا معماريا هنا بل شرط صحّة. القواعد الصارمة
// أدناه (لا إعلان بعد فشل، لا إعلان داخل تسعين ثانية من آخر إعلان، لا
// إعلان قبل المكافأة اليومية...) لو تفرّقت على شاشة اللعب وشاشة الخريطة
// وشاشة التحدي لكسرها أول مسار جديد يُضاف بعد شهور، بصمت، بلا اختبار
// يسقط. هنا تُكسر واحدة فقط: [AdPacing.decideInterstitial].

import '../../config/balance_config.dart';

/// لماذا مُنع الإعلان. القرار لا يعيد bool: عند تحليل «لماذا لا تُعرض
/// إعلانات في اليوم الأول» يجب أن يُقرأ السبب لا أن يُخمَّن.
enum AdBlockReason {
  /// سياسة القوالب لهذا البناء لا تسمح بالبيني (ads/ad_policy.dart) —
  /// لا إعداد عن بعد ولا تخزين يرفع هذا المنع
  formatDisabled,

  /// اشترى إزالة الإعلانات — منع دائم
  adsRemoved,

  /// مفتاح الإيقاف عن بعد أطفأ الإعلانات البينية
  killSwitch,

  /// قبل [BalanceConfig.interstitialFirstEligibleStage]
  tooEarlyInGame,

  /// لم يحن الدور بعد بحسب إيقاع المدى الحالي
  cadenceNotReached,

  /// المرحلة فُشلت أو غُودرت — الإعلان بعد الإخفاق يضاعف الإحباط
  stageNotCleared,

  /// تسلسل مكافأة إتمام المرحلة لم ينته بعد
  rewardSequenceRunning,

  /// لحظة محميّة: مكافأة يومية، عجلة، صندوق، أو ترقية مستوى
  protectedMoment,

  /// أقل من [BalanceConfig.adGlobalCooldown] منذ آخر إعلان
  globalCooldown,

  /// خلال 24 ساعة من عملية شراء
  recentPurchase,

  /// بداية باردة قبل أول لعب في الجلسة
  coldStart,
}

class InterstitialDecision {
  final bool allowed;
  final AdBlockReason? reason;

  const InterstitialDecision._(this.allowed, this.reason);

  static const _allowed = InterstitialDecision._(true, null);
  const InterstitialDecision.blocked(this.reason) : allowed = false;

  @override
  String toString() =>
      allowed ? 'InterstitialDecision(allowed)' : 'InterstitialDecision($reason)';
}

/// كل ما يحتاجه القرار. كائن واحد بدل عشرة معاملات مرتّبة، كي لا يقع
/// خطأ ترتيب صامت عند إضافة قاعدة جديدة.
class InterstitialRequest {
  /// رقم المرحلة التي انتهت للتو (ترتيبها في اللعبة كلها، لا داخل فصلها)
  final int stageNumber;

  /// كم إتمام مرحلة مؤهَّل مضى منذ آخر إعلان بيني
  final int completionsSinceLastInterstitial;

  /// سياسة القوالب لهذا البناء تسمح بالبيني. إلزامي بلا قيمة افتراضية:
  /// طلب لا يقول صراحة إن القالب مسموح لا يُفترض أنه مسموح
  final bool formatAllowed;

  final bool adsRemoved;

  /// مفتاح الإيقاف عن بعد (ads_interstitial_enabled)
  final bool interstitialsEnabled;

  /// أُتمّت المرحلة فعلا. false = فشل أو مغادرة
  final bool stageCleared;

  /// انتهى عرض مكافآت الإتمام (عملات، صندوق) كاملا
  final bool rewardSequenceComplete;

  /// بانتظار العرض الآن: مكافأة يومية أو عجلة أو صندوق أو ترقية مستوى
  final bool protectedMomentPending;

  /// وقعت لعبة واحدة على الأقل في هذه الجلسة
  final bool hadGameplayThisSession;

  final DateTime now;
  final DateTime? lastAdShownAt;
  final DateTime? lastPurchaseAt;

  const InterstitialRequest({
    required this.stageNumber,
    required this.completionsSinceLastInterstitial,
    required this.formatAllowed,
    required this.adsRemoved,
    required this.stageCleared,
    required this.rewardSequenceComplete,
    required this.hadGameplayThisSession,
    required this.now,
    this.interstitialsEnabled = true,
    this.protectedMomentPending = false,
    this.lastAdShownAt,
    this.lastPurchaseAt,
  });
}

class AdPacing {
  const AdPacing._();

  /// القرار الوحيد. الترتيب مقصود: سياسة البناء أولا، ثم المنع الدائم
  /// (فلا نحسب إيقاعا لمن اشترى إزالة الإعلانات)، ثم القواعد الصارمة، ثم
  /// الإيقاع أخيرا.
  static InterstitialDecision decideInterstitial(InterstitialRequest r) {
    if (!r.formatAllowed) {
      return const InterstitialDecision.blocked(AdBlockReason.formatDisabled);
    }
    if (r.adsRemoved) {
      return const InterstitialDecision.blocked(AdBlockReason.adsRemoved);
    }
    if (!r.interstitialsEnabled) {
      return const InterstitialDecision.blocked(AdBlockReason.killSwitch);
    }

    // ── القواعد الصارمة ──
    if (!r.hadGameplayThisSession) {
      return const InterstitialDecision.blocked(AdBlockReason.coldStart);
    }
    if (!r.stageCleared) {
      return const InterstitialDecision.blocked(AdBlockReason.stageNotCleared);
    }
    if (!r.rewardSequenceComplete) {
      return const InterstitialDecision.blocked(
          AdBlockReason.rewardSequenceRunning);
    }
    if (r.protectedMomentPending) {
      return const InterstitialDecision.blocked(AdBlockReason.protectedMoment);
    }
    if (_withinPurchaseSuppression(r)) {
      return const InterstitialDecision.blocked(AdBlockReason.recentPurchase);
    }
    if (_withinGlobalCooldown(r)) {
      return const InterstitialDecision.blocked(AdBlockReason.globalCooldown);
    }

    // ── الإيقاع ──
    final cadence = BalanceConfig.interstitialCadenceForStage(r.stageNumber);
    if (cadence <= 0) {
      return const InterstitialDecision.blocked(AdBlockReason.tooEarlyInGame);
    }
    if (r.completionsSinceLastInterstitial < cadence) {
      return const InterstitialDecision.blocked(
          AdBlockReason.cadenceNotReached);
    }

    return InterstitialDecision._allowed;
  }

  static bool _withinGlobalCooldown(InterstitialRequest r) {
    final last = r.lastAdShownAt;
    if (last == null) return false;
    // فارق سالب (ساعة الجهاز رجعت للخلف) يُعامل كأنه داخل المهلة:
    // الخطأ في صالح اللاعب دوما حين لا نثق بالساعة
    return r.now.difference(last) < BalanceConfig.adGlobalCooldown;
  }

  static bool _withinPurchaseSuppression(InterstitialRequest r) {
    final last = r.lastPurchaseAt;
    if (last == null) return false;
    return r.now.difference(last) <
        BalanceConfig.interstitialSuppressionAfterPurchase;
  }
}
