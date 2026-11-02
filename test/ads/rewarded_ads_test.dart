import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/ads/rewarded_ads.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/ads/ad_policy.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// آليات الإعلان كما ستعمل يوم يُعاد تفعيل القالب. سياسة هذا البناء نفسها
/// (كل القوالب مطفأة) مثبّتة في test/ads/ad_policy_test.dart.
const _adsEnabledForMechanics = AdFormatPolicy({AdFormat.rewardedInterstitial});

final _day = DateTime(2026, 8, 26, 12);

RewardedAdRequest _req(String id, int amount, {int viewNumber = 1}) =>
    RewardedAdRequest(
      id: id,
      quotedAmount: amount,
      surface: RewardedSurface.coinTopUp,
      viewNumber: viewNumber,
    );

Future<ProviderContainer> _container([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = ProgressStore(await SharedPreferences.getInstance());
  return ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      adFormatPolicyProvider.overrideWithValue(_adsEnabledForMechanics),
    ],
  );
}

void main() {
  group('سلّم المكافأة المتصاعد', () {
    test('20 ثم 30 ثم 40 ثم 50', () {
      expect(BalanceConfig.rewardedRewardForView(1), 20);
      expect(BalanceConfig.rewardedRewardForView(2), 30);
      expect(BalanceConfig.rewardedRewardForView(3), 40);
      expect(BalanceConfig.rewardedRewardForView(4), 50);
    });

    test('ما بعد آخر درجة يبقى عند آخرها بدل أن يرمي', () {
      expect(BalanceConfig.rewardedRewardForView(9), 50);
    });

    test('رقم مشاهدة غير صالح خطأ برمجي لا قيمة صامتة', () {
      expect(() => BalanceConfig.rewardedRewardForView(0), throwsArgumentError);
    });

    test('الدفتر يعرض مكافأة المشاهدة التالية قبل بدئها', () {
      var ledger = RewardedLedger.empty('2026-08-26');
      final amounts = <int>[];
      for (var i = 0; i < BalanceConfig.rewardedDailyBudget; i++) {
        amounts.add(ledger.nextReward);
        ledger = RewardedAds.onAdCompleted(
          ledger: ledger,
          request: _req('r$i', ledger.nextReward),
          now: _day,
        );
      }
      expect(amounts, [20, 30, 40, 50]);
    });
  });

  group('الميزانية اليومية المشتركة', () {
    test('أربع مشاهدات ثم لا شيء', () {
      var ledger = RewardedLedger.empty('2026-08-26');
      for (var i = 0; i < 4; i++) {
        final request = RewardedAds.beginRequest(
          ledger: ledger,
          surface: RewardedSurface.wheel,
          requestId: 'r$i',
        );
        expect(request, isNotNull, reason: 'المشاهدة ${i + 1}');
        ledger = RewardedAds.onAdCompleted(
          ledger: ledger,
          request: request!,
          now: _day,
        );
      }
      expect(
        RewardedAds.beginRequest(
          ledger: ledger,
          surface: RewardedSurface.wheel,
          requestId: 'r5',
        ),
        isNull,
      );
      expect(ledger.remaining, 0);
    });

    test('طلب لم يكتمل لا يحرق ميزانية — الاستهلاك عند الاكتمال', () {
      final ledger = RewardedLedger.empty('2026-08-26');
      RewardedAds.beginRequest(
        ledger: ledger,
        surface: RewardedSurface.wheel,
        requestId: 'x',
      );
      expect(ledger.viewsUsed, 0);
      expect(ledger.remaining, BalanceConfig.rewardedDailyBudget);
    });

    test('المفتاح المطفأ يمنع الطلب أصلا', () {
      expect(
        RewardedAds.beginRequest(
          ledger: RewardedLedger.empty('2026-08-26'),
          surface: RewardedSurface.wheel,
          requestId: 'x',
          rewardedEnabled: false,
        ),
        isNull,
      );
    });

    test('يوم جديد يعيد الميزانية لا سجلّ المعرّفات', () {
      var ledger = RewardedLedger.empty('2026-08-25');
      ledger = RewardedAds.onAdCompleted(
        ledger: ledger,
        request: _req('old', 20),
        now: _day,
      );
      ledger = RewardedAds.flushQueue(ledger).ledger;

      final rolled = RewardedAds.rollOver(
        ledger,
        _day.add(const Duration(days: 1)),
      );
      expect(rolled.viewsUsed, 0, reason: 'ميزانية جديدة');
      expect(
        rolled.hasGranted('old'),
        isTrue,
        reason: 'سجلّ المعرّفات لا يُمسح مع اليوم',
      );
    });
  });

  group('اختبار القبول: المنح مرة واحدة بالضبط رغم تكرار النداء', () {
    test('نداءان لنفس الطلب = مشاهدة واحدة ومنحة واحدة', () {
      var ledger = RewardedLedger.empty('2026-08-26');
      final request = _req('dup', 20);

      ledger = RewardedAds.onAdCompleted(
        ledger: ledger,
        request: request,
        now: _day,
      );
      ledger = RewardedAds.onAdCompleted(
        ledger: ledger,
        request: request,
        now: _day,
      );
      ledger = RewardedAds.onAdCompleted(
        ledger: ledger,
        request: request,
        now: _day,
      );

      expect(ledger.viewsUsed, 1);
      expect(ledger.queue, hasLength(1));
      expect(RewardedAds.flushQueue(ledger).coins, 20);
    });

    test('عبر المزوّد: النداء المكرّر يعيد صفرا ولا يزيد الرصيد', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);
      final notifier = container.read(rewardedAdsProvider.notifier);

      final request = notifier.begin(RewardedSurface.coinTopUp)!;
      expect(notifier.complete(request), request.quotedAmount);
      expect(notifier.complete(request), 0, reason: 'نداء مكرّر');
      expect(notifier.complete(request), 0);

      expect(container.read(pointsProvider), request.quotedAmount);
      expect(container.read(rewardedAdsProvider).viewsUsed, 1);
    });

    test('نداء مكرّر بعد منتصف الليل لا يمنح ثانية', () {
      var ledger = RewardedLedger.empty('2026-08-26');
      final request = _req('late', 20);
      ledger = RewardedAds.onAdCompleted(
        ledger: ledger,
        request: request,
        now: _day,
      );
      ledger = RewardedAds.flushQueue(ledger).ledger;

      // النداءة المكرّرة تصل بعد تغيّر اليوم
      final tomorrow = _day.add(const Duration(days: 1));
      ledger = RewardedAds.onAdCompleted(
        ledger: ledger,
        request: request,
        now: tomorrow,
      );

      expect(ledger.queue, isEmpty, reason: 'لا منحة ثانية');
      expect(ledger.viewsUsed, 0, reason: 'ولا استهلاك ميزانية اليوم الجديد');
    });
  });

  group('اختبار القبول: المنحة تنجو من إغلاق التطبيق', () {
    test('ما اكتمل ولم يُضَف يبقى في الطابور ويُضاف عند الإقلاع', () async {
      // جلسة أولى: اكتمل الإعلان وحُفظ الدفتر ثم أُغلق التطبيق قبل
      // التفريغ
      var ledger = RewardedLedger.empty('2026-08-26');
      ledger = RewardedAds.onAdCompleted(
        ledger: ledger,
        request: _req('crash', 30),
        now: _day,
      );
      final saved = ledger.encode();

      // جلسة ثانية: نقرأ الدفتر من التخزين ونفرّغ
      final container = await _container({
        'points': 0,
        'rewarded_ledger_json': saved,
      });
      addTearDown(container.dispose);

      expect(container.read(rewardedAdsProvider).queue, hasLength(1));
      final reconciled = container.read(rewardedAdsProvider.notifier).flush();

      expect(reconciled, 30);
      expect(container.read(pointsProvider), 30);
      expect(container.read(rewardedAdsProvider).queue, isEmpty);
    });

    test('التفريغ مرتين لا يضاعف', () async {
      var ledger = RewardedLedger.empty('2026-08-26');
      ledger = RewardedAds.onAdCompleted(
        ledger: ledger,
        request: _req('once', 40),
        now: _day,
      );
      final container = await _container({
        'points': 0,
        'rewarded_ledger_json': ledger.encode(),
      });
      addTearDown(container.dispose);
      final notifier = container.read(rewardedAdsProvider.notifier);

      expect(notifier.flush(), 40);
      expect(notifier.flush(), 0);
      expect(container.read(pointsProvider), 40);
    });

    test('دفتر تالف لا يمنع اللعب', () {
      final ledger = RewardedLedger.decode('{{{ ليس JSON', '2026-08-26');
      expect(ledger.viewsUsed, 0);
      expect(ledger.hasRemaining, isTrue);
    });

    test('الترميز وفكّه يحفظان كل شيء', () {
      var ledger = RewardedLedger.empty('2026-08-26');
      ledger = RewardedAds.onAdCompleted(
        ledger: ledger,
        request: _req('a', 20),
        now: _day,
      );
      final decoded = RewardedLedger.decode(ledger.encode(), '2026-08-26');

      expect(decoded.date, ledger.date);
      expect(decoded.viewsUsed, ledger.viewsUsed);
      expect(decoded.grantedRequestIds, ledger.grantedRequestIds);
      expect(decoded.queue.single.amount, 20);
    });
  });

  test('بطاقة المتجر: مبلغ ثابت خارج السلّم', () {
    final request = RewardedAds.beginRequest(
      ledger: RewardedLedger.empty('2026-08-26'),
      surface: RewardedSurface.coinTopUp,
      requestId: 'shop',
      amount: BalanceConfig.shopAdRewardCoins,
    )!;
    expect(request.quotedAmount, 70);
  });

  group('المبلغ المدفوع هو المبلغ المعروض', () {
    test('حتى لو تغيّر موضع السلّم بين العرض والاكتمال', () {
      var ledger = RewardedLedger.empty('2026-08-26');
      // عُرض 20 للمشاهدة الأولى
      final first = _req('first', ledger.nextReward);
      // ثم اكتملت مشاهدة أخرى قبلها فصار السلّم عند 30
      ledger = RewardedAds.onAdCompleted(
        ledger: ledger,
        request: _req('other', 20),
        now: _day,
      );
      // تكتمل الأولى الآن: تُدفع بمبلغها المعروض 20 لا بـ30
      ledger = RewardedAds.onAdCompleted(
        ledger: ledger,
        request: first,
        now: _day,
      );

      final amounts = [for (final g in ledger.queue) g.amount];
      expect(amounts, [20, 20]);
    });
  });

  group('السطوح تتشارك ميزانية واحدة فعلا', () {
    test('دورة عجلة بإعلان تستهلك من نفس الأربعة', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);

      expect(
        container.read(globalAdBudgetProvider).remaining,
        BalanceConfig.rewardedDailyBudget,
      );

      // سطح لا يمنح عملات (العجلة)
      expect(container.read(globalAdBudgetProvider.notifier).consume(), isTrue);
      expect(container.read(rewardedAdsProvider).viewsUsed, 1);
      expect(
        container.read(pointsProvider),
        0,
        reason: 'مكافأة العجلة هي الدورة لا العملات',
      );

      // ثم سطح يمنح عملات: هي المشاهدة الثانية لا الأولى
      final request = container
          .read(rewardedAdsProvider.notifier)
          .begin(RewardedSurface.coinTopUp)!;
      expect(request.viewNumber, 2);
      expect(request.quotedAmount, 30);
    });

    test('نفاد الميزانية يمنع كل السطوح', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);
      final budget = container.read(globalAdBudgetProvider.notifier);

      for (var i = 0; i < BalanceConfig.rewardedDailyBudget; i++) {
        expect(budget.consume(), isTrue);
      }
      expect(budget.consume(), isFalse);
      expect(
        container
            .read(rewardedAdsProvider.notifier)
            .begin(RewardedSurface.coinTopUp),
        isNull,
      );
    });
  });
}
