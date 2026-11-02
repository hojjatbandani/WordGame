// سجلّ مفاتيح التوازن القابلة للتحكّم عن بعد. Dart صرف.
//
// كل رقم توازن في BalanceConfig له مفتاح هنا باسمه نفسه حرفيا. لماذا
// سجلّ صريح بدل انعكاس (reflection): dart:mirrors غير متاح في Flutter
// أصلا، والأهم أن السجلّ الصريح يجعل «ما الذي يمكن تغييره عن بعد؟»
// سؤالا له إجابة واحدة مقروءة — وقائمة صريحة تمنع مفتاحا مكتوبا خطأ من
// أن يبدو ناجحا وهو لا يفعل شيئا (راجع [unknownKeys]).
//
// التحويل متساهل عمدا: لوحة تحكّم قد ترسل 5 مكان 5.0، أو "5" نصّا.
// قيمة لا تصلح تُتجاهل ويبقى الافتراضي المُصرَّف — أفضل من انهيار
// بسبب حقل في قاعدة بيانات.

import '../../config/balance_config.dart';

typedef ApplyOverride = void Function(Object value);

class BalanceOverrides {
  const BalanceOverrides._();

  static int? _int(Object v) => switch (v) {
    int() => v,
    num() => v.round(),
    String() => int.tryParse(v) ?? double.tryParse(v)?.round(),
    _ => null,
  };

  static double? _double(Object v) => switch (v) {
    num() => v.toDouble(),
    String() => double.tryParse(v),
    _ => null,
  };

  static Duration? _seconds(Object v) {
    final s = _int(v);
    return s == null ? null : Duration(seconds: s);
  }

  static Map<int, int>? _intMap(Object v) {
    if (v is! Map) return null;
    final out = <int, int>{};
    for (final entry in v.entries) {
      final k = int.tryParse('${entry.key}');
      final val = entry.value == null ? null : _int(entry.value as Object);
      if (k == null || val == null) return null;
      out[k] = val;
    }
    return out;
  }

  static Map<int, double>? _doubleMap(Object v) {
    if (v is! Map) return null;
    final out = <int, double>{};
    for (final entry in v.entries) {
      final k = int.tryParse('${entry.key}');
      final val = entry.value == null ? null : _double(entry.value as Object);
      if (k == null || val == null) return null;
      out[k] = val;
    }
    return out;
  }

  static List<int>? _intList(Object v) {
    if (v is! List) return null;
    final out = <int>[];
    for (final e in v) {
      final parsed = e == null ? null : _int(e as Object);
      if (parsed == null) return null;
      out.add(parsed);
    }
    return out;
  }

  // ─── تحقّق من الشكل ───
  //
  // التساهل في *النوع* (5 أو 5.0 أو "5") شيء، وقبول *شكل* لا يحتمله
  // المستهلك شيء آخر: جدول عوالم ينقصه عالم يرمي ArgumentError عند أول
  // إتمام مرحلة فيه، وسلّم فارغ يفهرس −1، وأسبوع تقويم من ستة أيام
  // يرمي RangeError على الشاشة الرئيسية. والنسخة المحفوظة تعيد تشغيل
  // القيمة نفسها في كل إقلاع بلا اتصال، فالانهيار يتكرّر بلا مخرج.
  // القيمة التي لا تستوفي شكلها تُرفض ويبقى الافتراضي، كما تُرفض
  // القيمة من نوع خاطئ تماما.

  /// يجب أن يغطّي كل عالم من 1 إلى [BalanceConfig.worldCount]
  static bool _coversAllWorlds(Map<int, Object> m) {
    for (var worldId = 1; worldId <= BalanceConfig.worldCount; worldId++) {
      if (!m.containsKey(worldId)) return false;
    }
    return true;
  }

  static Map<int, int>? _worldIntMap(Object v) {
    final m = _intMap(v);
    return m != null && _coversAllWorlds(m) ? m : null;
  }

  static Map<int, double>? _worldDoubleMap(Object v) {
    final m = _doubleMap(v);
    return m != null && _coversAllWorlds(m) ? m : null;
  }

  static Map<int, int>? _nonEmptyIntMap(Object v) {
    final m = _intMap(v);
    return m != null && m.isNotEmpty ? m : null;
  }

  static List<int>? _nonEmptyIntList(Object v) {
    final l = _intList(v);
    return l != null && l.isNotEmpty ? l : null;
  }

  /// أسبوع تقويم الدخول: سبعة أيام بالضبط
  static List<int>? _weekList(Object v) {
    final l = _intList(v);
    return l != null && l.length == 7 ? l : null;
  }

  static ApplyOverride _i(void Function(int) set) =>
      (v) => _int(v).let(set);
  static ApplyOverride _d(void Function(double) set) =>
      (v) => _double(v).let(set);
  static ApplyOverride _s(void Function(Duration) set) =>
      (v) => _seconds(v).let(set);
  static ApplyOverride _im(void Function(Map<int, int>) set) =>
      (v) => _nonEmptyIntMap(v).let(set);
  static ApplyOverride _wim(void Function(Map<int, int>) set) =>
      (v) => _worldIntMap(v).let(set);
  static ApplyOverride _wdm(void Function(Map<int, double>) set) =>
      (v) => _worldDoubleMap(v).let(set);
  static ApplyOverride _il(void Function(List<int>) set) =>
      (v) => _nonEmptyIntList(v).let(set);
  static ApplyOverride _wl(void Function(List<int>) set) =>
      (v) => _weekList(v).let(set);

  /// كل مفتاح → كيف يُطبَّق. الاسم يطابق اسم الحقل في BalanceConfig.
  static final Map<String, ApplyOverride> registry = {
    // ─── بنية العوالم والفصول ───
    'worldCount': _i((v) => BalanceConfig.worldCount = v),
    'chaptersPerWorld': _i((v) => BalanceConfig.chaptersPerWorld = v),
    'worldStageCountGroupA': _i((v) => BalanceConfig.worldStageCountGroupA = v),
    'worldStageCountGroupB': _i((v) => BalanceConfig.worldStageCountGroupB = v),
    'groupABoundaryWorldId': _i((v) => BalanceConfig.groupABoundaryWorldId = v),
    'initiallyUnlockedStageCount': _i(
      (v) => BalanceConfig.initiallyUnlockedStageCount = v,
    ),

    // ─── الجرّة ───
    'jarThresholdByWorld': _wim((v) => BalanceConfig.jarThresholdByWorld = v),

    // ─── XP والمستوى ───
    'xpPerStageClear': _i((v) => BalanceConfig.xpPerStageClear = v),
    'xpPerBonusWord': _i((v) => BalanceConfig.xpPerBonusWord = v),
    'xpBossStageExtra': _i((v) => BalanceConfig.xpBossStageExtra = v),
    'xpPerChapterComplete': _i((v) => BalanceConfig.xpPerChapterComplete = v),
    'xpPerWorldComplete': _i((v) => BalanceConfig.xpPerWorldComplete = v),
    'xpBaseForLevel': _i((v) => BalanceConfig.xpBaseForLevel = v),
    'xpIncrementPerLevel': _i((v) => BalanceConfig.xpIncrementPerLevel = v),

    // ─── بوابات المستوى ───
    'levelGateReferral': _i((v) => BalanceConfig.levelGateReferral = v),

    // ─── الهجرة ───
    'migrationXpPerCompletedStage': _i(
      (v) => BalanceConfig.migrationXpPerCompletedStage = v,
    ),
    'migrationWelcomeChestCoins': _i(
      (v) => BalanceConfig.migrationWelcomeChestCoins = v,
    ),

    // ─── كسب العملات ───
    'startingCoins': _i((v) => BalanceConfig.startingCoins = v),
    'coinsStageClear': _i((v) => BalanceConfig.coinsStageClear = v),
    'minCoinsPerStage': _i((v) => BalanceConfig.minCoinsPerStage = v),
    'maxCoinsPerStage': _i((v) => BalanceConfig.maxCoinsPerStage = v),
    'coinsPerCoreWord': _i((v) => BalanceConfig.coinsPerCoreWord = v),
    'coinsPerBonusWord': _i((v) => BalanceConfig.coinsPerBonusWord = v),
    'coinsPerfectStageBonus': _i(
      (v) => BalanceConfig.coinsPerfectStageBonus = v,
    ),
    'coinsBossStageBonus': _i((v) => BalanceConfig.coinsBossStageBonus = v),
    'coinsChapterComplete': _i((v) => BalanceConfig.coinsChapterComplete = v),
    'coinsChapterChest': _i((v) => BalanceConfig.coinsChapterChest = v),
    'coinsWorldComplete': _i((v) => BalanceConfig.coinsWorldComplete = v),
    'coinsAchievementBronze': _i(
      (v) => BalanceConfig.coinsAchievementBronze = v,
    ),
    'coinsAchievementSilver': _i(
      (v) => BalanceConfig.coinsAchievementSilver = v,
    ),
    'coinsAchievementGold': _i((v) => BalanceConfig.coinsAchievementGold = v),
    'coinEarningMultiplierByWorld': _wdm(
      (v) => BalanceConfig.coinEarningMultiplierByWorld = v,
    ),

    // ─── التلميحات ───
    'hintEscalationLadder': _il((v) => BalanceConfig.hintEscalationLadder = v),
    'coinsRevealEntireWord': _i((v) => BalanceConfig.coinsRevealEntireWord = v),
    'revealEntireWordMinHintsUsedThisStage': _i(
      (v) => BalanceConfig.revealEntireWordMinHintsUsedThisStage = v,
    ),
    'hintCostMultiplierByWorld': _wdm(
      (v) => BalanceConfig.hintCostMultiplierByWorld = v,
    ),
    'hintCostRoundingUnit': _i((v) => BalanceConfig.hintCostRoundingUnit = v),
    'stagesPerFreeHintCharge': _i(
      (v) => BalanceConfig.stagesPerFreeHintCharge = v,
    ),
    'maxHintCharges': _i((v) => BalanceConfig.maxHintCharges = v),

    // ─── إنفاق آخر ───
    'bonusWordMilestoneEvery': _i(
      (v) => BalanceConfig.bonusWordMilestoneEvery = v,
    ),
    'coinsBonusWordMilestone': _i(
      (v) => BalanceConfig.coinsBonusWordMilestone = v,
    ),
    'coinsHintOrderedLetter': _i(
      (v) => BalanceConfig.coinsHintOrderedLetter = v,
    ),
    'coinsHintRandomLetter': _i((v) => BalanceConfig.coinsHintRandomLetter = v),
    'coinsSkipStage': _i((v) => BalanceConfig.coinsSkipStage = v),
    'failedAttemptsBeforeSkipOffered': _i(
      (v) => BalanceConfig.failedAttemptsBeforeSkipOffered = v,
    ),
    'coinsStreakFreeze': _i((v) => BalanceConfig.coinsStreakFreeze = v),
    'maxStreakFreezesHeld': _i((v) => BalanceConfig.maxStreakFreezesHeld = v),
    'streakFreezeGrantEveryDays': _i(
      (v) => BalanceConfig.streakFreezeGrantEveryDays = v,
    ),
    'coinsJarBooster': _i((v) => BalanceConfig.coinsJarBooster = v),
    'jarBoosterDuration': _s((v) => BalanceConfig.jarBoosterDuration = v),
    'jarBoosterMultiplier': _d((v) => BalanceConfig.jarBoosterMultiplier = v),
    'cosmeticsMinPrice': _i((v) => BalanceConfig.cosmeticsMinPrice = v),
    'cosmeticsMaxPrice': _i((v) => BalanceConfig.cosmeticsMaxPrice = v),

    // ─── وضع الأمان ───
    'safetyModeCoinThreshold': _i(
      (v) => BalanceConfig.safetyModeCoinThreshold = v,
    ),
    'safetyModeMinFailedAttempts': _i(
      (v) => BalanceConfig.safetyModeMinFailedAttempts = v,
    ),
    'safetyModeAdRewardCoins': _i(
      (v) => BalanceConfig.safetyModeAdRewardCoins = v,
    ),
    'safetyModeMiniChallengeRewardCoins': _i(
      (v) => BalanceConfig.safetyModeMiniChallengeRewardCoins = v,
    ),
    'safetyModeFreeGrantCoins': _i(
      (v) => BalanceConfig.safetyModeFreeGrantCoins = v,
    ),

    // ─── تقويم الدخول ───
    'loginCalendarWeek1Coins': _wl(
      (v) => BalanceConfig.loginCalendarWeek1Coins = v,
    ),
    'loginCalendarWeek2Coins': _wl(
      (v) => BalanceConfig.loginCalendarWeek2Coins = v,
    ),
    'loginCalendarWeek3Coins': _wl(
      (v) => BalanceConfig.loginCalendarWeek3Coins = v,
    ),
    'loginCalendarShardFromWeek': _i(
      (v) => BalanceConfig.loginCalendarShardFromWeek = v,
    ),
    'loginCalendarShardDayInWeek': _i(
      (v) => BalanceConfig.loginCalendarShardDayInWeek = v,
    ),
    'loginCalendarShardAmount': _i(
      (v) => BalanceConfig.loginCalendarShardAmount = v,
    ),

    // ─── مسار الجوائز ───
    'rewardTrackDailyCoins': _i(
      (v) => BalanceConfig.rewardTrackDailyCoins = v,
    ),
    'rewardTrackDailyClaims': _i(
      (v) => BalanceConfig.rewardTrackDailyClaims = v,
    ),
    'rewardTrackWeeklyCoins': _i(
      (v) => BalanceConfig.rewardTrackWeeklyCoins = v,
    ),
    'rewardTrackWeeklyClaims': _i(
      (v) => BalanceConfig.rewardTrackWeeklyClaims = v,
    ),
    'rewardTrackMonthlyCoins': _i(
      (v) => BalanceConfig.rewardTrackMonthlyCoins = v,
    ),
    'rewardTrackMonthlyClaims': _i(
      (v) => BalanceConfig.rewardTrackMonthlyClaims = v,
    ),
    'widgetActivationRewardCoins': _i(
      (v) => BalanceConfig.widgetActivationRewardCoins = v,
    ),
    'widgetPromoAfterStages': _i(
      (v) => BalanceConfig.widgetPromoAfterStages = v,
    ),

    // ─── الدوري ───

    // ─── النزال ───

    // ─── الأصدقاء والدعوات ───
    'friendCodeLength': _i((v) => BalanceConfig.friendCodeLength = v),
    'maxFriends': _i((v) => BalanceConfig.maxFriends = v),
    'referralRewardInviter': _i((v) => BalanceConfig.referralRewardInviter = v),
    'referralRewardInvitee': _i((v) => BalanceConfig.referralRewardInvitee = v),
    'referralQualifyLevel': _i((v) => BalanceConfig.referralQualifyLevel = v),
    'referralMaxPaidPerAccount': _i(
      (v) => BalanceConfig.referralMaxPaidPerAccount = v,
    ),

    // ─── المشاركة ───
    'shareRewardCoins': _i((v) => BalanceConfig.shareRewardCoins = v),
    'shareRewardMaxTotal': _i((v) => BalanceConfig.shareRewardMaxTotal = v),

    // ─── الإعلانات ───
    'interstitialFirstEligibleStage': _i(
      (v) => BalanceConfig.interstitialFirstEligibleStage = v,
    ),
    'interstitialCadenceByStage': _im(
      (v) => BalanceConfig.interstitialCadenceByStage = v,
    ),
    'adGlobalCooldownSeconds': _s((v) => BalanceConfig.adGlobalCooldown = v),
    'interstitialSuppressionAfterPurchaseSeconds': _s(
      (v) => BalanceConfig.interstitialSuppressionAfterPurchase = v,
    ),
    'rewardedDailyBudget': _i((v) => BalanceConfig.rewardedDailyBudget = v),
    'rewardedRewardLadder': _il((v) => BalanceConfig.rewardedRewardLadder = v),

    // ─── المتجر والعروض ───
    'storePromoMinChaptersCompleted': _i(
      (v) => BalanceConfig.storePromoMinChaptersCompleted = v,
    ),
    'nearMissMaxDeficitRatio': _d(
      (v) => BalanceConfig.nearMissMaxDeficitRatio = v,
    ),
    'firstPurchaseMaxCoinBalance': _i(
      (v) => BalanceConfig.firstPurchaseMaxCoinBalance = v,
    ),
    'firstPurchaseMinStageFailures': _i(
      (v) => BalanceConfig.firstPurchaseMinStageFailures = v,
    ),
    'firstPurchaseMinStagesCompleted': _i(
      (v) => BalanceConfig.firstPurchaseMinStagesCompleted = v,
    ),
    'firstPurchaseMinGapBetweenShowsSeconds': _s(
      (v) => BalanceConfig.firstPurchaseMinGapBetweenShows = v,
    ),
    'firstPurchaseOfferDurationSeconds': _s(
      (v) => BalanceConfig.firstPurchaseOfferDuration = v,
    ),
    'firstPurchaseOfferDiscountPercent': _i(
      (v) => BalanceConfig.firstPurchaseOfferDiscountPercent = v,
    ),
    'firstPurchaseBonusDurationSeconds': _s(
      (v) => BalanceConfig.firstPurchaseBonusDuration = v,
    ),
    'firstPurchaseCoinMultiplier': _d(
      (v) => BalanceConfig.firstPurchaseCoinMultiplier = v,
    ),
  };

  /// يطبّق ما يفهمه ويعيد عدد المفاتيح التي طُبّقت فعلا. مفتاح مجهول
  /// يُتجاهل بهدوء (لوحة تحكّم قد تسبق نسخة التطبيق) — وتشخيصه في
  /// [unknownKeys].
  static int applyAll(Map<String, Object?> values) {
    var applied = 0;
    for (final entry in values.entries) {
      final apply = registry[entry.key];
      final value = entry.value;
      if (apply == null || value == null) continue;
      try {
        apply(value);
        applied++;
      } catch (_) {
        // قيمة لا تصلح لهذا المفتاح — نُبقي الافتراضي
      }
    }
    return applied;
  }

  static List<String> unknownKeys(Map<String, Object?> values) => [
    for (final k in values.keys)
      if (!registry.containsKey(k)) k,
  ];
}

extension _LetNullable<T> on T? {
  void let(void Function(T) f) {
    final value = this;
    if (value != null) f(value);
  }
}
