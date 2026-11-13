// المحاولة الفاشلة للإنفاق حدث مستقل: لو سُجّلت coins_spent لتضخّم مجموع
// ما «أُنفق» بعملات لم تخرج من المحفظة قط.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/analytics/analytics_event.dart';
import 'package:huruf/data/analytics/analytics_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('failed spend logs coins_spend_failed and no coins_spent', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore(await SharedPreferences.getInstance());
    final seen = <AnalyticsEvent>[];
    final container = ProviderContainer(
      overrides: [
        progressStoreProvider.overrideWithValue(store),
        analyticsProvider.overrideWithValue(AnalyticsService(sink: seen.add)),
      ],
    );
    addTearDown(container.dispose);

    final ok = container
        .read(pointsProvider.notifier)
        .spend(1000000, reason: 'hint');

    expect(ok, isFalse);
    expect(seen.map((e) => e.name), contains(Ev.coinsSpendFailed));
    expect(seen.map((e) => e.name), isNot(contains(Ev.coinsSpent)));
  });
}
