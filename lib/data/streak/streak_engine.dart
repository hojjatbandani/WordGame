// محرّك سلسلة الأيام المتتالية — منطق صرف بالكامل، بلا استيراد Flutter
// وبلا أي DateTime.now()/Random() داخلي: كل دالة تأخذ [now] صراحة، فتُختبر
// حتميا بلا شجرة ودجات ولا SharedPreferences ولا Supabase.
//
// التعريف: تُحتسب أيام متتالية فيها نشاط واحد على الأقل — إتمام مرحلة —
// بحسب اليوم التقويمي *المحلي* للجهاز، لا UTC. هذا يجعل المحرّك محليا
// بالكامل: لا خادم ولا اتصال في مسار السلسلة إطلاقا.
//
// كل يوم جديد يُؤمَّن هنا يزيد كذلك عدّاد [StatKey.daysPlayed] الذي
// تُبنى عليه إنجازات المثابرة — راجع StreakNotifier في providers.dart.
//
// التجميد: يُستهلك "تلقائيا عند منتصف الليل" فعليا يعني: في أول قراءة
// لاحقة للحالة (فتح التطبيق التالي) تُكتشف أي فجوة يوم كامل مضت فعلا
// وتُغطّى بتجميد إن أمكن، بدل تفويت فحص لحظي عند منتصف الليل بالضبط —
// النتيجة النهائية واحدة (يوم الفجوة يبقى "مؤمَّنا" ما دام تجميد يغطّيه)
// بلا حاجة لعملية خلفية تعمل والتطبيق مغلق.

import 'streak_models.dart';

class StreakEngine {
  const StreakEngine._();

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// عدد الأيام التقويمية من [from] إلى [to]. يُحسب على تواريخ UTC
  /// مجرّدة من الساعة: فارق التوقيت المحلي عبر يوم تغيير التوقيت
  /// الصيفي (23 ساعة) كان يجعل `difference().inDays` يقتطع يومين إلى
  /// واحد فيفوت يوم فجوة كاملا.
  static int _calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  static DateTime _parseDateKey(String key) {
    final parts = key.split('-');
    return DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  /// نقطة الدخول الوحيدة لتسوية أي فجوة ماضية — يجب استدعاؤها أولا دوما
  /// (تستدعيها [recordActivityToday] داخليا، فلا حاجة لاستدعائها يدويا
  /// قبلها، لكن استدعها بمفردها لقراءة الحالة "كما هي الآن" دون تسجيل أي
  /// نشاط جديد، مثلا عند فتح الشاشة الرئيسية فقط).
  ///
  /// فجوة يوم واحد فأكثر ممتلئة (يوم كامل مضى بلا أي تسجيل) تُغطّى
  /// بتجميد واحد لكل يوم إن كان الرصيد كافيا؛ وإلا تنكسر السلسلة، لكن
  /// التجميدات المتبقية *لا تُستهلك عبثا* (لا عقاب مضاعف على كسر أصلا
  /// حادث).
  static StreakState reconcile({
    required StreakState state,
    required DateTime now,
  }) {
    final securedKey = state.securedThroughDateKey;
    if (securedKey == null) return state; // لا سلسلة بدأت بعد، لا فجوة لتسويتها

    final securedDate = _parseDateKey(securedKey);
    final today = _dateOnly(now);
    final daysElapsed = _calendarDaysBetween(securedDate, today);
    final gapDays = daysElapsed - 1; // اليوم التالي مباشرة ليس فجوة، هو المتوقَّع

    if (gapDays <= 0) return state; // إمّا اليوم نفسه، أو أمس فقط — لا فجوة كاملة بعد

    if (state.freezesHeld >= gapDays) {
      // بإضافة أيام تقويمية لا Duration: عبر تغيير التوقيت الصيفي يومٌ
      // من 23 أو 25 ساعة يجعل Duration(days:) تهبط على اليوم الخطأ
      final newSecuredDate = DateTime(
        securedDate.year,
        securedDate.month,
        securedDate.day + gapDays,
      );
      return state.copyWith(
        freezesHeld: state.freezesHeld - gapDays,
        securedThroughDateKey: dateKey(newSecuredDate),
        pendingFreezeNoticeCount: state.pendingFreezeNoticeCount + gapDays,
      );
    }

    return state.copyWith(currentStreak: 0, clearSecuredThroughDateKey: true);
  }

  /// يسجّل نشاطا (إتمام مرحلة) في اليوم المحلي
  /// [now]. لا تأثير إن كان اليوم مؤمَّنا فعلا (مرات لعب متعددة في نفس
  /// اليوم لا تُحتسب أكثر من مرة).
  static StreakState recordActivityToday({
    required StreakState state,
    required DateTime now,
  }) {
    final reconciled = reconcile(state: state, now: now);
    final todayKey = dateKey(_dateOnly(now));
    if (reconciled.securedThroughDateKey == todayKey) return reconciled;

    final newStreak = reconciled.currentStreak + 1;
    return reconciled.copyWith(
      currentStreak: newStreak,
      longestStreak:
          newStreak > reconciled.longestStreak ? newStreak : reconciled.longestStreak,
      securedThroughDateKey: todayKey,
    );
  }

  /// يمنح تجميدا مجانيا واحدا لكل معلَم "يوم-N" (BalanceConfig.streakFreezeGrantEveryDays)
  /// جديد بلغته [longestStreak] منذ آخر منح، بحدود الحد الأقصى للتجميدات
  /// المحمولة — أي منح يتجاوز الحد يُهدَر بصمت (لا يُراكَم لوقت لاحق).
  static StreakState grantMilestoneFreezes({
    required StreakState state,
    required int grantEveryDays,
    required int maxHeld,
  }) {
    if (grantEveryDays <= 0) return state;
    final milestonesReached = state.longestStreak ~/ grantEveryDays;
    if (milestonesReached <= state.freezeMilestonesGranted) return state;

    final newGrants = milestonesReached - state.freezeMilestonesGranted;
    final newHeld = (state.freezesHeld + newGrants).clamp(0, maxHeld);
    return state.copyWith(
      freezesHeld: newHeld,
      freezeMilestonesGranted: milestonesReached,
    );
  }

  static bool canPurchaseFreeze({
    required StreakState state,
    required int maxHeld,
  }) =>
      state.freezesHeld < maxHeld;

  static StreakState addPurchasedFreeze({required StreakState state}) =>
      state.copyWith(freezesHeld: state.freezesHeld + 1);

  /// يأخذ عدد التجميدات المستهلكة تلقائيا منذ آخر مرة (ويصفّره) — النمط
  /// نفسه المتّبع في achievementsProvider.takeJustUnlocked: تُقرأ مرة
  /// واحدة، تُعرض للاعب، ثم تُستهلك، فلا تُعرض الرسالة مرتين لنفس الحدث.
  static (StreakState, int) takePendingFreezeNotice(StreakState state) {
    if (state.pendingFreezeNoticeCount == 0) return (state, 0);
    return (state.copyWith(pendingFreezeNoticeCount: 0),
        state.pendingFreezeNoticeCount);
  }
}
