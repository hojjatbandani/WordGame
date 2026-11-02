// بوابات الفتح (مرحلة/فصل/عالم). منطق صرف بالكامل — كل دالة هنا تأخذ
// حالتها كمدخلات صريحة ولا تقرأ أي تخزين، فتُختبر مباشرة بلا
// SharedPreferences ولا Supabase ولا شجرة ودجات.
//
// قاعدة واحدة تحكم كل البوابات: الإتمام. المرحلة تفتح المرحلة التالية،
// وإتمام كل مراحل الفصل يفتح الفصل التالي، وإتمام آخر فصل في العالم
// يفتح العالم التالي. لا نجوم ولا عتبة جرّة في أي منها — الجرّة مكافأة
// جانبية فقط (راجع jar_rewards.dart).

import '../../config/balance_config.dart';
import 'stage_progress.dart';
import 'world_defs.dart';

class ProgressionRules {
  const ProgressionRules._();

  /// عدد مراحل [chapter] المكتملة بحسب [progress] الحالي
  static int completedStagesInChapter(
    ChapterDef chapter,
    Map<int, StageProgress> progress,
  ) {
    var total = 0;
    for (final stageId in chapter.stageIds) {
      if (progress[stageId]?.completed ?? false) total++;
    }
    return total;
  }

  /// هل كل مراحل [chapter] مكتملة؟
  static bool isChapterComplete(
    ChapterDef chapter,
    Map<int, StageProgress> progress,
  ) =>
      chapter.stageIds.every((id) => progress[id]?.completed ?? false);

  /// هل كل فصول [world] مكتملة؟
  static bool isWorldComplete(
    WorldDef world,
    ProgressionStructure structure,
    Map<int, StageProgress> progress,
  ) =>
      world.chapterIds
          .every((id) => isChapterComplete(structure.chapterById(id), progress));

  /// فصل الفهرس 1 في أي عالم يخضع لبوابة العالم — يُفتح دوما بمجرد فتح
  /// العالم نفسه. وما بعده يُفتح بإتمام الفصل السابق كاملا.
  static bool canEnterChapter(
    ChapterDef chapter,
    ChapterDef? previousChapterInSameWorld,
    Map<int, StageProgress> progress,
  ) {
    if (chapter.index == 1) return true;
    if (previousChapterInSameWorld == null) return true;
    return isChapterComplete(previousChapterInSameWorld, progress);
  }

  /// إتمام الفصل الأخير من العالم السابق وحده يفتح العالم التالي
  static bool canEnterWorld({
    required WorldDef world,
    required ProgressionStructure structure,
    required Map<int, StageProgress> progress,
  }) {
    if (world.id == 1) return true;
    final previousWorld = structure.worldById(world.id - 1);
    final lastChapterId = previousWorld.chapterIds.last;
    return isChapterComplete(structure.chapterById(lastChapterId), progress);
  }

  /// خطّي داخل الفصل: أول N مرحلة مفتوحة عند أول تشغيل (BalanceConfig)،
  /// وبعدها إكمال المرحلة N يفتح N+1 داخل نفس الفصل. أول مرحلة في أي
  /// فصل تتبع بوابة الفصل بدل "المرحلة السابقة مكتملة" (فلا تعبر حدود
  /// فصل/عالم بالخطأ).
  static bool isStageUnlocked({
    required StageDef stage,
    required ProgressionStructure structure,
    required Map<int, StageProgress> progress,
  }) {
    if (stage.id <= BalanceConfig.initiallyUnlockedStageCount) return true;

    final chapter = structure.chapterById(stage.chapterId);
    final world = structure.worldById(stage.worldId);

    if (stage.indexInChapter == 1) {
      if (!canEnterWorld(
          world: world, structure: structure, progress: progress)) {
        return false;
      }
      final worldChapterPos = world.chapterIds.indexOf(chapter.id);
      final previousChapter = worldChapterPos <= 0
          ? null
          : structure.chapterById(world.chapterIds[worldChapterPos - 1]);
      return canEnterChapter(chapter, previousChapter, progress);
    }

    final previousStageId = stage.id - 1;
    return progress[previousStageId]?.completed ?? false;
  }

  /// أول مرحلة غير مكتملة يجب أن يلعبها اللاعب بعد إكمال [completedStageId]،
  /// محافظا على القيمة القديمة إن لم يفتح شيء جديد بعد
  static int nextPlayableStageId({
    required int completedStageId,
    required int previousCurrentStageId,
    required ProgressionStructure structure,
    required Map<int, StageProgress> progress,
  }) {
    if (completedStageId >= BalanceConfig.totalStages) {
      return completedStageId; // أكمل آخر مرحلة في اللعبة — لا "تالي"
    }
    final candidate = completedStageId + 1;
    final candidateStage = structure.stageById(candidate);
    final unlocked = isStageUnlocked(
      stage: candidateStage,
      structure: structure,
      progress: progress,
    );
    if (!unlocked) return previousCurrentStageId;
    return candidate > previousCurrentStageId
        ? candidate
        : previousCurrentStageId;
  }

  /// يعيد بناء مجموعتي الفتح من الصفر بحسب حالة التقدّم الحالية، ثم
  /// يتّحد مع القديم (لا نُزيل فتحا سابقا أبدا — خاصة حالة الهجرة التي
  /// تفتح محتوى تجاوز البوابات عمدا)
  static ({Set<int> worlds, Set<int> chapters}) recomputeUnlocks({
    required ProgressionStructure structure,
    required Map<int, StageProgress> progress,
    required Set<int> previouslyUnlockedWorldIds,
    required Set<int> previouslyUnlockedChapterIds,
  }) {
    final worlds = {...previouslyUnlockedWorldIds};
    final chapters = {...previouslyUnlockedChapterIds};

    for (final world in structure.worlds) {
      if (canEnterWorld(
          world: world, structure: structure, progress: progress)) {
        worlds.add(world.id);
      }
      ChapterDef? previous;
      for (final chapterId in world.chapterIds) {
        final chapter = structure.chapterById(chapterId);
        if (worlds.contains(world.id) &&
            canEnterChapter(chapter, previous, progress)) {
          chapters.add(chapter.id);
        }
        previous = chapter;
      }
    }
    return (worlds: worlds, chapters: chapters);
  }
}
