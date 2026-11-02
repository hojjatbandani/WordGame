import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/progression/jar_rewards.dart';

void main() {
  group('JarRewards.newlyReachedTiers', () {
    test('لا شيء قبل بلوغ العتبة', () {
      final result = JarRewards.newlyReachedTiers(
          worldId: 1, jarProgress: 39, tier1Threshold: 40, claimedTier: 0);
      expect(result, isEmpty);
    });

    test('الطبقة الأولى تُمنح فور بلوغ العتبة بالضبط', () {
      final result = JarRewards.newlyReachedTiers(
          worldId: 1, jarProgress: 40, tier1Threshold: 40, claimedTier: 0);
      expect(result, hasLength(1));
      expect(result.first.tier, 1);
      expect(result.first.coins, 150);
      expect(result.first.cosmeticRewardId, 'jar_tier1_world_1');
    });

    test('لا تُمنح الطبقة الأولى مرتين', () {
      final result = JarRewards.newlyReachedTiers(
          worldId: 1, jarProgress: 50, tier1Threshold: 40, claimedTier: 1);
      expect(result, isEmpty);
    });

    test('الطبقة الثانية عند 150% من العتبة بالضبط (40 → 60)', () {
      final below = JarRewards.newlyReachedTiers(
          worldId: 1, jarProgress: 59, tier1Threshold: 40, claimedTier: 1);
      expect(below, isEmpty);

      final at = JarRewards.newlyReachedTiers(
          worldId: 1, jarProgress: 60, tier1Threshold: 40, claimedTier: 1);
      expect(at, hasLength(1));
      expect(at.first.tier, 2);
      expect(at.first.coins, 225);
      expect(at.first.cosmeticRewardId, 'jar_tier2_world_1');
    });

    test('قفزة واحدة تتجاوز العتبتين معا تمنح الطبقتين دفعة واحدة', () {
      final result = JarRewards.newlyReachedTiers(
          worldId: 3, jarProgress: 80, tier1Threshold: 40, claimedTier: 0);
      expect(result.map((r) => r.tier), [1, 2]);
    });

    test('عالم مختلف ينتج معرّف عنصر زخرفي مختلفا', () {
      final w1 = JarRewards.newlyReachedTiers(
          worldId: 1, jarProgress: 40, tier1Threshold: 40, claimedTier: 0);
      final w8 = JarRewards.newlyReachedTiers(
          worldId: 8, jarProgress: 180, tier1Threshold: 180, claimedTier: 0);
      expect(w1.first.cosmeticRewardId, isNot(w8.first.cosmeticRewardId));
    });
  });

  test('الجرّة تستمر بالعدّ فوق العتبة دون أي قصّ (لا سلوك خاص هنا، توثيق فقط)',
      () {
    // jarProgress نفسها لا تُقصّ في progression_engine.dart — هذا الاختبار
    // يوثّق أن newlyReachedTiers تتعامل بأمان مع قيم أعلى من الطبقتين معا
    final result = JarRewards.newlyReachedTiers(
        worldId: 1, jarProgress: 1000, tier1Threshold: 40, claimedTier: 2);
    expect(result, isEmpty); // كلتا الطبقتين مُطالَب بهما فعلا
  });
}
