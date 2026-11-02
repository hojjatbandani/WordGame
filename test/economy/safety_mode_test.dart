import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/economy/safety_mode.dart';

void main() {
  group('وضع الأمان (أرضية العملات)', () {
    test('لا يُفعَّل عند coins=19 مع صفر محاولات فاشلة (اختبار قبول)', () {
      expect(
        SafetyMode.shouldTrigger(
            coins: 19, failedOrAbandonedAttemptsThisStage: 0),
        isFalse,
      );
    });

    test('لا يُفعَّل عند رصيد كافٍ حتى مع محاولات فاشلة كثيرة', () {
      expect(
        SafetyMode.shouldTrigger(
            coins: 500, failedOrAbandonedAttemptsThisStage: 10),
        isFalse,
      );
    });

    test('يُفعَّل فقط حين يجتمع الشرطان: رصيد منخفض ومحاولات فاشلة كافية',
        () {
      expect(
        SafetyMode.shouldTrigger(
            coins: 19, failedOrAbandonedAttemptsThisStage: 2),
        isTrue,
      );
      expect(
        SafetyMode.shouldTrigger(
            coins: 0, failedOrAbandonedAttemptsThisStage: 5),
        isTrue,
      );
    });

    test('حد الرصيد صارم من أسفل: العتبة نفسها لا تُفعّل (coins < العتبة)',
        () {
      // العتبة صارت مشتقّة من سعر أرخص تلميح لا رقما ثابتا — راجع
      // BalanceConfig.safetyModeCoinThreshold
      expect(
        SafetyMode.shouldTrigger(
            coins: BalanceConfig.safetyModeCoinThreshold,
            failedOrAbandonedAttemptsThisStage: 5),
        isFalse,
      );
      expect(
        SafetyMode.shouldTrigger(
            coins: BalanceConfig.safetyModeCoinThreshold - 1,
            failedOrAbandonedAttemptsThisStage: 5),
        isTrue,
      );
    });

    test('العتبة لا تنفصل عن سعر التلميح: من لا يقدر على أرخص تلميح محتاج',
        () {
      expect(
        BalanceConfig.safetyModeCoinThreshold,
        greaterThanOrEqualTo(BalanceConfig.coinsHintRandomLetter),
        reason: 'شبكة أمان تُفتح بعد العجز بخمس عملات هي شبكة مغلقة',
      );
    });

    test('المنحة المجانية متاحة مرة واحدة في اليوم التقويمي فقط', () {
      final now = DateTime(2026, 3, 5, 14, 30);
      final offerFirstTime = SafetyMode.buildOffer(
        lastFreeGrantDateKey: null,
        now: now,
      );
      expect(offerFirstTime.canClaimFreeGrant, isTrue);

      final offerSameDay = SafetyMode.buildOffer(
        lastFreeGrantDateKey: SafetyMode.dateKey(now),
        now: now.add(const Duration(hours: 3)),
      );
      expect(offerSameDay.canClaimFreeGrant, isFalse);

      final offerNextDay = SafetyMode.buildOffer(
        lastFreeGrantDateKey: SafetyMode.dateKey(now),
        now: now.add(const Duration(days: 1)),
      );
      expect(offerNextDay.canClaimFreeGrant, isTrue);
    });
  });
}
