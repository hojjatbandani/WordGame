// صندوق الفصل يدفع فعلا، ومضاعفة الجائزة بمشاهدة تُستهلك من ميزانية
// اليوم مرة واحدة — الرقمان اللذان يراهما اللاعب في محفظته.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/ads/ad_format.dart';
import 'package:huruf/data/ads/ad_policy.dart';
import 'package:huruf/data/ads/rewarded_ads.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// آليات المضاعفة كما ستعمل يوم يُعاد تفعيل الإعلان الجائزي. سياسة هذا
/// البناء نفسها (الجائزي مطفأ) مثبّتة في test/ads/ad_policy_test.dart.
const _rewardedEnabled = AdFormatPolicy({AdFormat.rewardedInterstitial});

/// «شوهد الإعلان واستُحقّت مكافأته» — المنح لا يقع إلا بـtrue صريح
Future<bool> _watched(AdLength _) async => true;

Future<ProviderContainer> _container({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  final store = ProgressStore(sharedPrefs);
  final progression = await ProgressionRepository.load(
    prefs: sharedPrefs,
    legacy: store,
  );
  final container = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      progressionRepositoryProvider.overrideWithValue(progression),
      adFormatPolicyProvider.overrideWithValue(_rewardedEnabled),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// يُكمل كل مراحل الفصل الأول كي يصير صندوقه قابلا للاستلام
void _completeChapterOne(ProgressionRepository repo) {
  final chapter = repo.structure.chapterById(1);
  for (var id = chapter.stageStart; id <= chapter.stageEnd; id++) {
    repo.recordStageCompletion(
      stageId: id,
      bonusWordsFoundThisRun: const {},
      hintsUsedThisRun: 1,
      timeMs: 30000,
      now: DateTime(2026, 1, 1),
    );
  }
}

void main() {
  group('صندوق الفصل', () {
    test('الاستلام يمنح عملات ضمن مدى الصندوق المعلن', () async {
      final c = await _container();
      _completeChapterOne(c.read(progressionRepositoryProvider));
      final before = c.read(pointsProvider);

      final coins = await c
          .read(progressionProvider.notifier)
          .claimChapterChest(1);

      expect(coins, BalanceConfig.coinsChapterChest);
      expect(c.read(pointsProvider), before + coins);
    });

    test('الاستلام الثاني لا يمنح شيئا — صندوق واحد لكل فصل', () async {
      final c = await _container();
      _completeChapterOne(c.read(progressionRepositoryProvider));
      final notifier = c.read(progressionProvider.notifier);

      final first = await notifier.claimChapterChest(1);
      expect(first, greaterThan(0));
      final balanceAfterFirst = c.read(pointsProvider);

      expect(await notifier.claimChapterChest(1), 0);
      expect(c.read(pointsProvider), balanceAfterFirst);
    });

    test('فصل غير مكتمل: لا استلام ولا عملات', () async {
      final c = await _container();
      final before = c.read(pointsProvider);
      expect(await c.read(progressionProvider.notifier).claimChapterChest(1), 0);
      expect(c.read(pointsProvider), before, reason: 'لا عملة تتحرّك');
    });
  });

  group('مضاعفة الجائزة بمشاهدة', () {
    test('المشاهدة تضيف المبلغ كاملا، وتستهلك مشاهدة واحدة', () async {
      // الزرّ يقول «×2» فيجب أن يعطي ×2 بالضبط. كانت نسبة (0.75)
      // بسقف (15) — جائزة 16 تصير 28 لا 32 — راجع
      // BalanceConfig.adDoubleBonusFor لسبب إسقاطهما
      final c = await _container();
      final before = c.read(pointsProvider);
      final viewsBefore = c.read(rewardedAdsProvider).viewsUsed;

      final granted = await c
          .read(rewardedAdsProvider.notifier)
          .doubleReward(40, surface: RewardedSurface.other, playAd: _watched);

      expect(granted, 40, reason: 'ضعف حرفي لا حصّة');
      expect(c.read(pointsProvider), before + 40);
      expect(c.read(rewardedAdsProvider).viewsUsed, viewsBefore + 1);
    });

    test('لا سقف يقصّ المبلغ الكبير — الصندوق يتضاعف كالمرحلة', () async {
      // بلا تأكيد على رصيد المحفظة هنا: مبلغ بهذا الحجم يتخطّى عتبة
      // إنجاز «النقاط المكتسبة» فيدفع الإنجازُ مكافأته فوقه، وذلك سلوك
      // آخر يخصّه اختباره. المقيس هنا هو ما تعيده المضاعفة وحدها.
      final c = await _container();
      final granted = await c
          .read(rewardedAdsProvider.notifier)
          .doubleReward(1000, surface: RewardedSurface.other, playAd: _watched);

      expect(granted, 1000, reason: 'السقف القديم كان يقصّها إلى 15');
    });

    test('كل جائزة مرحلة ممكنة تتضاعف تماما — لا رقم يُخلف الوعد', () {
      // هذا هو الاختبار الذي كان سيمنع الخلل أصلا: أي جائزة يمكن أن
      // تظهر على شاشة الإتمام يجب أن يعطي زرّ «×2» مثلها بالضبط
      for (var reward = BalanceConfig.minCoinsPerStage;
          reward <= BalanceConfig.maxCoinsPerStage;
          reward++) {
        expect(
          BalanceConfig.adDoubleBonusFor(reward),
          reward,
          reason: 'جائزة $reward',
        );
      }
    });

    test('صندوق الفصل يتضاعف تماما كذلك', () {
      expect(
        BalanceConfig.adDoubleBonusFor(BalanceConfig.coinsChapterChest),
        BalanceConfig.coinsChapterChest,
      );
    });

    test('المضاعفة لا تمرّ بمضاعف الشراء الأول مرة ثانية', () async {
      // المبلغ الممرَّر هو ما دخل المحفظة فعلا (مضروبا بالمضاعف سلفا)،
      // فإعادة ضربه هنا كانت تعطي صاحب المضاعف أكثر من الضعف
      final c = await _container();
      addTearDown(() => BalanceConfig.firstPurchaseCoinMultiplier = 1.0);
      BalanceConfig.firstPurchaseCoinMultiplier = 2.0;

      final before = c.read(pointsProvider);
      final granted = await c
          .read(rewardedAdsProvider.notifier)
          .doubleReward(16, surface: RewardedSurface.levelReward, playAd: _watched);

      expect(granted, 16);
      expect(c.read(pointsProvider), before + 16);
    });

    test('لا مضاعفة بمبلغ صفري — لا تُهدر مشاهدة على لا شيء', () async {
      final c = await _container();
      final viewsBefore = c.read(rewardedAdsProvider).viewsUsed;
      expect(await c.read(rewardedAdsProvider.notifier).doubleReward(0, playAd: _watched), 0);
      expect(c.read(rewardedAdsProvider).viewsUsed, viewsBefore);
    });

    test('نفاد ميزانية اليوم يمنع المضاعفة ولا يمنح شيئا', () async {
      final c = await _container();
      final rewarded = c.read(rewardedAdsProvider.notifier);
      // نستهلك كل ميزانية اليوم
      for (var i = 0; i < BalanceConfig.rewardedDailyBudget; i++) {
        await rewarded.doubleReward(10, playAd: _watched);
      }
      final before = c.read(pointsProvider);
      expect(await rewarded.doubleReward(10, playAd: _watched), 0);
      expect(c.read(pointsProvider), before);
    });
  });
}
