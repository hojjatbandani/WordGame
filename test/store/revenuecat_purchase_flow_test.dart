// الشراء من أوّله إلى آخره فوق RevenueCat: شاشة المتجر كما هي، StoreNotifier
// (التسليم الحقيقي)، RevenueCatIapService، وPluginRevenueCatGateway فوق
// purchases_flutter نفسها — والمزيّف وحده هو الطرف الأصلي خلف القناة
// (fake_revenuecat_platform.dart).
//
// ما يُقاس هو محفظة اللاعب: شراء ناجح، ملغى، معلَّق، ومكرّر — كلٌّ يُحتسب
// مرة واحدة أو لا يُحتسب.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/data/store/revenuecat_iap_service.dart';
import 'package:huruf/data/store/store_catalog.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/shop_screen.dart';
import 'package:huruf/presentation/widgets/reward_burst_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_revenuecat_platform.dart';

const _egp = {
  SkuIds.coins500: 'EGP 49.99',
  SkuIds.coins1650: 'EGP 119.99',
  SkuIds.coins4800: 'EGP 289.99',
  SkuIds.coins16000: 'EGP 729.99',
  SkuIds.removeAds: 'EGP 249.99',
  SkuIds.starterPack: 'EGP 49.99',
};

Future<(ProviderContainer, FakeRevenueCat)> _pumpShop(
  WidgetTester tester,
) async {
  // إطار أطول من القائمة كلها: كل بطاقة مبنية فعلا
  tester.view.physicalSize = const Size(1080, 7200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final rc = FakeRevenueCat(prices: _egp)..install();
  SharedPreferences.setMockInitialValues({'player_name_asked': true});
  final prefs = await SharedPreferences.getInstance();
  final store = ProgressStore(prefs);
  final progression = await ProgressionRepository.load(
    prefs: prefs,
    legacy: store,
  );
  final iap = RevenueCatIapService(
    gateway: PluginRevenueCatGateway(apiKey: 'test_key'),
    prefs: prefs,
  );
  final container = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      progressionRepositoryProvider.overrideWithValue(progression),
      iapServiceProvider.overrideWithValue(iap),
    ],
  );
  addTearDown(container.dispose);
  // ما يفعله main.dart وجذر التطبيق: الخدمة تبدأ، والمتجر حيّ فالتسليم موصول
  container.listen(storeProvider, (_, _) {});
  await iap.init();
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
  return (container, rc);
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

/// يفتح بطاقة [card] ويؤكّد الشراء بزرّ [confirm]
Future<void> _buy(WidgetTester tester, String card, String confirm) async {
  await tester.tap(find.text(card));
  await _settle(tester);
  await tester.tap(find.text(confirm));
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('البوّابة فوق purchases_flutter', () {
    late FakeRevenueCat rc;
    late PluginRevenueCatGateway gateway;

    setUp(() async {
      rc = FakeRevenueCat(prices: {..._egp}..remove(SkuIds.coins16000))
        ..install();
      gateway = PluginRevenueCatGateway(apiKey: 'test_key');
      await gateway.configure();
    });

    test('الأسعار كما يعرضها المتجر، وما لا يوجد فيه لا سعر له', () async {
      final prices = await gateway.queryPrices(SkuIds.forSale);

      expect(prices[SkuIds.coins500], 'EGP 49.99');
      expect(prices.containsKey(SkuIds.coins16000), isFalse);
    });

    test('شراء ناجح: المعاملة بمعرّف RevenueCat من CustomerInfo، لا برقم طلب '
        'Google', () async {
      await gateway.queryPrices(SkuIds.forSale);

      final outcome = await gateway.buy(SkuIds.coins500);

      expect(outcome.status, RcBuyStatus.purchased);
      expect(outcome.transactions.map((t) => t.id), ['rc_tx_1']);
      expect(outcome.transactions.single.sku, SkuIds.coins500);
      expect(outcome.transactions.single.purchasedAt, isNotNull);
    });

    test('رموز أخطاء RevenueCat: إلغاء، معلَّق، مملوك، فشل', () async {
      await gateway.queryPrices(SkuIds.forSale);
      const cases = {
        NextBuy.cancelled: RcBuyStatus.cancelled,
        NextBuy.pending: RcBuyStatus.pending,
        NextBuy.alreadyOwned: RcBuyStatus.alreadyOwned,
        NextBuy.error: RcBuyStatus.failed,
      };
      for (final MapEntry(key: next, value: status) in cases.entries) {
        rc.next = next;
        expect((await gateway.buy(SkuIds.coins500)).status, status);
      }
      expect(rc.transactions, isEmpty);
    });

    test('تحديثات بيانات العميل تصل بمعرّفات RevenueCat', () async {
      final updates = <List<String>>[];
      gateway.transactionUpdates.listen(
        (list) => updates.add([for (final t in list) t.id]),
      );
      rc.addTransaction(SkuIds.removeAds, DateTime(2026, 10, 1));

      await rc.pushCustomerInfo();
      await pumpEventQueue();

      expect(updates.last, ['rc_tx_1']);
    });
  });

  group('من المتجر إلى المحفظة', () {
    testWidgets('شراء ناجح: +500 مرة واحدة رغم تحديثات RevenueCat المتكرّرة', (
      tester,
    ) async {
      final (c, rc) = await _pumpShop(tester);
      final before = c.read(pointsProvider);

      await _buy(tester, 'كيس عملات', 'شراء EGP 49.99');

      expect(rc.calls, contains('purchaseProduct'));
      expect(c.read(pointsProvider), before + 500);
      expect(c.read(purchaseStateProvider).hasEverPurchased, isTrue);
      expect(find.textContaining('هدية أول شراء'), findsOneWidget);

      // RevenueCat يعيد إرسال بيانات العميل (عودة من الخلفية، مزامنة)
      await rc.pushCustomerInfo();
      await rc.pushCustomerInfo();
      await _settle(tester);
      expect(c.read(pointsProvider), before + 500);
      await _drain(tester);
    });

    testWidgets('شراء ملغى: لا عملات ولا رسالة خطأ', (tester) async {
      final (c, rc) = await _pumpShop(tester);
      final before = c.read(pointsProvider);
      rc.next = NextBuy.cancelled;

      await _buy(tester, 'كيس عملات', 'شراء EGP 49.99');

      expect(rc.calls, contains('purchaseProduct'));
      expect(c.read(pointsProvider), before);
      expect(c.read(purchaseStateProvider).hasEverPurchased, isFalse);
      expect(find.textContaining('تعذر إتمام الشراء'), findsNothing);
      await _drain(tester);
    });

    testWidgets(
      'شراء معلَّق: «قيد المعالجة»، ثم العملات مرة واحدة حين يُعتمد',
      (tester) async {
        final (c, rc) = await _pumpShop(tester);
        final before = c.read(pointsProvider);
        rc.next = NextBuy.pending;

        await _buy(tester, 'حقيبة عملات', 'شراء EGP 119.99');

        expect(find.textContaining('الدفع قيد المعالجة'), findsOneWidget);
        expect(c.read(pointsProvider), before);

        // اعتُمد الدفع: RevenueCat يسجّله ويطلق التحديث
        rc.addTransaction(SkuIds.coins1650, DateTime.now());
        await rc.pushCustomerInfo();
        await _settle(tester);
        expect(c.read(pointsProvider), before + 1650);

        await rc.pushCustomerInfo();
        await _settle(tester);
        expect(c.read(pointsProvider), before + 1650);
        await _drain(tester);
      },
    );

    testWidgets('شراء مكرّر لحزمة العملات: كل شراء يُحتسب مرة', (tester) async {
      final (c, rc) = await _pumpShop(tester);
      final before = c.read(pointsProvider);

      await _buy(tester, 'كيس عملات', 'شراء EGP 49.99');
      // بشارة العملات تبقى حتى يلمسها اللاعب
      await tester.tap(find.byType(RewardBurstOverlay));
      await _drain(tester);
      await _buy(tester, 'كيس عملات', 'شراء EGP 49.99');
      await rc.pushCustomerInfo();
      await _settle(tester);

      expect(rc.transactions, hasLength(2));
      expect(c.read(pointsProvider), before + 1000);
      await _drain(tester);
    });

    testWidgets('إزالة الإعلانات مملوكة من تثبيت سابق: «تملكه»، تُستعاد بلا '
        'هدية ثانية', (tester) async {
      final (c, rc) = await _pumpShop(tester);
      final before = c.read(pointsProvider);
      expect(c.read(adsRemovedProvider), isFalse);
      // اشتراها على تثبيت سابق، وRevenueCat لم يُرسل المملوك بعد
      rc.addTransaction(SkuIds.removeAds, DateTime(2026, 10, 1));
      rc.next = NextBuy.alreadyOwned;

      await _buy(tester, 'إزالة الإعلانات', 'شراء EGP 249.99');

      expect(find.textContaining('تملك هذا المنتج بالفعل'), findsOneWidget);
      expect(rc.calls, contains('restorePurchases'));
      expect(c.read(adsRemovedProvider), isTrue);
      expect(c.read(pointsProvider), before);
      await _drain(tester);
    });
  });
}
