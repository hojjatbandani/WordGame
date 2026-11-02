// مكافأة الكلمات الإضافية، واسم اللاعب، وسعرا التلميحين — ثلاثة أشياء
// يراها اللاعب مباشرة على الشاشة، فتُحرَس بأرقامها لا بوصفها.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/config/balance_overrides.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = ProgressStore(await SharedPreferences.getInstance());
  final container = ProviderContainer(
    overrides: [progressStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('مكافأة كل خمس كلمات إضافية', () {
    test('الخامسة تمنح المكافأة وما قبلها لا', () async {
      final c = await _container();
      final counter = c.read(bonusWordCounterProvider.notifier);

      for (var i = 1; i <= 4; i++) {
        expect(counter.register(), isNull, reason: 'الكلمة رقم $i');
      }
      expect(counter.register(), 5, reason: 'الخامسة تمنح المكافأة');
      expect(c.read(bonusWordCounterProvider), 5);
    });

    test('العاشرة تمنح مكافأة ثانية — العدّاد لا يُصفَّر بل يتراكم', () async {
      final c = await _container();
      final counter = c.read(bonusWordCounterProvider.notifier);
      final milestones = [
        for (var i = 0; i < 12; i++) counter.register(),
      ].whereType<int>().toList();
      expect(milestones, [5, 10]);
      expect(c.read(bonusWordCounterProvider), 12);
    });

    test('العدّاد يُستأنف من المحفوظ بعد إعادة التشغيل', () async {
      final c = await _container({'bonus_words_counted': 4});
      expect(c.read(bonusWordCounterProvider), 4);
      // الكلمة التالية هي الخامسة فعلا، فتمنح المكافأة
      expect(c.read(bonusWordCounterProvider.notifier).register(), 5);
    });

    test('المكافأة والعتبة رقمان معلومان في BalanceConfig', () {
      expect(BalanceConfig.bonusWordMilestoneEvery, 5);
      expect(BalanceConfig.coinsBonusWordMilestone, 2);
    });
  });

  group('اسم اللاعب', () {
    test('لا اسم على تثبيت جديد، والإدخال يُحفظ ويُعلَّم أنه سُئل', () async {
      final c = await _container();
      expect(c.read(playerNameProvider), isNull);
      expect(c.read(progressStoreProvider).playerNameAsked, isFalse);

      await c.read(playerNameProvider.notifier).set('  فهد  ');
      expect(c.read(playerNameProvider), 'فهد', reason: 'يُشذَّب الفراغ');
      expect(c.read(progressStoreProvider).playerName, 'فهد');
      expect(c.read(progressStoreProvider).playerNameAsked, isTrue);
    });

    test('التخطّي لا يحفظ اسما لكنه لا يسأل ثانية', () async {
      final c = await _container();
      await c.read(playerNameProvider.notifier).skip();
      expect(c.read(playerNameProvider), isNull);
      expect(c.read(progressStoreProvider).playerNameAsked, isTrue);
    });

    test('الاسم المحفوظ يُقرأ عند الإقلاع التالي', () async {
      final c = await _container({'player_name': 'نورة'});
      expect(c.read(playerNameProvider), 'نورة');
    });
  });

  group('شحنات التلميح المجانية', () {
    test('تُقرأ من المحفوظ وتُستهلك واحدة واحدة حتى النفاد', () async {
      final c = await _container({'banked_hint_charges': 2});
      final charges = c.read(hintChargesProvider.notifier);
      expect(c.read(hintChargesProvider), 2);

      expect(charges.consume(), isTrue);
      expect(c.read(hintChargesProvider), 1);
      expect(charges.consume(), isTrue);
      expect(c.read(hintChargesProvider), 0);

      expect(
        charges.consume(),
        isFalse,
        reason: 'بلا رصيد يدفع اللاعب عملات — لا رصيد سالب',
      );
      expect(c.read(hintChargesProvider), 0);
    });

    test('الاستهلاك يُحفظ فورا فلا يعود الرصيد بعد إعادة التشغيل', () async {
      final c = await _container({'banked_hint_charges': 3});
      c.read(hintChargesProvider.notifier).consume();
      // الرصيد يعيش في محفظة نظام التقدّم لا في مفتاح
      // banked_hint_charges القديم — ذاك يُقرأ مرة واحدة عند الهجرة
      // ثم لا يُكتب أبدا، فالتحقّق الصحيح هو ما تراه المحفظة
      expect(
        c.read(progressionRepositoryProvider).state.wallet.hintCharges,
        2,
      );
    });

    test('الإضافة تتراكم — حزمة البداية وعجلة الحظ نفس الرصيد', () async {
      final c = await _container();
      final charges = c.read(hintChargesProvider.notifier);
      charges.add(5); // حزمة البداية
      charges.add(1); // قطاع عجلة
      expect(c.read(hintChargesProvider), 6);
      expect(
        c.read(progressionRepositoryProvider).state.wallet.hintCharges,
        6,
      );
    });

    test('حزمة البداية (5 شحنات) لا يقصّها سقف الشحنات المجانية (3)',
        () async {
      final c = await _container();
      c.read(hintChargesProvider.notifier).add(5);
      expect(
        c.read(hintChargesProvider),
        5,
        reason: 'السقف يخصّ ما تمنحه اللعبة مجانا، لا ما دُفع ثمنه',
      );
    });
  });

  group('سعرا تلميحي شاشة اللعب', () {
    test('مختلفان ومعلومان: المرتّب 40 والعشوائي 25', () {
      expect(BalanceConfig.coinsHintOrderedLetter, 40);
      expect(BalanceConfig.coinsHintRandomLetter, 25);
      expect(
        BalanceConfig.coinsHintOrderedLetter,
        greaterThan(BalanceConfig.coinsHintRandomLetter),
        reason: 'الكشف المرتّب يختار الحرف المفيد، فهو أغلى',
      );
    });

    test('كلاهما قابل للضبط عن بعد', () {
      expect(BalanceOverrides.registry, contains('coinsHintOrderedLetter'));
      expect(BalanceOverrides.registry, contains('coinsHintRandomLetter'));
      expect(BalanceOverrides.registry, contains('coinsBonusWordMilestone'));
    });
  });
}
