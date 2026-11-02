/// أنواع أهداف المهمات — كل نوع يقابل حدثا واحدا يُبلَّغ صراحة من نقطة
/// وقوعه (game_screen.dart)، لا مشتقّا من فارق عدّاد StatKey تراكمي.
/// هذا يتفادى الحاجة لمعرفة "أي مصدر بيانات يغذّي أي هدف" في منطق صرف
/// عام، ويبقي التبليغ في نفس نقاط الحدث الموجودة فعلا لكل من
/// achievementsProvider وstreakProvider.
enum MissionObjectiveType {
  findWords,
  completeStages,
  findBonusWords,
  completeStageNoHints,

  /// أسبوعية فقط — يوم تقويمي محلي واحد فيه أي نشاط (مطابق لحدث
  /// streakProvider.recordActivityToday) يزيد التقدّم بمقدار 1، بحد أقصى
  /// مرة واحدة لكل يوم تقويمي (التكرار في نفس اليوم لا يُحتسب مرتين)
  playDifferentDays,
}

class MissionDef {
  final String id;
  final MissionObjectiveType type;
  final int target;

  /// 0 للمهمات الأسبوعية عمدا — مكافأتها واحدة مجمَّعة عند إكمال الثلاث
  /// معا (300 عملة + شارة)، لا مكافأة لكل مهمة على حدة كما نصّت المهمة
  /// حرفيا (خلافا لليومية التي تمنح مكافأة كل مستوى صعوبة على حدة)
  final int coinsReward;

  /// null يعني بلا شرط مستوى. لا مهمة تستعمله اليوم، ويبقى لأنّ سحب
  /// المهمات يحترمه (راجع MissionEngine.pickFrom) فأي مهمة مستقبلية
  /// مشروطة بمستوى تعمل بلا تغيير في المحرّك.
  final int? minPlayerLevel;

  const MissionDef({
    required this.id,
    required this.type,
    required this.target,
    required this.coinsReward,
    this.minPlayerLevel,
  });
}

/// نسخة حيّة من مهمة معطاة لليوم/الأسبوع الحالي، مع تقدّمها الفعلي
class MissionInstance {
  final MissionDef def;
  final int progress;

  const MissionInstance({required this.def, required this.progress});

  factory MissionInstance.fresh(MissionDef def) =>
      MissionInstance(def: def, progress: 0);

  bool get isComplete => progress >= def.target;

  MissionInstance withProgress(int newProgress) => MissionInstance(
        def: def,
        progress: newProgress.clamp(0, def.target),
      );

  /// يزيد التقدّم فقط إن كان الحدث [type] يطابق نوع هذه المهمة، وإلا يعيد
  /// نفس النسخة بلا تغيير — آمن الاستدعاء على كل المهمات النشطة معا لكل
  /// حدث دون فحص النوع خارجيا في كل موضع استدعاء
  MissionInstance reportEvent(MissionObjectiveType eventType, int amount) =>
      eventType == def.type ? withProgress(progress + amount) : this;

  Map<String, dynamic> toJson() => {'id': def.id, 'progress': progress};

  factory MissionInstance.fromJson(
          Map<String, dynamic> json, MissionDef def) =>
      MissionInstance(def: def, progress: json['progress'] as int);
}

/// مكافأة صندوق المهمات اليومي — تُسحَب عشوائيا عند إكمال المهمات
/// الثلاث معا (راجع MissionEngine.rollDailyChest)
class DailyChestReward {
  final int coins;
  final bool hintCharge;
  const DailyChestReward({required this.coins, required this.hintCharge});
}

// ─────────────────────── مجمعات المهمات المعطاة حرفيا ───────────────────────

const List<MissionDef> dailyEasyPool = [
  MissionDef(
      id: 'find_5_words',
      type: MissionObjectiveType.findWords,
      target: 5,
      coinsReward: 15),
  MissionDef(
      id: 'complete_1_stage',
      type: MissionObjectiveType.completeStages,
      target: 1,
      coinsReward: 15),
  MissionDef(
      id: 'find_1_bonus_word',
      type: MissionObjectiveType.findBonusWords,
      target: 1,
      coinsReward: 15),
];

const List<MissionDef> dailyMediumPool = [
  MissionDef(
      id: 'find_3_bonus_words',
      type: MissionObjectiveType.findBonusWords,
      target: 3,
      coinsReward: 25),
  MissionDef(
      id: 'complete_2_stages',
      type: MissionObjectiveType.completeStages,
      target: 2,
      coinsReward: 25),
  // حلّت محلّ `play_daily_challenge` بعد استبدال التحدي اليومي بمسار
  // الجوائز: مهمة عن ميزة محذوفة لا تكتمل أبدا، وثلث مهمات اليوم
  // المتوسطة كان يقع عليها. لا مهمة عن المطالبة بجائزة عمدا — ضغطة زر
  // واحدة ليست مهمة، والمسار يكافئ نفسه أصلا.
  MissionDef(
      id: 'find_10_words',
      type: MissionObjectiveType.findWords,
      target: 10,
      coinsReward: 25),
];

const List<MissionDef> dailyHardPool = [
  MissionDef(
      id: 'stage_no_hints',
      type: MissionObjectiveType.completeStageNoHints,
      target: 1,
      coinsReward: 40),
  MissionDef(
      id: 'find_8_bonus_words',
      type: MissionObjectiveType.findBonusWords,
      target: 8,
      coinsReward: 40),
  MissionDef(
      id: 'find_15_words_hard',
      type: MissionObjectiveType.findWords,
      target: 15,
      coinsReward: 40),
];

const List<MissionDef> weeklyPool = [
  MissionDef(
      id: 'find_100_words',
      type: MissionObjectiveType.findWords,
      target: 100,
      coinsReward: 0),
  MissionDef(
      id: 'find_25_bonus_words',
      type: MissionObjectiveType.findBonusWords,
      target: 25,
      coinsReward: 0),
  MissionDef(
      id: 'play_5_different_days',
      type: MissionObjectiveType.playDifferentDays,
      target: 5,
      coinsReward: 0),
  MissionDef(
      id: 'complete_20_stages',
      type: MissionObjectiveType.completeStages,
      target: 20,
      coinsReward: 0),
];

final Map<String, MissionDef> allMissionDefsById = {
  for (final m in [
    ...dailyEasyPool,
    ...dailyMediumPool,
    ...dailyHardPool,
    ...weeklyPool,
  ])
    m.id: m,
};
