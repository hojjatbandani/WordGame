import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/iap_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await ProgressStore.create();
  return ProviderContainer(
    overrides: [progressStoreProvider.overrideWithValue(store)],
  );
}

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('package totals include bonus percent', () {
    final legend = pointsPackages.firstWhere((p) => p.id == 'points_legend');
    expect(legend.totalPoints, 15000);
    final small = pointsPackages.firstWhere((p) => p.id == 'points_small');
    expect(small.totalPoints, 500);
  });

  test('first daily claim gives day 1 and blocks same-day reclaim', () async {
    final c = await _container({});
    final before = c.read(pointsProvider);
    expect(c.read(dailyRewardProvider).canClaim, isTrue);
    expect(c.read(dailyRewardProvider).nextDay, 1);

    final reward = c.read(dailyRewardProvider.notifier).claim();
    expect(reward, dailyRewards[0]);
    expect(c.read(pointsProvider), before + dailyRewards[0]);
    expect(c.read(dailyRewardProvider).canClaim, isFalse);
    expect(c.read(dailyRewardProvider.notifier).claim(), isNull);
  });

  test('streak continues after yesterday, resets after a gap', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final continued = await _container({
      'daily_last_claim': _key(yesterday),
      'daily_streak_day': 3,
    });
    expect(continued.read(dailyRewardProvider).nextDay, 4);

    final gapped = await _container({
      'daily_last_claim': '2020-01-01',
      'daily_streak_day': 6,
    });
    expect(gapped.read(dailyRewardProvider).nextDay, 1);
  });

  test('day 7 wraps back to day 1', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final c = await _container({
      'daily_last_claim': _key(yesterday),
      'daily_streak_day': 7,
    });
    expect(c.read(dailyRewardProvider).nextDay, 1);
  });

  test('ad rewards are capped at 5 per day', () async {
    final c = await _container({});
    final notifier = c.read(adRewardProvider.notifier);
    for (var i = 0; i < AdRewardNotifier.maxPerDay; i++) {
      expect(notifier.grantReward(), AdRewardNotifier.reward);
    }
    expect(notifier.grantReward(), isNull);
    expect(c.read(adRewardProvider), AdRewardNotifier.maxPerDay);
  });
}
