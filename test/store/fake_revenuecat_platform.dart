// RevenueCat مزيّف خلف قناة purchases_flutter: يردّ بالأشكال التي يرسلها
// الجسر الأصلي على أندرويد (purchases-hybrid-common 19.14)، بما فيها ما
// أوقع التسليم المزدوج: نتيجة الشراء تحمل رقم طلب Google (GPA.…)، و
// CustomerInfo يحمل للمعاملة نفسها معرّف RevenueCat. وكما في الأصل، يُطلَق
// تحديث بيانات العميل قبل أن تعود نتيجة الشراء.
//
// ليس ملف اختبار — تستورده اختبارات المتجر.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// ما ينتهي إليه الشراء التالي
enum NextBuy { success, cancelled, pending, alreadyOwned, error }

class FakeRevenueCat {
  FakeRevenueCat({Map<String, String>? prices}) : prices = prices ?? const {};

  static const channel = MethodChannel('purchases_flutter');

  /// sku → priceString. ما ليس هنا «غير موجود في المتجر»
  final Map<String, String> prices;

  /// معاملات العميل على خادم RevenueCat (nonSubscriptionTransactions)
  final transactions = <Map<String, Object?>>[];
  NextBuy next = NextBuy.success;

  /// أسماء الطرق التي استدعاها التطبيق، بالترتيب
  final calls = <String>[];
  int _seq = 0;

  TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void install() {
    _messenger.setMockMethodCallHandler(channel, _handle);
    addTearDown(() async {
      // purchases_flutter يحفظ آخر CustomerInfo في متغيّر ساكن ويسلّمه لكل
      // مستمع جديد: لا يتسرّب اختبار إلى ما بعده
      transactions.clear();
      await pushCustomerInfo();
      _messenger.setMockMethodCallHandler(channel, null);
    });
  }

  /// معاملة يملكها العميل على الخادم (شراء قديم، أو معلَّق اعتُمد). يعيد
  /// معرّف RevenueCat
  String addTransaction(String sku, DateTime at) {
    final id = 'rc_tx_${++_seq}';
    transactions.add({
      'transactionIdentifier': id,
      'revenueCatId': id,
      'productIdentifier': sku,
      'productId': sku,
      'purchaseDateMillis': at.millisecondsSinceEpoch,
      'purchaseDate': at.toUtc().toIso8601String(),
    });
    return id;
  }

  /// يدفع CustomerInfo الحالي إلى التطبيق كما يفعل المستمع الأصلي
  Future<void> pushCustomerInfo() async {
    await _messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('Purchases-CustomerInfoUpdated', customerInfo()),
      ),
      (_) {},
    );
  }

  Map<String, Object?> customerInfo() => {
    'entitlements': {'all': {}, 'active': {}, 'verification': 'NOT_REQUESTED'},
    'allPurchaseDates': {},
    'activeSubscriptions': <String>[],
    'allPurchasedProductIdentifiers': [
      for (final t in transactions) t['productIdentifier'],
    ],
    'nonSubscriptionTransactions': List.of(transactions),
    'firstSeen': '2026-10-01T00:00:00.000Z',
    'originalAppUserId': r'$RCAnonymousID:test',
    'allExpirationDates': {},
    'requestDate': DateTime.now().toUtc().toIso8601String(),
  };

  Future<Object?> _handle(MethodCall call) async {
    calls.add(call.method);
    final args = call.arguments is Map
        ? Map<String, Object?>.from(call.arguments as Map)
        : const <String, Object?>{};
    switch (call.method) {
      case 'getProductInfo':
        final ids = List<String>.from(args['productIdentifiers'] as List);
        return [
          for (final id in ids)
            if (prices[id] case final price?) _product(id, price),
        ];
      case 'purchaseProduct':
        return _purchase(args['productIdentifier'] as String);
      case 'getCustomerInfo':
      case 'restorePurchases':
        return customerInfo();
      default:
        // setupPurchases، setLogLevel…
        return null;
    }
  }

  Future<Map<String, Object?>> _purchase(String sku) async {
    switch (next) {
      case NextBuy.cancelled:
        throw _error(PurchasesErrorCode.purchaseCancelledError);
      case NextBuy.pending:
        throw _error(PurchasesErrorCode.paymentPendingError);
      case NextBuy.alreadyOwned:
        throw _error(PurchasesErrorCode.productAlreadyPurchasedError);
      case NextBuy.error:
        throw _error(PurchasesErrorCode.storeProblemError);
      case NextBuy.success:
        break;
    }
    final at = DateTime.now();
    addTransaction(sku, at);
    await pushCustomerInfo();
    return {
      'customerInfo': customerInfo(),
      'transaction': {
        'transactionIdentifier':
            'GPA.3300-0000-0000-${_seq.toString().padLeft(5, '0')}',
        'productIdentifier': sku,
        'purchaseDateMillis': at.millisecondsSinceEpoch,
        'purchaseDate': at.toUtc().toIso8601String(),
      },
    };
  }

  static Map<String, Object?> _product(String id, String price) => {
    'identifier': id,
    'description': id,
    'title': id,
    'price': 1.0,
    'priceString': price,
    'currencyCode': 'EGP',
    'productCategory': 'NON_SUBSCRIPTION',
  };

  static PlatformException _error(PurchasesErrorCode code) =>
      PlatformException(code: '${code.index}', message: code.name);
}
