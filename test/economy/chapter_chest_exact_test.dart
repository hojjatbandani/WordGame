// صندوق الفصل كان يَعِد برقم ويدفع آخر: البطاقة تعرض المنوال 45
// والاستلام يقرع Random() بين 20 و100، فيقبض اللاعب 38 مرة و75 مرة
// والوعد المكتوب أمامه 45 في الحالتين.
//
// الآن رقم واحد ثابت لكل الفصول: العرض والاستلام يقرآنه من نفس
// الدالة، فيستحيل اختلافهما.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/economy/chapter_chest.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final store = ProgressStore(await SharedPreferences.getInstance());
  final container = ProviderContainer(
    overrides: [progressStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('مبلغ صندوق الفصل ثابت لا مقروع', () {
    test('كل الفصول الأربعين تعطي نفس الرقم في كل نداء', () {
      for (var chapterId = 1; chapterId <= 40; chapterId++) {
        for (var i = 0; i < 20; i++) {
          expect(
            ChapterChest.amountFor(chapterId),
            BalanceConfig.coinsChapterChest,
            reason: 'الفصل $chapterId، النداء $i',
          );
        }
      }
    });

    test('الرقم يأتي من ملف التوازن لا من ثابت مدفون', () {
      // شرطه أن يتحرّك مع BalanceConfig كي يعمل الضبط عن بعد
      final original = BalanceConfig.coinsChapterChest;
      addTearDown(() => BalanceConfig.coinsChapterChest = original);

      BalanceConfig.coinsChapterChest = 77;
      expect(ChapterChest.amountFor(1), 77);
      expect(ChapterChest.amountFor(40), 77);
    });
  });

  group('ما يُعرض هو ما يُقبَض', () {
    test('الاستلام يدفع بالضبط ما تعرضه البطاقة', () async {
      final c = await _container();
      final structure = c.read(progressionStructureProvider);
      final chapter = structure.chapters.first;

      // ما تعرضه البطاقة قبل الفتح
      final shown = ChapterChest.amountFor(chapter.id);

      // نُكمل الفصل كله كي يُفتح صندوقه
      for (var id = chapter.stageStart; id <= chapter.stageEnd; id++) {
        await c
            .read(progressionProvider.notifier)
            .recordStageCompletion(
              stageId: id,
              bonusWordsFoundThisRun: const {},
              hintsUsedThisRun: 0,
              timeMs: 1000,
              coreWordsFound: 3,
            );
      }

      final before = c.read(pointsProvider);
      final paid = await c
          .read(progressionProvider.notifier)
          .claimChapterChest(chapter.id);

      expect(paid, shown, reason: 'الوعد المعروض هو المبلغ المدفوع');
      expect(
        c.read(pointsProvider) - before,
        shown,
        reason: 'والمحفظة تزيد بنفس الرقم لا برقم ثالث',
      );
    });

    test('الصندوق لا يُستلَم مرتين', () async {
      final c = await _container();
      final chapter = c.read(progressionStructureProvider).chapters.first;
      for (var id = chapter.stageStart; id <= chapter.stageEnd; id++) {
        await c
            .read(progressionProvider.notifier)
            .recordStageCompletion(
              stageId: id,
              bonusWordsFoundThisRun: const {},
              hintsUsedThisRun: 0,
              timeMs: 1000,
              coreWordsFound: 3,
            );
      }
      final notifier = c.read(progressionProvider.notifier);
      expect(await notifier.claimChapterChest(chapter.id), greaterThan(0));
      expect(await notifier.claimChapterChest(chapter.id), 0);
    });
  });
}
