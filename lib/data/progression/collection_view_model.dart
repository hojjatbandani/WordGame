// طبقة استعلام مجموعة الكلمات الإضافية — منطق صرف بالكامل، بلا استيراد
// Flutter. الكلمات نفسها محفوظة أصلا (نصّا لا عددا فقط) في
// StageProgress.bonusWordsFound لكل مرحلة على حدة؛ هذا الملف يجمّعها
// ويرتّبها حسب العالم ويبحث فيها، دون أي تخزين مكرّر جديد.
//
// المعاني: لا يحمل أي كلمة إضافية معنى في بيانات اللعبة اليوم —
// GameLevel.bonusWords في assets/data/levels.json مجرد List<String> بلا
// تعريفات (بخلاف WordEntry للكلمات الأساسية التي تحمل definition). لذا
// [BonusWordEntry.meaning] تبقى null حتى يُؤلَّف قاموس للكلمات الإضافية،
// والواجهة تعرض ذلك صراحة بدل اختلاق معنى.

import 'stage_progress.dart';
import 'world_defs.dart';

class BonusWordEntry {
  final String word;
  final int worldId;
  final int stageId;

  /// null يعني "لا معنى مؤلَّف بعد لهذه الكلمة" — راجع رأس الملف
  final String? meaning;

  const BonusWordEntry({
    required this.word,
    required this.worldId,
    required this.stageId,
    required this.meaning,
  });
}

class WorldCollection {
  final int worldId;
  final String nameKey;
  final List<BonusWordEntry> words;

  /// كل الكلمات الإضافية المتاحة نظريا في هذا العالم — صفر حاليا لأن
  /// StageDef.bonusWordPool لم يُؤلَّف بعد (راجع world_defs.dart)، فتعرض
  /// الواجهة العدد المكتشف وحده بدل نسبة مضلِّلة من صفر
  final int totalAvailable;

  const WorldCollection({
    required this.worldId,
    required this.nameKey,
    required this.words,
    required this.totalAvailable,
  });

  int get foundCount => words.length;
}

class CollectionViewModel {
  const CollectionViewModel._();

  /// يبني المجموعة كاملة مرتّبة حسب العالم ثم حسب رقم المرحلة ثم أبجديا.
  /// [meaningLookup] اختياري: أي مصدر معانٍ مستقبلي (قاموس مؤلَّف) —
  /// يُمرَّر كدالة كي لا يرتبط هذا الملف بأي مصدر بيانات بعينه.
  static List<WorldCollection> build({
    required Map<int, StageProgress> stageProgress,
    required ProgressionStructure structure,
    String? Function(String word)? meaningLookup,
  }) {
    final byWorld = <int, List<BonusWordEntry>>{};

    for (final entry in stageProgress.entries) {
      final stageId = entry.key;
      final progress = entry.value;
      if (progress.bonusWordsFound.isEmpty) continue;

      final worldId = structure.stageById(stageId).worldId;
      final list = byWorld.putIfAbsent(worldId, () => []);
      for (final word in progress.bonusWordsFound) {
        list.add(BonusWordEntry(
          word: word,
          worldId: worldId,
          stageId: stageId,
          meaning: meaningLookup?.call(word),
        ));
      }
    }

    return [
      for (final world in structure.worlds)
        WorldCollection(
          worldId: world.id,
          nameKey: world.nameKey,
          words: (byWorld[world.id] ?? [])
            ..sort((a, b) {
              final byStage = a.stageId.compareTo(b.stageId);
              return byStage != 0 ? byStage : a.word.compareTo(b.word);
            }),
          totalAvailable: _availableInWorld(world, structure),
        ),
    ];
  }

  static int _availableInWorld(WorldDef world, ProgressionStructure structure) {
    var total = 0;
    for (var stageId = world.stageStart; stageId <= world.stageEnd; stageId++) {
      total += structure.stageById(stageId).bonusWordPool.length;
    }
    return total;
  }

  /// بحث نصّي بسيط داخل مجموعة مبنيّة مسبقا — يُبقي العوالم التي فيها
  /// نتيجة واحدة على الأقل فقط، كي لا تُعرض عناوين عوالم فارغة أثناء البحث
  static List<WorldCollection> search(
    List<WorldCollection> all,
    String query,
  ) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return all;

    final result = <WorldCollection>[];
    for (final world in all) {
      final matches =
          world.words.where((w) => w.word.contains(trimmed)).toList();
      if (matches.isEmpty) continue;
      result.add(WorldCollection(
        worldId: world.worldId,
        nameKey: world.nameKey,
        words: matches,
        totalAvailable: world.totalAvailable,
      ));
    }
    return result;
  }

  static int totalFound(List<WorldCollection> all) =>
      all.fold<int>(0, (sum, w) => sum + w.foundCount);
}
