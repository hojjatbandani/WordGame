// خريطة طول الإعلان: النموذجان، والسطوح الخمسة التي تعرض فيديو.
//
// هذه الاختبارات تثبّت قرارا منتَجيا لا تفصيلا تقنيا: أي عرض يقع على
// اللاعب بلا طلب منه يبقى قصيرا، وأي عرض ذهب إليه هو مقابل مكسب يكون
// طويلا. تغيير أحدها يجب أن يُسقط اختبارا لا أن يمرّ صامتا.

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/ads/ad_format.dart';
import 'package:huruf/data/ads/rewarded_ads.dart';

void main() {
  group('السطوح الخمسة', () {
    test('١) بين المراحل: قصير', () {
      expect(AdFormats.betweenLevels, AdLength.short);
    });

    test('٢) مضاعفة جائزة نهاية المرحلة: قصير', () {
      expect(
        AdFormats.forSurface(RewardedSurface.levelReward),
        AdLength.short,
      );
    });

    test('٣) عجلة الحظ: طويل', () {
      expect(AdFormats.forSurface(RewardedSurface.wheel), AdLength.long);
    });

    test('٤) شحن العملات من المتجر: طويل', () {
      expect(AdFormats.forSurface(RewardedSurface.coinTopUp), AdLength.long);
    });

    test('٥) مضاعفة صندوق نهاية الفصل: طويل', () {
      expect(
        AdFormats.forSurface(RewardedSurface.chapterChest),
        AdLength.long,
      );
    });
  });

  group('المدد', () {
    test('كل سطح يعطي مدّة موجبة', () {
      for (final surface in RewardedSurface.values) {
        expect(
          AdFormats.forSurface(surface).duration,
          greaterThan(Duration.zero),
          reason: 'السطح ${surface.name} بلا مدّة',
        );
      }
      expect(AdFormats.betweenLevels.duration, greaterThan(Duration.zero));
    });

    test('الطويل أطول من القصير فعلا', () {
      expect(
        AdLength.long.duration,
        greaterThan(AdLength.short.duration),
      );
    });

    test('المدّة تتبع BalanceConfig لا قيمة مثبَّتة في الواجهة', () {
      final shortBefore = BalanceConfig.shortAdDuration;
      final longBefore = BalanceConfig.longAdDuration;
      addTearDown(() {
        BalanceConfig.shortAdDuration = shortBefore;
        BalanceConfig.longAdDuration = longBefore;
      });

      BalanceConfig.shortAdDuration = const Duration(seconds: 3);
      BalanceConfig.longAdDuration = const Duration(seconds: 25);
      expect(AdLength.short.duration, const Duration(seconds: 3));
      expect(AdLength.long.duration, const Duration(seconds: 25));
    });
  });

  test('سطح مجهول في محفوظ قديم يُفكّ إلى other فيأخذ الأقصر', () {
    final grant = PendingRewardGrant.fromJson({
      'id': 'x',
      'amount': 20,
      'surface': 'surface_from_a_future_build',
      'at': DateTime(2026, 8, 30).toIso8601String(),
    });
    expect(grant.surface, RewardedSurface.other);
    expect(AdFormats.forSurface(grant.surface), AdLength.short);
  });
}
