// المتجر من الواجهة: الشراء يمرّ بالتسليم الحقيقي (StoreNotifier)، والسعر
// المعروض هو سعر خدمة الدفع حرفيا، وما لا سعر له لا يُعرض للبيع.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/iap_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/data/store/store_catalog.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/shop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة دفع بأسعار ونتيجة يحدّدهما الاختبار
class _ScriptedIap extends ChangeNotifier implements IapService {
  _ScriptedIap({required this.prices, this.result});

  final Map<String, String> prices;

  /// null = يسلّم كاملا كالشراء الحقيقي الناجح
  final PurchaseStatus? result;
  PurchaseFulfiller? _fulfiller;
  final bought = <String>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> refresh() async {}

  @override
  void attachFulfiller(PurchaseFulfiller f) => _fulfiller = f;

  @override
  void detachFulfiller(PurchaseFulfiller f) {
    if (_fulfiller == f) _fulfiller = null;
  }

  @override
  String? priceOf(String sku) => prices[sku];

  @override
  Listenable get changes => this;

  @override
  Future<PurchaseResult> buy(String sku) async {
    bought.add(sku);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (result case final status?) return PurchaseResult(status);
    final delivery = await _fulfiller!(sku, fullDelivery: true);
    return PurchaseResult(PurchaseStatus.success, delivery: delivery);
  }
}

const _egp = {
  SkuIds.coins500: 'EGP 49.99',
  SkuIds.coins1650: 'EGP 119.99',
  SkuIds.coins4800: 'EGP 289.99',
  SkuIds.coins16000: 'EGP 729.99',
  SkuIds.removeAds: 'EGP 249.99',
  SkuIds.starterPack: 'EGP 49.99',
};

Future<ProviderContainer> _pumpShop(WidgetTester tester, IapService iap) async {
  // إطار أطول من القائمة كلها: كل بطاقة مبنية فعلا
  tester.view.physicalSize = const Size(1080, 7200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'player_name_asked': true});
  final prefs = await SharedPreferences.getInstance();
  final store = ProgressStore(prefs);
  final progression = await ProgressionRepository.load(
    prefs: prefs,
    legacy: store,
  );
  final container = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      progressionRepositoryProvider.overrideWithValue(progression),
      iapServiceProvider.overrideWithValue(iap),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: HurufTheme.build(),
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const ShopScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  return container;
}

/// يمرّر انتقال مسار كاملا (ورقة التأكيد تنزلق، ثم تُغلق)
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// يصرّف المؤقّتات (البشارة، الشريط السفلي، الانتقالات)
Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  testWidgets('شراء حزمة من الواجهة: سعر Google في البطاقة والتأكيد، والعملات '
      'تصل عبر التسليم', (tester) async {
    final iap = _ScriptedIap(prices: _egp);
    final c = await _pumpShop(tester, iap);
    final before = c.read(pointsProvider);

    // السعر المعروض هو سعر خدمة الدفع حرفيا — لا دولار مكتوب في الكود
    expect(find.text('EGP 49.99'), findsWidgets);
    expect(find.textContaining('\$'), findsNothing);
    expect(find.textContaining('محاكى'), findsNothing);

    await tester.tap(find.text('كيس عملات'));
    await _settle(tester);
    expect(find.text('شراء EGP 49.99'), findsOneWidget);
    expect(find.text('الدفع بمال حقيقي عبر Google Play'), findsOneWidget);

    await tester.tap(find.text('شراء EGP 49.99'));
    await _settle(tester);

    expect(iap.bought, [SkuIds.coins500]);
    expect(c.read(pointsProvider), before + 500);
    expect(c.read(purchaseStateProvider).hasEverPurchased, isTrue);
    expect(find.textContaining('هدية أول شراء'), findsOneWidget);
    await _drain(tester);
  });

  testWidgets('لا متجر: لا شيء يُعرض للبيع، وسطر يشرح السبب', (tester) async {
    await _pumpShop(tester, _ScriptedIap(prices: const {}));

    expect(find.text('حزم العملات'), findsNothing);
    for (final pack in StoreCatalog.coinPacks) {
      expect(find.text(pack.nameAr), findsNothing, reason: pack.id);
    }
    expect(find.text('حزمة البداية'), findsNothing);
    expect(find.text('إزالة الإعلانات'), findsNothing);
    expect(find.textContaining('الشراء غير متاح الآن'), findsOneWidget);
    // المجاني باقٍ
    expect(find.text('المكافأة اليومية'), findsOneWidget);
    await _drain(tester);
  });

  testWidgets('دفع معلَّق: رسالة «قيد المعالجة» ولا عملة قبل الاعتماد', (
    tester,
  ) async {
    final iap = _ScriptedIap(prices: _egp, result: PurchaseStatus.pending);
    final c = await _pumpShop(tester, iap);
    final before = c.read(pointsProvider);

    await tester.tap(find.text('حقيبة عملات'));
    await _settle(tester);
    await tester.tap(find.text('شراء EGP 119.99'));
    await _settle(tester);

    expect(find.textContaining('الدفع قيد المعالجة'), findsOneWidget);
    expect(c.read(pointsProvider), before);
    expect(c.read(purchaseStateProvider).hasEverPurchased, isFalse);
    await _drain(tester);
  });

  testWidgets(
    'إزالة الإعلانات: الوعد «بين المراحل»، وفيديو المكافأة يبقى اختياريا',
    (tester) async {
      await _pumpShop(tester, _ScriptedIap(prices: _egp));
      await tester.tap(find.text('إزالة الإعلانات'));
      await _settle(tester);
      expect(find.textContaining('بدون إعلانات بين المراحل'), findsWidgets);
      expect(
        find.textContaining('فيديوهات المكافأة الاختيارية تبقى'),
        findsOneWidget,
      );
      expect(find.text('شراء EGP 249.99'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await _drain(tester);
    },
  );
}
