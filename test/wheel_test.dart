import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/wheel/wheel_models.dart';
import 'package:huruf/data/ads/ad_policy.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// آليات الإعلان كما ستعمل يوم يُعاد تفعيل القالب. سياسة هذا البناء نفسها
/// (كل القوالب مطفأة) مثبّتة في test/ads/ad_policy_test.dart.
const _adsEnabledForMechanics = AdFormatPolicy({AdFormat.rewardedInterstitial});

Future<ProviderContainer> _container(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await ProgressStore.create();
  return ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      adFormatPolicyProvider.overrideWithValue(_adsEnabledForMechanics),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fresh day offers a free spin', () async {
    final c = await _container({});
    expect(c.read(wheelProvider).freeSpinAvailable, isTrue);
    expect(c.read(wheelProvider).canSpinNow, isTrue);
  });

  test('free spin is consumed once, then only ad spins remain', () async {
    final c = await _container({});
    final notifier = c.read(wheelProvider.notifier);

    expect(notifier.consumeSpin(viaAd: false), isTrue);
    expect(c.read(wheelProvider).freeSpinAvailable, isFalse);
    // لا دورة مجانية ثانية في نفس اليوم
    expect(notifier.consumeSpin(viaAd: false), isFalse);
  });

  test('ad spins are capped per day', () async {
    final c = await _container({});
    final notifier = c.read(wheelProvider.notifier);
    for (var i = 0; i < WheelState.maxAdSpinsPerDay; i++) {
      expect(notifier.consumeSpin(viaAd: true), isTrue);
    }
    expect(notifier.consumeSpin(viaAd: true), isFalse);
    expect(c.read(wheelProvider).adSpinsRemaining, 0);
  });

  test('grantPrize adds the segment prize to points for a coins segment',
      () async {
    final c = await _container({});
    final before = c.read(pointsProvider);
    // الفهرس 5 = عملات 100 حاليا (راجع BalanceConfig.wheelSegments)
    final segment = BalanceConfig.wheelSegments[5];
    expect(segment.type, WheelPrizeType.coins);
    c.read(wheelProvider.notifier).grantPrize(5);
    expect(c.read(pointsProvider), before + segment.value);
  });

  test('grantPrize لقطاع شحنة تلميح يُضاف إلى الرصيد المصرفي لا النقاط',
      () async {
    final c = await _container({});
    final pointsBefore = c.read(pointsProvider);
    final index =
        BalanceConfig.wheelSegments.indexWhere((s) => s.type == WheelPrizeType.hintCharge);
    c.read(wheelProvider.notifier).grantPrize(index);
    expect(c.read(pointsProvider), pointsBefore); // لا تغيير في النقاط
    // الشحنات في محفظة نظام التقدّم — دفتر واحد للعملات والشحنات معا
    expect(c.read(progressionRepositoryProvider).state.wallet.hintCharges, 1);
  });

  test('a new day resets the free spin and the ad spins', () async {
    final c = await _container({
      'wheel_date': '2020-01-01',
      'wheel_free_used': true,
      'wheel_ad_date': '2020-01-01',
      'wheel_ad_spins_used': 3,
    });
    // بما أن التاريخ المخزّن قديم، يجب أن تعود الدورة المجانية
    expect(c.read(wheelProvider).freeSpinAvailable, isTrue);
    expect(c.read(wheelProvider).adSpinsRemaining, WheelState.maxAdSpinsPerDay);
  });

  test('بعد الدورة المجانية: ثلاث دورات بإعلان بالضبط', () async {
    final c = await _container({});
    final notifier = c.read(wheelProvider.notifier);
    expect(WheelState.maxAdSpinsPerDay, 3);

    expect(notifier.consumeSpin(viaAd: false), isTrue);
    for (var left = 3; left > 0; left--) {
      expect(c.read(wheelProvider).adSpinsRemaining, left);
      expect(notifier.consumeSpin(viaAd: true), isTrue);
    }
    expect(c.read(wheelProvider).adSpinsRemaining, 0);
    expect(c.read(wheelProvider).canSpinNow, isFalse);
    expect(notifier.consumeSpin(viaAd: true), isFalse);
  });

  test('دورات العجلة لا تأكل من ميزانية إعلانات العملات ولا تأكل تلك منها',
      () async {
    final c = await _container({});
    final wheel = c.read(wheelProvider.notifier);
    for (var i = 0; i < WheelState.maxAdSpinsPerDay; i++) {
      expect(wheel.consumeSpin(viaAd: true), isTrue);
    }
    expect(c.read(rewardedAdsProvider).viewsUsed, 0);
    expect(
      c.read(globalAdBudgetProvider).remaining,
      BalanceConfig.rewardedDailyBudget,
    );

    // ميزانية العملات نفدت في سطح آخر: دورات العجلة في يوم جديد كاملة
    final fresh = await _container({});
    final budget = fresh.read(globalAdBudgetProvider.notifier);
    while (budget.consume()) {}
    expect(fresh.read(globalAdBudgetProvider).remaining, 0);
    expect(
      fresh.read(wheelProvider).adSpinsRemaining,
      WheelState.maxAdSpinsPerDay,
    );
    expect(fresh.read(wheelProvider.notifier).consumeSpin(viaAd: true), isTrue);
  });

  test('عدّاد اليوم محفوظ: إعادة فتح التطبيق لا تعيد الدورات', () async {
    final c = await _container({});
    c.read(wheelProvider.notifier).consumeSpin(viaAd: true);
    c.read(wheelProvider.notifier).consumeSpin(viaAd: true);

    final store = c.read(progressStoreProvider);
    final reopened = ProviderContainer(
      overrides: [
        progressStoreProvider.overrideWithValue(store),
        adFormatPolicyProvider.overrideWithValue(_adsEnabledForMechanics),
      ],
    );
    expect(reopened.read(wheelProvider).adSpinsRemaining, 1);
  });
}
