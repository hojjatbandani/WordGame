// حدث تحليلي واحد وأسماء كل الأحداث. Dart صرف — بلا Flutter وبلا شبكة.
//
// الأسماء ثوابت في مكان واحد لسبب عملي لا جمالي: اسم مكتوب حرفيا في
// شاشة يصبح بعد شهرين `stage_complete` هنا و`stageComplete` هناك، فتنقسم
// السلسلة الزمنية للحدث نفسه إلى سلسلتين ولا يُكتشف ذلك إلا بعد فوات
// أوان التحليل. من هنا تُشتق الأسماء دوما.

/// كل الأحداث التي يرسلها التطبيق. لا يُرسَل حدث خارج هذه القائمة.
class Ev {
  const Ev._();

  // ─────────── دورة حياة المرحلة ───────────
  static const stageStart = 'stage_start';
  static const stageComplete = 'stage_complete';
  static const stageFail = 'stage_fail';
  static const stageAbandon = 'stage_abandon';

  // ─────────── داخل المرحلة ───────────
  static const hintUsed = 'hint_used';
  static const bonusWordFound = 'bonus_word_found';
  static const jarFilled = 'jar_filled';

  // ─────────── الاقتصاد ───────────
  static const coinsEarned = 'coins_earned';
  static const coinsSpent = 'coins_spent';

  // ─────────── وضع الأمان والمساعدة ───────────
  static const safetyModeShown = 'safety_mode_shown';
  static const safetyModeOptionChosen = 'safety_mode_option_chosen';
  static const assistTriggered = 'assist_triggered';

  // ─────────── التقدّم ───────────
  static const chapterUnlocked = 'chapter_unlocked';
  static const worldUnlocked = 'world_unlocked';
  static const worldGateBlocked = 'world_gate_blocked';

  // ─────────── العودة اليومية ───────────
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

  // ─────────── الإعلانات ───────────
  static const adRequested = 'ad_requested';
  static const adShown = 'ad_shown';
  static const adFailed = 'ad_failed';
  static const adRewardGranted = 'ad_reward_granted';

  // ─────────── المتجر ───────────
  static const storeOpened = 'store_opened';
  static const offerShown = 'offer_shown';
  static const purchaseStarted = 'purchase_started';
  static const purchaseCompleted = 'purchase_completed';

  // ─────────── النزال ───────────

  // ─────────── الاجتماعي ───────────
  static const referralSent = 'referral_sent';
  static const referralRedeemed = 'referral_redeemed';
  static const shareCompleted = 'share_completed';

  /// كل الأسماء — يستخدمها اختبار يمنع الازدواج والانحراف
  static const all = <String>[
    stageStart, stageComplete, stageFail, stageAbandon,
    hintUsed, bonusWordFound, jarFilled,
    coinsEarned, coinsSpent,
    safetyModeShown, safetyModeOptionChosen, assistTriggered,
    chapterUnlocked, worldUnlocked, worldGateBlocked,
    dailyRewardClaimed, rewardTrackClaimed, streakBroken, streakFreezeUsed,
    missionCompleted, wheelSpun,
    adRequested, adShown, adFailed, adRewardGranted,
    storeOpened, offerShown, purchaseStarted, purchaseCompleted,
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
