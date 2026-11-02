// اختبار انحدار لعطل «الجدار عند المرحلة 13»: كانت بوّابة الفصل التالي
// تطلب نسبة من سقف الثلاث نجوم، فلاعب يُنهي كل مراحل الفصل الأول قد يبقى
// محبوسا فيه. أُزيل نظام النجوم بالكامل، والقاعدة الآن واحدة: إتمام كل
// مراحل الفصل — بأي أداء — يفتح الفصل التالي، ولا شيء غيره يفتحه.

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression/map_view_model.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProgressionRepository> _freshRepo() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProgressionRepository.load(prefs: prefs, legacy: ProgressStore(prefs));
}

/// يلعب كل مراحل الفصل الأول بأداء موصوف
void _playChapterOne(
  ProgressionRepository repo, {
  required int hintsPerStage,
  required int bonusWordsPerStage,
}) {
  final chapter = repo.structure.chapterById(1);
  for (var id = chapter.stageStart; id <= chapter.stageEnd; id++) {
    repo.recordStageCompletion(
      stageId: id,
      bonusWordsFoundThisRun: {
        for (var i = 0; i < bonusWordsPerStage; i++) 'w$id-$i',
      },
      hintsUsedThisRun: hintsPerStage,
      timeMs: 60000,
      now: DateTime(2026, 1, 1),
    );
  }
}

bool _chapterTwoUnlocked(ProgressionRepository repo) =>
    MapViewModel.buildChapterCards(
      worldId: 1,
      state: repo.state,
      progress: repo.stageProgress,
      structure: repo.structure,
    )[1].isUnlocked;

void main() {
  group('بوّابة الفصل الثاني', () {
    test('إتمام كل مراحل الفصل الأول يفتح الفصل الثاني', () async {
      final repo = await _freshRepo();
      _playChapterOne(repo, hintsPerStage: 0, bonusWordsPerStage: 1);
      expect(_chapterTwoUnlocked(repo), isTrue);
    });

    test(
      'الإتمام بتلميحات في كل مرحلة وبلا كلمات إضافية يفتح أيضا',
      () async {
        final repo = await _freshRepo();
        _playChapterOne(repo, hintsPerStage: 3, bonusWordsPerStage: 0);
        expect(
          _chapterTwoUnlocked(repo),
          isTrue,
          reason: 'لا بوّابة إتقان: الإتمام وحده يكفي',
        );
      },
    );

    test('مرحلة واحدة ناقصة تُبقي الفصل الثاني مقفلا', () async {
      final repo = await _freshRepo();
      final chapter = repo.structure.chapterById(1);
      for (var id = chapter.stageStart; id < chapter.stageEnd; id++) {
        repo.recordStageCompletion(
          stageId: id,
          bonusWordsFoundThisRun: {'w$id'},
          hintsUsedThisRun: 0,
          timeMs: 60000,
          now: DateTime(2026, 1, 1),
        );
      }
      expect(_chapterTwoUnlocked(repo), isFalse);

      // وإتمام المرحلة الأخيرة (الزعيم) يفتحه فورا
      repo.recordStageCompletion(
        stageId: chapter.stageEnd,
        bonusWordsFoundThisRun: const {},
        hintsUsedThisRun: 4,
        timeMs: 60000,
        now: DateTime(2026, 1, 1),
      );
      expect(_chapterTwoUnlocked(repo), isTrue);
    });
  });

  group('حالة المرحلة تتبع الإتمام وحده', () {
    test('أول إتمام يعلّم المرحلة مكتملة ويُعلن إتمام الفصل عند آخرها',
        () async {
      final repo = await _freshRepo();
      final result = repo.recordStageCompletion(
        stageId: 1,
        bonusWordsFoundThisRun: {'كلمة'},
        hintsUsedThisRun: 0,
        timeMs: 1000,
        now: DateTime(2026, 1, 1),
      );
      expect(result.stageProgress.completed, isTrue);
      expect(
        result.chapterCompletedThisRun,
        isFalse,
        reason: 'بقيت مراحل أخرى في الفصل',
      );
    });

    test('إتمام آخر مرحلة ناقصة في الفصل يُعلن إتمام الفصل مرة واحدة',
        () async {
      final repo = await _freshRepo();
      final chapter = repo.structure.chapterById(1);
      late final bool announcedOnLast;
      for (var id = chapter.stageStart; id <= chapter.stageEnd; id++) {
        final r = repo.recordStageCompletion(
          stageId: id,
          bonusWordsFoundThisRun: const {},
          hintsUsedThisRun: 1,
          timeMs: 60000,
          now: DateTime(2026, 1, 1),
        );
        if (id == chapter.stageEnd) announcedOnLast = r.chapterCompletedThisRun;
      }
      expect(announcedOnLast, isTrue);

      // إعادة لعب مرحلة في فصل مكتمل أصلا لا تُعلن الإتمام ثانية
      final again = repo.recordStageCompletion(
        stageId: chapter.stageStart,
        bonusWordsFoundThisRun: const {},
        hintsUsedThisRun: 0,
        timeMs: 30000,
        now: DateTime(2026, 1, 2),
      );
      expect(again.chapterCompletedThisRun, isFalse);
    });

    test('إعادة اللعب بأداء أسوأ لا تُلغي الإتمام', () async {
      final repo = await _freshRepo();
      repo.recordStageCompletion(
        stageId: 1,
        bonusWordsFoundThisRun: {'كلمة'},
        hintsUsedThisRun: 0,
        timeMs: 1000,
        now: DateTime(2026, 1, 1),
      );
      final again = repo.recordStageCompletion(
        stageId: 1,
        bonusWordsFoundThisRun: const {},
        hintsUsedThisRun: 5,
        timeMs: 9000,
        now: DateTime(2026, 1, 2),
      );
      expect(again.stageProgress.completed, isTrue);
      expect(
        again.stageProgress.bonusWordsFound,
        contains('كلمة'),
        reason: 'الكلمات الإضافية تتراكم ولا تُفرَّغ',
      );
    });
  });
}
