// مدخل ونتيجة حساب مكافأة إتمام مرحلة. منطق صرف بالكامل.
//
// قرار عزل متعمّد: هذا الملف لا يستورد شيئا من lib/data/progression/*.
// المكوّنان يحسبان أرقاما مختلفة تماما من نفس حدث اللعب (XP مقابل
// عملات)، ولكل منهما مصدر حقيقة خاص لا يجب أن يتّكل أحدهما على تفاصيل
// تمثيل الآخر الداخلية. طبقة تكامل لاحقة (لم تُبنَ بعد) هي من يستدعي
// كليهما لنفس الحدث الفعلي وتضمن اتساق المدخلات المشتركة بينهما —
// تحديدا: hintsUsedThisStage يجب أن يُحتسب بنفس الطريقة لكلا الطرفين
// (حتى التلميح المموَّل بشحنة مجانية يُحتسب هنا وهناك)، وisReplay هنا
// يجب أن يطابق "!oldStageProgress.completed" هناك تماما. هذه ملاحظة
// تكامل مهمة، لا تفصيل تنفيذ داخلي.

class StageResult {
  final int worldId;
  final bool isBossStage;

  /// true إن كانت هذه المرحلة مكتملة من قبل بالفعل (أي محاولة سابقة
  /// ناجحة) — إعادة اللعب هذه تدفع صفر عملات دوما، بصرف النظر عن بقية
  /// الحقول أدناه
  final bool isReplay;

  final int coreWordsFound;

  /// الكلمات الإضافية *الجديدة* في هذه المحاولة تحديدا (لا المتراكمة)
  final int newBonusWordsFoundThisRun;

  /// أُنهيت هذه المحاولة بلا أي تلميح — نفس تعريف StatKey.perfectLevels
  final bool isPerfect;

  final bool chapterJustCompleted;
  final bool worldJustCompleted;

  /// صندوق الفصل مُحسوَب سلفا (ChapterChest.roll) قبل الوصول هنا — 0 إن
  /// لم يكتمل فصل في هذه المحاولة. العشوائية تعيش خارج هذا الحساب
  /// الحتمي عمدا، تماما كما يُمرَّر DateTime كمعامل في مكان آخر بدل
  /// استدعاء DateTime.now() داخليا.
  final int chapterChestAlreadyRolled;

  const StageResult({
    required this.worldId,
    required this.isBossStage,
    required this.isReplay,
    required this.coreWordsFound,
    required this.newBonusWordsFoundThisRun,
    required this.isPerfect,
    required this.chapterJustCompleted,
    required this.worldJustCompleted,
    this.chapterChestAlreadyRolled = 0,
  });
}

class StageRewardBreakdown {
  final int stageClearCoins;
  final int coreWordCoins;
  final int bonusWordCoins;
  final int perfectBonusCoins;
  final int bossBonusCoins;
  final int chapterCompleteCoins;
  final int chapterChestCoins;
  final int worldCompleteCoins;

  const StageRewardBreakdown({
    this.stageClearCoins = 0,
    this.coreWordCoins = 0,
    this.bonusWordCoins = 0,
    this.perfectBonusCoins = 0,
    this.bossBonusCoins = 0,
    this.chapterCompleteCoins = 0,
    this.chapterChestCoins = 0,
    this.worldCompleteCoins = 0,
  });

  static const zero = StageRewardBreakdown();

  int get total =>
      stageClearCoins +
      coreWordCoins +
      bonusWordCoins +
      perfectBonusCoins +
      bossBonusCoins +
      chapterCompleteCoins +
      chapterChestCoins +
      worldCompleteCoins;
}
