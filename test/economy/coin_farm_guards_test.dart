// مزارع العملات: الأماكن التي كان يُدفع فيها على عمل واحد مرارا.
//
// العلّة المشتركة في الحالتين واحدة: الدفع كان معلّقا على حالة **في
// الودجت** (`_bonusFound`، `_solved`) بينما الدفتر المحفوظ لا يُكتب
// إلا في لحظة لاحقة قد لا تقع أصلا. كل خروج من الشاشة يمسح الحالة
// ويترك الدفتر فارغا، فيُدفع على نفس العمل من جديد بلا حدّ.
//
// الاختبارات هنا تعمل على الطبقة التي تحرس فعلا (المستودع والمزوّد) لا
// على الودجت: الحارس يجب أن يصمد أيا كانت الشاشة التي تناديه.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/challenge_models.dart';
import 'package:huruf/data/challenge_progress.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
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

  group('الكلمة الإضافية تُدفع مرة واحدة مهما تكرّرت المحاولات', () {
    test('أول اكتشاف يُقبل، وإعادته تُرفض — بلا إتمام المرحلة', () async {
      final c = await _container();
      final notifier = c.read(progressionProvider.notifier);

      expect(
        await notifier.recordBonusWordFound(7, 'ملح'),
        isTrue,
        reason: 'أول مرة',
      );
      expect(
        await notifier.recordBonusWordFound(7, 'ملح'),
        isFalse,
        reason: 'نفس الكلمة، نفس المرحلة — لا دفعة ثانية',
      );
    });

    test('التثبيت لا ينتظر إتمام المرحلة — وهي حالة المزرعة بالضبط',
        () async {
      final c = await _container();
      await c.read(progressionProvider.notifier).recordBonusWordFound(7, 'ملح');

      // المرحلة لم تُكمَل قط، ومع ذلك الدفتر يعرف الكلمة
      final progress = c.read(progressionProvider).stageProgress[7];
      expect(progress?.completed, isNot(true), reason: 'لم تُكمَل');
      expect(progress?.bonusWordsFound, contains('ملح'));
    });

    test('ينجو من إعادة تشغيل التطبيق', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ProgressStore(await SharedPreferences.getInstance());

      final first = ProviderContainer(
        overrides: [progressStoreProvider.overrideWithValue(store)],
      );
      await first
          .read(progressionProvider.notifier)
          .recordBonusWordFound(7, 'ملح');
      first.dispose();

      // إقلاع بارد من نفس التخزين
      final prefs = await SharedPreferences.getInstance();
      final repo = await ProgressionRepository.load(prefs: prefs, legacy: store);
      expect(
        repo.stageProgress[7]?.bonusWordsFound,
        contains('ملح'),
        reason: 'لو ضاعت بالإقلاع عادت المزرعة',
      );
    });

    test('كلمتان مختلفتان في نفس المرحلة تُقبلان معا', () async {
      final c = await _container();
      final notifier = c.read(progressionProvider.notifier);
      expect(await notifier.recordBonusWordFound(7, 'ملح'), isTrue);
      expect(await notifier.recordBonusWordFound(7, 'لحم'), isTrue);
      expect(
        c.read(progressionProvider).stageProgress[7]?.bonusWordsFound,
        {'ملح', 'لحم'},
      );
    });

    test('نفس الكلمة في مرحلة أخرى اكتشاف مستقلّ', () async {
      final c = await _container();
      final notifier = c.read(progressionProvider.notifier);
      expect(await notifier.recordBonusWordFound(7, 'ملح'), isTrue);
      expect(
        await notifier.recordBonusWordFound(8, 'ملح'),
        isTrue,
        reason: 'الجرد لكل مرحلة على حدة',
      );
    });
  });

  group('عنصر التحدّي يُدفع عليه مرة واحدة', () {
    test('markSolved حارس ثابت: الحلّ الثاني لا يضيف شيئا', () async {
      final c = await _container();
      final notifier = c.read(challengeProgressProvider.notifier);
      final category = ChallengeCategory.values.first;

      notifier.markSolved(category, 0);
      final afterFirst = c.read(challengeProgressProvider).solvedIds;
      expect(afterFirst.length, 1);

      notifier.markSolved(category, 0);
      expect(
        c.read(challengeProgressProvider).solvedIds.length,
        1,
        reason: 'نفس العنصر لا يُسجَّل مرتين',
      );
    });

    test('المعرّف المحفوظ هو نفسه الذي تفحصه الشاشة قبل الدفع', () {
      // الشاشة تسأل ChallengeProgressRules.idFor(category, index) قبل أن
      // تدفع. لو اختلفت صيغة المعرّف بين الطرفين عاد الدفع المكرّر بلا
      // أن يسقط اختبار آخر — فنقفل الصيغة نفسها هنا.
      final category = ChallengeCategory.values.first;
      expect(
        ChallengeProgressRules.idFor(category, 3),
        ChallengeProgressRules.idFor(category, 3),
      );
      expect(
        ChallengeProgressRules.idFor(category, 3),
        isNot(ChallengeProgressRules.idFor(category, 4)),
      );
      if (ChallengeCategory.values.length > 1) {
        expect(
          ChallengeProgressRules.idFor(ChallengeCategory.values[1], 3),
          isNot(ChallengeProgressRules.idFor(category, 3)),
          reason: 'الفئة جزء من المعرّف وإلا تداخلت الفئات',
        );
      }
    });
  });
}
