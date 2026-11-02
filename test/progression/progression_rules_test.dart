import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/progression/progression_rules.dart';
import 'package:huruf/data/progression/stage_progress.dart';
import 'package:huruf/data/progression/world_defs.dart';

StageProgress _completed(int stageId) => StageProgress(
      stageId: stageId,
      completed: true,
      bestTimeMs: null,
      hintsUsedBest: 0,
      bonusWordsFound: const {},
      attempts: 1,
      lastPlayedAt: null,
    );

/// يُكمل أول [count] مرحلة من [chapter] (كلها إن أُهمل العدد)
Map<int, StageProgress> _completeStagesIn(ChapterDef chapter, {int? count}) {
  final ids = chapter.stageIds.toList();
  final take = count ?? ids.length;
  return {
    for (final stageId in ids.take(take)) stageId: _completed(stageId),
  };
}

void main() {
  late ProgressionStructure structure;

  setUp(() {
    structure = ProgressionStructure.generate();
  });

  group('بوابة دخول الفصل', () {
    test('مرحلة واحدة ناقصة تُبقي الفصل التالي مقفلا، وإتمامها يفتحه', () {
      final world1 = structure.worldById(1);
      final chapter1 = structure.chapterById(world1.chapterIds[0]); // 12 مرحلة
      final chapter2 = structure.chapterById(world1.chapterIds[1]);
      expect(chapter1.stageCount, 12);

      final almost = _completeStagesIn(chapter1, count: 11);
      expect(
        ProgressionRules.canEnterChapter(chapter2, chapter1, almost),
        isFalse,
      );

      final all = _completeStagesIn(chapter1);
      expect(
        ProgressionRules.canEnterChapter(chapter2, chapter1, all),
        isTrue,
      );
    });

    test('الأداء لا يدخل في البوّابة: إتمام بتلميحات وبلا كلمات إضافية يفتح',
        () {
      final world1 = structure.worldById(1);
      final chapter1 = structure.chapterById(world1.chapterIds[0]);
      final chapter2 = structure.chapterById(world1.chapterIds[1]);

      final sloppy = {
        for (final stageId in chapter1.stageIds)
          stageId: StageProgress(
            stageId: stageId,
            completed: true,
            bestTimeMs: null,
            hintsUsedBest: 5,
            bonusWordsFound: const {},
            attempts: 3,
            lastPlayedAt: null,
          ),
      };
      expect(
        ProgressionRules.canEnterChapter(chapter2, chapter1, sloppy),
        isTrue,
      );
    });

    test('الفصل الأول في أي عالم لا يشترط شيئا — بوابته العالم فقط', () {
      final world3 = structure.worldById(3);
      final chapter1 = structure.chapterById(world3.chapterIds[0]);
      expect(ProgressionRules.canEnterChapter(chapter1, null, {}), isTrue);
    });
  });

  group('بوابة دخول العالم', () {
    test('إتمام الفصل الأخير من العالم السابق وحده يفتح العالم التالي', () {
      final world1 = structure.worldById(1);
      final world2 = structure.worldById(2);
      final lastChapter = structure.chapterById(world1.chapterIds.last);

      final almost = <int, StageProgress>{
        for (final chapterId in world1.chapterIds)
          if (chapterId != lastChapter.id)
            ..._completeStagesIn(structure.chapterById(chapterId)),
        ..._completeStagesIn(lastChapter, count: lastChapter.stageCount - 1),
      };
      expect(
        ProgressionRules.canEnterWorld(
          world: world2,
          structure: structure,
          progress: almost,
        ),
        isFalse,
        reason: 'مرحلة واحدة في الفصل الأخير لم تُحَل بعد',
      );

      final full = <int, StageProgress>{
        ...almost,
        ..._completeStagesIn(lastChapter),
      };
      expect(
        ProgressionRules.canEnterWorld(
          world: world2,
          structure: structure,
          progress: full,
        ),
        isTrue,
      );
    });

    test('العالم 1 مفتوح دوما بلا أي شرط', () {
      final world1 = structure.worldById(1);
      expect(
        ProgressionRules.canEnterWorld(
          world: world1,
          structure: structure,
          progress: const {},
        ),
        isTrue,
      );
    });
  });

  group('فتح المراحل الخطّي', () {
    test('المرحلة الأولى وحدها مفتوحة عند أول تشغيل', () {
      expect(
        ProgressionRules.isStageUnlocked(
          stage: structure.stageById(1),
          structure: structure,
          progress: const {},
        ),
        isTrue,
      );
      for (var id = 2; id <= 5; id++) {
        expect(
          ProgressionRules.isStageUnlocked(
            stage: structure.stageById(id),
            structure: structure,
            progress: const {},
          ),
          isFalse,
          reason: 'المرحلة $id يجب أن تبقى مقفلة قبل إتمام ما قبلها',
        );
      }
    });

    test('إتمام مرحلة يفتح التالية داخل نفس الفصل', () {
      expect(
        ProgressionRules.isStageUnlocked(
          stage: structure.stageById(2),
          structure: structure,
          progress: {1: _completed(1)},
        ),
        isTrue,
      );
    });
  });
}
