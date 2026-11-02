import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/wheel/wheel_engine.dart';
import 'package:huruf/data/wheel/wheel_models.dart';

/// Random وهمي يعيد قيمة ثابتة من nextInt — لاختبار حدود التراكم بدقّة
/// بدل الاعتماد على عشوائية حقيقية
class _FixedRandom implements Random {
  final int value;
  const _FixedRandom(this.value);

  @override
  int nextInt(int max) => value;

  @override
  double nextDouble() => throw UnimplementedError();

  @override
  bool nextBool() => throw UnimplementedError();
}

void main() {
  // أوزان BalanceConfig.wheelSegments الفعلية: 22,20,18,14,12,8,4,2
  // (تجمع 100). حدود التراكم: [0,22) [22,42) [42,60) [60,74) [74,86)
  // [86,94) [94,98) [98,100)
  final segments = BalanceConfig.wheelSegments;

  group('WheelEngine.pickSegmentIndex — حدود التراكم بدقّة', () {
    final cases = {
      0: 0,
      21: 0,
      22: 1,
      41: 1,
      42: 2,
      59: 2,
      60: 3,
      73: 3,
      74: 4,
      85: 4,
      86: 5,
      93: 5,
      94: 6,
      97: 6,
      98: 7,
      99: 7,
    };

    cases.forEach((roll, expectedIndex) {
      test('roll=$roll يختار القطاع $expectedIndex', () {
        expect(WheelEngine.pickSegmentIndex(segments, _FixedRandom(roll)),
            expectedIndex);
      });
    });
  });

  test('توزيع إحصائي عبر 100000 محاولة يطابق الأوزان تقريبا (هامش 3%)', () {
    final counts = List<int>.filled(segments.length, 0);
    final rng = Random(1234); // بذرة ثابتة — نتيجة حتمية عبر التشغيلات
    const trials = 100000;
    for (var i = 0; i < trials; i++) {
      counts[WheelEngine.pickSegmentIndex(segments, rng)]++;
    }
    final totalWeight = segments.fold<int>(0, (sum, s) => sum + s.weight);
    for (var i = 0; i < segments.length; i++) {
      final expectedFraction = segments[i].weight / totalWeight;
      final actualFraction = counts[i] / trials;
      expect((actualFraction - expectedFraction).abs(), lessThan(0.03),
          reason:
              'القطاع $i: متوقَّع ${(expectedFraction * 100).toStringAsFixed(1)}%'
              '، فعلي ${(actualFraction * 100).toStringAsFixed(1)}%');
    }
  });

  test('يعمل بأوزان مخصّصة لا تجمع إلى 100 — يُقسَم دوما على المجموع الفعلي', () {
    const custom = [
      WheelSegmentDef(type: WheelPrizeType.coins, value: 5, weight: 1),
      WheelSegmentDef(type: WheelPrizeType.coins, value: 10, weight: 1),
    ];
    expect(WheelEngine.pickSegmentIndex(custom, _FixedRandom(0)), 0);
    expect(WheelEngine.pickSegmentIndex(custom, _FixedRandom(1)), 1);
  });
}
