// مكافأة تفعيل الودجة: تُمنح مرة واحدة، ولا تتكرّر بأي حيلة.
//
// الاختبار الأهم هنا ليس «تُمنح»، بل «لا تُمنح مرتين» — إزالة الودجة
// وإعادتها، وأكثر من نسخة، وتغيير الحجم، وإعادة تشغيل الجهاز، و«البدء
// من جديد» كلها مسارات كانت ستصير مزرعة 100 ألماسة.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/data/widget/widget_activation.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ProviderContainer, ProgressStore)> _container([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await ProgressStore.create();
  final progression = await ProgressionRepository.load(
    prefs: store.prefs,
    legacy: store,
  );
  final container = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      progressionRepositoryProvider.overrideWithValue(progression),
    ],
  );
  addTearDown(container.dispose);
  return (container, store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('قاعدة المنح', () {
    test('ودجة مضافة ولم تُمنح بعد ⇒ تُمنح', () {
      expect(
        WidgetActivation.shouldGrant(
          widgetInstalled: true,
          alreadyRewarded: false,
        ),
        isTrue,
      );
    });

    test('لا ودجة ⇒ لا منح', () {
      expect(
        WidgetActivation.shouldGrant(
          widgetInstalled: false,
          alreadyRewarded: false,
        ),
        isFalse,
      );
    });

    test('مُنحت من قبل ⇒ لا تُمنح ثانية مهما تكرّرت الإضافة', () {
      // إزالة ثم إعادة، أو نسخة ثانية، أو تغيير حجم: كلها تصل إلى هنا
      // بـwidgetInstalled=true — والعلَم وحده هو ما يمنع التكرار
      expect(
        WidgetActivation.shouldGrant(
          widgetInstalled: true,
          alreadyRewarded: true,
        ),
        isFalse,
      );
    });

    test('حتى بعد إزالة الودجة يبقى العلَم مانعا', () {
      expect(
        WidgetActivation.shouldGrant(
          widgetInstalled: false,
          alreadyRewarded: true,
        ),
        isFalse,
      );
    });

    test('سبب الكسب هو المطلوب حرفيا', () {
      expect(WidgetActivation.earnReason, 'widget_activation');
    });
  });

  group('العلَم في التخزين', () {
    test('يبدأ مطفأ في تثبيت جديد', () async {
      final (_, store) = await _container();
      expect(store.widgetActivationRewarded, isFalse);
    });

    test('يُقرأ كما كُتب', () async {
      final (_, store) = await _container();
      await store.setWidgetActivationRewarded(true);
      expect(store.widgetActivationRewarded, isTrue);
    });

    test('اختبار قبول: «البدء من جديد» لا يعيد فتح باب المكافأة', () async {
      final (_, store) = await _container();
      await store.setWidgetActivationRewarded(true);
      await store.setWidgetPromoShown(true);

      await store.resetProgress();

      // لو صُفِّر هذان العلَمان لصار «امسح التقدّم ثم أعد إضافة الودجة»
      // مزرعة 100 ألماسة متكرّرة
      expect(store.widgetActivationRewarded, isTrue);
      expect(store.widgetPromoShown, isTrue);
    });

    test('مسح بيانات التطبيق يعيد كل شيء للصفر — وهو المقصود', () async {
      // تثبيت نظيف: لا علَم ولا رصيد ولا تقدّم. لا ربح في تكرارها.
      final (_, store) = await _container();
      expect(store.widgetActivationRewarded, isFalse);
      expect(store.widgetPromoShown, isFalse);
    });
  });

  group('قيمة المكافأة', () {
    test('100 ألماسة كما طُلبت', () {
      expect(BalanceConfig.widgetActivationRewardCoins, 100);
    });

    test('قابلة للضبط عن بعد', () {
      final original = BalanceConfig.widgetActivationRewardCoins;
      addTearDown(
        () => BalanceConfig.widgetActivationRewardCoins = original,
      );
      BalanceConfig.widgetActivationRewardCoins = 150;
      expect(BalanceConfig.widgetActivationRewardCoins, 150);
    });
  });

  group('عرض «أضف الودجة»', () {
    test('لا يُعرض قبل إتمام عدة مراحل — لا عند أول تشغيل', () {
      expect(BalanceConfig.widgetPromoAfterStages, greaterThan(0));
    });

    test('يُعرض مرة واحدة ثم لا يُسأل اللاعب ثانية', () async {
      final (_, store) = await _container();
      expect(store.widgetPromoShown, isFalse);
      await store.setWidgetPromoShown(true);
      expect(store.widgetPromoShown, isTrue);
    });
  });
}
