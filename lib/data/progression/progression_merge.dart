// دمج حالة محلية مع حالة سحابية محتملة القِدَم. منطق صرف تماما — هذا هو
// المصدر الوحيد المُختبَر لقاعدة "لا يتراجع أي عدّاد أبدا"؛ دالة
// sync_player_progress في Supabase (schema_progression.sql) حارس أمان
// إضافي على الخادم للأرقام الثلاثة القابلة للقياس بسهولة فقط
// (coins/xp)، لا مصدر الحقيقة لدمج كل حقل لكل مرحلة — ذاك
// لا يمكن التحقق من صحته هنا بلا قاعدة بيانات فعلية لتشغيله عليها،
// فبقي الدمج التفصيلي في Dart القابل للاختبار الآن.
//
// قرار مأخوذ حرفيا من المهمة رغم أثره الجانبي المعروف: أخذ "الأكبر" في
// [coins] (عملة قابلة للإنفاق) يعني أن جهازا أنفق عملات بعد آخر مزامنة
// قد يستعيدها الدمج التالي إن كان الجهاز الآخر لم ينفقها بعد. هذا مقصود
// صراحة في نصّ المهمة ("take the MAXIMUM of coins")، لا خطأ سهوا — لكنه
// يعني أن إنفاق العملات عبر أكثر من جهاز متزامن قد يُستعاد أحيانا. طُبّق
// نفس المبدأ على hintCharges (غير مذكورة صراحة) للاتساق: هي عملة شبه
// قابلة للإنفاق أيضا، فمعاملتها كالعملات أكثر أمانا من معاملتها كXP.
//
// attempts يُدمَج بـmax لا بالجمع: الجمع قد يُضاعف نفس المحاولة إن
// تكرّرت المزامنة (كل مزامنة تُعيد نفس الرقمين فتُجمَعان من جديد)، بينما
// max يبقى صحيحا سواء تكرّرت المزامنة أو لا.

import 'player_state.dart';
import 'progression_rules.dart';
import 'stage_progress.dart';
import 'world_defs.dart';

class MergedProgress {
  final PlayerState state;
  final Map<int, StageProgress> stageProgress;

  const MergedProgress({required this.state, required this.stageProgress});
}

class ProgressionMerge {
  const ProgressionMerge._();

  static MergedProgress merge({
    required PlayerState local,
    required Map<int, StageProgress> localProgress,
    required PlayerState remote,
    required Map<int, StageProgress> remoteProgress,
    required ProgressionStructure structure,
  }) {
    final mergedProgress = <int, StageProgress>{};
    final allStageIds = {...localProgress.keys, ...remoteProgress.keys};
    for (final stageId in allStageIds) {
      mergedProgress[stageId] = _mergeStage(
        structure: structure,
        stageId: stageId,
        a: localProgress[stageId],
        b: remoteProgress[stageId],
      );
    }

    final mergedWallet = PlayerWallet(
      coins: _max(local.wallet.coins, remote.wallet.coins),
      xp: _max(local.wallet.xp, remote.wallet.xp),
      hintCharges: _max(local.wallet.hintCharges, remote.wallet.hintCharges),
    );

    final mergedJar = <int, int>{};
    for (final worldId in {...local.jarProgress.keys, ...remote.jarProgress.keys}) {
      mergedJar[worldId] =
          _max(local.jarProgress[worldId] ?? 0, remote.jarProgress[worldId] ?? 0);
    }

    final mergedUnlockedWorlds = {...local.unlockedWorldIds, ...remote.unlockedWorldIds};
    final mergedUnlockedChapters =
        {...local.unlockedChapterIds, ...remote.unlockedChapterIds};

    // اتحاد لا حد أقصى: "استُلم"/"عُرضت مراسمه" حقيقتان دائمتان — إن
    // حدث أي منهما على أي جهاز فلن يتراجعا أبدا بعد الدمج
    final mergedClaimedChests = {
      ...local.claimedChapterChestIds,
      ...remote.claimedChapterChestIds
    };
    final mergedCeremonyShown = {
      ...local.ceremonyShownForWorldIds,
      ...remote.ceremonyShownForWorldIds
    };

    // بحد أقصى (max) لا اتحاد: طبقة الجرّة رقم يتصاعد (0→1→2)، لا مجموعة
    // هويات — نفس مبدأ jarProgress/coins أعلاه، لا تراجع أبدا
    final mergedJarTiers = <int, int>{
      for (final worldId in {
        ...local.claimedJarTierByWorld.keys,
        ...remote.claimedJarTierByWorld.keys,
      })
        worldId: _max(local.claimedJarTierByWorld[worldId] ?? 0,
            remote.claimedJarTierByWorld[worldId] ?? 0),
    };

    // تمريرة إعادة حساب إضافية: الدمج بحد ذاته (مراحل مكتملة على جهاز
    // دون الآخر) قد يستحق فتح فصل/عالم لم يكن أي من الطرفين قد فتحه بعد
    // على حدة
    final recomputed = ProgressionRules.recomputeUnlocks(
      structure: structure,
      progress: mergedProgress,
      previouslyUnlockedWorldIds: mergedUnlockedWorlds,
      previouslyUnlockedChapterIds: mergedUnlockedChapters,
    );

    final mergedState = PlayerState(
      wallet: mergedWallet,
      level: local.level > remote.level ? local.level : remote.level,
      currentStageId: _max(local.currentStageId, remote.currentStageId),
      unlockedWorldIds: recomputed.worlds,
      unlockedChapterIds: recomputed.chapters,
      jarProgress: mergedJar,
      schemaVersion: _max(local.schemaVersion, remote.schemaVersion),
      claimedChapterChestIds: mergedClaimedChests,
      ceremonyShownForWorldIds: mergedCeremonyShown,
      claimedJarTierByWorld: mergedJarTiers,
    );

    return MergedProgress(state: mergedState, stageProgress: mergedProgress);
  }

  static StageProgress _mergeStage({
    required ProgressionStructure structure,
    required int stageId,
    required StageProgress? a,
    required StageProgress? b,
  }) {
    if (a == null) return b!;
    if (b == null) return a;

    final bonusWordsFound = {...a.bonusWordsFound, ...b.bonusWordsFound};
    final hintsUsedBest = _minNullable(a.hintsUsedBest, b.hintsUsedBest);
    final bestTimeMs = _minNullable(a.bestTimeMs, b.bestTimeMs);
    final completed = a.completed || b.completed;

    return StageProgress(
      stageId: stageId,
      completed: completed,
      bestTimeMs: bestTimeMs,
      hintsUsedBest: hintsUsedBest,
      bonusWordsFound: bonusWordsFound,
      attempts: _max(a.attempts, b.attempts),
      lastPlayedAt: _laterNullable(a.lastPlayedAt, b.lastPlayedAt),
    );
  }

  static int _max(int a, int b) => a > b ? a : b;

  static int? _minNullable(int? a, int? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a < b ? a : b;
  }

  static DateTime? _laterNullable(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}
