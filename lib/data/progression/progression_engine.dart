// نقطة التحوّل الوحيدة لتسجيل إتمام مرحلة. منطق صرف، حتمي بالكامل —
// [DateTime now] يُمرَّر كمدخل بدل استدعاء DateTime.now() داخليا كي تبقى
// الدالة قابلة للاختبار بمدخلات ثابتة معروفة النتيجة.
//
// قرار تصميم: مكافآت XP الثابتة (مرحلة/زعيم/فصل/عالم) تُمنح فقط أول
// مرة تُكمَل فيها المرحلة (`!old.completed`) — إعادة اللعب لا تُكرّر هذه
// المكافآت الثابتة، وإلا صارت إعادة لعب مرحلة واحدة مصدر XP لا نهائيا. مكافأة الكلمات الإضافية استثناء: تُحتسب فقط عن
// كلمات *جديدة فعلا* هذه المحاولة (الفرق بين المجموعتين قبل وبعد)، فلا
// إعادة إيجاد الكلمة نفسها تمنح XP مكرّرا، لكن كلمة مختلفة حقا في محاولة
// لاحقة تُحتسب كإنجاز جديد فعلي.
//
// هذه المهمة لا تحدّد أي مكافأة عملات (coins) لإكمال مرحلة — فقط XP. اقتصاد العملات مؤجَّل لمهمة لاحقة (راجع ملاحظة "Prompt 2" في
// وصف المهمة) تفاديا لاختراع رقم لم يُعطَ.

import '../../config/balance_config.dart';
import 'jar_rewards.dart';
import 'player_level_curve.dart';
import 'player_state.dart';
import 'progression_rules.dart';
import 'stage_progress.dart';
import 'world_defs.dart';

class StageCompletionResult {
  final PlayerState state;
  final StageProgress stageProgress;

  /// XP مُنحت في هذه المحاولة تحديدا
  final int xpGainedThisRun;

  /// أُكمل فصل هذه المرحلة للتوّ بهذه المحاولة تحديدا (كان ناقصا قبلها)
  final bool chapterCompletedThisRun;

  /// أُكمل عالم هذه المرحلة للتوّ بهذه المحاولة تحديدا
  final bool worldCompletedThisRun;

  /// كانت المرحلة مكتملة *قبل* هذه المحاولة — أي هذه إعادة لعب.
  /// تقرؤها طبقة الاقتصاد كـ[StageResult.isReplay]: إعادة اللعب تدفع
  /// صفر عملات، وهذا هو مصدر الحقيقة الوحيد لتلك الحقيقة.
  final bool wasAlreadyCompleted;

  /// كم كلمة إضافية *جديدة فعلا* أُضيفت بهذه المحاولة — نفس الرقم الذي
  /// تُحتسب به XP والجرّة، فتُحتسب به العملات أيضا بلا حساب ثانٍ مختلف
  final int newBonusWordsFoundThisRun;

  /// طبقات جرّة عالم هذه المرحلة التي بُلغت للتوّ هذه المحاولة تحديدا
  /// (عادة فارغة؛ عنصر واحد أو اثنان إن قفز التقدّم فوق العتبتين معا)
  final List<JarTierReward> jarRewardsGained;

  const StageCompletionResult({
    required this.state,
    required this.stageProgress,
    required this.xpGainedThisRun,
    this.chapterCompletedThisRun = false,
    this.worldCompletedThisRun = false,
    this.wasAlreadyCompleted = false,
    this.newBonusWordsFoundThisRun = 0,
    this.jarRewardsGained = const [],
  });
}

class ProgressionEngine {
  const ProgressionEngine._();

  static StageCompletionResult applyStageCompletion({
    required PlayerState state,
    required Map<int, StageProgress> allProgress,
    required ProgressionStructure structure,
    required int stageId,
    required Set<String> bonusWordsFoundThisRun,
    required int hintsUsedThisRun,
    required int timeMs,
    required DateTime now,
  }) {
    final stageDef = structure.stageById(stageId);
    final chapter = structure.chapterById(stageDef.chapterId);
    final world = structure.worldById(stageDef.worldId);
    final old = allProgress[stageId] ?? StageProgress.empty(stageId);
    final wasCompletedBefore = old.completed;

    final mergedBonusWords = {...old.bonusWordsFound, ...bonusWordsFoundThisRun};
    final newlyFoundBonusWordCount =
        mergedBonusWords.length - old.bonusWordsFound.length;

    final newHintsUsedBest = old.hintsUsedBest == null
        ? hintsUsedThisRun
        : (old.hintsUsedBest! < hintsUsedThisRun
            ? old.hintsUsedBest!
            : hintsUsedThisRun);
    final newBestTimeMs = old.bestTimeMs == null
        ? timeMs
        : (old.bestTimeMs! < timeMs ? old.bestTimeMs! : timeMs);

    final newStageProgress = old.copyWith(
      completed: true,
      bestTimeMs: newBestTimeMs,
      hintsUsedBest: newHintsUsedBest,
      bonusWordsFound: mergedBonusWords,
      attempts: old.attempts + 1,
      lastPlayedAt: now,
    );

    // خريطة تقدّم مؤقتة تعكس هذه المحاولة، تُستخدم لحساب اكتمال
    // الفصل/العالم واستحقاقات الفتح بعدها مباشرة
    final progressAfter = Map<int, StageProgress>.from(allProgress)
      ..[stageId] = newStageProgress;

    var xpGain = 0;
    if (!wasCompletedBefore) {
      xpGain += BalanceConfig.xpPerStageClear;
      if (stageDef.isBoss) xpGain += BalanceConfig.xpBossStageExtra;
    }
    xpGain += newlyFoundBonusWordCount * BalanceConfig.xpPerBonusWord;

    final chapterWasComplete = ProgressionRules.isChapterComplete(
        chapter,
        Map<int, StageProgress>.from(allProgress)..[stageId] = old);
    final chapterIsCompleteNow =
        ProgressionRules.isChapterComplete(chapter, progressAfter);
    if (!chapterWasComplete && chapterIsCompleteNow) {
      xpGain += BalanceConfig.xpPerChapterComplete;
    }

    final worldWasComplete = ProgressionRules.isWorldComplete(
        world,
        structure,
        Map<int, StageProgress>.from(allProgress)..[stageId] = old);
    final worldIsCompleteNow =
        ProgressionRules.isWorldComplete(world, structure, progressAfter);
    if (!worldWasComplete && worldIsCompleteNow) {
      xpGain += BalanceConfig.xpPerWorldComplete;
    }

    final newJarProgress = Map<int, int>.from(state.jarProgress);
    newJarProgress[world.id] =
        (newJarProgress[world.id] ?? 0) + newlyFoundBonusWordCount;

    final claimedTierBefore = state.claimedJarTierByWorld[world.id] ?? 0;
    final jarRewardsGained = JarRewards.newlyReachedTiers(
      worldId: world.id,
      jarProgress: newJarProgress[world.id]!,
      tier1Threshold: BalanceConfig.jarThresholdForWorld(world.id),
      claimedTier: claimedTierBefore,
    );
    final newClaimedJarTierByWorld =
        Map<int, int>.from(state.claimedJarTierByWorld);
    if (jarRewardsGained.isNotEmpty) {
      newClaimedJarTierByWorld[world.id] = jarRewardsGained.last.tier;
    }
    // مكافأة عملات الجرّة تُمنَح في طبقة المزوّدات (providers.dart) إلى
    // pointsProvider الحيّ، لا هنا — هذا الملف صرف ولا يعرف أي محفظة
    // فعلية يُفترض أن تستقبل العملات (راجع نفس القرار في مهمة الأنظمة
    // اليومية لكل مكافأة عملات مشابهة)

    final newXp = state.wallet.xp + xpGain;
    final newWallet = state.wallet.copyWith(xp: newXp);
    final newLevel = PlayerLevelCurve.currentLevel(newXp);

    final recomputed = ProgressionRules.recomputeUnlocks(
      structure: structure,
      progress: progressAfter,
      previouslyUnlockedWorldIds: state.unlockedWorldIds,
      previouslyUnlockedChapterIds: state.unlockedChapterIds,
    );

    final newCurrentStageId = ProgressionRules.nextPlayableStageId(
      completedStageId: stageId,
      previousCurrentStageId: state.currentStageId,
      structure: structure,
      progress: progressAfter,
    );

    final newState = state.copyWith(
      wallet: newWallet,
      level: newLevel,
      currentStageId: newCurrentStageId,
      unlockedWorldIds: recomputed.worlds,
      unlockedChapterIds: recomputed.chapters,
      jarProgress: newJarProgress,
      claimedJarTierByWorld: newClaimedJarTierByWorld,
    );

    return StageCompletionResult(
      state: newState,
      stageProgress: newStageProgress,
      xpGainedThisRun: xpGain,
      chapterCompletedThisRun: !chapterWasComplete && chapterIsCompleteNow,
      worldCompletedThisRun: !worldWasComplete && worldIsCompleteNow,
      wasAlreadyCompleted: wasCompletedBefore,
      newBonusWordsFoundThisRun: newlyFoundBonusWordCount,
      jarRewardsGained: jarRewardsGained,
    );
  }
}
