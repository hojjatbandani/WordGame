import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/ads/rewarded_ads.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/store/store_catalog.dart';
import 'package:huruf/data/login_calendar.dart';
import 'package:huruf/data/progress_store.dart';
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

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('كتالوج الحزم يطابق التسعير المعتمد', () {
    final packs = StoreCatalog.coinPacks;
    expect(packs.first.coins, 500);
    expect(packs.first.referenceUsd, 0.99);
    expect(packs.last.coins, 16000);
    expect(packs.last.referenceUsd, 14.99);
  });

  test('first daily claim gives position 1 and blocks same-day reclaim',
      () async {
    final c = await _container({});
    final before = c.read(pointsProvider);
    expect(c.read(dailyRewardProvider).canClaim, isTrue);
    expect(c.read(dailyRewardProvider).nextPosition, 1);

    final reward = c.read(dailyRewardProvider.notifier).claim();
    final expected = LoginCalendar.rewardForPosition(1);
    expect(reward!.coins, expected.coins);
    expect(c.read(pointsProvider), before + expected.coins);
    expect(c.read(dailyRewardProvider).canClaim, isFalse);
    expect(c.read(dailyRewardProvider.notifier).claim(), isNull);
  });

  test(
      'اختبار قبول: بلوغ الموضع 5 ثم فوات أيام كثيرة يستأنف عند الموضع 6، لا الصفر',
      () async {
    final continued = await _container({
      'daily_last_claim': _key(DateTime.now().subtract(const Duration(days: 1))),
      'daily_calendar_position': 5,
    });
    expect(continued.read(dailyRewardProvider).nextPosition, 6);

    // فوات طويل جدا (سنوات، لا يوم واحد) — الموضع يبقى كما هو تماما،
    // لا يُصفَّر أبدا؛ هذا هو الفرق الجوهري عن dailyStreakDay القديم
    final longGap = await _container({
      'daily_last_claim': '2020-01-01',
      'daily_calendar_position': 5,
    });
    expect(longGap.read(dailyRewardProvider).nextPosition, 6);
  });

  test('الهجرة من dailyStreakDay القديم: لاعب عائد يكمل من موضعه القديم لا من الصفر',
      () async {
    // لا daily_calendar_position محفوظ بعد، فقط المفتاح القديم
    final c = await _container({
      'daily_last_claim': _key(DateTime.now().subtract(const Duration(days: 1))),
      'daily_streak_day': 6,
    });
    expect(c.read(dailyRewardProvider).nextPosition, 7);
  });

  test('لا التفاف عند الموضع 7 — الموضع 8 يتابع التصاعد لا يعود لـ1', () async {
    final c = await _container({
      'daily_last_claim': _key(DateTime.now().subtract(const Duration(days: 1))),
      'daily_calendar_position': 7,
    });
    expect(c.read(dailyRewardProvider).nextPosition, 8);
  });

  test('مكافآت الإعلانات محدودة بميزانية اليوم المشتركة', () async {
    final c = await _container({});
    addTearDown(c.dispose);
    final rewarded = c.read(rewardedAdsProvider.notifier);
    final before = c.read(pointsProvider);

    var total = 0;
    for (var i = 0; i < BalanceConfig.rewardedDailyBudget; i++) {
      final request = rewarded.begin(RewardedSurface.coinTopUp);
      expect(request, isNotNull, reason: 'المشاهدة ${i + 1}');
      total += rewarded.complete(request!);
    }

    // 20+30+40+50 = 140 — السلّم المتصاعد كاملا
    expect(total, 140);
    expect(rewarded.begin(RewardedSurface.coinTopUp), isNull,
        reason: 'الميزانية نفدت');
    expect(c.read(pointsProvider), before + total);
  });
}
