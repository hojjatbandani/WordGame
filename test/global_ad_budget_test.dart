import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('يوم جديد يمنح الميزانية كاملة', () async {
    final c = await _container({});
    expect(c.read(globalAdBudgetProvider).remaining,
        BalanceConfig.globalDailyAdBudget);
    expect(c.read(globalAdBudgetProvider).hasRemaining, isTrue);
  });

  test('الاستهلاك يخصم واحدا في كل مرة حتى النفاد بالضبط', () async {
    final c = await _container({});
    final notifier = c.read(globalAdBudgetProvider.notifier);
    for (var i = 0; i < BalanceConfig.globalDailyAdBudget; i++) {
      expect(notifier.consume(), isTrue);
    }
    expect(notifier.consume(), isFalse);
    expect(c.read(globalAdBudgetProvider).remaining, 0);
    expect(c.read(globalAdBudgetProvider).hasRemaining, isFalse);
  });

  test('تاريخ قديم محفوظ يُعاد ضبطه بميزانية كاملة', () async {
    final c = await _container({
      'global_ad_budget_date': '2020-01-01',
      'global_ad_budget_used': BalanceConfig.globalDailyAdBudget,
    });
    expect(c.read(globalAdBudgetProvider).remaining,
        BalanceConfig.globalDailyAdBudget);
  });

  test('الميزانية مشتركة فعلا: استهلاك واحد يظهر لأي قارئ آخر لنفس المزوّد',
      () async {
    final c = await _container({});
    final notifier = c.read(globalAdBudgetProvider.notifier);
    notifier.consume();
    // قراءة مستقلة عبر نفس الحاوية — تعكس نفس الاستهلاك، لا نسخة منفصلة
    expect(c.read(globalAdBudgetProvider).usedToday, 1);
  });
}
