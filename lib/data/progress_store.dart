import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/balance_config.dart';
import 'achievement_models.dart';

/// تخزين التقدم محليا (يستبدل لاحقا بمزامنة سحابية)
class ProgressStore {
  static const _kPoints = 'points';
  static const _kMaxUnlocked = 'max_unlocked';

  /// اسم اللاعب كما أدخله بنفسه عند أول تشغيل. محلّي دوما: التحية في
  /// الرئيسية يجب أن تعمل بلا حساب ولا شبكة، والملف الاجتماعي (إن وُجد)
  /// اسم ثانٍ لا بديل عنه.
  static const _kPlayerName = 'player_name';

  /// سُئل اللاعب عن اسمه مرة — لا نسأله ثانية ولو تخطّى السؤال
  static const _kPlayerNameAsked = 'player_name_asked';

  /// ضغط «قيّم» فعلا مرة واحدة — بعدها لا يُطلب منه التقييم أبدا
  static const _kAppRated = 'app_rated';

  static const _kBonusJar = 'bonus_jar';

  /// مجموع الكلمات الإضافية *الجديدة* عبر كل المراحل — يقود مكافأة كل
  /// خمس كلمات. منفصل عن bonus_jar (جرّة العالم) لأن ذاك يُقرأ ويُعرض
  /// لكل عالم على حدة، وهذا عدّاد تراكمي واحد لا يُصفَّر أبدا.
  static const _kBonusWordsCounted = 'bonus_words_counted';
  static const _kDailyLastClaim = 'daily_last_claim';
  static const _kDailyStreakDay = 'daily_streak_day';
  static const _kAdDate = 'ad_date';
  static const _kAdCount = 'ad_count';
  static const _kAdsRemoved = 'ads_removed';
  static const _kLevelsCompletedCount = 'levels_completed_count';
  static const _kWheelDate = 'wheel_date';
  static const _kWheelFreeUsed = 'wheel_free_used';
  static const _kWheelAdDate = 'wheel_ad_date';
  static const _kWheelAdSpinsUsed = 'wheel_ad_spins_used';

  static const _kBankedHintCharges = 'banked_hint_charges';
  static const _kJarBoosterActiveUntil = 'jar_booster_active_until';
  static const _kGlobalAdBudgetDate = 'global_ad_budget_date';
  static const _kGlobalAdBudgetUsed = 'global_ad_budget_used';
  static const _kPendingCosmeticUnlocks = 'pending_cosmetic_unlocks';
  static const _kDailyMissionsJson = 'daily_missions_json';
  static const _kWeeklyMissionsJson = 'weekly_missions_json';

  /// حالة مسار الجوائز كاملة بصيغة JSON — راجع
  /// [RewardTrackState.encode] في lib/data/rewards/reward_track.dart
  static const _kRewardTrackJson = 'reward_track_json';

  /// مُنحت مكافأة تفعيل ودجة الشاشة الرئيسية. يُرفع مرة ولا يُخفَض أبدا
  /// — لا بإزالة الودجة ولا بإعادة إضافتها، وينجو من «البدء من جديد»
  /// (راجع [_preservedOnReset] وlib/data/widget/widget_activation.dart)
  static const _kWidgetActivationRewarded = 'widget_activation_rewarded';

  /// عُرض عرض «أضف الودجة» مرة — لا يُعاد عرضه بعدها مهما فعل اللاعب
  static const _kWidgetPromoShown = 'widget_promo_shown';

  static const _kNotifDailyRewardEnabled = 'notif_daily_reward_enabled';
  static const _kNotifRewardTrackEnabled = 'notif_reward_track_enabled';
  static const _kNotifStreakEnabled = 'notif_streak_enabled';
  static const _kNotificationsSentDate = 'notif_sent_date';
  static const _kNotificationsSentTypes = 'notif_sent_types';
  static const _kLastAppOpenedAt = 'last_app_opened_at';
  static const _kSessionCount = 'session_count';
  static const _kNotificationPermissionRequested = 'notif_permission_requested';

  /// موضع تقويم الدخول اليومي — رقم يتزايد للأبد بمقدار 1 مع كل مطالبة
  /// ناجحة فقط، لا يُصفَّر أبدا بفوات يوم. مفتاح جديد يحلّ محلّ
  /// _kDailyStreakDay القديم (الذي كان يُصفَّر عند الفوات ويبقى ضمن 1-7)
  /// — يُهاجَر بقيمة _kDailyStreakDay القديمة أول مرة كي لا يبدأ اللاعب
  /// العائد من الصفر، راجع DailyRewardNotifier.build في providers.dart
  static const _kDailyCalendarPosition = 'daily_calendar_position';

  static const _kCosmeticShards = 'cosmetic_shards';

  static const _kStreakCurrent = 'streak_current';
  static const _kStreakLongest = 'streak_longest';
  static const _kStreakFreezesHeld = 'streak_freezes_held';
  static const _kStreakFreezeMilestonesGranted =
      'streak_freeze_milestones_granted';
  static const _kStreakSecuredThrough = 'streak_secured_through';
  static const _kStreakPendingFreezeNotice = 'streak_pending_freeze_notice';

  final SharedPreferences prefs;

  ProgressStore(this.prefs);

  static Future<ProgressStore> create() async =>
      ProgressStore(await SharedPreferences.getInstance());

  /// رصيد النظام القديم. **للهجرة وحدها**: منذ ربط EconomyService صار
  /// [PlayerWallet.coins] هو الدفتر الوحيد، وهذا المفتاح يُقرأ مرة
  /// واحدة عند أول تحميل لنظام التقدّم ثم لا يُكتب أبدا. لا تُضِف له
  /// setter — وجود دفترين للعملات جنبا إلى جنب هو ما عطّل كل أرقام
  /// `BalanceConfig.coins*` طوال ما مضى.
  int get points => prefs.getInt(_kPoints) ?? BalanceConfig.startingCoins;
  int get maxUnlocked => prefs.getInt(_kMaxUnlocked) ?? 1;
  String? get playerName {
    final value = prefs.getString(_kPlayerName)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  bool get playerNameAsked => prefs.getBool(_kPlayerNameAsked) ?? false;

  bool get appRated => prefs.getBool(_kAppRated) ?? false;

  int get bonusJar => prefs.getInt(_kBonusJar) ?? 0;
  int get bonusWordsCounted => prefs.getInt(_kBonusWordsCounted) ?? 0;
  String? get dailyLastClaim => prefs.getString(_kDailyLastClaim);
  int get dailyStreakDay => prefs.getInt(_kDailyStreakDay) ?? 0;
  String? get adDate => prefs.getString(_kAdDate);
  int get adCount => prefs.getInt(_kAdCount) ?? 0;
  bool get adsRemoved => prefs.getBool(_kAdsRemoved) ?? false;
  int get levelsCompletedCount => prefs.getInt(_kLevelsCompletedCount) ?? 0;
  String? get wheelDate => prefs.getString(_kWheelDate);
  bool get wheelFreeUsed => prefs.getBool(_kWheelFreeUsed) ?? false;

  /// اليوم الذي تخصّه [wheelAdSpinsUsed] (yyyy-MM-dd)
  String? get wheelAdDate => prefs.getString(_kWheelAdDate);
  int get wheelAdSpinsUsed => prefs.getInt(_kWheelAdSpinsUsed) ?? 0;

  Future<void> setMaxUnlocked(int value) => prefs.setInt(_kMaxUnlocked, value);
  Future<void> setPlayerName(String value) =>
      prefs.setString(_kPlayerName, value.trim());
  Future<void> setPlayerNameAsked(bool value) =>
      prefs.setBool(_kPlayerNameAsked, value);

  Future<void> setAppRated(bool value) => prefs.setBool(_kAppRated, value);

  Future<void> setBonusJar(int value) => prefs.setInt(_kBonusJar, value);
  Future<void> setBonusWordsCounted(int value) =>
      prefs.setInt(_kBonusWordsCounted, value);
  Future<void> setDailyLastClaim(String value) =>
      prefs.setString(_kDailyLastClaim, value);
  Future<void> setDailyStreakDay(int value) =>
      prefs.setInt(_kDailyStreakDay, value);
  Future<void> setAdDate(String value) => prefs.setString(_kAdDate, value);
  Future<void> setAdCount(int value) => prefs.setInt(_kAdCount, value);
  Future<void> setAdsRemoved(bool value) => prefs.setBool(_kAdsRemoved, value);
  Future<void> setLevelsCompletedCount(int value) =>
      prefs.setInt(_kLevelsCompletedCount, value);
  Future<void> setWheelDate(String value) =>
      prefs.setString(_kWheelDate, value);
  Future<void> setWheelFreeUsed(bool value) =>
      prefs.setBool(_kWheelFreeUsed, value);
  Future<void> setWheelAdDate(String value) =>
      prefs.setString(_kWheelAdDate, value);
  Future<void> setWheelAdSpinsUsed(int value) =>
      prefs.setInt(_kWheelAdSpinsUsed, value);

  /// شحنات التلميح في النظام القديم. **للهجرة وحدها**، تماما كـ[points]:
  /// الشحنات تعيش الآن في [PlayerWallet.hintCharges] وتُستهلك عبر
  /// EconomyService.
  int get bankedHintCharges => prefs.getInt(_kBankedHintCharges) ?? 0;

  /// null يعني لا معزّز نشط. راجع تعليق WheelPrizeType.jarBooster أعلاه
  String? get jarBoosterActiveUntil => prefs.getString(_kJarBoosterActiveUntil);
  Future<void> setJarBoosterActiveUntil(String value) =>
      prefs.setString(_kJarBoosterActiveUntil, value);

  String? get globalAdBudgetDate => prefs.getString(_kGlobalAdBudgetDate);
  int get globalAdBudgetUsed => prefs.getInt(_kGlobalAdBudgetUsed) ?? 0;
  Future<void> setGlobalAdBudgetDate(String value) =>
      prefs.setString(_kGlobalAdBudgetDate, value);
  Future<void> setGlobalAdBudgetUsed(int value) =>
      prefs.setInt(_kGlobalAdBudgetUsed, value);

  /// JSON خام — التحويل من/إلى DailyMissionsState/WeeklyMissionsState يتم
  /// في providers.dart، لا هنا (هذا الملف تخزين صرف بلا معرفة بنماذج
  /// المهمات، لتفادي استيراد دائري)
  String? get dailyMissionsJson => prefs.getString(_kDailyMissionsJson);
  Future<void> setDailyMissionsJson(String value) =>
      prefs.setString(_kDailyMissionsJson, value);
  String? get weeklyMissionsJson => prefs.getString(_kWeeklyMissionsJson);
  Future<void> setWeeklyMissionsJson(String value) =>
      prefs.setString(_kWeeklyMissionsJson, value);

  /// JSON خام لمسار الجوائز — نفس عقد المهمات أعلاه: التخزين لا يعرف
  /// النموذج، والتحويل يقع في rewardTrackProvider
  String? get rewardTrackJson => prefs.getString(_kRewardTrackJson);
  Future<void> setRewardTrackJson(String value) =>
      prefs.setString(_kRewardTrackJson, value);

  // ─────────────────────── ودجة الشاشة الرئيسية ───────────────────────

  bool get widgetActivationRewarded =>
      prefs.getBool(_kWidgetActivationRewarded) ?? false;
  Future<void> setWidgetActivationRewarded(bool value) =>
      prefs.setBool(_kWidgetActivationRewarded, value);

  bool get widgetPromoShown => prefs.getBool(_kWidgetPromoShown) ?? false;
  Future<void> setWidgetPromoShown(bool value) =>
      prefs.setBool(_kWidgetPromoShown, value);

  /// null يعني "لم يهاجَر بعد من dailyStreakDay القديم" — راجع تعليق
  /// المفتاح أعلاه
  int? get dailyCalendarPosition => prefs.getInt(_kDailyCalendarPosition);
  Future<void> setDailyCalendarPosition(int value) =>
      prefs.setInt(_kDailyCalendarPosition, value);

  int get cosmeticShards => prefs.getInt(_kCosmeticShards) ?? 0;
  Future<void> setCosmeticShards(int value) =>
      prefs.setInt(_kCosmeticShards, value);

  // ─────────────────────── سلسلة الأيام المتتالية ───────────────────────

  int get streakCurrent => prefs.getInt(_kStreakCurrent) ?? 0;
  int get streakLongest => prefs.getInt(_kStreakLongest) ?? 0;
  int get streakFreezesHeld => prefs.getInt(_kStreakFreezesHeld) ?? 0;
  int get streakFreezeMilestonesGranted =>
      prefs.getInt(_kStreakFreezeMilestonesGranted) ?? 0;
  String? get streakSecuredThrough => prefs.getString(_kStreakSecuredThrough);
  int get streakPendingFreezeNotice =>
      prefs.getInt(_kStreakPendingFreezeNotice) ?? 0;

  Future<void> saveStreak({
    required int current,
    required int longest,
    required int freezesHeld,
    required int freezeMilestonesGranted,
    required String? securedThrough,
    required int pendingFreezeNotice,
  }) async {
    await prefs.setInt(_kStreakCurrent, current);
    await prefs.setInt(_kStreakLongest, longest);
    await prefs.setInt(_kStreakFreezesHeld, freezesHeld);
    await prefs.setInt(
      _kStreakFreezeMilestonesGranted,
      freezeMilestonesGranted,
    );
    if (securedThrough == null) {
      await prefs.remove(_kStreakSecuredThrough);
    } else {
      await prefs.setString(_kStreakSecuredThrough, securedThrough);
    }
    await prefs.setInt(_kStreakPendingFreezeNotice, pendingFreezeNotice);
  }

  // ─────────────────────── الإنجازات ───────────────────────

  static const _kUnlockedAchievements = 'unlocked_achievements';

  String _statKey(StatKey key) => 'stat_${key.name}';

  int stat(StatKey key) => prefs.getInt(_statKey(key)) ?? 0;

  Future<void> setStat(StatKey key, int value) =>
      prefs.setInt(_statKey(key), value);

  /// معرّفات الإنجازات المفتوحة
  Set<String> get unlockedAchievements =>
      (prefs.getStringList(_kUnlockedAchievements) ?? const []).toSet();

  Future<void> setUnlockedAchievements(Set<String> ids) =>
      prefs.setStringList(_kUnlockedAchievements, ids.toList());

  // ─────────────────────── مكافأة المشاركة ───────────────────────

  static const _kShareRewardCount = 'share_reward_count';

  /// كم مكافأة مشاركة قُبضت **طوال عمر الحساب** — لا رصيد يومي بعد اليوم
  /// (راجع BalanceConfig.shareRewardMaxTotal). المفتاح نفسه محفوظ من
  /// النسخة اليومية: من قبض مرّتين اليوم يُقرأ عنده 2 فيُغلق السقف
  /// فورا، وهو الاتجاه الآمن — لا منح مكرّر بسبب تغيير القاعدة.
  int get shareRewardCount => prefs.getInt(_kShareRewardCount) ?? 0;

  Future<void> setShareRewardCount(int value) =>
      prefs.setInt(_kShareRewardCount, value);

  // ─────────────────────── الدعوة ───────────────────────

  static const _kReferralRedeemed = 'referral_redeemed';
  static const _kInstallId = 'install_id';
  static const _kPendingInviteCode = 'pending_invite_code';

  /// هل استخدم اللاعب رمز دعوة من قبل؟ (السيرفر هو المرجع، وهذا للواجهة)
  bool get referralRedeemed => prefs.getBool(_kReferralRedeemed) ?? false;
  Future<void> setReferralRedeemed(bool value) =>
      prefs.setBool(_kReferralRedeemed, value);

  /// معرّف التثبيت: يُولَّد مرة واحدة عند أول قراءة ويبقى ما بقي التطبيق
  /// مثبّتا. يُرسَل مع استبدال رمز الدعوة كي يفرض الخادم «استبدال واحد
  /// لكل تثبيت» — الفرادة على الحساب وحدها لا تكفي، فمسح بيانات التطبيق
  /// ينشئ حسابا مجهولا جديدا فيصير كل مسح دعوة جديدة.
  ///
  /// ليس معرّفا للجهاز ولا يُشتق من عتاده: قيمة عشوائية محلية بحتة،
  /// تختفي مع إزالة التطبيق ولا تتيح تتبّع اللاعب عبر التطبيقات.
  String get installId {
    final existing = prefs.getString(_kInstallId);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _generateInstallId();
    // كتابة غير منتظَرة عمدا: القيمة صارت في الذاكرة فورا، والقرص يلحق
    prefs.setString(_kInstallId, generated);
    return generated;
  }

  static String _generateInstallId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// رمز دعوة وصل من رابط عميق قبل أن يفتح اللاعب شاشة الأصدقاء —
  /// يُخزَّن كي يُملأ الحقل تلقائيا عند أول فتح لها، ثم يُمحى
  String? get pendingInviteCode => prefs.getString(_kPendingInviteCode);
  Future<void> setPendingInviteCode(String? code) => code == null
      ? prefs.remove(_kPendingInviteCode)
      : prefs.setString(_kPendingInviteCode, code);

  // ─────────────────── إيقاع الإعلانات والمتجر ───────────────────
  //
  // التواريخ تُخزَّن كنصّ ISO لا كعدّاد: مهلة التسعين ثانية ومهلة الـ24
  // ساعة بعد الشراء يجب أن تبقيا ساريتين عبر إغلاق التطبيق وإعادة فتحه،
  // وعدّاد في الذاكرة يُصفَّر بأول إغلاق.

  static const _kLastAdShownAt = 'last_ad_shown_at';
  static const _kCompletionsSinceInterstitial = 'completions_since_ad';
  static const _kRewardedLedger = 'rewarded_ledger_json';
  static const _kLastPurchaseAt = 'last_purchase_at';
  static const _kHasEverPurchased = 'has_ever_purchased';
  static const _kStarterPackOwned = 'starter_pack_owned';
  static const _kStarterPackClaimedDays = 'starter_pack_claimed_days';
  static const _kStarterPackLastClaim = 'starter_pack_last_claim';
  static const _kFirstPurchaseOfferShownAt = 'first_purchase_offer_shown_at';
  static const _kFirstPurchaseBonusUntil = 'first_purchase_bonus_until';

  DateTime? _readTime(String key) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _writeTime(String key, DateTime value) =>
      prefs.setString(key, value.toIso8601String());

  DateTime? get lastAdShownAt => _readTime(_kLastAdShownAt);
  Future<void> setLastAdShownAt(DateTime value) =>
      _writeTime(_kLastAdShownAt, value);

  /// كم إتمام مرحلة مؤهَّل مضى منذ آخر إعلان بيني
  int get completionsSinceInterstitial =>
      prefs.getInt(_kCompletionsSinceInterstitial) ?? 0;
  Future<void> setCompletionsSinceInterstitial(int value) =>
      prefs.setInt(_kCompletionsSinceInterstitial, value);

  /// دفتر الإعلانات الجائزية مُسلسلا — راجع lib/data/ads/rewarded_ads.dart
  String? get rewardedLedgerJson => prefs.getString(_kRewardedLedger);
  Future<void> setRewardedLedgerJson(String value) =>
      prefs.setString(_kRewardedLedger, value);

  DateTime? get lastPurchaseAt => _readTime(_kLastPurchaseAt);
  Future<void> setLastPurchaseAt(DateTime value) =>
      _writeTime(_kLastPurchaseAt, value);

  bool get hasEverPurchased => prefs.getBool(_kHasEverPurchased) ?? false;
  Future<void> setHasEverPurchased(bool value) =>
      prefs.setBool(_kHasEverPurchased, value);

  bool get starterPackOwned => prefs.getBool(_kStarterPackOwned) ?? false;
  Future<void> setStarterPackOwned(bool value) =>
      prefs.setBool(_kStarterPackOwned, value);

  /// كم قسطا من حزمة البداية قُبض (0..3). لا يُصفَّر أبدا — راجع قاعدة
  /// «القسط لا يسقط» في data/store/starter_pack.dart
  int get starterPackClaimedDays => prefs.getInt(_kStarterPackClaimedDays) ?? 0;
  Future<void> setStarterPackClaimedDays(int value) =>
      prefs.setInt(_kStarterPackClaimedDays, value);

  /// يوم آخر قبض (yyyy-MM-dd) — يمنع قبض قسطين في يوم واحد
  String? get starterPackLastClaimDate =>
      prefs.getString(_kStarterPackLastClaim);
  Future<void> setStarterPackLastClaimDate(String value) =>
      prefs.setString(_kStarterPackLastClaim, value);

  /// متى عُرض عرض الشراء الأول. وجوده أصلا = عُرض في هذا التثبيت،
  /// وهذا هو ما يمنع ظهوره مرتين.
  DateTime? get firstPurchaseOfferShownAt =>
      _readTime(_kFirstPurchaseOfferShownAt);
  Future<void> setFirstPurchaseOfferShownAt(DateTime value) =>
      _writeTime(_kFirstPurchaseOfferShownAt, value);

  DateTime? get firstPurchaseBonusUntil => _readTime(_kFirstPurchaseBonusUntil);
  Future<void> setFirstPurchaseBonusUntil(DateTime value) =>
      _writeTime(_kFirstPurchaseBonusUntil, value);

  // ─────────────────────── الصوت ───────────────────────

  static const _kMusicEnabled = 'music_enabled';
  static const _kSfxEnabled = 'sfx_enabled';
  static const _kAssistantEnabled = 'assistant_enabled';

  bool get musicEnabled => prefs.getBool(_kMusicEnabled) ?? true;
  bool get sfxEnabled => prefs.getBool(_kSfxEnabled) ?? true;

  Future<void> setMusicEnabled(bool value) =>
      prefs.setBool(_kMusicEnabled, value);
  Future<void> setSfxEnabled(bool value) => prefs.setBool(_kSfxEnabled, value);

  /// مرشد الخريطة — مفعّل افتراضا
  bool get assistantEnabled => prefs.getBool(_kAssistantEnabled) ?? true;
  Future<void> setAssistantEnabled(bool value) =>
      prefs.setBool(_kAssistantEnabled, value);

  // ─────────────────────── لغة الواجهة ───────────────────────

  static const _kLanguage = 'ui_language';

  /// 'ar' أو 'en' — الافتراضي عربي
  String get language => prefs.getString(_kLanguage) ?? 'ar';

  Future<void> setLanguage(String value) => prefs.setString(_kLanguage, value);

  // ─────────────────────── الإشعارات المحلية ───────────────────────

  bool get notifDailyRewardEnabled =>
      prefs.getBool(_kNotifDailyRewardEnabled) ?? true;
  bool get notifRewardTrackEnabled =>
      prefs.getBool(_kNotifRewardTrackEnabled) ?? true;
  bool get notifStreakEnabled => prefs.getBool(_kNotifStreakEnabled) ?? true;

  Future<void> setNotifDailyRewardEnabled(bool value) =>
      prefs.setBool(_kNotifDailyRewardEnabled, value);
  Future<void> setNotifRewardTrackEnabled(bool value) =>
      prefs.setBool(_kNotifRewardTrackEnabled, value);
  Future<void> setNotifStreakEnabled(bool value) =>
      prefs.setBool(_kNotifStreakEnabled, value);

  /// أي أنواع الإشعارات "استُهلكت" فعلا اليوم (جُدولت مرة على الأقل، حتى
  /// لو أُلغيت لاحقا) — لا تُعاد جدولتها مطلقا بعد ذلك في نفس اليوم، وهذا
  /// ما يضمن السقف 2/يوم الفعلي عبر إعادات مزامنة متعددة (كل فتح تطبيق).
  /// يُصفَّر ضمنيا حين يختلف [notificationsSentDate] عن اليوم الحالي
  /// (يتحقّق منه المستدعي في notifications_coordinator)
  String? get notificationsSentDate => prefs.getString(_kNotificationsSentDate);
  Set<String> get notificationsSentTypes =>
      (prefs.getStringList(_kNotificationsSentTypes) ?? const []).toSet();
  Future<void> setNotificationsSentDate(String value) =>
      prefs.setString(_kNotificationsSentDate, value);
  Future<void> setNotificationsSentTypes(Set<String> types) =>
      prefs.setStringList(_kNotificationsSentTypes, types.toList());

  /// null يعني لم يُفتح التطبيق قط من قبل (تثبيت جديد)
  String? get lastAppOpenedAt => prefs.getString(_kLastAppOpenedAt);
  Future<void> setLastAppOpenedAt(String value) =>
      prefs.setString(_kLastAppOpenedAt, value);

  int get sessionCount => prefs.getInt(_kSessionCount) ?? 0;
  Future<void> setSessionCount(int value) =>
      prefs.setInt(_kSessionCount, value);

  bool get notificationPermissionRequested =>
      prefs.getBool(_kNotificationPermissionRequested) ?? false;
  Future<void> setNotificationPermissionRequested(bool value) =>
      prefs.setBool(_kNotificationPermissionRequested, value);

  // ─────────────────────── عناصر زخرفية معلَّقة ───────────────────────
  //
  // معرّفات عناصر زخرفية مُنحت فعلا (إنجاز أسطوري، طبقة جرّة..) قبل أن
  // يُبنى كتالوج/مخزون الأزياء الفعلي (مهمة منفصلة). لا مكافأة تُفقَد:
  // متى بُني ذلك المخزون، يقرأ هذه القائمة مرة واحدة ويحوّل كل عنصر فيها
  // إلى ملكية حقيقية، ثم يُفرَّغ.
  Set<String> get pendingCosmeticUnlocks =>
      (prefs.getStringList(_kPendingCosmeticUnlocks) ?? const []).toSet();

  Future<void> setPendingCosmeticUnlocks(Set<String> ids) =>
      prefs.setStringList(_kPendingCosmeticUnlocks, ids.toList());

  Future<void> addPendingCosmeticUnlock(String id) =>
      setPendingCosmeticUnlocks({...pendingCosmeticUnlocks, id});

  // ─────────────────────── دخول النزال اليومي ───────────────────────
  //
  // يُتتبَّع محليا كسقف عجلة الحظ وميزانية الإعلانات تماما. الدخول
  // المجاني يتجدّد يوميا، فردّ "دخول مجاني" عند انتهاء صلاحية نزال لا
  // يعني شيئا بعد منتصف الليل — لذلك الخادم يردّ العملات المدفوعة فقط

  // ─────────────────────── تقدّم التحدّيات اللغوية ───────────────────────
  //
  // معرّفات العناصر المحلولة ("proverb:3")، ومعرّفات صناديق الفئات
  // المستلَمة ("proverb"). راجع lib/data/challenge_progress.dart.
  static const _kSolvedChallenges = 'solved_challenges';
  static const _kClaimedChallengeChests = 'claimed_challenge_chests';

  Set<String> get solvedChallenges =>
      (prefs.getStringList(_kSolvedChallenges) ?? const []).toSet();

  Future<void> setSolvedChallenges(Set<String> ids) =>
      prefs.setStringList(_kSolvedChallenges, ids.toList());

  Set<String> get claimedChallengeChests =>
      (prefs.getStringList(_kClaimedChallengeChests) ?? const []).toSet();

  Future<void> setClaimedChallengeChests(Set<String> ids) =>
      prefs.setStringList(_kClaimedChallengeChests, ids.toList());

  // ─────────────────────── البدء من جديد ───────────────────────

  /// المفاتيح التي تنجو من [resetProgress]: كل ما ليس تقدّم لعب.
  ///
  /// - تفضيلات جهاز: إعادة اللعبة من الصفر لا تعني نسيان لغة اللاعب ولا
  ///   إعادة تشغيل موسيقى أطفأها.
  /// - هوية: اسم اللاعب ومعرّف التثبيت. مسح معرّف التثبيت مع
  ///   referral_redeemed كان يجعل «ابدأ من جديد ثم استبدل نفس رمز
  ///   الدعوة» مزرعة دعوات.
  /// - ما دُفع ثمنه: إزالة الإعلانات وحزمة البداية وأقساطها ومكافأة
  ///   الشراء الأول. الشراء ليس تقدّما، ولا مسار «استعادة المشتريات»
  ///   يعيده إن مُسح.
  /// - جلسة Supabase (مفاتيح `sb-`): يخزّنها supabase_flutter في نفس
  ///   SharedPreferences، ومسحها يُنشئ حسابا مجهولا جديدا فتضيع قائمة
  ///   الأصدقاء ورمز الصديق وسجلّ لوحة الترتيب كلها.
  static const _preservedOnReset = <String>{
    _kLanguage,
    _kMusicEnabled,
    _kSfxEnabled,
    _kAssistantEnabled,
    _kNotifDailyRewardEnabled,
    _kNotifRewardTrackEnabled,
    _kNotifStreakEnabled,
    _kNotificationPermissionRequested,
    _kPlayerName,
    _kPlayerNameAsked,
    _kAppRated,
    _kInstallId,
    _kReferralRedeemed,
    // «البدء من جديد» ثم إعادة إضافة الودجة كان مزرعة 100 ألماسة —
    // نفس علّة _kReferralRedeemed تماما
    _kWidgetActivationRewarded,
    _kWidgetPromoShown,
    _kAdsRemoved,
    _kHasEverPurchased,
    _kLastPurchaseAt,
    _kStarterPackOwned,
    _kStarterPackClaimedDays,
    _kStarterPackLastClaim,
    _kFirstPurchaseOfferShownAt,
    _kFirstPurchaseBonusUntil,
  };

  /// بادئة مفاتيح جلسة Supabase داخل SharedPreferences
  static const _supabaseKeyPrefix = 'sb-';

  /// بادئة سجلّ RevenueCat (store/revenuecat_iap_service.dart): ما سُلِّم من
  /// معاملات وخطّ أساس التثبيت. مسحه يجعل كل شراء سابق «جديدا» فيُسلَّم
  /// ثانية — نفس علّة «ما دُفع ثمنه» أعلاه
  static const _billingKeyPrefix = 'rc_';

  static bool _isPreservedOnReset(String key) =>
      _preservedOnReset.contains(key) ||
      key.startsWith(_supabaseKeyPrefix) ||
      key.startsWith(_billingKeyPrefix);

  /// يمسح كل تقدّم محلي: المراحل والعملات والسلسلة والإنجازات
  /// والمهام. عملية لا رجعة فيها — اطلب تأكيدا قبل استدعائها.
  ///
  /// يمسح كذلك مفاتيح [ProgressionRepository] (نظام v2)، لذا استدعِ
  /// [ProgressionRepository.resetToInitial] بعدها مباشرة كي تُصفَّر
  /// الحالة المحفوظة في الذاكرة أيضا، لا المخزّنة فقط.
  Future<void> resetProgress() async {
    final preserved = <String, Object>{};
    for (final key in prefs.getKeys()) {
      if (!_isPreservedOnReset(key)) continue;
      final value = prefs.get(key);
      if (value != null) preserved[key] = value;
    }

    await prefs.clear();

    for (final entry in preserved.entries) {
      final value = entry.value;
      if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(entry.key, value);
      }
    }
  }
}
