// منطق صرف بلا أي استيراد من Flutter — قابل للاختبار كوحدة دون أي شجرة
// ودجات. لا يُنشئ هذا الملف كائناته إلا عبر [ProgressionStructure.generate],
// فتبقى حدود العوالم/الفصول/المراحل محسوبة من رقم واحد (BalanceConfig)
// بدل جدول مكتوب يدويا يمكن أن ينحرف عن الحقيقة.

import '../../config/balance_config.dart';

/// عالم واحد من عوالم اللعبة الثمانية.
///
/// [colorSeed] و[guideCharacterId] عنصرا هوية بصرية لم تُحدَّد قيمهما
/// الفعلية بعد (لا لوحة ألوان ولا تعيين شخصيات في هذه المهمة) — القيم
/// هنا مشتقة آليا من [id] كحجز مكان صريح، لا اختراع تصميم.
class WorldDef {
  final int id;
  final String nameKey;
  final String themeId;
  final int colorSeed;
  final String guideCharacterId;
  final int stageStart;
  final int stageEnd;
  final List<int> chapterIds;
  final int jarThreshold;
  final String wordDomain;
  final String mechanicId;

  const WorldDef({
    required this.id,
    required this.nameKey,
    required this.themeId,
    required this.colorSeed,
    required this.guideCharacterId,
    required this.stageStart,
    required this.stageEnd,
    required this.chapterIds,
    required this.jarThreshold,
    required this.wordDomain,
    required this.mechanicId,
  });

  int get stageCount => stageEnd - stageStart + 1;
}

/// فصل واحد (5 فصول لكل عالم). [bossStageId] هو دائما آخر مرحلة في
/// الفصل — العلَم مضبوط هنا فقط؛ السلوك الفعلي لمرحلة الزعيم مهمة لاحقة.
class ChapterDef {
  final int id;
  final int worldId;

  /// ترتيب الفصل داخل عالمه، يبدأ من 1
  final int index;
  final int stageStart;
  final int stageEnd;
  final int bossStageId;

  const ChapterDef({
    required this.id,
    required this.worldId,
    required this.index,
    required this.stageStart,
    required this.stageEnd,
    required this.bossStageId,
  });

  int get stageCount => stageEnd - stageStart + 1;

  Iterable<int> get stageIds sync* {
    for (var s = stageStart; s <= stageEnd; s++) {
      yield s;
    }
  }
}

/// مرحلة واحدة. [letterCount]/[coreWordCount]/[bonusWordPool] بيانات
/// محتوى فعلي (كلمات حقيقية) لم تُعطَ في هذه المهمة — القيم الافتراضية
/// هنا صفر/فارغة عمدا، بانتظار خط أنابيب تأليف مشابه لـ
/// tool/generate_levels.dart الحالي. لا اختبار قبول يفحص هذه الحقول.
class StageDef {
  final int id;
  final int chapterId;
  final int worldId;

  /// ترتيب المرحلة داخل فصلها، يبدأ من 1
  final int indexInChapter;
  final bool isBoss;
  final int letterCount;
  final int coreWordCount;
  final List<String> bonusWordPool;

  /// مشتقّة من رقم العالم (السلّم الطبيعي للصعوبة في هذا التصميم)، لا
  /// قيمة مخترعة بمعزل عن البنية المعطاة
  final int difficultyBucket;

  const StageDef({
    required this.id,
    required this.chapterId,
    required this.worldId,
    required this.indexInChapter,
    required this.isBoss,
    this.letterCount = 0,
    this.coreWordCount = 0,
    this.bonusWordPool = const [],
    required this.difficultyBucket,
  });
}

/// الشجرة الكاملة (8 عوالم / 40 فصلا / 500 مرحلة) مبنيّة مرة واحدة من
/// BalanceConfig، مع خرائط بحث بزمن ثابت. لا حالة قابلة للتغيير هنا؛
/// [generate] حتمية بالكامل (لا DateTime.now ولا Random) فتُعيد نفس
/// الشجرة تماما في كل استدعاء.
class ProgressionStructure {
  final List<WorldDef> worlds;
  final List<ChapterDef> chapters;
  final List<StageDef> stages;

  final Map<int, WorldDef> _worldById;
  final Map<int, ChapterDef> _chapterById;
  final Map<int, StageDef> _stageById;

  ProgressionStructure._({
    required this.worlds,
    required this.chapters,
    required this.stages,
    required Map<int, WorldDef> worldById,
    required Map<int, ChapterDef> chapterById,
    required Map<int, StageDef> stageById,
  })  : _worldById = Map.unmodifiable(worldById),
        _chapterById = Map.unmodifiable(chapterById),
        _stageById = Map.unmodifiable(stageById);

  WorldDef worldById(int id) =>
      _worldById[id] ?? (throw ArgumentError('لا عالم بهذا المعرّف: $id'));

  ChapterDef chapterById(int id) =>
      _chapterById[id] ?? (throw ArgumentError('لا فصل بهذا المعرّف: $id'));

  StageDef stageById(int id) =>
      _stageById[id] ?? (throw ArgumentError('لا مرحلة بهذا المعرّف: $id'));

  WorldDef worldOfStage(int stageId) => worldById(stageById(stageId).worldId);

  ChapterDef chapterOfStage(int stageId) =>
      chapterById(stageById(stageId).chapterId);

  /// الفصل التالي داخل نفس العالم، أو null إن كان آخر فصل في العالم
  ChapterDef? nextChapterInWorld(ChapterDef chapter) {
    final world = worldById(chapter.worldId);
    final pos = world.chapterIds.indexOf(chapter.id);
    if (pos == -1 || pos == world.chapterIds.length - 1) return null;
    return chapterById(world.chapterIds[pos + 1]);
  }

  /// العالم التالي، أو null إن كان آخر عالم
  WorldDef? nextWorld(int worldId) =>
      worldId >= worlds.length ? null : worldById(worldId + 1);

  /// جدول هوية العوالم الثابت: (nameKey, themeId, wordDomain, mechanicId)
  /// — معطى حرفيا في المواصفة، لا يُشتق من رقم
  static const List<(String nameKey, String themeId, String wordDomain,
      String mechanicId)> _identities = [
    ('bidaya', 'journey_start', 'everyday', 'base'),
    ('waha', 'oasis', 'nature', 'bonus_jar'),
    ('souq', 'market', 'trade_culture', 'locked_letters'),
    ('madina', 'city', 'proverbs', 'complete_proverb'),
    ('diwan', 'royal_court', 'poetry', 'complete_verse'),
    ('khaleej', 'the_gulf', 'gulf_dialect', 'timed'),
    ('hikma', 'land_of_wisdom', 'meaning_based', 'guess_from_definition'),
    ('ustura', 'legend', 'mixed_rare', 'combined_no_shuffle'),
  ];

  static ProgressionStructure generate() {
    final worldCount = BalanceConfig.worldCount;
    final chaptersPerWorld = BalanceConfig.chaptersPerWorld;
    if (_identities.length != worldCount) {
      throw StateError(
          'جدول هوية العوالم يحوي ${_identities.length} عالما لكن '
          'BalanceConfig.worldCount = $worldCount — حدّث أحدهما');
    }

    final worlds = <WorldDef>[];
    final chapters = <ChapterDef>[];
    final stages = <StageDef>[];

    var runningStageId = 1;
    var runningChapterId = 1;

    for (var worldId = 1; worldId <= worldCount; worldId++) {
      final worldStageStart = runningStageId;
      final chapterStageCount =
          BalanceConfig.worldStageCount(worldId) ~/ chaptersPerWorld;
      final chapterIds = <int>[];

      for (var chapterIndex = 1;
          chapterIndex <= chaptersPerWorld;
          chapterIndex++) {
        final chapterId = runningChapterId++;
        final chapterStageStart = runningStageId;
        final chapterStageEnd = runningStageId + chapterStageCount - 1;

        chapters.add(ChapterDef(
          id: chapterId,
          worldId: worldId,
          index: chapterIndex,
          stageStart: chapterStageStart,
          stageEnd: chapterStageEnd,
          bossStageId: chapterStageEnd,
        ));
        chapterIds.add(chapterId);

        for (var s = chapterStageStart; s <= chapterStageEnd; s++) {
          stages.add(StageDef(
            id: s,
            chapterId: chapterId,
            worldId: worldId,
            indexInChapter: s - chapterStageStart + 1,
            isBoss: s == chapterStageEnd,
            difficultyBucket: worldId,
          ));
        }

        runningStageId = chapterStageEnd + 1;
      }

      final identity = _identities[worldId - 1];
      worlds.add(WorldDef(
        id: worldId,
        nameKey: identity.$1,
        themeId: identity.$2,
        colorSeed: worldId,
        guideCharacterId: 'guide_${identity.$1}',
        stageStart: worldStageStart,
        stageEnd: runningStageId - 1,
        chapterIds: List.unmodifiable(chapterIds),
        jarThreshold: BalanceConfig.jarThresholdForWorld(worldId),
        wordDomain: identity.$3,
        mechanicId: identity.$4,
      ));
    }

    return ProgressionStructure._(
      worlds: List.unmodifiable(worlds),
      chapters: List.unmodifiable(chapters),
      stages: List.unmodifiable(stages),
      worldById: {for (final w in worlds) w.id: w},
      chapterById: {for (final c in chapters) c.id: c},
      stageById: {for (final s in stages) s.id: s},
    );
  }
}
