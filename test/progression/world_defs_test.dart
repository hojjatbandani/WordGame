import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/progression/world_defs.dart';

void main() {
  group('توليد بنية التقدّم (اختبار قبول 1)', () {
    late ProgressionStructure structure;

    setUp(() {
      structure = ProgressionStructure.generate();
    });

    test('500 مرحلة بالضبط، مرقّمة 1..500 بلا فجوة ولا تكرار', () {
      expect(structure.stages.length, 500);
      final ids = structure.stages.map((s) => s.id).toList()..sort();
      expect(ids, List.generate(500, (i) => i + 1));
    });

    test('40 فصلا بالضبط، و40 مرحلة زعيم بالضبط', () {
      expect(structure.chapters.length, 40);
      final bossStages = structure.stages.where((s) => s.isBoss).toList();
      expect(bossStages.length, 40);
      // كل مرحلة زعيم هي آخر مرحلة في فصلها بالضبط
      for (final chapter in structure.chapters) {
        expect(chapter.bossStageId, chapter.stageEnd);
        final bossStageDef = structure.stageById(chapter.bossStageId);
        expect(bossStageDef.isBoss, isTrue);
        expect(bossStageDef.indexInChapter, chapter.stageCount);
      }
    });

    test('8 عوالم، حدودها متطابقة تماما مع الجدول المعطى', () {
      expect(structure.worlds.length, 8);

      const expectedRanges = [
        (1, 1, 60),
        (2, 61, 120),
        (3, 121, 180),
        (4, 181, 240),
        (5, 241, 305),
        (6, 306, 370),
        (7, 371, 435),
        (8, 436, 500),
      ];
      for (final (id, start, end) in expectedRanges) {
        final world = structure.worldById(id);
        expect(world.stageStart, start, reason: 'عالم $id stageStart');
        expect(world.stageEnd, end, reason: 'عالم $id stageEnd');
        expect(world.chapterIds.length, 5, reason: 'عالم $id عدد الفصول');
      }
    });

    test('العوالم 1-4 فيها 12 مرحلة لكل فصل (36 نجمة متاحة)، 5-8 فيها 13 '
        '(39 نجمة متاحة)', () {
      for (final world in structure.worlds) {
        for (final chapterId in world.chapterIds) {
          final chapter = structure.chapterById(chapterId);
          final expectedCount = world.id <= 4 ? 12 : 13;
          expect(chapter.stageCount, expectedCount,
              reason: 'عالم ${world.id} فصل ${chapter.index}');
        }
      }
    });

    test('مرحلة الزعيم دوما آخر مرحلة في كل فصل', () {
      for (final world in structure.worlds) {
        for (final chapterId in world.chapterIds) {
          final chapter = structure.chapterById(chapterId);
          expect(chapter.bossStageId, chapter.stageEnd,
              reason: 'عالم ${world.id} فصل ${chapter.index}');
        }
      }
    });

    test('عتبات الجرّة تطابق الجدول المعطى بالضبط', () {
      const expected = {
        1: 40,
        2: 60,
        3: 80,
        4: 100,
        5: 120,
        6: 140,
        7: 160,
        8: 180,
      };
      for (final entry in expected.entries) {
        expect(structure.worldById(entry.key).jarThreshold, entry.value);
      }
    });

    test('هوية العوالم (nameKey/wordDomain/mechanicId) مطابقة للجدول المعطى', () {
      const expected = [
        ('bidaya', 'everyday', 'base'),
        ('waha', 'nature', 'bonus_jar'),
        ('souq', 'trade_culture', 'locked_letters'),
        ('madina', 'proverbs', 'complete_proverb'),
        ('diwan', 'poetry', 'complete_verse'),
        ('khaleej', 'gulf_dialect', 'timed'),
        ('hikma', 'meaning_based', 'guess_from_definition'),
        ('ustura', 'mixed_rare', 'combined_no_shuffle'),
      ];
      for (var i = 0; i < expected.length; i++) {
        final world = structure.worldById(i + 1);
        expect(world.nameKey, expected[i].$1);
        expect(world.wordDomain, expected[i].$2);
        expect(world.mechanicId, expected[i].$3);
      }
    });

    test('يبقى حتميا: استدعاءان متتاليان ينتجان نفس البنية بالضبط', () {
      final second = ProgressionStructure.generate();
      expect(second.stages.length, structure.stages.length);
      for (var i = 0; i < structure.stages.length; i++) {
        expect(second.stages[i].id, structure.stages[i].id);
        expect(second.stages[i].chapterId, structure.stages[i].chapterId);
      }
    });

    test('إجمالي المراحل والزعماء في BalanceConfig يطابقان الشجرة الفعلية', () {
      expect(BalanceConfig.totalStages, structure.stages.length);
      expect(BalanceConfig.totalBossStages,
          structure.stages.where((s) => s.isBoss).length);
    });
  });
}
