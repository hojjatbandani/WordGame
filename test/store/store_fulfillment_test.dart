// التسليم (StoreNotifier): ما يُمنح مقابل كل شراء، وما يُستعاد على تثبيت
// جديد. خدمة الدفع تقرّر «كامل أم استعادة» (revenuecat_iap_service_test)؛
// هنا ما يعنيه كلٌّ منهما في محفظة اللاعب وحالته.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/iap_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/store/store_catalog.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة دفع يقود الاختبار تسليمها بنفسه
class _ControllableIap extends ChangeNotifier implements IapService {
  PurchaseFulfiller? fulfiller;
  Map<String, String> prices = {
    SkuIds.coins500: 'EGP 49.99',
    SkuIds.removeAds: 'EGP 249.99',
  };

  Future<Delivery> deliver(String sku, {bool full = true}) =>
      fulfiller!(sku, fullDelivery: full);

  void setPrices(Map<String, String> next) {
    prices = next;
    notifyListeners();
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> refresh() async {}

  @override
  void attachFulfiller(PurchaseFulfiller f) => fulfiller = f;

  @override
  void detachFulfiller(PurchaseFulfiller f) {
    if (fulfiller == f) fulfiller = null;
  }

  @override
  String? priceOf(String sku) => prices[sku];

  @override
  Listenable get changes => this;

  @override
  Future<PurchaseResult> buy(String sku) async =>
      const PurchaseResult(PurchaseStatus.failed);
}

class _Rig {
  _Rig(this.store, this.iap, this.container);

  final ProgressStore store;
  final _ControllableIap iap;
  final ProviderContainer container;

  int get coins => container.read(pointsProvider);
}

Future<_Rig> _rig([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = ProgressStore(await SharedPreferences.getInstance());
  final iap = _ControllableIap();
  final container = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      iapServiceProvider.overrideWithValue(iap),
    ],
  );
  addTearDown(container.dispose);
  // ما يفعله جذر التطبيق عند الإقلاع: المتجر حيّ فالتسليم موصول
  container.listen(storeProvider, (_, _) {});
  return _Rig(store, iap, container);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('الأسعار', () {
    test('من خدمة الدفع كما هي، وما لا سعر له ليس للبيع', () async {
      final rig = await _rig();
      final shop = rig.container.read(storeProvider);
      expect(shop.priceOf(SkuIds.coins500), 'EGP 49.99');
      expect(shop.priceOf(SkuIds.starterPack), isNull);
      expect(shop.anyForSale, isTrue);

      rig.iap.setPrices({});
      expect(rig.container.read(storeProvider).anyForSale, isFalse);
    });
  });

  group('تسليم كامل (شراء جديد)', () {
    test('حزمة عملات: العملات نفسها، وأول شراء يُسجَّل مرة واحدة', () async {
      final rig = await _rig();
      final before = rig.coins;

      final first = await rig.iap.deliver(SkuIds.coins500);
      expect(first.coins, 500);
      expect(first.firstPurchase, isTrue);
      expect(rig.coins, before + 500);
      expect(rig.store.hasEverPurchased, isTrue);
      expect(rig.store.lastPurchaseAt, isNotNull, reason: 'كتم البيني 24 ساعة');

      final second = await rig.iap.deliver(SkuIds.coins1650);
      expect(second.coins, 1650);
      expect(second.firstPurchase, isFalse);
      expect(rig.coins, before + 500 + 1650);
    });

    test('إزالة الإعلانات: تُفعَّل ومعها هدية العملات', () async {
      final rig = await _rig();
      final before = rig.coins;

      final delivery = await rig.iap.deliver(SkuIds.removeAds);
      expect(rig.container.read(adsRemovedProvider), isTrue);
      expect(delivery.coins, StoreCatalog.removeAdsGiftCoins);
      expect(rig.coins, before + StoreCatalog.removeAdsGiftCoins);
    });

    test(
      'حزمة البداية: الملكية والزينة والقسط الأول فورا، والباقي أقساط',
      () async {
        final rig = await _rig();
        final before = rig.coins;

        final delivery = await rig.iap.deliver(SkuIds.starterPack);
        expect(
          rig.container.read(purchaseStateProvider).starterPackOwned,
          isTrue,
        );
        expect(delivery.coins, StoreCatalog.starterPackDailyCoins.first);
        expect(rig.coins, before + StoreCatalog.starterPackDailyCoins.first);
        expect(
          rig.store.pendingCosmeticUnlocks,
          containsAll([
            StoreCatalog.starterPackAvatarId,
            StoreCatalog.starterPackFrameId,
          ]),
        );
        final status = rig.container.read(starterPackProvider);
        expect(status.isFullyDelivered, isFalse);
        expect(status.claimable, isNull, reason: 'القسط التالي غدا');
      },
    );

    test('منتج غير معروف لا يمنح شيئا', () async {
      final rig = await _rig();
      final before = rig.coins;
      final delivery = await rig.iap.deliver('unknown_sku');
      expect(delivery.coins, 0);
      expect(rig.coins, before);
      expect(rig.store.hasEverPurchased, isFalse);
    });
  });

  group('استعادة على تثبيت جديد — الملكية وحدها', () {
    test(
      'إزالة الإعلانات: تُفعَّل بلا هدية ولا كتم إعلانات ولا مكافأة أول شراء',
      () async {
        final rig = await _rig();
        final before = rig.coins;

        final delivery = await rig.iap.deliver(SkuIds.removeAds, full: false);
        expect(delivery.coins, 0);
        expect(rig.container.read(adsRemovedProvider), isTrue);
        expect(rig.coins, before, reason: 'إعادة التثبيت ليست ماكينة عملات');
        expect(rig.store.lastPurchaseAt, isNull);
        expect(rig.store.firstPurchaseBonusUntil, isNull);
        expect(
          rig.store.hasEverPurchased,
          isTrue,
          reason: 'عرض الشراء الأول لا يُعرض على من اشترى فعلا',
        );
      },
    );

    test('حزمة البداية: الملكية والزينة، والأقساط تُعدّ مستلَمة', () async {
      final rig = await _rig();
      final before = rig.coins;

      await rig.iap.deliver(SkuIds.starterPack, full: false);
      expect(
        rig.container.read(purchaseStateProvider).starterPackOwned,
        isTrue,
      );
      expect(rig.coins, before);
      expect(rig.container.read(starterPackProvider).isFullyDelivered, isTrue);
      expect(rig.container.read(starterPackProvider).hasClaimable, isFalse);
      expect(
        rig.store.pendingCosmeticUnlocks,
        contains(StoreCatalog.starterPackFrameId),
      );
    });

    test(
      'حزمة البداية مملوكة محليا وسط أقساطها: الاستعادة لا تمسّ الأقساط',
      () async {
        final rig = await _rig();
        await rig.iap.deliver(SkuIds.starterPack);
        final claimed = rig.store.starterPackClaimedDays;
        expect(claimed, 1);

        await rig.iap.deliver(SkuIds.starterPack, full: false);
        expect(rig.store.starterPackClaimedDays, claimed);
        expect(
          rig.container.read(starterPackProvider).isFullyDelivered,
          isFalse,
        );
      },
    );
  });

  test(
    'البدء من جديد: الشجرة القديمة تُهدم بعد وصول الجديدة ولا تفصل مُسلِّمها',
    () async {
      final rig = await _rig();
      final first = rig.iap.fulfiller;
      expect(first, isNotNull);

      final next = ProviderContainer(
        overrides: [
          progressStoreProvider.overrideWithValue(rig.store),
          iapServiceProvider.overrideWithValue(rig.iap),
        ],
      );
      addTearDown(next.dispose);
      next.listen(storeProvider, (_, _) {});
      final second = rig.iap.fulfiller;
      expect(second, isNot(same(first)));

      rig.container.dispose();
      expect(rig.iap.fulfiller, same(second));
      await rig.iap.deliver(SkuIds.coins500);
      expect(next.read(pointsProvider), greaterThanOrEqualTo(500));
    },
  );
}
