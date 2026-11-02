import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/ads/ad_pacing.dart';

/// طلب سليم تماما — كل اختبار يغيّر منه ما يخصّه فقط، فيبقى واضحا أي
/// قاعدة تُختبر بالضبط.
///
/// `formatAllowed` مشغَّل هنا لأن هذه الاختبارات تفحص قواعد الإيقاع كما
/// ستعمل يوم يُعاد تفعيل البيني. سياسة هذا البناء نفسها (البيني مطفأ)
/// مثبّتة في test/ads/ad_policy_test.dart.
InterstitialRequest _request({
  int stageNumber = 50,
  int completions = 99,
  bool formatAllowed = true,
  bool adsRemoved = false,
  bool interstitialsEnabled = true,
  bool stageCleared = true,
  bool rewardSequenceComplete = true,
  bool protectedMomentPending = false,
  bool hadGameplayThisSession = true,
  DateTime? now,
  DateTime? lastAdShownAt,
  DateTime? lastPurchaseAt,
}) =>
    InterstitialRequest(
      stageNumber: stageNumber,
      completionsSinceLastInterstitial: completions,
      formatAllowed: formatAllowed,
      adsRemoved: adsRemoved,
      interstitialsEnabled: interstitialsEnabled,
      stageCleared: stageCleared,
      rewardSequenceComplete: rewardSequenceComplete,
      protectedMomentPending: protectedMomentPending,
      hadGameplayThisSession: hadGameplayThisSession,
      now: now ?? DateTime(2026, 8, 26, 12),
      lastAdShownAt: lastAdShownAt,
      lastPurchaseAt: lastPurchaseAt,
    );

void main() {
  group('جدول الإيقاع', () {
    test('لا إيقاع إطلاقا قبل المرحلة 13', () {
      for (var stage = 1; stage <= 12; stage++) {
        expect(BalanceConfig.interstitialCadenceForStage(stage), 0,
            reason: 'المرحلة $stage');
      }
    });

    test('المدَيات الثلاثة: 5 ثم 4 ثم 3', () {
      expect(BalanceConfig.interstitialCadenceForStage(13), 5);
      expect(BalanceConfig.interstitialCadenceForStage(40), 5);
      expect(BalanceConfig.interstitialCadenceForStage(41), 4);
      expect(BalanceConfig.interstitialCadenceForStage(120), 4);
      expect(BalanceConfig.interstitialCadenceForStage(121), 3);
      expect(BalanceConfig.interstitialCadenceForStage(500), 3);
    });
  });

  group('اختبار القبول: لا إعلان قبل المرحلة 13 تحت أي مسار', () {
    test('كل مرحلة من 1 إلى 12 ممنوعة مهما كانت بقية المدخلات مثالية', () {
      for (var stage = 1; stage <= 12; stage++) {
        for (final completions in [1, 5, 50, 1000]) {
          final decision = AdPacing.decideInterstitial(_request(
            stageNumber: stage,
            completions: completions,
          ));
          expect(decision.allowed, isFalse,
              reason: 'المرحلة $stage بعد $completions إتمام');
          expect(decision.reason, AdBlockReason.tooEarlyInGame);
        }
      }
    });

    test('المرحلة 13 مسموحة حين يكتمل إيقاعها — فالمنع ليس منعا مطلقا', () {
      expect(
        AdPacing.decideInterstitial(_request(stageNumber: 13, completions: 5))
            .allowed,
        isTrue,
      );
      expect(
        AdPacing.decideInterstitial(_request(stageNumber: 13, completions: 4))
            .allowed,
        isFalse,
      );
    });
  });

  group('القواعد الصارمة', () {
    test('لا إعلان بعد مرحلة فُشلت أو غُودرت', () {
      final d = AdPacing.decideInterstitial(_request(stageCleared: false));
      expect(d.allowed, isFalse);
      expect(d.reason, AdBlockReason.stageNotCleared);
    });

    test('لا إعلان قبل انتهاء تسلسل المكافأة', () {
      final d =
          AdPacing.decideInterstitial(_request(rewardSequenceComplete: false));
      expect(d.allowed, isFalse);
      expect(d.reason, AdBlockReason.rewardSequenceRunning);
    });

    test('لا إعلان قبل لحظة محميّة (مكافأة يومية/عجلة/صندوق/ترقية)', () {
      final d =
          AdPacing.decideInterstitial(_request(protectedMomentPending: true));
      expect(d.allowed, isFalse);
      expect(d.reason, AdBlockReason.protectedMoment);
    });

    test('لا إعلان على بداية باردة قبل أول لعب في الجلسة', () {
      final d =
          AdPacing.decideInterstitial(_request(hadGameplayThisSession: false));
      expect(d.allowed, isFalse);
      expect(d.reason, AdBlockReason.coldStart);
    });

    test('إزالة الإعلانات منع دائم يسبق كل شيء', () {
      final d = AdPacing.decideInterstitial(_request(
        adsRemoved: true,
        stageNumber: 500,
        completions: 999,
      ));
      expect(d.allowed, isFalse);
      expect(d.reason, AdBlockReason.adsRemoved);
    });

    test('مفتاح الإيقاف عن بعد يمنع كل الإعلانات البينية', () {
      final d =
          AdPacing.decideInterstitial(_request(interstitialsEnabled: false));
      expect(d.allowed, isFalse);
      expect(d.reason, AdBlockReason.killSwitch);
    });

    test('قالب مطفأ في البناء يمنع أولا — قبل إزالة الإعلانات والمفتاح', () {
      final d = AdPacing.decideInterstitial(_request(
        formatAllowed: false,
        adsRemoved: true,
        interstitialsEnabled: false,
        stageNumber: 500,
        completions: 999,
      ));
      expect(d.allowed, isFalse);
      expect(d.reason, AdBlockReason.formatDisabled);
    });

    test('قالب مطفأ لا يرفعه مفتاح مُشغَّل ولا إيقاع مكتمل', () {
      final d = AdPacing.decideInterstitial(_request(
        formatAllowed: false,
        interstitialsEnabled: true,
        stageNumber: 500,
        completions: 999,
      ));
      expect(d.allowed, isFalse);
      expect(d.reason, AdBlockReason.formatDisabled);
    });
  });

  group('اختبار القبول: مهلة التسعين ثانية', () {
    final now = DateTime(2026, 8, 26, 12, 0, 0);

    test('تمنع خلال 89 ثانية وتسمح بعد 90', () {
      expect(
        AdPacing.decideInterstitial(_request(
          now: now,
          lastAdShownAt: now.subtract(const Duration(seconds: 89)),
        )).reason,
        AdBlockReason.globalCooldown,
      );
      expect(
        AdPacing.decideInterstitial(_request(
          now: now,
          lastAdShownAt: now.subtract(const Duration(seconds: 90)),
        )).allowed,
        isTrue,
      );
    });

    test('تسري عبر تصغير التطبيق: الفارق زمن حقيقي لا عدّاد جلسة', () {
      // «إعادة فتح التطبيق» = نفس الطابع الزمني المحفوظ، ساعة لاحقة
      final reopened = now.add(const Duration(seconds: 30));
      expect(
        AdPacing.decideInterstitial(_request(
          now: reopened,
          lastAdShownAt: now,
        )).reason,
        AdBlockReason.globalCooldown,
        reason: 'إغلاق التطبيق وفتحه لا يعيد ضبط المهلة',
      );
    });

    test('ساعة رجعت للخلف تُعامَل كأنها داخل المهلة', () {
      expect(
        AdPacing.decideInterstitial(_request(
          now: now,
          lastAdShownAt: now.add(const Duration(hours: 1)),
        )).reason,
        AdBlockReason.globalCooldown,
      );
    });
  });

  group('كتم الإعلانات بعد الشراء', () {
    final now = DateTime(2026, 8, 26, 12);

    test('مكتومة 24 ساعة بعد أي شراء', () {
      expect(
        AdPacing.decideInterstitial(_request(
          now: now,
          lastPurchaseAt: now.subtract(const Duration(hours: 23, minutes: 59)),
        )).reason,
        AdBlockReason.recentPurchase,
      );
    });

    test('تعود بعد انقضاء الأربع والعشرين', () {
      expect(
        AdPacing.decideInterstitial(_request(
          now: now,
          lastPurchaseAt: now.subtract(const Duration(hours: 24, minutes: 1)),
        )).allowed,
        isTrue,
      );
    });
  });

  group('ترتيب القواعد', () {
    test('الفشل يسبق الإيقاع: لا يُبلَّغ عن «لم يحن الدور» لمرحلة فُشلت',
        () {
      final d = AdPacing.decideInterstitial(
          _request(stageCleared: false, completions: 0, stageNumber: 5));
      expect(d.reason, AdBlockReason.stageNotCleared,
          reason: 'سبب المنع يجب أن يكون الأدقّ لا الأول عرضا');
    });
  });
}
