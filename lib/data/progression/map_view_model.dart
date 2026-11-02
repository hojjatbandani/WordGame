// منطق عرض الخريطة الصرف: يحوّل PlayerState + StageProgress +
// ProgressionStructure إلى بيانات عرض جاهزة لثلاثة مستويات التكبير
// (عوالم/فصول/مراحل)، وشريط أقرب مكافأة، وحالة صندوق الفصل. بلا أي
// استيراد Flutter، بلا أي نص عربي/إنجليزي مكتوب هنا — كل شيء أرقام
// ومعرّفات (nameKey/themeId/mechanicId..)؛ طبقة العرض (widgets) هي من
// تحوّلها لنص عبر lang.t() تماما كبقية الشاشات في هذا المشروع. هذا الملف
// لا يقرر شكل شيء ولا يترجم شيئا — فقط "ما هي الحقيقة" ليعرضها غيره.

import '../../config/balance_config.dart';
import 'player_state.dart';
import 'progression_rules.dart';
import 'stage_progress.dart';
import 'world_defs.dart';

enum StageNodeStatus { locked, upcoming, next, current, completed }

class StageNodeViewData {
  final int stageId;
  final StageNodeStatus status;
  final bool isBoss;

  /// المراحل الثلاث التالية لـcurrent (وcurrent نفسها ليست منها — هي
  /// تُلعب مباشرة) تعرض معاينة عند اللمس، تحديدا كي "يعرف اللاعب أن
  /// المحتوى موجود قبل أن يصله" كما نصّت المهمة حرفيا
  final bool previewAvailableOnTap;

  const StageNodeViewData({
    required this.stageId,
    required this.status,
    required this.isBoss,
    required this.previewAvailableOnTap,
  });
}

enum ChestState { locked, unlocked, claimed }

class ChapterCardViewData {
  final int chapterId;
  final int worldId;
  final int index;

  /// مراحل هذا الفصل المكتملة / مجموع مراحله — بديل عدّاد النجوم القديم
  final int stagesCompleted;
  final int stageCount;
  final bool isUnlocked;
  final ChestState chestState;

  const ChapterCardViewData({
    required this.chapterId,
    required this.worldId,
    required this.index,
    required this.stagesCompleted,
    required this.stageCount,
    required this.isUnlocked,
    required this.chestState,
  });
}

/// شرط فتح عالم مقفل — بيانات خام فقط، لا نص. الواجهة تركّبها في جملة
/// محلَّية مثل "أكمل العالم N". شرط واحد لا غير: إتمام الفصل الأخير من
/// العالم السابق.
class WorldUnlockConditionData {
  final int requiredWorldId;
  final bool requiredWorldLastChapterComplete;

  const WorldUnlockConditionData({
    required this.requiredWorldId,
    required this.requiredWorldLastChapterComplete,
  });

  bool get isMet => requiredWorldLastChapterComplete;
}

class WorldCardViewData {
  final int worldId;
  final String nameKey;
  final String themeId;
  final String guideCharacterId;
  final int colorSeed;
  final bool isUnlocked;
  final int completionRewardCoins;

  /// null فقط إن كان isUnlocked==true — عالم مفتوح لا شرط يُعرض له
  final WorldUnlockConditionData? unlockCondition;

  const WorldCardViewData({
    required this.worldId,
    required this.nameKey,
    required this.themeId,
    required this.guideCharacterId,
    required this.colorSeed,
    required this.isUnlocked,
    required this.completionRewardCoins,
    required this.unlockCondition,
  });
}

enum NearRewardKind { wordsToJar, stagesToChest, worldCompletionPercent }

class NearRewardBannerData {
  final NearRewardKind kind;

  /// للنوعين الأولين فقط
  final int remaining;

  /// لـworldCompletionPercent فقط، 0..100
  final double percent;

  const NearRewardBannerData._(this.kind, this.remaining, this.percent);

  factory NearRewardBannerData.remaining(NearRewardKind kind, int remaining) =>
      NearRewardBannerData._(kind, remaining, 0);

  factory NearRewardBannerData.percent(double percent) =>
      NearRewardBannerData._(NearRewardKind.worldCompletionPercent, 0, percent);
}

class MapViewModel {
  const MapViewModel._();

  // ─────────────────────── L1: اختيار العالم ───────────────────────

  static List<WorldCardViewData> buildWorldCards({
    required PlayerState state,
    required Map<int, StageProgress> progress,
    required ProgressionStructure structure,
  }) =>
      [
        for (final world in structure.worlds)
          _buildWorldCard(world, state, progress, structure)
      ];

  static WorldCardViewData _buildWorldCard(
    WorldDef world,
    PlayerState state,
    Map<int, StageProgress> progress,
    ProgressionStructure structure,
  ) {
    final unlocked = state.unlockedWorldIds.contains(world.id);
    WorldUnlockConditionData? condition;
    if (!unlocked) {
      // العالم1 مفتوح دوما (PlayerState.initial)، فأي عالم غير مفتوح
      // هنا هو دوما world.id > 1، فـworld.id-1 معرّف عالم صحيح دوما
      final previous = structure.worldById(world.id - 1);
      final previousLastChapter =
          structure.chapterById(previous.chapterIds.last);
      condition = WorldUnlockConditionData(
        requiredWorldId: previous.id,
        requiredWorldLastChapterComplete:
            ProgressionRules.isChapterComplete(previousLastChapter, progress),
      );
    }
    return WorldCardViewData(
      worldId: world.id,
      nameKey: world.nameKey,
      themeId: world.themeId,
      guideCharacterId: world.guideCharacterId,
      colorSeed: world.colorSeed,
      isUnlocked: unlocked,
      completionRewardCoins: BalanceConfig.coinsWorldComplete,
      unlockCondition: condition,
    );
  }

  // ─────────────────────── L2: اختيار الفصل ───────────────────────

  static List<ChapterCardViewData> buildChapterCards({
    required int worldId,
    required PlayerState state,
    required Map<int, StageProgress> progress,
    required ProgressionStructure structure,
  }) {
    final world = structure.worldById(worldId);
    ChapterDef? previous;
    final result = <ChapterCardViewData>[];
    for (final chapterId in world.chapterIds) {
      final chapter = structure.chapterById(chapterId);
      final stagesCompleted =
          ProgressionRules.completedStagesInChapter(chapter, progress);
      final unlocked = state.unlockedChapterIds.contains(chapterId) ||
          ProgressionRules.canEnterChapter(chapter, previous, progress);
      result.add(ChapterCardViewData(
        chapterId: chapterId,
        worldId: worldId,
        index: chapter.index,
        stagesCompleted: stagesCompleted,
        stageCount: chapter.stageCount,
        isUnlocked: unlocked,
        chestState: _chestStateFor(chapter, state, progress),
      ));
      previous = chapter;
    }
    return result;
  }

  static ChestState _chestStateFor(
    ChapterDef chapter,
    PlayerState state,
    Map<int, StageProgress> progress,
  ) {
    if (!ProgressionRules.isChapterComplete(chapter, progress)) {
      return ChestState.locked;
    }
    return state.claimedChapterChestIds.contains(chapter.id)
        ? ChestState.claimed
        : ChestState.unlocked;
  }

  // ─────────────────────── L3: مسار المراحل ───────────────────────

  static List<StageNodeViewData> buildStageNodes({
    required int chapterId,
    required PlayerState state,
    required Map<int, StageProgress> progress,
    required ProgressionStructure structure,
  }) {
    final chapter = structure.chapterById(chapterId);
    return [
      for (final stageId in chapter.stageIds)
        _buildStageNode(stageId, state, progress, structure)
    ];
  }

  static StageNodeViewData _buildStageNode(
    int stageId,
    PlayerState state,
    Map<int, StageProgress> progress,
    ProgressionStructure structure,
  ) {
    final stageDef = structure.stageById(stageId);
    final stageProgress = progress[stageId];
    final unlocked = ProgressionRules.isStageUnlocked(
      stage: stageDef,
      structure: structure,
      progress: progress,
    );

    final StageNodeStatus status;
    if (!unlocked) {
      status = StageNodeStatus.locked;
    } else if (stageProgress?.completed ?? false) {
      status = StageNodeStatus.completed;
    } else if (stageId == state.currentStageId) {
      status = StageNodeStatus.current;
    } else if (stageId == state.currentStageId + 1) {
      status = StageNodeStatus.next;
    } else {
      status = StageNodeStatus.upcoming;
    }

    // "المراحل الثلاث التالية لـcurrent تعرض معاينة دوما عند اللمس" —
    // حرفيا: المسافة 1..3 أمام current، لا current نفسها (تُلعب مباشرة)
    final distanceAheadOfCurrent = stageId - state.currentStageId;
    final previewAvailableOnTap =
        distanceAheadOfCurrent >= 1 && distanceAheadOfCurrent <= 3;

    return StageNodeViewData(
      stageId: stageId,
      status: status,
      isBoss: stageDef.isBoss,
      previewAvailableOnTap: previewAvailableOnTap,
    );
  }

  /// نطاق فهرس العقد الواجب ظهورها عند فتح المسار: العقدتان السابقتان
  /// لـcurrent + الثلاث التاليتان لها، بحدود الفصل. [currentIndex] فهرس
  /// current ضمن قائمة عقد الفصل (0-based).
  static (int start, int end) visibleNodeIndexRange({
    required int currentIndex,
    required int nodeCount,
  }) {
    final start = (currentIndex - 2).clamp(0, nodeCount - 1);
    final end = (currentIndex + 3).clamp(0, nodeCount - 1);
    return (start, end);
  }

  // ─────────────────────── شريط أقرب مكافأة ───────────────────────

  /// أقرب معلَم غير مكتمل بأصغر "مسافة" متبقية (كلمات/مراحل تُقارَن
  /// كأعداد صحيحة مباشرة كما نصّت المهمة حرفيا). لو لم يكن أي منها
  /// قابلا للتطبيق (كل شيء قريب مكتمل فعلا)، الاحتياط: نسبة إتمام العالم
  /// الحالي — لا يُترك الشريط فارغا أبدا.
  static NearRewardBannerData computeNearRewardBanner({
    required PlayerState state,
    required Map<int, StageProgress> progress,
    required ProgressionStructure structure,
  }) {
    final currentStageId =
        state.currentStageId.clamp(1, BalanceConfig.totalStages);
    final currentStage = structure.stageById(currentStageId);
    final chapter = structure.chapterById(currentStage.chapterId);
    final world = structure.worldById(currentStage.worldId);

    final candidates = <MapEntry<NearRewardKind, int>>[];

    // الجرّة لم تعد بوابة عالم، لكنها ما زالت مكافأة طبقات فعلية
    // (jar_rewards.dart) — تبقى مرشّحا للشريط ما لم تُستلَم طبقتها الأولى
    if ((state.claimedJarTierByWorld[world.id] ?? 0) < 1) {
      final jarRemaining = BalanceConfig.jarThresholdForWorld(world.id) -
          (state.jarProgress[world.id] ?? 0);
      if (jarRemaining > 0) {
        candidates.add(MapEntry(NearRewardKind.wordsToJar, jarRemaining));
      }
    }

    if (!state.claimedChapterChestIds.contains(chapter.id)) {
      final remainingStages = chapter.stageIds
          .where((id) => !(progress[id]?.completed ?? false))
          .length;
      if (remainingStages > 0) {
        candidates.add(MapEntry(NearRewardKind.stagesToChest, remainingStages));
      }
    }

    if (candidates.isEmpty) {
      var completedInWorld = 0;
      for (var id = world.stageStart; id <= world.stageEnd; id++) {
        if (progress[id]?.completed ?? false) completedInWorld++;
      }
      final percent = world.stageCount == 0
          ? 0.0
          : completedInWorld / world.stageCount * 100;
      return NearRewardBannerData.percent(percent);
    }

    candidates.sort((a, b) => a.value.compareTo(b.value));
    final winner = candidates.first;
    return NearRewardBannerData.remaining(winner.key, winner.value);
  }
}
