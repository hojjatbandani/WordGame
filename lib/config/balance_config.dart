/// كل رقم يشكّل اقتصاد وتوازن اللعبة يعيش هنا فقط — ولا يوجد أي رقم
/// توازن (تكلفة، عتبة، مكافأة) مكتوب مباشرة في أي ملف آخر. أي تعديل على
/// التوازن يبدأ وينتهي في هذا الملف.
///
/// كل الحقول غير final عمدا: نقطة الحقن الوحيدة لجدول remote_config
/// المستقبلي (مهمة لاحقة) هي استبدال هذه القيم وقت التشغيل دون إصدار
/// جديد من التطبيق. هذا الملف لا يبني تلك المزامنة، فقط يوفّر مكانا
/// واحدا آمنا لتستبدل فيه القيم لاحقا.
library;

import '../data/wheel/wheel_models.dart';

class BalanceConfig {
  BalanceConfig._();

  // ─────────────────────── بنية العوالم والفصول ───────────────────────

  static int worldCount = 8;
  static int chaptersPerWorld = 5;

  /// عدد مراحل كل عالم: 60 للعوالم 1-4 (Group A)، 65 للعوالم 5-8 (Group B)
  static int worldStageCountGroupA = 60;
  static int worldStageCountGroupB = 65;

  /// آخر عالم في Group A — ما بعده ينتمي لـ Group B
  static int groupABoundaryWorldId = 4;

  static int worldStageCount(int worldId) => worldId <= groupABoundaryWorldId
      ? worldStageCountGroupA
      : worldStageCountGroupB;

  static int get totalStages =>
      groupABoundaryWorldId * worldStageCountGroupA +
      (worldCount - groupABoundaryWorldId) * worldStageCountGroupB;

  static int get totalBossStages => worldCount * chaptersPerWorld;

  // ─────────────────────── فتح المراحل ───────────────────────

  /// أول N مرحلة مفتوحة عند أول تشغيل، بلا حاجة لإكمال ما قبلها.
  /// واحدة عمدا: اللاعب يبدأ بالمرحلة الأولى وحدها، وكل إتمام يفتح
  /// التالية — لا بوابات نجوم ولا جرّة في مسار التقدّم.
  static int initiallyUnlockedStageCount = 1;

  // ─────────────────────── فتح التحدّيات اللغوية ───────────────────────
  //
  // الأنماط الأربعة في الرئيسية ليست متاحة من اللحظة الأولى: تُفتح
  // واحدا بعد الآخر مع تقدّم اللاعب في الرحلة، فيبقى للرحلة ما تعد به.

  /// النمط الأول يُفتح بعد إتمام هذا العدد من الفصول — لا بعد عالم
  /// كامل: انتظار 60 مرحلة قبل أول نمط جديد وعدٌ بعيد جدا، واللاعب
  /// الذي لم يرَ أي جديد في فصليه الأولين يملّ قبل أن يصل.
  static int challengeFirstUnlockChapters = 2;

  /// وكل نمط بعده يحتاج هذا العدد من العوالم المكتملة إضافةً لما قبله:
  /// النمط2 عند عالمين، النمط3 عند أربعة، النمط4 عند ستة.
  static int challengeUnlockWorldStep = 2;

  // ─────────────────────── جرّة الكلمات الإضافية لكل عالم ───────────────────────
  //
  // الجرّة مكافأة جانبية بحتة (طبقات JarRewards) ولا تفتح شيئا في مسار
  // التقدّم — فتح العالم التالي يتبع إتمام مراحله وحده.

  /// غير const عمدا: قابلة للاستبدال الكامل لاحقا من remote_config
  static Map<int, int> jarThresholdByWorld = {
    1: 40,
    2: 60,
    3: 80,
    4: 100,
    5: 120,
    6: 140,
    7: 160,
    8: 180,
  };

  static int jarThresholdForWorld(int worldId) =>
      jarThresholdByWorld[worldId] ??
      (throw ArgumentError('لا عتبة جرّة معرّفة للعالم $worldId'));

  // ─────────────────────── نقاط الخبرة (XP) ───────────────────────

  static int xpPerStageClear = 20;
  static int xpPerBonusWord = 5;
  static int xpBossStageExtra = 25;
  static int xpPerChapterComplete = 40;
  static int xpPerWorldComplete = 150;

  /// XP اللازمة للانتقال من المستوى n إلى n+1 = xpBaseForLevel +
  /// xpIncrementPerLevel * (n - 1)
  static int xpBaseForLevel = 150;
  static int xpIncrementPerLevel = 50;

  // ─────────────────────── بوابات المستوى ───────────────────────

  static int levelGateReferral = 5;

  // ─────────────────────── الهجرة من v1 ───────────────────────

  static int migrationXpPerCompletedStage = 20;

  /// يُمنح كـ"معلّق" عبر [MigrationResult.pendingWelcomeChestCoins]، لا
  /// يُضاف مباشرة إلى wallet.coins أثناء الهجرة — راجع progression_migration.dart
  static int migrationWelcomeChestCoins = 200;

  // ─────────────────────── التحدّيات اللغوية ───────────────────────

  /// صندوق يُستلَم مرة واحدة عند حلّ كل عناصر فئة تحدٍّ (مثل، بيت،
  /// كلمة، مثل خليجي). أعلى من مكافأة العنصر الواحد بكثير: هو أجر
  /// إنهاء مجموعة كاملة لا أجر إجابة.
  static int challengeCategoryChestCoins = 150;

  // ─────────────────────── اقتصاد العملات: الكسب ───────────────────────

  /// رصيد أول تشغيل. كان الرقم مخبّأ كقيمة افتراضية في
  /// `ProgressStore.points` (`?? 100`) لا في ملف التوازن — فلم يكن
  /// قابلا للضبط عن بعد ولا مرئيا لمن يوازن الاقتصاد.
  static int startingCoins = 100;

  static int coinsStageClear = 8;
  static int coinsPerCoreWord = 2;
  static int coinsPerBonusWord = 2;

  /// مرحلة أُنهيت بلا أي تلميح — نفس تعريف StatKey.perfectLevels
  static int coinsPerfectStageBonus = 4;

  /// أرضية وسقف ما تدفعه المرحلة الواحدة على اللعب نفسه.
  ///
  /// المجموع كان ينفلت: 15 للإتمام + 2 لكل كلمة أساس + 3 لكل كلمة
  /// إضافية + 5 للكمال، ثم مضاعف العالم فوق ذلك — فتدفع مرحلة واحدة في
  /// العالم الثامن أكثر من صندوق فصل كامل. مجموع الأسطر الخمسة أدناه
  /// (الإتمام، الأساس، الإضافية، الكمال، الزعيم) يُحصر بين الرقمين.
  ///
  /// الأرضية شرط صريح لا نتيجة حساب: أصغر مرحلة في اللعبة كلمتان،
  /// فبالمكوّنات وحدها تدفع أقلَّ من المطلوب. حصرُها هنا يضمن الأرضية
  /// مهما تغيّر حجم المراحل أو عدد كلماتها لاحقا.
  ///
  /// **ليسا** حدّين على كل ما يُقبض عند إتمام مرحلة: صندوق الفصل وإتمام
  /// العالم حدثان لهما اسمهما ومكافأتهما، لا أجرَ لعبِ مرحلة.
  static int minCoinsPerStage = 16;
  static int maxCoinsPerStage = 24;

  /// مكافأتا آخر مرحلة في الفصل — صفر عمدا.
  ///
  /// كانت 25 و30، فيقبض اللاعب على المرحلة الأخيرة ~76 عملة ثم يقبض
  /// صندوق الفصل فوقها: ثلاث مكافآت لحدث واحد هو «أتممتَ الفصل».
  /// الصندوق (100 ثابتة) هو مكافأة إتمام الفصل، والمرحلة الأخيرة
  /// تدفع ما تدفعه أي مرحلة.
  ///
  /// الأنبوب كله باقٍ (breakdown وحدث تحليلي مستقل لكل سطر، وكلاهما
  /// يتخطّى الصفر): إعادة أيٍّ منهما رقمٌ واحد هنا أو من الضبط عن بعد.
  /// [coinsBossStageBonus] هو المرشّح لو أردنا لاحقا تمييز مرحلة
  /// الزعيم بأنها الأصعب في فصلها، دون أن تُدفع مكافأة الفصل مرتين.
  static int coinsBossStageBonus = 0;
  static int coinsChapterComplete = 0;

  /// صندوق الفصل: **رقم واحد ثابت لكل الفصول**.
  ///
  /// كان توزيعا مثلثيا بين 20 و100 بمنوال 45، وكانت البطاقة تعرض رقما
  /// والاستلام يقرع آخر فيَعِد بـ45 ويدفع 38. عولج التناقض أولا بجعل
  /// المبلغ مشتقّا من معرّف الفصل (فيتساوى المعروض والمدفوع مع بقاء
  /// التنويع)، ثم أُلغي التنويع أصلا: قيمة واحدة معلومة للاعب قبل أن
  /// يفتح، ولا مجال لأن يشعر أن صندوقه كان أفقر من صندوق غيره.
  static int coinsChapterChest = 100;

  static int coinsWorldComplete = 400;

  /// مكافأة الإنجاز حسب طبقته لا حسب معرّفه — الطبقة هي مقياس الصعوبة
  /// الوحيد في القائمة، فربط المكافأة بها يمنع تباعد الأرقام عند إضافة
  /// إنجاز جديد.
  ///
  /// السلّم كان 20/50/100. المطلوب «قمم محسوسة بلا تضخّم»، والقمة تأتي
  /// من الفارق بين الطبقات لا من كرمها المطلق: رفعُ الذهبي وخفضُ
  /// الفضّي يجعل الأعلى يُشعَر (أربعة أضعاف ونصف البرونزي بدل فارق
  /// باهت في الوسط)، مع بقاء مجموع ما تدفعه الإنجازات المئة كما كان
  /// تقريبا (~4200) — أي أن المنحنى تغيّر لا الميزانية.
  ///
  /// التدرّج الحقيقي يأتي من الطبقة **ومن ترتيب الإنجاز في سلّمه** معا:
  /// سلّم المراحل أُعيد توزيعه ليصعد مبكرا (1/5/10 برونزي، 25/50 فضّي،
  /// 75 فما فوق ذهبي) بدل أن يبقى برونزيا حتى الخمسين.
  ///
  /// الطبقة الأسطورية بلا عملات عمدا — مكافأتها زخرفية حصرية، راجع
  /// [Achievement.cosmeticRewardId].
  static int coinsAchievementBronze = 20;
  static int coinsAchievementSilver = 40;
  static int coinsAchievementGold = 90;

  /// مضاعف الكسب حسب العالم — يُطبَّق فقط على: إتمام المرحلة، الكلمة
  /// الأساسية، الكلمة الإضافية، مكافأة الإتقان (المذكورة حرفيا في
  /// المهمة). لا يُطبَّق على مكافأة الزعيم/إتمام الفصل/صندوق
  /// الفصل/إتمام العالم — تبقى هذه ثابتة بصرف النظر عن العالم عمدا.
  static Map<int, double> coinEarningMultiplierByWorld = {
    1: 1.00,
    2: 1.10,
    3: 1.20,
    4: 1.30,
    5: 1.45,
    6: 1.60,
    7: 1.75,
    8: 2.00,
  };

  static double coinEarningMultiplierForWorld(int worldId) =>
      coinEarningMultiplierByWorld[worldId] ??
      (throw ArgumentError('لا مضاعف كسب معرّف للعالم $worldId'));

  // ─────────────────────── اقتصاد العملات: الإنفاق (التلميحات) ───────────────────────

  /// سلّم تصعيد كلفة التلميح داخل المرحلة الواحدة: العنصر بالفهرس i هو
  /// كلفة التلميح رقم i+1. آخر عنصر يتكرر لكل ما بعده ("الرابع فما فوق").
  static List<int> hintEscalationLadder = [15, 25, 40, 70];

  /// [hintsUsedThisStage] = كم تلميحا استُخدم في هذه المرحلة *قبل* هذا
  /// التلميح (0 يعني هذا أول تلميح في المرحلة)
  static int hintBaseCostForPosition(int hintsUsedThisStage) {
    final index = hintsUsedThisStage < hintEscalationLadder.length
        ? hintsUsedThisStage
        : hintEscalationLadder.length - 1;
    return hintEscalationLadder[index];
  }

  static int coinsRevealEntireWord = 120;

  /// "كشف الكلمة كاملة" متاح من التلميح الثاني فصاعدا — أي بعد استخدام
  /// تلميح واحد على الأقل في هذه المرحلة
  static int revealEntireWordMinHintsUsedThisStage = 1;

  /// كل [bonusWordMilestoneEvery] كلمة إضافية *جديدة* تمنح
  /// [coinsBonusWordMilestone] عملة دفعة واحدة، فوق الخمس عملات لكل
  /// كلمة. الجديدة وحدها تُحتسب: إعادة إيجاد كلمة سبق اكتشافها في نفس
  /// المرحلة لا تقرّب اللاعب من المكافأة (وإلا صارت مزرعة عملات).
  static int bonusWordMilestoneEvery = 5;
  static int coinsBonusWordMilestone = 2;

  /// تلميحا شاشة اللعب سعران ثابتان معلومان قبل الضغط (لا سلّم تصاعدي
  /// ولا مضاعف عالم): الكشف المرتّب أغلى لأنه يختار الحرف *المفيد* —
  /// أول حرف ناقص من أول كلمة — بينما العشوائي قد يكشف حرفا لا يفكّ شيئا.
  static int coinsHintOrderedLetter = 40;
  static int coinsHintRandomLetter = 25;

  static int coinsSkipStage = 250;
  static int failedAttemptsBeforeSkipOffered = 3;

  static int coinsStreakFreeze = 200;
  static int maxStreakFreezesHeld = 2;

  /// كل [streakFreezeGrantEveryDays] يوما من السلسلة (7، 14، 21..) يُمنح
  /// تجميد مجاني تلقائيا (بحدود [maxStreakFreezesHeld] — أي منح يتجاوز
  /// الحد يُهدَر بصمت، لا يُراكَم لوقت لاحق)
  static int streakFreezeGrantEveryDays = 7;

  static int coinsJarBooster = 200;
  static Duration jarBoosterDuration = const Duration(minutes: 30);
  static double jarBoosterMultiplier = 2.0;

  /// مدى تسعير الأزياء فقط (Prompt 7) — لا أسعار أفراد بعد
  static int cosmeticsMinPrice = 300;
  static int cosmeticsMaxPrice = 1500;

  /// مضاعف كلفة التلميح حسب العالم — يفوق مضاعف الكسب قليلا عمدا
  /// (2.10 مقابل 2.00 في العالم 8) كي يشتدّ ضغط العملات تدريجيا عبر
  /// اللعبة بدل أن ينهار أو يتضخّم فجأة
  static Map<int, double> hintCostMultiplierByWorld = {
    1: 1.00,
    2: 1.10,
    3: 1.20,
    4: 1.35,
    5: 1.50,
    6: 1.70,
    7: 1.90,
    8: 2.10,
  };

  static double hintCostMultiplierForWorld(int worldId) =>
      hintCostMultiplierByWorld[worldId] ??
      (throw ArgumentError('لا مضاعف كلفة تلميح معرّف للعالم $worldId'));

  /// كل كلفة تلميح نهائية تُقرَّب لأقرب مضاعف لهذا الرقم
  static int hintCostRoundingUnit = 5;

  // ─────────────────────── شحنات التلميح المجانية ───────────────────────

  static int stagesPerFreeHintCharge = 5;
  static int maxHintCharges = 3;

  // ─────────────────────── وضع الأمان (أرضية العملات) ───────────────────────

  /// الشرطان معا (AND): عملات أقل من هذا الرقم، وفشل/تخلٍّ عن المرحلة
  /// الحالية [safetyModeMinFailedAttempts] مرة على الأقل.
  ///
  /// كان الرقم 20 بينما أرخص تلميح في شاشة اللعب 25: فمن يملك 22 عملة
  /// **لا يستطيع شراء أي تلميح** ومع ذلك لا تراه شبكةُ الأمان محتاجا.
  /// شبكة أمان لا تُفتح إلا بعد أن يعجز اللاعب بخمس عملات هي شبكة
  /// مغلقة على من صُمّمت له.
  ///
  /// الشرط الصحيح ليس رقما بل علاقة: «لا يقدر على أرخص تلميح». يبقى
  /// الحقل قابلا للضبط عن بعد، لكن قيمته الافتراضية تتبع السعر فلا
  /// ينفصلان مرة أخرى إن غُيّر السعر.
  static int safetyModeCoinThreshold = coinsHintRandomLetter;
  static int safetyModeMinFailedAttempts = 2;

  static int safetyModeAdRewardCoins = 25;
  static int safetyModeMiniChallengeRewardCoins = 15;

  /// مرة واحدة فقط في اليوم التقويمي الواحد لكل لاعب
  static int safetyModeFreeGrantCoins = 10;

  // ─────────────────────── تقويم الدخول اليومي ───────────────────────

  /// دوري لا لمرة واحدة: 3 جداول أسابيع صريحة، ثم الأسبوع الثالث يتكرر
  /// للأبد بدءا من [loginCalendarShardFromWeek]. الفوات لا يصفّر موضع
  /// التقويم أبدا — راجع lib/data/streak/streak_engine.dart لمنطق ذلك.
  static List<int> loginCalendarWeek1Coins = [20, 30, 40, 50, 75, 100, 200];
  static List<int> loginCalendarWeek2Coins = [25, 35, 50, 60, 80, 120, 250];
  static List<int> loginCalendarWeek3Coins = [30, 40, 55, 70, 90, 140, 300];

  /// من هذا رقم الأسبوع فصاعدا (1-based، يبدأ التكرار الفعلي من 4) تُمنح
  /// قطعة أزياء إضافية في يوم [loginCalendarShardDayInWeek] من كل أسبوع
  static int loginCalendarShardFromWeek = 4;
  static int loginCalendarShardDayInWeek = 7;
  static int loginCalendarShardAmount = 1;

  // ─────────────────────── مسار الجوائز (يومي/أسبوعي/شهري) ───────────────────────

  /// مسار مؤقّت لا دوري، بخلاف تقويم الدخول أعلاه: كل طبقة تنتهي بعدد
  /// مطالباتها فلا تُمنح بعدها شيئا أبدا، وينتهي المسار كله بعد ستة
  /// أشهر (6 مطالبات شهرية × 30 يوما). راجع lib/data/rewards/
  /// reward_track.dart للجدول الزمني الكامل.
  ///
  /// مجموع ما يمنحه المسار على مدى ستة أشهر:
  /// 30×20 + 4×50 + 6×200 = 2000 ألماسة.
  ///
  /// الطبقة اليومية ثلاثون مطالبة لا سبعا: أسبوع واحد كان ينتهي قبل أن
  /// تترسّخ عادة الفتح اليومي أصلا، فيرى اللاعبُ الطبقةَ تُغلق في
  /// الأسبوع الذي يقرّر فيه إن كان سيبقى. شهر كامل يغطّي نافذة القرار.
  static int rewardTrackDailyCoins = 20;
  static int rewardTrackDailyClaims = 30;

  static int rewardTrackWeeklyCoins = 50;
  static int rewardTrackWeeklyClaims = 4;

  static int rewardTrackMonthlyCoins = 200;
  static int rewardTrackMonthlyClaims = 6;

  /// مكافأة تفعيل ودجة الشاشة الرئيسية — مرة واحدة لكل تثبيت، لا تتكرّر
  /// بإزالة الودجة وإعادتها (راجع lib/data/widget/widget_activation.dart).
  /// منحة لمرة واحدة لا صنبورا دوريا، فلا تدخل في حساب فاست اليوم.
  static int widgetActivationRewardCoins = 100;

  /// لا يُعرض عرض «أضف الودجة» قبل إتمام هذا العدد من المراحل: طلب
  /// إضافة ودجة من لاعب لم يقرّر بعد أنه سيلعب غدا طلبٌ في غير أوانه
  static int widgetPromoAfterStages = 5;

  // ─────────────────────── عجلة الحظ ───────────────────────

  /// 8 قطاعات موزونة — الوزن نسبي لا نسبة مئوية مباشرة، يُقسَم على
  /// المجموع الفعلي في wheel_engine.dart (يصادف هنا 100 بالضبط، لا حاجة
  /// لضبطه لو أُضيف/حُذف قطاع لاحقا).
  static List<WheelSegmentDef> wheelSegments = const [
    WheelSegmentDef(type: WheelPrizeType.coins, value: 20, weight: 22),
    WheelSegmentDef(type: WheelPrizeType.coins, value: 30, weight: 20),
    WheelSegmentDef(type: WheelPrizeType.coins, value: 50, weight: 18),
    WheelSegmentDef(type: WheelPrizeType.coins, value: 75, weight: 14),
    WheelSegmentDef(type: WheelPrizeType.hintCharge, value: 1, weight: 12),
    WheelSegmentDef(type: WheelPrizeType.coins, value: 100, weight: 8),
    WheelSegmentDef(type: WheelPrizeType.jarBooster, value: 1, weight: 4),
    WheelSegmentDef(type: WheelPrizeType.coins, value: 250, weight: 2),
  ];

  /// دورات إضافية بإعلان في اليوم بعد الدورة المجانية. عدّاد للعجلة وحدها:
  /// لا تأكل من ميزانية إعلانات العملات ([rewardedDailyBudget]) ولا تأكل
  /// تلك منها، فوعد «مجانية + 3 بالإعلانات» المكتوب على الشاشة ثابت لا
  /// ينقص لأن اللاعب ضاعف جائزة مرحلة قبله.
  static int wheelAdSpinsPerDay = 3;

  // ─────────────────────── ميزانية الإعلانات اليومية العامة ───────────────────────
  //
  // "Prompt 10" المذكورة في economy/safety_mode.dart — لم تُبنَ من قبل.
  // مشتركة بين كل ميزة تمنح عملات بمشاهدة إعلان. عجلة الحظ خارجها: لها
  // عدّادها الخاص ([wheelAdSpinsPerDay]).
  /// اسم قديم للميزانية المشتركة. صار مرآة لـ[rewardedDailyBudget] بعد
  /// توحيد كل السطوح على دفتر واحد — رقمان منفصلان كانا يعنيان
  /// ميزانيتين فعليتين مهما قيل إنها «مشتركة».
  static int get globalDailyAdBudget => rewardedDailyBudget;

  // ─────────────────────── الأصدقاء ───────────────────────

  /// طول رمز الصديق الدائم. مفروض في الخادم أيضا
  /// (generate_friend_code في supabase/schema_social_v2.sql) — الرقم هنا
  /// للواجهة: طول حقل الإدخال والنص النائب.
  static int friendCodeLength = 8;

  /// سقف قائمة الأصدقاء. مفروض في الخادم (max_friends) لا في الواجهة —
  /// الرقم هنا لعرض «١٩٨ من ٢٠٠» ولإبقاء الرقمين في مكان واحد.
  static int maxFriends = 200;

  // ─────────────────────── الدعوات ───────────────────────

  static int referralRewardInviter = 150;
  static int referralRewardInvitee = 100;

  /// لا يُدفع للداعي قبل أن يبلغ مدعوّه هذا المستوى. الفحص الفعلي في
  /// الخادم (try_qualify_referral) من XP المخزَّنة، لا هنا.
  static int referralQualifyLevel = 3;

  /// سقف الدعوات *الناجحة* (المدفوعة) لكل حساب
  static int referralMaxPaidPerAccount = 20;

  /// عتبات مكافآت مراحل الدعوة → معرّف الزينة الممنوحة. زخرفية بحتة، لا
  /// عملات: مضاعفة العملات على نفس المحور كانت ستضاعف حافز التزوير.
  /// المعرّفات تطابق public.referral_milestones() في الخادم.
  static Map<int, String> referralMilestoneCosmetics = {
    3: 'invite_milestone_3',
    5: 'invite_milestone_5',
    10: 'invite_milestone_10',
  };

  // ─────────────────────── مشاركة النتيجة ───────────────────────

  static int shareRewardCoins = 15;

  /// سقف *مدى الحياة* لا سقف يومي: مكافأة المشاركة غرضها إثبات أن الزرّ
  /// يعطي شيئا فعلا، لا أن تصير دخلا يوميا. مشاركتان مكافأتان ثم يبقى
  /// الزرّ للمشاركة نفسها بلا عملات — ولهذا لا يُعلَن المبلغ على الزرّ
  /// أصلا (راجع share_result_row.dart): وعدٌ ينتهي بعد مرّتين ويظلّ
  /// مكتوبا يُقرأ خُلفا للوعد.
  static int shareRewardMaxTotal = 2;

  // ─────────────────────── بوابة مستوى الدعوة ───────────────────────
  // levelGateReferral أعلاه (في «بوابات المستوى») هو المستوى الذي تظهر
  // عنده دعوة الأصدقاء أصلا. طلب الدعوة قبل أن يعيش اللاعب اللعبة يحرق
  // الطلب بلا مقابل: لا يدعو أحدا، ولا يعود الطلب مرة ثانية.

  // ═══════════════════ إيقاع الإعلانات البينية ═══════════════════
  //
  // مبدأ الجدول: أخفّ ما يمكن في البداية. الإعلان البيني المبكر هو أكبر
  // مصدر منفرد لفقدان الاحتفاظ باليوم الأول في هذا النوع من الألعاب —
  // اللاعب لم يفهم اللعبة بعد، فيقرأ الإعلان حكما عليها كلها.
  //
  // المفتاح = رقم المرحلة الذي يبدأ عنده المدى، والقيمة = كل كم إتمام
  // مرحلة يُعرض إعلان. غياب مدى المرحلة 1 مقصود: لا إعلان إطلاقا قبل
  // [interstitialFirstEligibleStage].

  /// لا إعلان بيني قبل هذه المرحلة تحت أي مسار في الشيفرة
  static int interstitialFirstEligibleStage = 13;

  /// (بداية المدى → كل كم مرحلة). يُقرأ تنازليا: أكبر مفتاح ≤ رقم المرحلة
  static Map<int, int> interstitialCadenceByStage = {13: 5, 41: 4, 121: 3};

  /// كل كم إتمام مرحلة يُعرض إعلان بيني عند [stageNumber].
  /// صفر يعني «ممنوع هنا» — لا «كل صفر مراحل».
  static int interstitialCadenceForStage(int stageNumber) {
    if (stageNumber < interstitialFirstEligibleStage) return 0;
    var bestKey = -1;
    for (final key in interstitialCadenceByStage.keys) {
      if (stageNumber >= key && key > bestKey) bestKey = key;
    }
    return bestKey < 0 ? 0 : interstitialCadenceByStage[bestKey]!;
  }

  /// لا إعلان خلال هذه المدة من أي إعلان آخر — تُقاس بالساعة الحقيقية
  /// فتبقى سارية عبر الشاشات وعبر تصغير التطبيق وإعادة فتحه
  static Duration adGlobalCooldown = const Duration(seconds: 90);

  /// كل الإعلانات البينية تُكتم هذه المدة بعد أي شراء
  static Duration interstitialSuppressionAfterPurchase = const Duration(
    hours: 24,
  );

  // ═══════════════════ طول الإعلان ═══════════════════
  //
  // نموذجان لا أكثر: قصير وطويل. أيّهما يُعرض في أيّ سطح تقرّره خريطة
  // واحدة (data/ads/ad_format.dart) لا كل شاشة على حدة — بلا ذلك يقرّر
  // كل مسار جديد طولا مختلفا بصمت.

  /// القصير: بين المراحل، ومضاعفة جائزة المرحلة
  static Duration shortAdDuration = const Duration(seconds: 5);

  /// الطويل: العجلة، والمتجر، وصندوق الفصل
  static Duration longAdDuration = const Duration(seconds: 15);

  // ═══════════════════ الإعلانات الجائزية ═══════════════════
  //
  // ميزانية واحدة مشتركة بين كل السطوح (العجلة، وضع الأمان، شحن
  // العملات). التصاعد داخل اليوم هو ما يدفع اللاعب إلى المشاهدات
  // المتأخرة الأعلى عائدا: من يعرف أن الرابعة تعطي 50 يصل إليها.

  static int rewardedDailyBudget = 4;

  /// مكافأة المشاهدة رقم n (بدءا من 1). ما بعد آخر قيمة يأخذ آخرها.
  static List<int> rewardedRewardLadder = [20, 30, 40, 50];

  /// مكافأة بطاقة «شاهد إعلانا» في المتجر — ثابتة، خارج السلّم أعلاه.
  /// تستهلك من الميزانية المشتركة نفسها.
  static int shopAdRewardCoins = 70;

  /// مضاعفة الجائزة بإعلان — **مضاعفة كاملة حرفيا**: ما يُمنح هو نفس
  /// المبلغ المعروض مرة ثانية، فيصير المجموع ضعفه بالضبط.
  ///
  /// كانت نسبة (0.75) بسقف (15): جائزة 16 تصير 28 لا 32، والزرّ يقول
  /// «×2». الوفر الاقتصادي لا يساوي ثمنه: اللاعب يرى الرقمين — قبل
  /// وبعد — فيحسب الفرق في ثانية، ولاعبٌ ضبط اللعبةَ تُخلف وعدا مكتوبا
  /// لا يصدّق بعدها عرضا آخر. حدُّ الإعلانات هو ميزانية المشاهدات
  /// اليومية ([rewardedDailyBudget]) لا اقتطاعٌ خفيّ من المعروض.
  ///
  /// المفتاحان يبقيان قابلين للضبط عن بعد للطوارئ: [adDoubleBonusRatio]
  /// نسبة الممنوح من المعروض، و[adDoubleBonusCap] سقف مطلق حيث **0
  /// يعني بلا سقف**. أي قيمة غير (1.0، 0) تُخلف وعد «×2» على الزرّ،
  /// فلا تُغيَّر إلا مع تغيير نصّ الزرّ معها.
  static double adDoubleBonusRatio = 1.0;
  static int adDoubleBonusCap = 0;

  static int adDoubleBonusFor(int reward) {
    if (reward <= 0) return 0;
    final scaled = (reward * adDoubleBonusRatio).round();
    if (adDoubleBonusCap <= 0) return scaled;
    return scaled < adDoubleBonusCap ? scaled : adDoubleBonusCap;
  }

  static int rewardedRewardForView(int viewNumber) {
    if (viewNumber < 1) {
      throw ArgumentError('رقم المشاهدة يبدأ من 1: $viewNumber');
    }
    final index = (viewNumber - 1).clamp(0, rewardedRewardLadder.length - 1);
    return rewardedRewardLadder[index];
  }

  // ═══════════════════ المتجر والعروض ═══════════════════

  /// لا شارة ولا نافذة ولا عرض بيني قبل إتمام الفصل الأول. اللاعب في
  /// فصله الأول لم يقرّر بعد أن اللعبة تستحق وقته، فضلا عن ماله.
  static int storePromoMinChaptersCompleted = 1;

  /// ورقة «ينقصك القليل»: تظهر فقط حين يكون النقص ≤ هذه النسبة من
  /// السعر. أبعد من ذلك تُقرأ جدارا لا فرصة، والفرق ليس ذوقا: على بعد
  /// 20 عملة من شيء قرّر اللاعب شراءه فعلا، بينما على بعد 60 يكون
  /// العرض إعلانا مقحما في لحظة إحباط.
  static double nearMissMaxDeficitRatio = 0.25;

  // ─────────── محفّز الشراء الأول (سلوكي لا تقويمي) ───────────
  // كل الشروط مطلوبة معا. المحفّزات السلوكية تحوّل أضعافا مقارنة
  // بـ«اليوم الثالث» التقويمي: اللحظة نفسها هي الرسالة.

  static int firstPurchaseMaxCoinBalance = 30;
  static int firstPurchaseMinStageFailures = 2;
  static int firstPurchaseMinStagesCompleted = 20;
  static Duration firstPurchaseMinGapBetweenShows = const Duration(days: 7);
  static Duration firstPurchaseOfferDuration = const Duration(hours: 24);
  static int firstPurchaseOfferDiscountPercent = 70;

  /// أي شراء أول، مهما صغر، يمنح مضاعف عملات مؤقّتا وزينة حصرية —
  /// «أخذت أكثر من المعروض» هو ما يرفع احتمال الشراء الثاني
  static Duration firstPurchaseBonusDuration = const Duration(hours: 24);
  static double firstPurchaseCoinMultiplier = 1.20;
  static String firstPurchaseAvatarId = 'avatar_first_supporter';
}
