// ما يُرسَل إلى PostHog يعبر قناة المنصّة ثم JSON: قيمة لا تعبرها (NaN،
// كائن غير معروف) تُسقِط الحدث كله بصمت في الخلفية ولا يظهر خطؤه في
// اللعبة — فالاختبار هو الحارس.

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/analytics/analytics_event.dart';
import 'package:huruf/data/analytics/posthog_sink.dart';

AnalyticsEvent _event({
  Map<String, Object?> properties = const {},
  int? playerLevel,
  int? stageId,
  int? coinBalance,
}) => AnalyticsEvent(
  name: Ev.stageStart,
  properties: properties,
  playerLevel: playerLevel,
  stageId: stageId,
  coinBalance: coinBalance,
);

void main() {
  test('أسماء أحداث التطبيق لا تبدأ بـ\$ (محجوزة لأحداث PostHog)', () {
    for (final name in Ev.all) {
      expect(name.startsWith(r'$'), isFalse, reason: name);
    }
  });

  group('propertiesFor', () {
    test('السياق أولا ثم الخصائص، والفارغ يُسقَط', () {
      final params = PostHogSink.propertiesFor(
        _event(
          playerLevel: 7,
          coinBalance: 120,
          properties: {'surface': 'wheel', 'reward': 20, 'skipped': null},
        ),
      );
      expect(params, {
        'player_level': 7,
        'coin_balance': 120,
        'surface': 'wheel',
        'reward': 20,
      });
      expect(params.keys.first, 'player_level');
    });

    test('البولياني والقوائم تبقى، وغير المنتهي يُسقَط، والكائن يصير نصّا', () {
      final params = PostHogSink.propertiesFor(
        _event(
          properties: {
            'from_offer': true,
            'ratio': 0.5,
            'bad': double.nan,
            'inf': double.infinity,
            'ids': [1, double.nan, null, 'x'],
            'nested': {'a': 1, 'b': null},
            'when': Duration.zero,
          },
        ),
      );
      expect(params['from_offer'], true);
      expect(params['ratio'], 0.5);
      expect(params, isNot(contains('bad')));
      expect(params, isNot(contains('inf')));
      expect(params['ids'], [1, 'x']);
      expect(params['nested'], {'a': 1});
      expect(params['when'], '${Duration.zero}');
    });
  });
}
