/// طبقة الشراء داخل التطبيق.
///
/// الكتالوج يعيش في lib/data/store/store_catalog.dart (منطق صرف قابل
/// للاختبار)؛ هنا العقد وحده. تنفيذان: RevenueCatIapService (store/
/// revenuecat_iap_service.dart) فوق RevenueCat على الهاتف، و
/// [MockIapService] للاختبارات وتطوير سطح المكتب.
///
/// **التسليم ليس في الشاشة.** الشراء الحقيقي قد يكتمل والمتجر مغلق: دفع
/// نقدي يُعتمد بعد ساعات، تطبيق أُغلق وسط الدفع، تثبيت جديد يستعيد ما
/// اشتُري. لذلك تسلّم خدمة الدفع كل شراء موثَّق عبر [PurchaseFulfiller]
/// الذي يوصله التطبيق مرة واحدة (StoreNotifier في providers.dart)، والشاشة
/// تنتظر النتيجة لتعرض البشارة فقط.
///
/// **قاعدة لا تُخترق**: لا منتج هنا يفتح محتوى. لا مرحلة ولا عالم ولا
/// نمط لعب خلف أي شراء — يُدفع للتسريع أو للتجميل فقط.
library;

import 'package:flutter/foundation.dart';

import 'store/store_catalog.dart';

enum PurchaseStatus {
  /// دُفع وسُلِّم
  success,

  /// الدفع قيد المعالجة (نقدي/عبر شركة الاتصالات) — يُسلَّم تلقائيا حين يُعتمد.
  /// وكذلك: دُفع وتعثّر التسليم — يُعاد في المطابقة التالية
  pending,

  /// أغلق اللاعب ورقة الدفع
  cancelled,

  /// منتج يملكه الحساب أصلا (شراء على جهاز آخر) — استُعيد بدل أن يُباع ثانية
  alreadyOwned,

  /// المنتج غير متاح الآن (لا Google Play، أو لم تصل الأسعار، أو بناء بلا متجر)
  unavailable,

  failed,
}

/// ما سُلّم فعلا مقابل شراء — تعرضه الشاشة كما هو
class Delivery {
  final int coins;

  /// أول شراء على هذا التثبيت: تُعرض بشارة مكافأته
  final bool firstPurchase;

  const Delivery({this.coins = 0, this.firstPurchase = false});

  static const none = Delivery();
}

class PurchaseResult {
  final PurchaseStatus status;
  final Delivery delivery;
  final String? error;

  const PurchaseResult(
    this.status, {
    this.delivery = Delivery.none,
    this.error,
  });

  bool get isSuccess => status == PurchaseStatus.success;
}

/// يمنح ما اشتُري. [fullDelivery] false = استعادة ما يُملك دائما فقط (إزالة
/// الإعلانات، شارة حزمة البداية) بلا عملات ولا هدايا: شراء قديم سُلِّم من
/// قبل، يعود على تثبيت جديد.
typedef PurchaseFulfiller =
    Future<Delivery> Function(String sku, {required bool fullDelivery});

abstract class IapService {
  /// يبدأ الاستماع ويجلب الأسعار ويستعيد المعلَّق والمملوك. لا يرمي ولا
  /// يؤخّر الإقلاع — يُنادى بلا await.
  Future<void> init();

  /// يعيد سؤال المتجر إن نقص شيء عند الإقلاع (بلا اتصال، المتجر لم
  /// يجهز، منتج فُعِّل للتوّ). يُنادى عند فتح المتجر؛ لا يرمي.
  Future<void> refresh();

  /// يصل من شجرة التطبيق. ما يكتمل قبل وصوله ينتظر في طابور ثم يُسلَّم.
  void attachFulfiller(PurchaseFulfiller fulfiller);

  /// يفصل [fulfiller] إن كان هو الموصول — شجرة تُهدم بعد أن وصلت أخرى
  /// (البدء من جديد) لا تفصل الجديدة
  void detachFulfiller(PurchaseFulfiller fulfiller);

  /// السعر كما يعرضه Google Play بعملة اللاعب، أو null إن لم يُعرف — والمنتج
  /// بلا سعر لا يُعرض للبيع إطلاقا: الرقم المعروض هو الرقم المدفوع أو لا رقم.
  String? priceOf(String sku);

  /// يُطلَق حين تصل الأسعار أو تتغيّر الإتاحة
  Listenable get changes;

  Future<PurchaseResult> buy(String sku);
}

/// شراء محاكى للاختبارات وتطوير سطح المكتب: ينجح بعد مهلة قصيرة ويمرّ
/// بالتسليم نفسه الذي يمرّ به الشراء الحقيقي.
///
/// **لا يبيع شيئا في بناء الإصدار**: النسخة 3 خرجت والمتجر محاكى فكان كل
/// شيء فيه مجانيا. في الإصدار لا سعر ولا شراء، فيختفي ما يُباع.
class MockIapService extends ChangeNotifier implements IapService {
  MockIapService({this.delay = const Duration(milliseconds: 1200)});

  final Duration delay;
  PurchaseFulfiller? _fulfiller;

  static const _referencePrices = <String, double>{
    SkuIds.coins500: 0.99,
    SkuIds.coins1650: 2.49,
    SkuIds.coins4800: 5.99,
    SkuIds.coins16000: 14.99,
    SkuIds.removeAds: StoreCatalog.removeAdsReferenceUsd,
    SkuIds.starterPack: StoreCatalog.starterPackReferenceUsd,
  };

  @override
  Future<void> init() async {}

  @override
  Future<void> refresh() async {}

  @override
  void attachFulfiller(PurchaseFulfiller fulfiller) => _fulfiller = fulfiller;

  @override
  void detachFulfiller(PurchaseFulfiller fulfiller) {
    if (_fulfiller == fulfiller) _fulfiller = null;
  }

  @override
  String? priceOf(String sku) {
    if (kReleaseMode) return null;
    final usd = _referencePrices[sku];
    return usd == null ? null : '\$${usd.toStringAsFixed(2)}';
  }

  @override
  Listenable get changes => this;

  @override
  Future<PurchaseResult> buy(String sku) async {
    if (priceOf(sku) == null) {
      return const PurchaseResult(PurchaseStatus.unavailable);
    }
    await Future<void>.delayed(delay);
    final fulfiller = _fulfiller;
    if (fulfiller == null) return const PurchaseResult(PurchaseStatus.failed);
    final delivery = await fulfiller(sku, fullDelivery: true);
    return PurchaseResult(PurchaseStatus.success, delivery: delivery);
  }
}
