// تحويل صرف من بيانات v1 (نظام "points/maxUnlocked" الخطي القديم) إلى
// PlayerState/StageProgress الجديدة. بلا أي قراءة/كتابة SharedPreferences
// هنا — تلك مسؤولية progression_repository.dart؛ هذا الملف يأخذ الأرقام
// القديمة كمدخلات صريحة فيبقى قابلا للاختبار بمعزل تام.
//
// ملاحظة تناقض مهمة بين نصّ المهمة واختبار القبول: النصّ يطلب "منح
// صندوق ترحيب لمرة واحدة بـ200 عملة"، لكن اختبار القبول يشترط
// coins == 4210 بالضبط (=points القديمة 1:1، بلا أي إضافة). الاثنان لا
// يجتمعان إن أُضيف الصندوق مباشرة إلى wallet.coins. الحل هنا: الصندوق
// يُعاد كقيمة منفصلة [MigrationResult.pendingWelcomeChestCoins] لم
// تُدمَج بعد في الرصيد — تماما كنمط claimPendingReferralRewards
// الموجود فعلا في هذا المشروع (providers.dart) لمكافآت الدعوة المعلّقة.
// مهمة لاحقة تعرض هذا الصندوق وتطبّقه على الرصيد عند فتح التطبيق. إن
// كان القصد الفعلي ضمّه فورا، فرقم الاختبار المطلوب يجب أن يصير 4410
// لا العكس.

import '../../config/balance_config.dart';
import 'player_level_curve.dart';
import 'player_state.dart';
import 'progression_rules.dart';
import 'stage_progress.dart';
import 'world_defs.dart';

class MigrationResult {
  final PlayerState state;
  final Map<int, StageProgress> stageProgress;

  /// صندوق ترحيب معلّق، لم يُدمَج بعد في wallet.coins — راجع الشرح أعلاه
  final int pendingWelcomeChestCoins;

  const MigrationResult({
    required this.state,
    required this.stageProgress,
    required this.pendingWelcomeChestCoins,
  });
}

class ProgressionMigration {
  const ProgressionMigration._();

  /// [legacyCompletedCount] = عدد المراحل المكتملة تباعا من المرحلة 1
  /// (النظام القديم خطي: maxUnlocked يعني "التالي غير الملعوب"، فعدد
  /// المكتمل = maxUnlocked - 1). يُقصّ إلى مدى مراحل اللعبة الحالي حتى
  /// لو تغيّر إجمالي المراحل لاحقا.
  ///
  /// [legacyHintCharges] هي `ProgressStore.bankedHintCharges` القديمة —
  /// صارت المحفظة دفترها الوحيد بعد ربط EconomyService، فتُنقل هنا مع
  /// العملات بدل أن تُترك في مفتاح لم يعد أحد يقرؤه.
  static MigrationResult migrateFromV1({
    required int legacyPoints,
    required int legacyCompletedCount,
    required int legacyBonusJar,
    required ProgressionStructure structure,
    int legacyHintCharges = 0,
  }) {
    final completedCount =
        legacyCompletedCount.clamp(0, BalanceConfig.totalStages);

    final stageProgress = <int, StageProgress>{};
    for (var stageId = 1; stageId <= completedCount; stageId++) {
      // لا سجل تلميحات ولا سجل كلمات إضافية لكل مرحلة في النظام القديم،
      // فيُنقل الإتمام وحده — وهو كل ما يحرّك التقدّم أصلا
      stageProgress[stageId] = StageProgress(
        stageId: stageId,
        completed: true,
        bestTimeMs: null,
        hintsUsedBest: null,
        bonusWordsFound: const {},
        attempts: 1,
        lastPlayedAt: null,
      );
    }

    final xp = completedCount * BalanceConfig.migrationXpPerCompletedStage;
    final level = PlayerLevelCurve.currentLevel(xp);

    // فتح كل عالم/فصل يحوي مرحلة مكتملة، بصرف النظر عن ترتيب الإتمام —
    // لا نحبس لاعبا عائدا خارج محتوى وصله فعلا
    final unlockedWorldIds = <int>{1};
    final unlockedChapterIds = <int>{structure.worldById(1).chapterIds.first};
    for (var stageId = 1; stageId <= completedCount; stageId++) {
      final stage = structure.stageById(stageId);
      unlockedWorldIds.add(stage.worldId);
      unlockedChapterIds.add(stage.chapterId);
    }

    final currentStageId =
        (completedCount + 1).clamp(1, BalanceConfig.totalStages);

    // الجرّة القديمة رقم واحد عام؛ الجديدة لكل عالم. لا معنى لوضعها في
    // عالم أُنجز وتجاوزه اللاعب فعلا (بوابته مفتوحة أصلا بقاعدة الهجرة
    // أعلاه)، فتوضع في عالم موضعه الحالي — أو عالم 1 إن لم يكمل شيئا.
    final currentWorldId = completedCount == 0
        ? 1
        : structure.stageById(completedCount).worldId;
    final jarProgress = <int, int>{
      if (legacyBonusJar > 0) currentWorldId: legacyBonusJar,
    };

    var state = PlayerState(
      wallet: PlayerWallet(
        coins: legacyPoints,
        xp: xp,
        hintCharges: legacyHintCharges,
      ),
      level: level,
      currentStageId: currentStageId,
      unlockedWorldIds: unlockedWorldIds,
      unlockedChapterIds: unlockedChapterIds,
      jarProgress: jarProgress,
      schemaVersion: kPlayerStateSchemaVersion,
    );

    // تمريرة إضافية عبر recomputeUnlocks: قد تفتح فصلا/عالما تاليا
    // استحقّه الإتمام المنقول ولم تصله حلقة "يحوي مرحلة مكتملة" وحدها —
    // لا تُزيل شيئا أبدا، فقط تزيد
    final recomputed = ProgressionRules.recomputeUnlocks(
      structure: structure,
      progress: stageProgress,
      previouslyUnlockedWorldIds: unlockedWorldIds,
      previouslyUnlockedChapterIds: unlockedChapterIds,
    );
    state = state.copyWith(
      unlockedWorldIds: recomputed.worlds,
      unlockedChapterIds: recomputed.chapters,
      // كل عالم فتحته الهجرة قسرا وصله اللاعب فعلا في الماضي — مراسم
      // "عالم جديد!" لا معنى لها له. بلا هذا، عائد بتقدّم إلى عالم5
      // مثلا يرى 4 مراسم فتح متتالية زائفة عند أول تشغيل بعد التحديث.
      ceremonyShownForWorldIds: recomputed.worlds,
    );

    return MigrationResult(
      state: state,
      stageProgress: stageProgress,
      pendingWelcomeChestCoins: BalanceConfig.migrationWelcomeChestCoins,
    );
  }
}
