// النموذج السلوكي لمحاكاة الاقتصاد — أرقام *سلوك* لا أرقام *توازن*.
//
// الفصل صارم: كل رقم توازن (مكافأة، كلفة، عتبة) يأتي من BalanceConfig
// والمحرّكات الحقيقية حصرا، ولا يُكرَّر هنا. ما يعيش هنا هو ما لا تملكه
// اللعبة أصلا: كيف يتصرّف البشر — كم يوما يلعبون، كم يعيدون لعب مراحل
// قديمة، متى يشترون زينة، متى يبخلون بتلميح.
//
// كل ثابت هنا افتراض نموذج موثَّق. تغييره يغيّر نتائج المحاكاة لا
// اللعبة. التقرير المولَّد يطبع هذه الافتراضات كاملة كي لا يُقرأ رقم
// ناتج بمعزل عن سلوكه المفترض.

import 'dart:math';

/// أنماط اللاعبين الأربعة كما نصّت المهمة حرفيا (الحصة، الجلسات،
/// المراحل، معدّل التلميحات)، مع سلوكيات مكمّلة لا بد منها لأي محاكاة
/// يوما-بيوم ولم تنصّ عليها المهمة — موثَّقة حقلا حقلا.
class ArchetypeSpec {
  final String id;
  final String nameEn;

  /// حصة النمط من الألف لاعب
  final double share;

  final int sessionsPerDay;

  /// مراحل تُلعب في يوم لعب واحد (المجموع عبر الجلسات)
  final int stagesPerDay;

  final double meanHintsPerStage;

  /// نسبة المراحل المهجورة (فشل/تخلٍّ) من مراحل اليوم
  final double abandonRate;

  // ── سلوكيات غير منصوصة، افتراضات نموذج ──

  /// احتمال أن يلعب في يوم تقويمي معيّن. لا أحد يلعب 30/30 —
  /// الاحتفاظ الفعلي لهذه الفئة من الألعاب يجعل حتى «المنتظم» يفوّت
  /// يوما أو يومين في الأسبوع.
  final double playProb;

  /// نسبة مراحل اليوم التي هي *إتمام أول* (تقدّم فعلي). الباقي إعادة
  /// لعب (نجوم/كلمات إضافية) — إعادة اللعب تدفع صفر عملات في المحرّك
  /// الحقيقي لكنها تُطعم الجرّة. لاعبو ألعاب الكلمات يعيدون كثيرا.
  final double newStageShare;

  /// متوسط الكلمات الإضافية المكتشفة في مرحلة جديدة (بواسون، سقف 3)
  final double bonusMeanNew;

  /// متوسط الكلمات الإضافية *الجديدة* في إعادة لعب عادية
  final double bonusMeanReplay;

  /// متوسطها في إعادة لعب «حصاد» أثناء انسداد بوابة عالم — أعلى لأن
  /// اللاعب يتعمّد المراحل التي بقيت فيها كلمات لم تُكتشف
  final double bonusMeanFarm;

  /// احتمال مطالبة مكافأة الدخول اليومية في يوم لعب
  final double loginClaimProb;


  /// احتمالات إكمال مهمة اليوم السهلة/المتوسطة/الصعبة (صفر = لا مهمات)
  final double missionEasyProb;
  final double missionMediumProb;
  final double missionHardProb;

  /// احتمال إكمال شارة المهمات الأسبوعية في أسبوع معيّن
  final double weeklyBadgeProb;

  /// يشاهد كل الإعلانات الجائزية (4/يوم بالسلّم المتصاعد)
  final bool watchesAllAds;

  /// كم مرة في اليوم يشاهد إعلانا ليضاعف جائزة مرحلة انتهى منها للتوّ.
  ///
  /// مسار منفصل عن [watchesAllAds]: ذاك ينفق الميزانية على سطح «اشحن
  /// عملات» بالسلّم المتصاعد (20/30/40/50)، وهذا ينفقها على
  /// `RewardedAdsNotifier.doubleReward` لحظة إنهاء المرحلة. الميزانية
  /// اليومية واحدة مشتركة (BalanceConfig.rewardedDailyBudget) فيتنافس
  /// المساران عليها — وهذا هو سلوك اللعبة الحقيقي.
  final int adDoublesPerDay;

  /// نسبة التلميحات التي يشتريها اللاعب بالكشف *المرتّب* (الأغلى)
  /// بدل العشوائي. أغلب اللاعبين يبخلون فيأخذون الأرخص، ومن يتعثّر
  /// يدفع أكثر ليضمن الحرف المفيد.
  final double orderedHintShare;

  /// يدير عجلة الحظ المجانية يوميا
  final bool spinsWheel;


  /// لا يشتري تلميحا يُنزل رصيده تحت هذا الرقم — «اكتناز دفاعي».
  /// المتعثّر وحده يحتاجه: بلا احتياطي ينفق آخر عملاته على تلميحات ثم
  /// يقضي بقية اليوم تحت عتبة وضع الأمان.
  final int hintReserve;

  /// سياسة شراء الزينة: حين يتجاوز الرصيد [cosmeticThreshold] يشتري
  /// باحتمال [cosmeticProb] قطعة بسعر منتظم في [cosmeticMin..cosmeticMax]
  /// (داخل مدى BalanceConfig.cosmeticsMin/MaxPrice دوما)، بحد
  /// [cosmeticMaxPerDay] يوميا. هذا هو المصرف الكبير الذي تختبره
  /// المحاكاة — سطر «الزينة رخيصة أو قليلة» في تأكيد الطاحن.
  final int cosmeticThreshold;
  final double cosmeticProb;
  final int cosmeticMin;
  final int cosmeticMax;
  final int cosmeticMaxPerDay;

  /// عند انسداد بوابة عالم: يدفع 500 (BalanceConfig) للتجاوز إن بقي
  /// له بعدها هذا الاحتياطي على الأقل
  final int bypassReserve;

  const ArchetypeSpec({
    required this.id,
    required this.nameEn,
    required this.share,
    required this.sessionsPerDay,
    required this.stagesPerDay,
    required this.meanHintsPerStage,
    required this.abandonRate,
    required this.playProb,
    required this.newStageShare,
    required this.bonusMeanNew,
    required this.bonusMeanReplay,
    required this.bonusMeanFarm,
    required this.loginClaimProb,
    required this.missionEasyProb,
    required this.missionMediumProb,
    required this.missionHardProb,
    required this.weeklyBadgeProb,
    required this.watchesAllAds,
    required this.adDoublesPerDay,
    required this.orderedHintShare,
    required this.spinsWheel,
    required this.hintReserve,
    required this.cosmeticThreshold,
    required this.cosmeticProb,
    required this.cosmeticMin,
    required this.cosmeticMax,
    required this.cosmeticMaxPerDay,
    required this.bypassReserve,
  });
}

/// التوزيع المطلوب حرفيا: 45/35/15/5 على ألف لاعب.
///
/// ملاحظة معايرة صريحة — الثوابت السلوكية أدناه ليست اعتباطية:
/// تأكيدا «المنتظم» (رصيد وسيط 300-800 كل يوم 3-30) و(مصدر/مصرف بين
/// 1.10 و1.30) مترابطان رياضيا: النسبة والرصيد المتراكم وجهان لنفس
/// الفارق مصدر−مصرف، فمجموع مصدر المنتظم في 30 يوما لا يجوز أن يتجاوز
/// ~8800 عملة وإلا استحال إرضاؤهما معا. مع كرم المنح اليومية الحالي في
/// BalanceConfig (تقويم دخول ~85/يوم + تحدٍّ ~65 + مهمات) يفرض ذلك
/// نمطا يفوّت أياما، ولا يطالب بكل منحة، ويقضي جزءا كبيرا من مراحله
/// إعادة لعب. هذه المنطقة الضيقة هي بالضبط ما تكشفه المحاكاة.
const archetypes = <ArchetypeSpec>[
  ArchetypeSpec(
    id: 'casual',
    nameEn: 'Casual',
    share: 0.40,
    sessionsPerDay: 1,
    stagesPerDay: 4,
    meanHintsPerStage: 1.5,
    abandonRate: 0.05,
    playProb: 0.80,
    newStageShare: 0.70,
    bonusMeanNew: 0.90,
    bonusMeanReplay: 0.35,
    bonusMeanFarm: 0.80,
    loginClaimProb: 1.0, // «يطالب بالمكافأة اليومية فقط» — لكنه يطالب بها
    missionEasyProb: 0,
    missionMediumProb: 0,
    missionHardProb: 0,
    weeklyBadgeProb: 0,
    watchesAllAds: false,
    adDoublesPerDay: 0,
    orderedHintShare: 0.25,
    spinsWheel: false,
    hintReserve: 0,
    cosmeticThreshold: 900,
    cosmeticProb: 0.45,
    cosmeticMin: 300,
    cosmeticMax: 700,
    cosmeticMaxPerDay: 1,
    bypassReserve: 300,
  ),
  ArchetypeSpec(
    id: 'regular',
    nameEn: 'Regular',
    share: 0.30,
    sessionsPerDay: 2,
    stagesPerDay: 9,
    meanHintsPerStage: 1.0,
    abandonRate: 0.04,
    playProb: 0.72,
    newStageShare: 0.34,
    bonusMeanNew: 1.05,
    bonusMeanReplay: 0.35,
    bonusMeanFarm: 0.80,
    loginClaimProb: 0.85,
    missionEasyProb: 0.75,
    missionMediumProb: 0.60,
    missionHardProb: 0.20,
    weeklyBadgeProb: 0.25,
    watchesAllAds: false,
    adDoublesPerDay: 1,
    orderedHintShare: 0.30,
    spinsWheel: false,
    hintReserve: 0,
    cosmeticThreshold: 780,
    cosmeticProb: 0.90,
    cosmeticMin: 300,
    cosmeticMax: 400,
    cosmeticMaxPerDay: 1,
    bypassReserve: 400,
  ),
  ArchetypeSpec(
    id: 'grinder',
    nameEn: 'Grinder',
    share: 0.13,
    sessionsPerDay: 4,
    stagesPerDay: 22,
    meanHintsPerStage: 0.4,
    abandonRate: 0.02,
    playProb: 0.95,
    newStageShare: 1.0, // الطاحن يتقدّم — لا يعيد إلا مضطرا (حصاد بوابة)
    bonusMeanNew: 1.20,
    bonusMeanReplay: 0.35,
    bonusMeanFarm: 1.00,
    loginClaimProb: 1.0,
    missionEasyProb: 1.0,
    missionMediumProb: 1.0,
    missionHardProb: 0.95,
    weeklyBadgeProb: 0.90,
    watchesAllAds: true,
    adDoublesPerDay: 0,
    orderedHintShare: 0.20,
    spinsWheel: true,
    hintReserve: 0,
    cosmeticThreshold: 1900,
    cosmeticProb: 0.90,
    cosmeticMin: 800,
    cosmeticMax: 1500,
    cosmeticMaxPerDay: 2,
    bypassReserve: 600,
  ),
  ArchetypeSpec(
    id: 'struggler',
    nameEn: 'Struggler',
    share: 0.05,
    sessionsPerDay: 1,
    stagesPerDay: 2,
    meanHintsPerStage: 3.5,
    abandonRate: 0.35,
    playProb: 0.60,
    newStageShare: 1.0,
    bonusMeanNew: 0.60,
    bonusMeanReplay: 0.35,
    bonusMeanFarm: 0.80,
    loginClaimProb: 0.90,
    missionEasyProb: 0,
    missionMediumProb: 0,
    missionHardProb: 0,
    weeklyBadgeProb: 0,
    watchesAllAds: false,
    adDoublesPerDay: 0,
    orderedHintShare: 0.55,
    spinsWheel: false,
    hintReserve: 25,
    cosmeticThreshold: 100000, // لا يشتري زينة أبدا — كل عملة للتلميحات
    cosmeticProb: 0,
    cosmeticMin: 300,
    cosmeticMax: 300,
    cosmeticMaxPerDay: 0,
    bypassReserve: 300,
  ),
  // النمط الخامس: من يموّل لعبه بالإعلانات لا بالمراحل.
  //
  // يلعب كالمنتظم تقريبا لكنه ينفق ميزانيته اليومية كاملة (4 مشاهدات)
  // على الإعلانات الجائزية: مضاعفة جوائز المراحل أولا لأنها اللحظة
  // التي يُعرض فيها الزرّ، ثم سطح «اشحن عملات» بالسلّم المتصاعد. هذا
  // هو النمط الذي يكشف إن كانت الإعلانات تُفقد العملةَ قيمتها: إن
  // تراكم عنده أضعافُ ما يتراكم عند المنتظم فالإعلان يشتري اللعبة.
  ArchetypeSpec(
    id: 'adWatcher',
    nameEn: 'Ad Watcher',
    share: 0.12,
    sessionsPerDay: 2,
    stagesPerDay: 8,
    meanHintsPerStage: 1.4,
    abandonRate: 0.05,
    playProb: 0.75,
    newStageShare: 0.45,
    bonusMeanNew: 1.00,
    bonusMeanReplay: 0.35,
    bonusMeanFarm: 0.80,
    loginClaimProb: 0.95,
    missionEasyProb: 0.60,
    missionMediumProb: 0.35,
    missionHardProb: 0.10,
    weeklyBadgeProb: 0.15,
    watchesAllAds: true,
    adDoublesPerDay: 3,
    orderedHintShare: 0.35,
    spinsWheel: true,
    hintReserve: 0,
    cosmeticThreshold: 800,
    cosmeticProb: 0.85,
    cosmeticMin: 300,
    cosmeticMax: 500,
    cosmeticMaxPerDay: 1,
    bypassReserve: 400,
  ),
];

/// عيّنة بواسون بخوارزمية كنوث القياسية — نفس الدالة المستخدمة في
/// test/economy/economy_simulation_test.dart
int poisson(Random rng, double mean) {
  if (mean <= 0) return 0;
  final l = exp(-mean);
  var k = 0;
  var p = 1.0;
  do {
    k++;
    p *= rng.nextDouble();
  } while (p > l);
  return k - 1;
}
