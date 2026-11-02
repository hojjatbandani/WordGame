// مسار الجوائز: ثلاث طبقات متوازية (يومية/أسبوعية/شهرية) لكل واحدة عدد
// محدود من المطالبات، فينتهي المسار كله بعد ستة أشهر. منطق صرف بالكامل:
// بلا استيراد Flutter وبلا `DateTime.now()` داخلي — «اليوم» يُمرَّر دوما
// من المستدعي، تماما كنمط notification_engine.dart، فيبقى كل شيء قابلا
// للاختبار الحتمي بلا ساعة حقيقية ولا انتظار ستة أشهر.
//
// لماذا يُقاس التقدّم بالمطالبات لا بالتقويم: من يفوته يوم لا يخسر
// جائزته بل تنتظره — نفس عقد تقويم الدخول (lib/data/login_calendar.dart:
// «الفوات لا يصفّر موضع التقويم أبدا»). الوقت هنا شرط *فتح* المطالبة
// التالية، لا شرط فقدان السابقة. البديل (تثبيت كل جائزة بيوم تقويمي من
// بداية المسار) كان يعني أن غياب أسبوع واحد يمحو الطبقة اليومية كلها من
// لاعب لم يرها أصلا.
//
// جدول لاعب منتظم — اليوم 0 هو أول يوم يبدأ فيه المسار:
//   اليومية  : الأيام 0..29       — 30 مطالبة، تنتهي بعد شهر
//   الأسبوعية: الأيام 7، 14، 21، 28 — 4 مطالبات، تنتهي بعد شهر
//   الشهرية  : الأيام 30، 60 .. 180 — 6 مطالبات، تنتهي بعد ستة أشهر
//
// ملاحظة على الواجهة: لا شيء في شاشة الجوائز يعرض هذه الأعداد للاعب —
// لا «3 من 30» ولا شريط تقدّم ولا «بقي لك N». الطبقة المنتهية تختفي
// بدل أن تعلن انتهاءها. راجع rewards_screen.dart لسبب ذلك.

import 'dart:convert';

import '../../config/balance_config.dart';

enum RewardTier { daily, weekly, monthly }

extension RewardTierDef on RewardTier {
  /// عدد الألماسات في المطالبة الواحدة
  int get coins => switch (this) {
    RewardTier.daily => BalanceConfig.rewardTrackDailyCoins,
    RewardTier.weekly => BalanceConfig.rewardTrackWeeklyCoins,
    RewardTier.monthly => BalanceConfig.rewardTrackMonthlyCoins,
  };

  /// كم مطالبة قبل أن تنتهي هذه الطبقة نهائيا
  int get totalClaims => switch (this) {
    RewardTier.daily => BalanceConfig.rewardTrackDailyClaims,
    RewardTier.weekly => BalanceConfig.rewardTrackWeeklyClaims,
    RewardTier.monthly => BalanceConfig.rewardTrackMonthlyClaims,
  };

  /// كم يوما تقويميا بين مطالبة وأخرى. بنيوي لا توازني — «يومية» تعني
  /// يوما و«أسبوعية» تعني أسبوعا، فلا يُضبط عن بعد مع بقية الأرقام.
  int get periodDays => switch (this) {
    RewardTier.daily => 1,
    RewardTier.weekly => 7,
    RewardTier.monthly => 30,
  };

  /// مجموع ما تمنحه الطبقة على مدى المسار كله
  int get totalCoins => coins * totalClaims;
}

/// تقدّم طبقة واحدة. [lastClaimDay] يوم تقويمي بلا وقت (منتصف الليل
/// المحلي) — الساعة لا معنى لها هنا، ومقارنة لحظتين بفارق ساعات كانت
/// تجعل «مرّ يوم» صحيحة أو خاطئة حسب ساعة المطالبة السابقة.
class RewardTierProgress {
  final int claimed;
  final DateTime? lastClaimDay;

  const RewardTierProgress({this.claimed = 0, this.lastClaimDay});
}

/// حالة المسار كاملة. [startDay] هو اليوم الذي بدأ فيه المسار فعلا (أول
/// فتح للعبة بعد وصول الميزة) لا يوم تثبيت اللعبة: لاعب قديم يبدأ مساره
/// من اليوم، لا من ماضٍ انقضت فيه مواعيده كلها بلا أن يراها.
class RewardTrackState {
  final DateTime startDay;
  final Map<RewardTier, RewardTierProgress> tiers;

  const RewardTrackState({required this.startDay, required this.tiers});

  /// مسار جديد لم يُطالَب فيه بشيء بعد
  factory RewardTrackState.fresh(DateTime today) => RewardTrackState(
    startDay: RewardTrackEngine.dayOf(today),
    tiers: const {},
  );

  RewardTierProgress progressOf(RewardTier tier) =>
      tiers[tier] ?? const RewardTierProgress();

  RewardTrackState withTier(RewardTier tier, RewardTierProgress progress) =>
      RewardTrackState(
        startDay: startDay,
        tiers: {...tiers, tier: progress},
      );

  // ─────────────────────── التخزين ───────────────────────
  //
  // مفتاح واحد بصيغة JSON بدل سبعة مفاتيح متفرّقة في SharedPreferences
  // — نفس نمط `daily_missions_json`. التواريخ نصّ `yyyy-mm-dd`: ما
  // يُخزَّن يوم لا لحظة، وISO كامل كان يوهم بدقّة ساعة لا وجود لها.

  Map<String, Object?> toJson() => {
    'start': _encodeDay(startDay),
    for (final entry in tiers.entries)
      entry.key.name: {
        'claimed': entry.value.claimed,
        if (entry.value.lastClaimDay != null)
          'last': _encodeDay(entry.value.lastClaimDay!),
      },
  };

  String encode() => jsonEncode(toJson());

  /// null إن كان النصّ غائبا أو تالفا — يعامله المستدعي كمسار لم يبدأ
  /// بعد. تلف مخزَّن لا يجوز أن يُسقط التطبيق عند الإقلاع.
  static RewardTrackState? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final start = _decodeDay(json['start']);
      if (start == null) return null;
      final tiers = <RewardTier, RewardTierProgress>{};
      for (final tier in RewardTier.values) {
        final node = json[tier.name];
        if (node is! Map) continue;
        final claimed = node['claimed'];
        tiers[tier] = RewardTierProgress(
          claimed: claimed is int ? claimed : 0,
          lastClaimDay: _decodeDay(node['last']),
        );
      }
      return RewardTrackState(startDay: start, tiers: tiers);
    } catch (_) {
      return null;
    }
  }

  static String _encodeDay(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static DateTime? _decodeDay(Object? raw) {
    if (raw is! String) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }
}

/// لقطة جاهزة للعرض عن طبقة واحدة في يوم بعينه — الواجهة لا تحسب شيئا
/// بنفسها، فلا تنحرف قواعد الأهلية بين شاشة وإشعار.
class RewardTierStatus {
  final RewardTier tier;

  /// كم مطالبة تمّت فعلا (0..[totalClaims])
  final int claimed;

  /// كم يوما بقي حتى تُفتح المطالبة التالية — 0 يعني جاهزة الآن،
  /// و`null` يعني لا مطالبة تالية أصلا (انتهت الطبقة)
  final int? daysUntilReady;

  const RewardTierStatus({
    required this.tier,
    required this.claimed,
    required this.daysUntilReady,
  });

  int get totalClaims => tier.totalClaims;
  int get coins => tier.coins;

  bool get isComplete => claimed >= totalClaims;
  bool get isReady => !isComplete && daysUntilReady == 0;

  /// كم مطالبة باقية — يشمل الجاهزة الآن
  int get remainingClaims => (totalClaims - claimed).clamp(0, totalClaims);
}

class RewardTrackEngine {
  const RewardTrackEngine._();

  /// اليوم التقويمي المحلي بلا وقت
  static DateTime dayOf(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);

  /// جمع أيام تقويمية لا `Duration`: عبر يوم تغيير التوقيت الصيفي كان
  /// الجمع بالساعات يهبط على 23:00 من اليوم السابق فيُفتح الموعد قبل
  /// أوانه بيوم — نفس علّة `MissionEngine.mostRecentMonday`.
  static DateTime addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  /// فارق الأيام التقويمية بين يومين. يُحسَب بـUTC لأن الطرح المحلي عبر
  /// تغيير التوقيت الصيفي يعطي 23 أو 25 ساعة، و`inDays` يبترها إلى صفر
  /// أو يوم زائد.
  static int daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  /// أول يوم تصبح فيه الطبقة جاهزة إن لم يُطالَب بها قط.
  ///
  /// اليومية جاهزة فور بدء المسار — جائزتها عن *اليوم* نفسه، وتأجيلها
  /// يوما يجعل أول لقاء باللعبة بلا شيء. أما الأسبوعية والشهرية فتُستحقّ
  /// كل منهما بعد انقضاء مدّتها فعلا: «جائزة الأسبوع» في يومه الأول
  /// جائزة عن أسبوع لم يمرّ.
  static DateTime firstReadyDay(RewardTier tier, DateTime startDay) =>
      tier == RewardTier.daily
      ? startDay
      : addDays(startDay, tier.periodDays);

  /// اليوم الذي تُفتح فيه المطالبة التالية، أو null إن انتهت الطبقة
  static DateTime? nextReadyDay(RewardTier tier, RewardTrackState state) {
    final progress = state.progressOf(tier);
    if (progress.claimed >= tier.totalClaims) return null;
    final last = progress.lastClaimDay;
    return last == null
        ? firstReadyDay(tier, state.startDay)
        : addDays(last, tier.periodDays);
  }

  static RewardTierStatus statusOf(
    RewardTier tier,
    RewardTrackState state,
    DateTime today,
  ) {
    final progress = state.progressOf(tier);
    final ready = nextReadyDay(tier, state);
    return RewardTierStatus(
      tier: tier,
      claimed: progress.claimed,
      daysUntilReady: ready == null
          ? null
          : daysBetween(dayOf(today), ready).clamp(0, 1 << 30),
    );
  }

  static List<RewardTierStatus> statuses(
    RewardTrackState state,
    DateTime today,
  ) => [for (final tier in RewardTier.values) statusOf(tier, state, today)];

  /// المسار كله انتهى: لا طبقة بقيت فيها مطالبة واحدة
  static bool isTrackComplete(RewardTrackState state) =>
      RewardTier.values.every(
        (tier) => state.progressOf(tier).claimed >= tier.totalClaims,
      );

  /// حالة جديدة بعد مطالبة ناجحة. يرمي إن لم تكن الطبقة جاهزة فعلا —
  /// خطأ برمجي لا حالة لعب متوقّعة؛ المستدعي يسأل [statusOf] أولا.
  static RewardTrackState claim(
    RewardTier tier,
    RewardTrackState state,
    DateTime today,
  ) {
    final status = statusOf(tier, state, today);
    if (!status.isReady) {
      throw StateError('مطالبة بطبقة غير جاهزة: ${tier.name}');
    }
    return state.withTier(
      tier,
      RewardTierProgress(
        claimed: status.claimed + 1,
        lastClaimDay: dayOf(today),
      ),
    );
  }

  /// الأيام القادمة (1..[horizonDays]) التي ستكون فيها الطبقة جاهزة لو
  /// لم يفتح اللاعب اللعبة إطلاقا — أساس سلسلة الإشعارات المسبقة.
  ///
  /// الجاهز اليوم يبقى جاهزا غدا (لا مطالبة تُسقطه ما دامت اللعبة
  /// مغلقة)، فكل يوم بعد [nextReadyDay] مؤهَّل. ومن يفتح اللعبة فعلا
  /// تُلغى سلسلته وتُعاد جدولتها من الصفر — راجع notification_engine.dart.
  static List<int> readyDaysAhead(
    RewardTier tier,
    RewardTrackState state,
    DateTime today, {
    required int horizonDays,
  }) {
    final ready = nextReadyDay(tier, state);
    if (ready == null) return const [];
    final offset = daysBetween(dayOf(today), ready);
    return [
      for (var days = 1; days <= horizonDays; days++)
        if (days >= offset) days,
    ];
  }
}
