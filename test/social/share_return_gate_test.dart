import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/core/share_return_gate.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = ProgressStore(await SharedPreferences.getInstance());
  return ProviderContainer(
    overrides: [progressStoreProvider.overrideWithValue(store)],
  );
}

void main() {
  group('بوّابة العودة من المشاركة', () {
    test('فتح الورقة وحده لا يمنح شيئا — المنح عند العودة', () {
      final gate = ShareReturnGate();

      // الورقة أُغلقت بعد اختيار تطبيق، والتطبيق في الخلفية الآن
      expect(
        gate.onSheetClosed(
            outcome: ShareSheetOutcome.shared, appIsResumed: false),
        isFalse,
        reason: 'لا مكافأة قبل عودة اللاعب',
      );
      expect(gate.isAwaitingReturn, isTrue);

      expect(gate.onAppResumed(), isTrue);
    });

    test('اختبار القبول: الإلغاء لا يمنح شيئا مهما تكرّر', () {
      final gate = ShareReturnGate();

      for (var i = 0; i < 10; i++) {
        expect(
          gate.onSheetClosed(
              outcome: ShareSheetOutcome.dismissed, appIsResumed: true),
          isFalse,
        );
        expect(gate.isAwaitingReturn, isFalse);
        // حتى لو عاد التطبيق للمقدّمة بعدها (تبديل تطبيقات عاديّ)
        expect(gate.onAppResumed(), isFalse);
      }
    });

    test('العودة مرتين تمنح مرة واحدة', () {
      final gate = ShareReturnGate();
      gate.onSheetClosed(
          outcome: ShareSheetOutcome.shared, appIsResumed: false);

      expect(gate.onAppResumed(), isTrue);
      expect(gate.onAppResumed(), isFalse);
      expect(gate.onAppResumed(), isFalse);
    });

    test('منصّة لا تغادر التطبيق: المنح فور إغلاق الورقة', () {
      final gate = ShareReturnGate();

      expect(
        gate.onSheetClosed(
            outcome: ShareSheetOutcome.unknown, appIsResumed: true),
        isTrue,
      );
      // ولا تُمنح ثانية عند أول عودة لاحقة
      expect(gate.onAppResumed(), isFalse);
    });

    test('مغادرة الشاشة قبل العودة تلغي الانتظار', () {
      final gate = ShareReturnGate();
      gate.onSheetClosed(
          outcome: ShareSheetOutcome.shared, appIsResumed: false);

      gate.reset();
      expect(gate.onAppResumed(), isFalse);
    });
  });

  group('مكافأة المشاركة', () {
    test('القيمة والسقف من BalanceConfig لا من أرقام مكتوبة', () {
      expect(ShareRewardNotifier.reward, BalanceConfig.shareRewardCoins);
      expect(ShareRewardNotifier.maxTotal, BalanceConfig.shareRewardMaxTotal);
      expect(BalanceConfig.shareRewardCoins, 15);
      expect(BalanceConfig.shareRewardMaxTotal, 2);
    });

    test('السقف الكلي 30 عملة (15 × 2) في عمر الحساب', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);
      final notifier = container.read(shareRewardProvider.notifier);

      notifier.claim();
      notifier.claim();
      notifier.claim(); // فوق السقف

      expect(container.read(pointsProvider), 30);
    });

    test('اختبار القبول: فتح وإلغاء متكرّران لا يمنحان شيئا', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);
      final gate = ShareReturnGate();

      // عشر محاولات كاملة: فتح الورقة ثم إلغاؤها
      for (var i = 0; i < 10; i++) {
        final earned = gate.onSheetClosed(
            outcome: ShareSheetOutcome.dismissed, appIsResumed: true);
        if (earned) container.read(shareRewardProvider.notifier).claim();
      }

      expect(container.read(pointsProvider), 0);
      expect(container.read(shareRewardProvider).canEarn, isTrue,
          reason: 'رصيد اليوم لم يُستهلك بالإلغاء');
    });

    test('مشاركة حقيقية واحدة تمنح مرة واحدة رغم تكرار حدث العودة',
        () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);
      final gate = ShareReturnGate();

      gate.onSheetClosed(
          outcome: ShareSheetOutcome.shared, appIsResumed: false);
      for (var i = 0; i < 5; i++) {
        if (gate.onAppResumed()) {
          container.read(shareRewardProvider.notifier).claim();
        }
      }

      expect(container.read(pointsProvider), BalanceConfig.shareRewardCoins);
    });
  });
}
