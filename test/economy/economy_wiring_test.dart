// اختبارات «الوصل» لا اختبارات المحرّك: محرّك الاقتصاد كان مختبَرا
// بالكامل ومعزولا بالكامل في آن واحد — كل أرقام BalanceConfig تعمل في
// وحداتها ولا يمسّ منها اللعب رقما واحدا، لأن الرصيد الحيّ كان دفترا
// ثانيا (ProgressStore.points) لا علاقة له بـPlayerWallet.
//
// كل اختبار هنا يمرّ عبر المزوّدات كما تمرّ الشاشة تماما، فيفشل لو
// انفصل الطرفان ثانية.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = ProgressStore(await SharedPreferences.getInstance());
  final container = ProviderContainer(
    overrides: [progressStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

/// أول مرحلة في العالم [worldId] — تُشتق من البنية لا من رقم مكتوب،
/// فتبقى صحيحة لو تغيّرت أحجام العوالم في BalanceConfig
int _firstStageOfWorld(ProviderContainer c, int worldId) =>
    c.read(progressionStructureProvider).worldById(worldId).stageStart;

Future<int> _clear(
  ProviderContainer c,
  int stageId, {
  int coreWords = 3,
  int hints = 0,
}) async {
  final before = c.read(pointsProvider);
  await c
      .read(progressionProvider.notifier)
      .recordStageCompletion(
        stageId: stageId,
        bonusWordsFoundThisRun: const {},
        hintsUsedThisRun: hints,
        timeMs: 1000,
        coreWordsFound: coreWords,
      );
  return c.read(pointsProvider) - before;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('دفتر واحد للعملات', () {
    test('الرصيد الابتدائي من BalanceConfig.startingCoins', () async {
      final c = await _container();
      expect(c.read(pointsProvider), BalanceConfig.startingCoins);
      expect(
        c.read(progressionRepositoryProvider).state.wallet.coins,
        BalanceConfig.startingCoins,
        reason: 'المزوّد والمحفظة رقم واحد لا رقمان',
      );
    });

    test('كل كسب وإنفاق ينعكس في المحفظة نفسها', () async {
      final c = await _container();
      c.read(pointsProvider.notifier).add(50, reason: 'wheel');
      expect(
        c.read(progressionRepositoryProvider).state.wallet.coins,
        BalanceConfig.startingCoins + 50,
      );

      expect(c.read(pointsProvider.notifier).spend(30, reason: 'hint'), isTrue);
      expect(
        c.read(progressionRepositoryProvider).state.wallet.coins,
        BalanceConfig.startingCoins + 20,
      );
    });

    test('الإنفاق فوق الرصيد يفشل ولا يغيّر شيئا — لا رصيد سالب', () async {
      final c = await _container();
      final before = c.read(pointsProvider);
      expect(
        c.read(pointsProvider.notifier).spend(before + 1, reason: 'hint'),
        isFalse,
      );
      expect(c.read(pointsProvider), before);
    });

    test('الرصيد ينجو من إعادة تشغيل التطبيق', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ProgressStore(prefs);

      final first = ProviderContainer(
        overrides: [progressStoreProvider.overrideWithValue(store)],
      );
      first.read(pointsProvider.notifier).add(275, reason: 'wheel');
      await first.read(progressionRepositoryProvider).save();
      final expected = first.read(pointsProvider);
      first.dispose();

      // حاوية جديدة من نفس التخزين = إقلاع جديد
      final second = ProviderContainer(
        overrides: [progressStoreProvider.overrideWithValue(store)],
      );
      addTearDown(second.dispose);
      expect(second.read(pointsProvider), expected);
    });

    test(
      'رصيد لاعب قديم (مفتاح points) يُهاجَر إلى المحفظة مرة واحدة',
      () async {
        final c = await _container({'points': 4210});
        expect(c.read(pointsProvider), 4210);
      },
    );
  });

  group('مكافأة إتمام المرحلة تأتي من BalanceConfig', () {
    test('إتمام نظيف في العالم1: مرحلة + كلمات أساسية + إتقان', () async {
      final c = await _container();
      final gained = await _clear(c, 1, coreWords: 3);
      expect(
        gained,
        BalanceConfig.coinsStageClear +
            BalanceConfig.coinsPerCoreWord * 3 +
            BalanceConfig.coinsPerfectStageBonus,
      );
    });

    test('استخدام تلميح يُسقط مكافأة الإتقان وحدها', () async {
      final c = await _container();
      final withHints = await _clear(c, 1, coreWords: 3, hints: 2);
      final clean = await _clear(c, 2, coreWords: 3);
      expect(withHints, lessThan(clean), reason: 'الإتقان وحده هو الفارق');
      // 8 + 2×3 = 14، دون الأرضية، فتُكمَّل المرحلة إلى 16
      expect(withHints, BalanceConfig.minCoinsPerStage);
    });

    test('إعادة لعب مرحلة مكتملة تدفع صفرا (اختبار قبول)', () async {
      final c = await _container();
      await _clear(c, 1);
      expect(await _clear(c, 1), 0);
    });

    test('مضاعف كسب العالم8 (2.00) يُطبَّق فعلا على ما يقبضه اللاعب', () async {
      // السقف يُرفع هنا وحده: المطلوب قياس المضاعف، وبالسقف الفعلي (12)
      // يبتلع القصُّ فرقَ العالمين فيمرّ الاختبار حتى لو أُلغي المضاعف
      final cap = BalanceConfig.maxCoinsPerStage;
      addTearDown(() => BalanceConfig.maxCoinsPerStage = cap);
      BalanceConfig.maxCoinsPerStage = 1000;

      final c = await _container();
      final stageId = _firstStageOfWorld(c, 8);
      final gained = await _clear(c, stageId, coreWords: 3);
      final multiplier = BalanceConfig.coinEarningMultiplierForWorld(8);
      expect(
        gained,
        ((BalanceConfig.coinsStageClear * multiplier).round()) +
            ((BalanceConfig.coinsPerCoreWord * 3 * multiplier).round()) +
            ((BalanceConfig.coinsPerfectStageBonus * multiplier).round()),
      );
      expect(multiplier, greaterThan(1), reason: 'وإلا فالاختبار لا يفحص شيئا');
    });

    test('لا مرحلة تدفع فوق السقف مهما كبر المضاعف أو عدد الكلمات', () async {
      final c = await _container();
      // أسخى حالة ممكنة: العالم الأعلى مضاعفا، أكبر عدد كلمات، بلا تلميح
      final gained = await _clear(c, _firstStageOfWorld(c, 8), coreWords: 8);
      expect(gained, lessThanOrEqualTo(BalanceConfig.maxCoinsPerStage));
      expect(gained, greaterThanOrEqualTo(BalanceConfig.minCoinsPerStage));
      expect(
        BalanceConfig.minCoinsPerStage,
        16,
        reason: 'الأرضية المطلوبة: تبدأ المرحلة من 16 عملة',
      );
    });

    test('آخر مرحلة في الفصل تدفع مكافأة مرحلة عادية — لا مكافأة ثالثة', () {
      // مكافأة إتمام الفصل تعيش في الصندوق وحده (20–100). كانت المرحلة
      // الأخيرة تدفع فوقها 25+30، فيقبض اللاعب ثلاث مرات على حدث واحد.
      expect(BalanceConfig.coinsBossStageBonus, 0);
      expect(BalanceConfig.coinsChapterComplete, 0);
    });

    test('إتمام آخر مرحلة في الفصل = إتمام أي مرحلة أخرى فيه', () async {
      final c = await _container();
      final chapter = c.read(progressionStructureProvider).chapters.first;

      // مرحلة عادية من نفس الفصل، بنفس الشكل تماما
      final gainedOnOrdinary = await _clear(
        c,
        chapter.stageStart,
        coreWords: 3,
      );

      // بقية مراحل الفصل حتى ما قبل الأخيرة
      for (var id = chapter.stageStart + 1; id < chapter.stageEnd; id++) {
        await _clear(c, id);
      }
      final gainedOnBoss = await _clear(c, chapter.stageEnd, coreWords: 3);

      expect(
        gainedOnBoss,
        gainedOnOrdinary,
        reason: 'المرحلة الأخيرة لا تحمل أي علاوة فوق المرحلة العادية',
      );
      expect(
        gainedOnBoss,
        BalanceConfig.coinsStageClear +
            BalanceConfig.coinsPerCoreWord * 3 +
            BalanceConfig.coinsPerfectStageBonus,
      );
    });

    test(
      'عملات الكلمة الإضافية تُسعَّر من BalanceConfig لا برقم ثابت',
      () async {
        final c = await _container();
        final repo = c.read(progressionRepositoryProvider);
        expect(
          repo.runEconomy((economy) => economy.quoteBonusWordCoins(1)),
          BalanceConfig.coinsPerBonusWord,
        );
        expect(
          repo.runEconomy((economy) => economy.quoteBonusWordCoins(8)),
          (BalanceConfig.coinsPerBonusWord *
                  BalanceConfig.coinEarningMultiplierForWorld(8))
              .round(),
        );
      },
    );
  });

  group('لا شحنة تلميح مجانية بإتمام المراحل', () {
    test('إتمام مراحل كثيرة لا يمنح شحنة تلميح', () async {
      final c = await _container();
      for (var id = 1; id <= BalanceConfig.stagesPerFreeHintCharge * 2; id++) {
        await _clear(c, id);
      }
      expect(c.read(hintChargesProvider), 0);
    });
  });

  group('الضبط عن بعد يصل إلى اللعب فعلا', () {
    // تُلتقط القيم الحيّة لا أرقام مكتوبة هنا: نسخة سابقة كانت تستعيد
    // 15 و2 حرفيا، فلو تغيّرت في ملف التوازن تسرّبت القيمة القديمة إلى
    // كل اختبار يليها في نفس التشغيل
    late int stageClear;
    late int perCoreWord;
    late int cap;

    setUp(() {
      stageClear = BalanceConfig.coinsStageClear;
      perCoreWord = BalanceConfig.coinsPerCoreWord;
      cap = BalanceConfig.maxCoinsPerStage;
    });

    tearDown(() {
      BalanceConfig.coinsStageClear = stageClear;
      BalanceConfig.coinsPerCoreWord = perCoreWord;
      BalanceConfig.maxCoinsPerStage = cap;
    });

    test(
      'تغيير coinsStageClear يغيّر ما يقبضه اللاعب في المرحلة التالية',
      () async {
        final c = await _container();
        BalanceConfig.maxCoinsPerStage = 1000;
        BalanceConfig.coinsStageClear = 99;
        BalanceConfig.coinsPerCoreWord = 0;
        final gained = await _clear(c, 1, coreWords: 3);
        expect(gained, 99 + BalanceConfig.coinsPerfectStageBonus);
      },
    );

    test('تغيير maxCoinsPerStage يغيّر السقف فعلا', () async {
      final c = await _container();
      BalanceConfig.maxCoinsPerStage = 5;
      expect(await _clear(c, 1, coreWords: 8), 5);
    });
  });
}
