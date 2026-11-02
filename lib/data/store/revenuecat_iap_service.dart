// RevenueCat خلف عقد IapService.
//
// RevenueCat يتحقّق من كل إيصال على خادمه، ويُنهي الشراء بنفسه (يستهلك
// القابل للاستهلاك ويقرّ بغيره) قبل أن يعيد النتيجة. ما يبقى على التطبيق
// هو التسليم، وقواعده هنا، وكلها مختبَرة بلا جهاز عبر [RevenueCatGateway]:
//
//   - **سجلّ المسلَّم.** كل معاملة سُلِّمت يُحفظ معرّفها، فلا تُسلَّم مرتين
//     مهما تكرّر وصولها (نتيجة الشراء ثم تحديث بيانات العميل ثم الإقلاع
//     التالي). السجلّ بلا حدّ أقصى، وينجو من «البدء من جديد» (بادئة
//     `rc_` في ProgressStore): RevenueCat يعيد السجلّ كله في كل مرة،
//     فمعرّف يسقط من هنا يعود «جديدا».
//   - **معرّف واحد للمعاملة: معرّف RevenueCat من CustomerInfo.** نتيجة
//     purchase() تحمل على أندرويد رقم طلب Google (GPA.…)، وCustomerInfo
//     يحمل للمعاملة نفسها معرّف RevenueCat — مفتاحان لشراء واحد كانا
//     تسليمين. لذلك لا يُقرأ storeTransaction أبدا: الشراء الجديد هو أحدث
//     معاملة لم تُسلَّم من المنتج نفسه في CustomerInfo الذي يعود معه.
//   - **ما يصل والشراء جارٍ يُمسك.** تحديث بيانات العميل قد يسبق نتيجة
//     الشراء نفسه؛ معاملة منتجٍ شراؤه جارٍ تنتظر النتيجة كي تُسلَّم مرة
//     واحدة بوصفها شراء جديدا (مع بشارتها).
//   - **المعاملة المعروفة سلفا ليست شراء جديدا.** عند أول تشغيل لهذا
//     الإصدار على الجهاز يُحفظ «خطّ أساس» زمني. معاملة أقدم منه شراء قديم
//     عاد عبر الاستعادة: ما لا يُستهلك (إزالة الإعلانات، حزمة البداية)
//     تُستعاد ملكيته وحدها بلا عملات ولا هدايا، وحزم العملات لا تُسلَّم
//     ثانية إطلاقا. معاملة أحدث منه شراء على هذا التثبيت لم يُسلَّم بعد
//     (أُغلق التطبيق بين الدفع والتسليم، أو دفع معلَّق اعتُمد لاحقا): تسليم
//     كامل.
//   - كل شيء صامت الفشل: خطأ في الدفع يُسجَّل ولا يُسقط اللعبة.
//
// في لوحة RevenueCat يجب أن يكون remove_ads وstarter_pack من نوع
// **Non-consumable**؛ وإلا استهلكهما RevenueCat فلا يعودان على تثبيت جديد.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:shared_preferences/shared_preferences.dart';

import '../iap_service.dart';
import 'store_catalog.dart';

/// معاملة شراء غير اشتراكية كما يراها RevenueCat
class RcTransaction {
  final String id;
  final String sku;

  /// null = تاريخ لم يُفهم: يُعامَل قديما (لا عملات مجانية بالخطأ)
  final DateTime? purchasedAt;

  const RcTransaction({required this.id, required this.sku, this.purchasedAt});
}

enum RcBuyStatus { purchased, cancelled, pending, alreadyOwned, failed }

class RcBuyOutcome {
  final RcBuyStatus status;

  /// بعد شراء ناجح: معاملات العميل كما أعادها RevenueCat، والشراء الجديد
  /// بينها
  final List<RcTransaction> transactions;
  final String? error;

  const RcBuyOutcome(this.status, {this.transactions = const [], this.error});
}

/// الحدّ الرقيق بين القواعد وحزمة RevenueCat. التنفيذ الحقيقي
/// [PluginRevenueCatGateway]؛ الاختبارات تمرّر بديلا.
abstract class RevenueCatGateway {
  Future<void> configure();

  /// sku → السعر المعروض بعملة اللاعب، لما وُجد منها فقط
  Future<Map<String, String>> queryPrices(Set<String> ids);

  Future<RcBuyOutcome> buy(String sku);

  /// كل المعاملات غير الاشتراكية للعميل
  Future<List<RcTransaction>> transactions();

  /// يُطلَق كلما تغيّرت بيانات العميل (شراء معلَّق اعتُمد، استعادة…)
  Stream<List<RcTransaction>> get transactionUpdates;

  /// يستعيد ما يملكه حساب المتجر ولا يعرفه هذا العميل
  Future<void> restore();
}

class RevenueCatIapService extends ChangeNotifier implements IapService {
  RevenueCatIapService({required this.gateway, required this.prefs});

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final RevenueCatGateway gateway;
  final SharedPreferences prefs;

  static const deliveredKey = 'rc_delivered_transactions';
  static const baselineKey = 'rc_install_baseline';

  final _prices = <String, String>{};
  final _waiting = <String>{};
  final _queued = <RcTransaction>[];

  /// معاملات منتجٍ شراؤه جارٍ — تُحسم بعد نتيجة الشراء
  final _held = <RcTransaction>[];
  bool _configured = false;
  bool _synced = false;
  PurchaseFulfiller? _fulfiller;
  StreamSubscription<List<RcTransaction>>? _subscription;
  Future<void>? _loading;

  /// المعالجة متسلسلة كي لا تُسلَّم معاملة واحدة مرتين في سباق
  Future<void> _chain = Future.value();

  @override
  Listenable get changes => this;

  /// ما قبله شراء قديم عاد بالاستعادة — راجع رأس الملف
  late final DateTime _baseline = _readOrCreateBaseline();

  DateTime _readOrCreateBaseline() {
    final stored = prefs.getInt(baselineKey);
    if (stored != null) return DateTime.fromMillisecondsSinceEpoch(stored);
    final now = DateTime.now();
    unawaited(prefs.setInt(baselineKey, now.millisecondsSinceEpoch));
    return now;
  }

  @override
  Future<void> init() async {
    _baseline; // يُثبَّت قبل أي معاملة تصل
    await refresh();
  }

  @override
  Future<void> refresh() {
    if (_configured && _prices.length == SkuIds.forSale.length) {
      return Future.value();
    }
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    try {
      if (!_configured) {
        await gateway.configure();
        _configured = true;
        _subscription ??= gateway.transactionUpdates.listen(
          (list) => _enqueue(() => _reconcile(list)),
          onError: (Object e) =>
              debugPrint('RevenueCat: خطأ في التحديثات — $e'),
        );
      }
      _prices.addAll(await gateway.queryPrices(SkuIds.forSale));
      notifyListeners();
      // مرة واحدة لكل تشغيل: ما اكتمل ولم يُسلَّم (أُغلق التطبيق بين الدفع
      // والتسليم، دفع معلَّق اعتُمد والتطبيق مغلق). ما يملكه حساب المتجر
      // على تثبيت جديد يرسله RevenueCat بنفسه عند الإقلاع فيصل بالتحديثات
      if (!_synced) {
        _synced = true;
        final list = await gateway.transactions();
        _enqueue(() => _reconcile(list));
      }
    } catch (e) {
      debugPrint('RevenueCat: فشلت التهيئة — $e');
    }
  }

  @override
  void attachFulfiller(PurchaseFulfiller fulfiller) {
    _fulfiller = fulfiller;
    if (_queued.isEmpty) return;
    final pending = List.of(_queued);
    _queued.clear();
    _enqueue(() => _reconcile(pending));
  }

  @override
  void detachFulfiller(PurchaseFulfiller fulfiller) {
    if (_fulfiller == fulfiller) _fulfiller = null;
  }

  @override
  String? priceOf(String sku) => _configured ? _prices[sku] : null;

  @override
  Future<PurchaseResult> buy(String sku) async {
    if (priceOf(sku) == null) {
      return const PurchaseResult(PurchaseStatus.unavailable);
    }
    // نقرتان سريعتان لا تفتحان ورقتي دفع
    if (!_waiting.add(sku)) {
      return const PurchaseResult(PurchaseStatus.failed, error: 'in_progress');
    }
    var after = const <RcTransaction>[];
    try {
      final outcome = await gateway.buy(sku);
      after = outcome.transactions;
      switch (outcome.status) {
        case RcBuyStatus.purchased:
          final done = Completer<Delivery>();
          _enqueue(() async {
            try {
              final tx = _justBought(after, sku);
              done.complete(
                tx == null ? Delivery.none : await _settle(tx, fresh: true),
              );
            } catch (e, s) {
              done.completeError(e, s);
            }
          });
          try {
            return PurchaseResult(
              PurchaseStatus.success,
              delivery: await done.future,
            );
          } catch (e) {
            // دُفع ولم يُسلَّم: المطابقة التالية تعيد التسليم. «قيد
            // المعالجة» أصدق هنا من «حاول مجددا» التي تدفعه لدفعٍ ثان
            debugPrint('RevenueCat: فشل تسليم $sku — $e');
            return PurchaseResult(PurchaseStatus.pending, error: '$e');
          }
        case RcBuyStatus.pending:
          return const PurchaseResult(PurchaseStatus.pending);
        case RcBuyStatus.cancelled:
          return const PurchaseResult(PurchaseStatus.cancelled);
        case RcBuyStatus.alreadyOwned:
          // يملكه الحساب ولا يعرفه هذا التثبيت: يُستعاد الآن
          unawaited(_restoreOwned());
          return PurchaseResult(
            PurchaseStatus.alreadyOwned,
            error: outcome.error,
          );
        case RcBuyStatus.failed:
          return PurchaseResult(PurchaseStatus.failed, error: outcome.error);
      }
    } catch (e) {
      return PurchaseResult(PurchaseStatus.failed, error: '$e');
    } finally {
      _waiting.remove(sku);
      // ما أُمسك والشراء جارٍ، وبقية ما أعاده الشراء
      final rest = [..._held, ...after];
      _held.clear();
      if (rest.isNotEmpty) _enqueue(() => _reconcile(rest));
    }
  }

  /// الشراء الذي تمّ للتوّ: أحدث معاملة لم تُسلَّم من المنتج نفسه. ما
  /// سواها (معلَّق اعتُمد، قديم عاد بالاستعادة) يُحسم بعده بقواعده
  RcTransaction? _justBought(List<RcTransaction> list, String sku) {
    final delivered = _delivered;
    RcTransaction? newest;
    for (final tx in list) {
      if (tx.sku != sku || delivered.contains(tx.id)) continue;
      final at = tx.purchasedAt;
      final best = newest?.purchasedAt;
      if (newest == null ||
          (at != null && (best == null || at.isAfter(best)))) {
        newest = tx;
      }
    }
    return newest;
  }

  Future<void> _restoreOwned() async {
    try {
      await gateway.restore();
      final list = await gateway.transactions();
      _enqueue(() => _reconcile(list));
    } catch (e) {
      debugPrint('RevenueCat: فشلت الاستعادة — $e');
    }
  }

  void _enqueue(Future<void> Function() task) {
    _chain = _chain.then((_) => task()).catchError((Object e) {
      debugPrint('RevenueCat: فشلت معالجة شراء — $e');
    });
  }

  Future<void> _reconcile(List<RcTransaction> list) async {
    for (final tx in list) {
      // معاملة تفشل لا تحبس ما بعدها؛ هي نفسها تعود في المطابقة التالية
      try {
        await _settle(tx, fresh: false);
      } catch (e) {
        debugPrint('RevenueCat: فشل تسليم ${tx.sku} — $e');
      }
    }
  }

  /// [fresh] = جاءت للتوّ من شراء أجراه اللاعب الآن
  Future<Delivery> _settle(RcTransaction tx, {required bool fresh}) async {
    // منتج لا نبيعه (اشتراك مستقبلي مثلا): لا نلمسه
    if (!SkuIds.forSale.contains(tx.sku)) return Delivery.none;
    if (_delivered.contains(tx.id)) return Delivery.none;
    // قد تكون هي الشراء الجاري نفسه سبق تحديثُه نتيجتَه: تنتظرها
    if (!fresh && _waiting.contains(tx.sku)) {
      _held.add(tx);
      return Delivery.none;
    }

    final purchasedAt = tx.purchasedAt;
    final isNew =
        fresh || (purchasedAt != null && !purchasedAt.isBefore(_baseline));
    final consumable = SkuIds.consumables.contains(tx.sku);
    // حزمة عملات قديمة عادت بالاستعادة: سُلِّمت على تثبيتها الأصلي
    if (consumable && !isNew) {
      _markDelivered(tx.id);
      return Delivery.none;
    }

    final fulfiller = _fulfiller;
    if (fulfiller == null) {
      _queued.add(tx);
      return Delivery.none;
    }
    final delivery = await fulfiller(tx.sku, fullDelivery: isNew);
    _markDelivered(tx.id);
    return delivery;
  }

  List<String> get _delivered => prefs.getStringList(deliveredKey) ?? const [];

  void _markDelivered(String id) =>
      unawaited(prefs.setStringList(deliveredKey, [..._delivered, id]));

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// التنفيذ الحقيقي فوق purchases_flutter
class PluginRevenueCatGateway implements RevenueCatGateway {
  PluginRevenueCatGateway({required this.apiKey});

  final String apiKey;
  final _products = <String, rc.StoreProduct>{};
  final _updates = StreamController<List<RcTransaction>>.broadcast();

  @override
  Future<void> configure() async {
    if (!kReleaseMode) await rc.Purchases.setLogLevel(rc.LogLevel.debug);
    await rc.Purchases.configure(rc.PurchasesConfiguration(apiKey));
    rc.Purchases.addCustomerInfoUpdateListener(
      (info) => _updates.add(_transactionsOf(info)),
    );
  }

  @override
  Future<Map<String, String>> queryPrices(Set<String> ids) async {
    final products = await rc.Purchases.getProducts(
      ids.toList(),
      productCategory: rc.ProductCategory.nonSubscription,
    );
    final found = {for (final p in products) p.identifier: p};
    final missing = ids.difference(found.keys.toSet());
    if (missing.isNotEmpty) {
      // منتج لم يُنشأ (أو لم يُفعَّل) في المتجر أو في RevenueCat: يختفي
      debugPrint('RevenueCat: منتجات غير موجودة — $missing');
    }
    _products.addAll(found);
    return {for (final p in found.values) p.identifier: p.priceString};
  }

  @override
  Future<RcBuyOutcome> buy(String sku) async {
    final product = _products[sku];
    if (product == null) return const RcBuyOutcome(RcBuyStatus.failed);
    try {
      final result = await rc.Purchases.purchase(
        rc.PurchaseParams.storeProduct(product),
      );
      // لا result.storeTransaction: معرّفه رقم طلب Google — راجع رأس الملف
      return RcBuyOutcome(
        RcBuyStatus.purchased,
        transactions: _transactionsOf(result.customerInfo),
      );
    } on PlatformException catch (e) {
      final status = switch (rc.PurchasesErrorHelper.getErrorCode(e)) {
        rc.PurchasesErrorCode.purchaseCancelledError => RcBuyStatus.cancelled,
        rc.PurchasesErrorCode.paymentPendingError => RcBuyStatus.pending,
        rc.PurchasesErrorCode.productAlreadyPurchasedError =>
          RcBuyStatus.alreadyOwned,
        _ => RcBuyStatus.failed,
      };
      return RcBuyOutcome(status, error: e.message);
    }
  }

  @override
  Future<List<RcTransaction>> transactions() async =>
      _transactionsOf(await rc.Purchases.getCustomerInfo());

  @override
  Stream<List<RcTransaction>> get transactionUpdates => _updates.stream;

  @override
  Future<void> restore() => rc.Purchases.restorePurchases();

  static List<RcTransaction> _transactionsOf(rc.CustomerInfo info) => [
    for (final t in info.nonSubscriptionTransactions) _toTransaction(t),
  ];

  static RcTransaction _toTransaction(rc.StoreTransaction t) => RcTransaction(
    id: t.transactionIdentifier,
    sku: t.productIdentifier,
    purchasedAt: DateTime.tryParse(t.purchaseDate),
  );
}
