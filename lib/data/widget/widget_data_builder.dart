// بناء لقطة الودجة من حالة اللعبة. منطق صرف: كل مدخل يُمرَّر صراحة
// (لا مزوّدات، ولا `DateTime.now()` داخلي)، فتُختبر قواعد الأولوية
// حتميا بلا شجرة ودجات ولا تخزين — نفس نمط notification_engine.dart.

import '../rewards/reward_track.dart';
import 'widget_data.dart';

class WidgetDataBuilder {
  const WidgetDataBuilder._();

  /// أي طبقة تتصدّر الودجة.
  ///
  /// القاعدة المطلوبة حرفيا، بترتيب اليومية ثم الأسبوعية ثم الشهرية:
  ///  1. جائزة **جاهزة للاستلام** الآن — الأقرب إلى فعل ممكن.
  ///  2. وإلا: أوّل طبقة تنتظر موعدها ولم تُستلم اليوم، تُعرض
  ///     **بتقدّمها** («4 / 7 أيام»). ولهذا تتنحّى اليومية بعد استلامها:
  ///     «✓ تم الاستلام» خبر منتهٍ، بينما تقدّم الأسبوعية خبر حيّ.
  ///  3. وإلا: أوّل طبقة لم تنتهِ — أي أن كل ما بقي استُلم اليوم، فتُعرض
  ///     حالته «✓ تم الاستلام · غدا مكافأة جديدة» بدل ودجة فارغة.
  ///  4. وإلا: لا شيء — اكتمل المسار كله.
  ///
  /// لماذا اليومية أولا لا الأثمن أولا (بخلاف ترتيب الإشعارات في
  /// notification_engine.dart): الإشعار مقاطعة واحدة يجب أن تحمل أثمن
  /// خبر، أما الودجة فمعروضة دوما — والأقرب إلى فعلٍ ممكن اليوم أنفع من
  /// الأثمن الذي لا يُستحقّ قبل شهر.
  static RewardTier? pickFocus(List<WidgetTierState> tiers) {
    for (final tier in tiers) {
      if (tier.isReady) return tier.tier;
    }
    for (final tier in tiers) {
      if (!tier.isComplete && !tier.claimedToday) return tier.tier;
    }
    for (final tier in tiers) {
      if (!tier.isComplete) return tier.tier;
    }
    return null;
  }

  static WidgetTierState tierState(
    RewardTier tier,
    RewardTrackState track,
    DateTime now,
  ) {
    final status = RewardTrackEngine.statusOf(tier, track, now);
    final period = tier.periodDays;
    final remaining = status.daysUntilReady;

    // كم يوما مضى من الدورة الحالية. الجاهزة تعرض دورتها مكتملة
    // (7/7) لا صفرا: «جاهزة» تعني أن المدّة انقضت بالفعل.
    final elapsed = remaining == null
        ? period
        : (period - remaining).clamp(0, period);

    return WidgetTierState(
      tier: tier,
      coins: tier.coins,
      claimed: status.claimed,
      totalClaims: status.totalClaims,
      isReady: status.isReady,
      isComplete: status.isComplete,
      claimedToday:
          track.progressOf(tier).lastClaimDay == RewardTrackEngine.dayOf(now),
      cycleElapsedDays: elapsed,
      cyclePeriodDays: period,
      daysUntilReady: remaining,
    );
  }

  static HomeWidgetData build({
    required RewardTrackState track,
    required DateTime now,
    required int diamonds,
    required int streakDays,
    required int stagesCompleted,
    required int chaptersCompleted,
    required int worldsCompleted,
    required String languageCode,
  }) {
    final tiers = [
      for (final tier in RewardTier.values) tierState(tier, track, now),
    ];
    return HomeWidgetData(
      diamonds: diamonds,
      streakDays: streakDays,
      tiers: tiers,
      focusTier: pickFocus(tiers),
      stagesCompleted: stagesCompleted,
      chaptersCompleted: chaptersCompleted,
      worldsCompleted: worldsCompleted,
      languageCode: languageCode,
      updatedAt: now,
    );
  }
}
