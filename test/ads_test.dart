import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/wheel/wheel_models.dart';
import 'package:huruf/data/ads/ad_policy.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// آليات الإعلان كما ستعمل يوم يُعاد تفعيل القالب. سياسة هذا البناء نفسها
/// (كل القوالب مطفأة) مثبّتة في test/ads/ad_policy_test.dart.
const _adsEnabledForMechanics = AdFormatPolicy({
  AdFormat.interstitial,
  AdFormat.rewardedInterstitial,
});

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

/// يهيّئ حاوية جاهزة لعرض إعلان: وقع لعب في الجلسة، ولا مهلة قائمة
Future<ProviderContainer> _playingContainer([
  Map<String, Object> prefs = const {},
]) async {
  final c = await _container(prefs);
  c.read(sessionGameplayProvider.notifier).markGameplayStarted();
  return c;
}

/// يشغّل [count] إتمام مرحلة ثم يطلب إعلانا عند [stage]
AdCue _finishAndRequest(
  ProviderContainer c, {
  required int stage,
  required int completions,
  DateTime? now,
}) {
  final gate = c.read(interstitialGateProvider.notifier);
  for (var i = 0; i < completions; i++) {
    gate.recordStageCleared();
  }
  return gate.requestInterstitial(
    stageNumber: stage,
    stageCleared: true,
    rewardSequenceComplete: true,
    nowOverride: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('إيقاع الإعلانات البينية عبر المزوّد', () {
    test('لا إعلان قبل المرحلة 13 مهما تراكمت الإتمامات', () async {
      final c = await _playingContainer();
      addTearDown(c.dispose);

      for (final stage in [1, 3, 6, 12]) {
        expect(
          _finishAndRequest(c, stage: stage, completions: 6),
          AdCue.none,
          reason: 'المرحلة $stage',
        );
      }
    });

    test('من 13 إلى 40: كل خامس إتمام', () async {
      final c = await _playingContainer();
      addTearDown(c.dispose);
      final gate = c.read(interstitialGateProvider.notifier);

      for (var i = 0; i < 4; i++) {
        gate.recordStageCleared();
      }
      expect(
        gate.requestInterstitial(
            stageNumber: 20,
            stageCleared: true,
            rewardSequenceComplete: true),
        AdCue.none,
        reason: 'أربعة إتمامات لا تكفي',
      );

      gate.recordStageCleared();
      expect(
        gate.requestInterstitial(
            stageNumber: 20,
            stageCleared: true,
            rewardSequenceComplete: true),
        AdCue.interstitial,
      );
    });

    test('العدّاد يُصفَّر بعد كل إعلان', () async {
      final c = await _playingContainer();
      addTearDown(c.dispose);
      final now = DateTime(2026, 8, 26, 12);

      expect(
        _finishAndRequest(c, stage: 20, completions: 5, now: now),
        AdCue.interstitial,
      );
      expect(c.read(interstitialGateProvider), 0);

      // بعد ساعتين (خارج المهلة) يحتاج خمسة إتمامات جديدة كاملة
      final later = now.add(const Duration(hours: 2));
      expect(
        _finishAndRequest(c, stage: 21, completions: 4, now: later),
        AdCue.none,
      );
      expect(
        _finishAndRequest(c, stage: 21, completions: 1, now: later),
        AdCue.interstitial,
      );
    });

    test('الفشل لا يقدّم العدّاد ولا يعرض إعلانا', () async {
      final c = await _playingContainer();
      addTearDown(c.dispose);
      final gate = c.read(interstitialGateProvider.notifier);

      for (var i = 0; i < 10; i++) {
        expect(
          gate.requestInterstitial(
              stageNumber: 30,
              stageCleared: false,
              rewardSequenceComplete: true),
          AdCue.none,
        );
      }
      expect(c.read(interstitialGateProvider), 0,
          reason: 'الفشل لا يقرّب الإعلان بشيء');
    });

    test('مهلة التسعين ثانية تمنع إعلانا ثانيا مهما اكتمل الإيقاع',
        () async {
      final c = await _playingContainer();
      addTearDown(c.dispose);
      final now = DateTime(2026, 8, 26, 12);

      expect(
        _finishAndRequest(c, stage: 200, completions: 3, now: now),
        AdCue.interstitial,
      );
      expect(
        _finishAndRequest(
            c,
            stage: 201,
            completions: 3,
            now: now.add(const Duration(seconds: 60))),
        AdCue.none,
      );
      expect(
        _finishAndRequest(
            c,
            stage: 202,
            completions: 0,
            now: now.add(const Duration(seconds: 91))),
        AdCue.interstitial,
      );
    });

    test('المهلة تنجو من إعادة تشغيل التطبيق (تُقرأ من التخزين)', () async {
      final now = DateTime(2026, 8, 26, 12);
      final first = await _playingContainer();
      _finishAndRequest(first, stage: 200, completions: 3, now: now);
      final savedAt =
          first.read(progressStoreProvider).lastAdShownAt;
      first.dispose();
      expect(savedAt, now);

      // «جلسة جديدة» بنفس التخزين
      final second = await _playingContainer({
        'last_ad_shown_at': now.toIso8601String(),
      });
      addTearDown(second.dispose);
      expect(
        _finishAndRequest(
            second,
            stage: 200,
            completions: 5,
            now: now.add(const Duration(seconds: 30))),
        AdCue.none,
      );
    });

    test('لا إعلان على بداية باردة قبل أول لعب', () async {
      final c = await _container({}); // بلا markGameplayStarted
      addTearDown(c.dispose);
      expect(
        _finishAndRequest(c, stage: 200, completions: 9),
        AdCue.none,
      );
    });

    test('إزالة الإعلانات تمنع كل شيء', () async {
      final c = await _playingContainer();
      addTearDown(c.dispose);
      c.read(adsRemovedProvider.notifier).setPurchased();

      for (final stage in [13, 20, 55, 200]) {
        expect(_finishAndRequest(c, stage: stage, completions: 9), AdCue.none);
      }
    });

    test('الشراء يكتم الإعلانات 24 ساعة', () async {
      final now = DateTime(2026, 8, 26, 12);
      final c = await _playingContainer({
        'last_purchase_at':
            now.subtract(const Duration(hours: 2)).toIso8601String(),
      });
      addTearDown(c.dispose);

      expect(
        _finishAndRequest(c, stage: 200, completions: 9, now: now),
        AdCue.none,
      );
      expect(
        _finishAndRequest(
            c, stage: 200, completions: 0, now: now.add(const Duration(days: 2))),
        AdCue.interstitial,
      );
    });

    test('لحظة محميّة (مكافأة/عجلة/صندوق/ترقية) تؤجّل الإعلان', () async {
      final c = await _playingContainer();
      addTearDown(c.dispose);

      c.read(protectedMomentProvider.notifier).begin();
      expect(_finishAndRequest(c, stage: 200, completions: 9), AdCue.none);

      c.read(protectedMomentProvider.notifier).end();
      expect(_finishAndRequest(c, stage: 200, completions: 0),
          AdCue.interstitial);
    });
  });

  group('عجلة الحظ', () {
    test('أوزان القطاعات الثمانية تجمع إلى 100 بالضبط', () {
      final segments = BalanceConfig.wheelSegments;
      expect(segments.length, 8);
      expect(segments.fold<int>(0, (sum, s) => sum + s.weight), 100);
    });

    test('لا قطاع بوزن صفر أو سالب — كل قطاع قابل للربح فعلا', () {
      for (final segment in BalanceConfig.wheelSegments) {
        expect(segment.weight, greaterThan(0),
            reason: 'لا يجوز عرض قطاع لا يمكن أن يربحه اللاعب أبدا');
      }
    });

    test('قيم قطاعات العملات تطابق الجدول المعطى بالضبط', () {
      final coinValues = BalanceConfig.wheelSegments
          .where((s) => s.type == WheelPrizeType.coins)
          .map((s) => s.value)
          .toList()
        ..sort();
      expect(coinValues, [20, 30, 50, 75, 100, 250]);
    });
  });

  group('إزالة الإعلانات', () {
    test('تبقى محفوظة بعد إعادة التشغيل', () async {
      final first = await _container({});
      first.read(adsRemovedProvider.notifier).setPurchased();
      first.dispose();

      SharedPreferences.setMockInitialValues({'ads_removed': true});
      final store = await ProgressStore.create();
      final second = ProviderContainer(
        overrides: [progressStoreProvider.overrideWithValue(store)],
      );
      addTearDown(second.dispose);
      expect(second.read(adsRemovedProvider), isTrue);
    });
  });
}
