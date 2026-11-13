// حدث تحليلي واحد وأسماء كل الأحداث. Dart صرف — بلا Flutter وبلا شبكة.
//
// الأسماء ثوابت في مكان واحد لسبب عملي لا جمالي: اسم مكتوب حرفيا في
// شاشة يصبح بعد شهرين `stage_complete` هنا و`stageComplete` هناك، فتنقسم
// السلسلة الزمنية للحدث نفسه إلى سلسلتين ولا يُكتشف ذلك إلا بعد فوات
// أوان التحليل. من هنا تُشتق الأسماء دوما.

/// كل الأحداث التي يرسلها التطبيق. لا يُرسَل حدث خارج هذه القائمة.
class Ev {
  const Ev._();

  // ─────────── رحلة اللاعب الأولى ───────────
  /// الرئيسية صارت الشاشة الظاهرة (بعد البدء أو بعد العودة إليها)
  static const homeViewed = 'home_viewed';
  static const continuePlayClicked = 'continue_play_clicked';

  /// أول بدء مرحلة على هذا التثبيت — يقيس «من التثبيت إلى اللعب»
  static const newGameStarted = 'new_game_started';
  static const onboardingStarted = 'onboarding_started';
  static const onboardingCompleted = 'onboarding_completed';

  // ─────────── دورة حياة المرحلة ───────────
  /// واجهة ما اختارت مرحلة، قبل الانتقال إليها
  static const stageSelected = 'stage_selected';
  static const stageStart = 'stage_start';
  static const stageComplete = 'stage_complete';
  static const stageFail = 'stage_fail';
  static const stageAbandon = 'stage_abandon';
  static const nextStageClicked = 'next_stage_clicked';

  // ─────────── داخل المرحلة ───────────
  static const hintViewed = 'hint_viewed';
  static const hintUsed = 'hint_used';
  static const hintUnavailable = 'hint_unavailable';
  static const bonusWordFound = 'bonus_word_found';
  static const jarFilled = 'jar_filled';

  // ─────────── الاقتصاد ───────────
  static const coinsEarned = 'coins_earned';
  static const coinsSpent = 'coins_spent';

  /// محاولة إنفاق رُفضت لنقص الرصيد — منفصلة كي لا يتضخّم مجموع المُنفَق
  static const coinsSpendFailed = 'coins_spend_failed';

  // ─────────── وضع الأمان والمساعدة ───────────
  static const safetyModeShown = 'safety_mode_shown';
  static const safetyModeOptionChosen = 'safety_mode_option_chosen';
  static const assistTriggered = 'assist_triggered';

  // ─────────── التقدّم ───────────
  static const worldViewed = 'world_viewed';
  static const chapterUnlocked = 'chapter_unlocked';
  static const worldUnlocked = 'world_unlocked';
  static const worldGateBlocked = 'world_gate_blocked';

  // ─────────── العودة اليومية ───────────
  static const rewardsViewed = 'rewards_viewed';
  static const dailyRewardClaimed = 'daily_reward_claimed';

  /// مطالبة بطبقة من مسار الجوائز. الطبقة (يومية/أسبوعية/شهرية) خاصيّة
  /// لا حدثا مستقلا: ثلاثة أحداث لشيء واحد تُقسّم السلسلة الزمنية بلا
  /// داع، والقطع بالخاصية يعطي نفس التفصيل ومجموعا صحيحا معا.
  static const rewardTrackClaimed = 'reward_track_claimed';
  static const streakBroken = 'streak_broken';
  static const streakFreezeUsed = 'streak_freeze_used';

  // ─────────── المهمات والعجلة ───────────
  static const missionCompleted = 'mission_completed';
  static const wheelSpun = 'wheel_spun';

  // ─────────── الإعلانات: دورة الحياة كاملة ───────────
  //
  // requested ← طلبه مسار في اللعبة
  // eligible / skipped ← قرار الأهلية (الإيقاع، الميزانية...) لا عطل
  // loaded / load_failed ← نتيجة الشبكة الحقيقية
  // shown → clicked → reward_earned → dismissed ← نداءات SDK الفعلية
  // reward_granted ← اللعبة أضافت المكافأة فعلا
  static const adRequested = 'ad_requested';
  static const adEligible = 'ad_eligible';
  static const adSkipped = 'ad_skipped';
  static const adLoaded = 'ad_loaded';
  static const adLoadFailed = 'ad_load_failed';
  static const adShown = 'ad_shown';
  static const adClicked = 'ad_clicked';
  static const adRewardEarned = 'ad_reward_earned';
  static const adDismissed = 'ad_dismissed';
  static const adRewardGranted = 'ad_reward_granted';

  // ─────────── المتجر ───────────
  static const shopViewed = 'shop_viewed';
  static const offerShown = 'offer_shown';
  static const purchaseStarted = 'purchase_started';
  static const purchaseCompleted = 'purchase_completed';
  static const purchaseFailed = 'purchase_failed';

  // ─────────── الاجتماعي ───────────
  static const referralSent = 'referral_sent';
  static const referralRedeemed = 'referral_redeemed';
  static const shareCompleted = 'share_completed';

  /// كل الأسماء — يستخدمها اختبار يمنع الازدواج والانحراف
  static const all = <String>[
    homeViewed, continuePlayClicked, newGameStarted, onboardingStarted,
    onboardingCompleted,
    stageSelected, stageStart, stageComplete, stageFail, stageAbandon,
    nextStageClicked,
    hintViewed, hintUsed, hintUnavailable, bonusWordFound, jarFilled,
    coinsEarned, coinsSpent, coinsSpendFailed,
    safetyModeShown, safetyModeOptionChosen, assistTriggered,
    worldViewed, chapterUnlocked, worldUnlocked, worldGateBlocked,
    rewardsViewed, dailyRewardClaimed, rewardTrackClaimed, streakBroken,
    streakFreezeUsed,
    missionCompleted, wheelSpun,
    adRequested, adEligible, adSkipped, adLoaded, adLoadFailed, adShown,
    adClicked, adRewardEarned, adDismissed, adRewardGranted,
    shopViewed, offerShown, purchaseStarted, purchaseCompleted, purchaseFailed,
    referralSent, referralRedeemed, shareCompleted,
  ];
}

/// حدث جاهز للإرسال إلى PostHog. السياق العام (المستوى، المرحلة، الرصيد)
/// حقول مستقلة لا داخل [properties]، ويدمجها الناقل معها
/// (posthog_sink.dart).
class AnalyticsEvent {
  final String name;
  final Map<String, Object?> properties;
  final int? playerLevel;
  final int? stageId;
  final int? coinBalance;

  const AnalyticsEvent({
    required this.name,
    this.properties = const {},
    this.playerLevel,
    this.stageId,
    this.coinBalance,
  });
}
