// قواعد التسليم فوق RevenueCat (RevenueCatIapService) ببوّابة مزيّفة.
//
// كل اختبار هنا يقابل طريقة حقيقية يخسر بها لاعبٌ ماله أو يكسب بها ما لم
// يدفعه: تسليم مكرّر، إعادة تثبيت تعيد العملات، شراء اكتمل والتطبيق مغلق
// فلا يُسلَّم، دفع معلَّق يضيع بعد اعتماده.
//
// البوّابة المزيّفة تتصرّف كـRevenueCat: لكل شراء معرّف جديد، وتحديث
// بيانات العميل يصل قبل نتيجة الشراء نفسه.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/iap_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/store/revenuecat_iap_service.dart';
import 'package:huruf/data/store/store_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeGateway implements RevenueCatGateway {
  bool configureFails = false;
  final prices = <String, String>{
    for (final sku in SkuIds.forSale) sku: 'EGP ${sku.length}.99',
  };

  /// ما ينتهي إليه الشراء التالي؛ null = ينجح
  RcBuyStatus? next;

  /// كما يفعل RevenueCat: تحديث بيانات العميل يسبق نتيجة الشراء
  bool updateBeforeResult = true;

  /// معاملات العميل كما يراها RevenueCat
  final owned = <RcTransaction>[];
  final _updates = StreamController<List<RcTransaction>>.broadcast();
  final bought = <String>[];
  int restores = 0;
  int _seq = 0;

  /// معاملة على خادم RevenueCat بمعرّف جديد
  RcTransaction add(String sku, {DateTime? at}) {
    final tx = RcTransaction(id: 'rc-${++_seq}', sku: sku, purchasedAt: at);
    owned.add(tx);
    return tx;
  }

  void emit([List<RcTransaction>? list]) =>
      _updates.add(list ?? List.of(owned));

  @override
  Future<void> configure() async {
    if (configureFails) throw StateError('no network');
  }

  @override
  Future<Map<String, String>> queryPrices(Set<String> ids) async => {
    for (final id in ids) id: ?prices[id],
  };

  @override
  Future<RcBuyOutcome> buy(String sku) async {
    bought.add(sku);
    if (next case final status?) return RcBuyOutcome(status);
    add(sku, at: DateTime.now());
    if (updateBeforeResult) emit();
    return RcBuyOutcome(RcBuyStatus.purchased, transactions: List.of(owned));
  }

  @override
  Future<List<RcTransaction>> transactions() async => List.of(owned);

  @override
  Stream<List<RcTransaction>> get transactionUpdates => _updates.stream;

  @override
  Future<void> restore() async => restores++;
}

Future<void> _drain() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Rig {
  _Rig(this.prefs, [_FakeGateway? gateway])
    : gateway = gateway ?? _FakeGateway() {
    service = RevenueCatIapService(gateway: this.gateway, prefs: prefs);
  }

  final SharedPreferences prefs;
  final _FakeGateway gateway;
  late final RevenueCatIapService service;

  /// sku:full أو sku:restore بترتيب التسليم
  final delivered = <String>[];

  /// يرمي في التسليمات الأولى بهذا العدد
  int failNext = 0;

  Future<Delivery> fulfill(String sku, {required bool fullDelivery}) async {
    if (failNext > 0) {
      failNext--;
      throw StateError('disk full');
    }
    delivered.add('$sku:${fullDelivery ? 'full' : 'restore'}');
    return Delivery(coins: fullDelivery ? 100 : 0);
  }

  Future<void> start({bool attach = true}) async {
    if (attach) service.attachFulfiller(fulfill);
    await service.init();
    await _drain();
  }

  /// «إقلاع تالٍ»: خدمة جديدة على الجهاز نفسه وحساب RevenueCat نفسه
  _Rig relaunch() {
    final next = _FakeGateway()..owned.addAll(gateway.owned);
    return _Rig(prefs, next);
  }
}

final _old = DateTime(2020);
final _future = DateTime.now().add(const Duration(days: 1));

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('شراء ناجح', () {
    test('يُسلَّم كاملا ويعيد ما سُلِّم', () async {
      final rig = _Rig(prefs);
      await rig.start();

      final result = await rig.service.buy(SkuIds.coins500);
      await _drain();

      expect(result.status, PurchaseStatus.success);
      expect(result.delivery.coins, 100);
      expect(rig.delivered, ['${SkuIds.coins500}:full']);
    });

    test(
      'تحديث بيانات العميل يسبق النتيجة: تسليم واحد، والبشارة باقية',
      () async {
        // البوّابة تطلق التحديث قبل أن تعيد النتيجة، ثم يتكرّر بعدها
        final rig = _Rig(prefs);
        await rig.start();

        final result = await rig.service.buy(SkuIds.coins500);
        rig.gateway.emit();
        await _drain();

        expect(rig.delivered, ['${SkuIds.coins500}:full']);
        expect(result.delivery.coins, 100);
      },
    );

    test('ولا يُسلَّم ثانية في الإقلاع التالي', () async {
      final first = _Rig(prefs);
      await first.start();
      await first.service.buy(SkuIds.coins500);
      await _drain();

      final second = first.relaunch();
      await second.start();

      expect(second.delivered, isEmpty);
    });

    test('ساعة الجهاز متقدّمة: الشراء الجاري يُسلَّم رغم خطّ الأساس', () async {
      await prefs.setInt(
        RevenueCatIapService.baselineKey,
        _future.millisecondsSinceEpoch,
      );
      final rig = _Rig(prefs);
      await rig.start();

      final result = await rig.service.buy(SkuIds.coins1650);
      await _drain();

      expect(result.delivery.coins, 100);
      expect(rig.delivered, ['${SkuIds.coins1650}:full']);
    });

    test(
      'فشل التسليم بعد الدفع: لا تعليق، «قيد المعالجة»، ثم تسليم واحد',
      () async {
        final rig = _Rig(prefs)..failNext = 1;
        await rig.start();

        final result = await rig.service.buy(SkuIds.coins500);
        await _drain();

        expect(result.status, PurchaseStatus.pending);
        // المطابقة بعد الشراء أعادت المحاولة فنجحت
        expect(rig.delivered, ['${SkuIds.coins500}:full']);

        rig.gateway.emit();
        await _drain();
        expect(rig.delivered, hasLength(1));
      },
    );
  });

  group('إلغاء', () {
    test('إغلاق ورقة الدفع: لا تسليم ولا قيد', () async {
      final rig = _Rig(prefs);
      await rig.start();
      rig.gateway.next = RcBuyStatus.cancelled;

      final result = await rig.service.buy(SkuIds.coins500);
      await _drain();

      expect(result.status, PurchaseStatus.cancelled);
      expect(rig.delivered, isEmpty);
      expect(prefs.getStringList(RevenueCatIapService.deliveredKey), isNull);
    });

    test('والشراء بعده يعمل', () async {
      final rig = _Rig(prefs);
      await rig.start();
      rig.gateway.next = RcBuyStatus.cancelled;
      await rig.service.buy(SkuIds.coins500);

      rig.gateway.next = null;
      final result = await rig.service.buy(SkuIds.coins500);

      expect(result.status, PurchaseStatus.success);
      expect(rig.delivered, ['${SkuIds.coins500}:full']);
    });
  });

  group('معلَّق (Pending)', () {
    test('لا تسليم الآن، وتسليم كامل واحد حين يُعتمد', () async {
      final rig = _Rig(prefs);
      await rig.start();
      rig.gateway.next = RcBuyStatus.pending;

      final result = await rig.service.buy(SkuIds.coins1650);
      await _drain();
      expect(result.status, PurchaseStatus.pending);
      expect(rig.delivered, isEmpty);

      // اعتُمد الدفع: RevenueCat يسجّله ويطلق التحديث
      rig.gateway.add(SkuIds.coins1650, at: DateTime.now());
      rig.gateway.emit();
      await _drain();
      expect(rig.delivered, ['${SkuIds.coins1650}:full']);

      rig.gateway.emit();
      await _drain();
      expect(rig.delivered, hasLength(1));
    });

    test('اعتُمد والتطبيق مغلق: يُسلَّم كاملا عند الإقلاع', () async {
      // التثبيت قائم منذ أمس، والدفع اعتُمد اليوم
      await prefs.setInt(
        RevenueCatIapService.baselineKey,
        DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      );
      final rig = _Rig(prefs);
      rig.gateway.add(SkuIds.coins500, at: DateTime.now());
      await rig.start();

      expect(rig.delivered, ['${SkuIds.coins500}:full']);
    });

    test('يُعتمد وشراء المنتج نفسه جارٍ: كلاهما يُسلَّم مرة', () async {
      await prefs.setInt(
        RevenueCatIapService.baselineKey,
        DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      );
      final rig = _Rig(prefs);
      await rig.start();
      rig.gateway.next = RcBuyStatus.pending;
      await rig.service.buy(SkuIds.coins500);

      // اعتُمد المعلَّق (أقدم) في اللحظة التي يشتري فيها اللاعب ثانية
      rig.gateway.add(
        SkuIds.coins500,
        at: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      rig.gateway.next = null;
      final result = await rig.service.buy(SkuIds.coins500);
      await _drain();

      expect(result.delivery.coins, 100);
      expect(rig.delivered, [
        '${SkuIds.coins500}:full',
        '${SkuIds.coins500}:full',
      ]);
    });
  });

  group('شراء مكرّر', () {
    test('حزم العملات تُشترى مرارا: كل شراء يُسلَّم مرة', () async {
      final rig = _Rig(prefs);
      await rig.start();

      for (var i = 0; i < 3; i++) {
        final result = await rig.service.buy(SkuIds.coins4800);
        expect(result.status, PurchaseStatus.success);
      }
      rig.gateway.emit();
      await _drain();

      expect(rig.delivered, List.filled(3, '${SkuIds.coins4800}:full'));
      expect(
        prefs.getStringList(RevenueCatIapService.deliveredKey),
        hasLength(3),
      );
    });

    test('المعاملة نفسها من كل الطرق (النتيجة، التحديث، الإقلاع، الاستعادة): '
        'تسليم واحد', () async {
      final rig = _Rig(prefs);
      await rig.start();
      await rig.service.buy(SkuIds.coins500);
      rig.gateway.emit();
      rig.gateway.emit();
      await _drain();
      await rig.service.refresh();
      await _drain();

      final next = rig.relaunch();
      await next.start();

      expect(rig.delivered, hasLength(1));
      expect(next.delivered, isEmpty);
    });

    test(
      'إزالة الإعلانات مرة ثانية: «تملكه»، استعادة، ولا هدية ثانية',
      () async {
        final rig = _Rig(prefs);
        await rig.start();
        await rig.service.buy(SkuIds.removeAds);
        await _drain();
        expect(rig.delivered, ['${SkuIds.removeAds}:full']);

        rig.gateway.next = RcBuyStatus.alreadyOwned;
        final again = await rig.service.buy(SkuIds.removeAds);
        await _drain();

        expect(again.status, PurchaseStatus.alreadyOwned);
        expect(rig.gateway.restores, 1);
        expect(rig.delivered, ['${SkuIds.removeAds}:full']);
      },
    );

    test(
      'إزالة الإعلانات على تثبيت جديد: «تملكه» يستعيد الملكية بلا هدية',
      () async {
        final rig = _Rig(prefs);
        rig.gateway.add(SkuIds.removeAds, at: _old);
        // RevenueCat لم يُرسل المملوك بعد حين ضغط اللاعب «شراء»
        final owned = List.of(rig.gateway.owned);
        rig.gateway.owned.clear();
        await rig.start();

        rig.gateway.next = RcBuyStatus.alreadyOwned;
        rig.gateway.owned.addAll(owned);
        final result = await rig.service.buy(SkuIds.removeAds);
        await _drain();

        expect(result.status, PurchaseStatus.alreadyOwned);
        expect(rig.delivered, ['${SkuIds.removeAds}:restore']);
      },
    );

    test('نقرتان سريعتان لا تفتحان ورقتي دفع', () async {
      final rig = _Rig(prefs);
      final gate = Completer<void>();
      final service = RevenueCatIapService(
        gateway: _SlowGateway(rig.gateway, gate),
        prefs: prefs,
      )..attachFulfiller(rig.fulfill);
      await service.init();

      final first = service.buy(SkuIds.coins500);
      final second = await service.buy(SkuIds.coins500);
      gate.complete();
      await first;

      expect(second.error, 'in_progress');
      expect(rig.gateway.bought, [SkuIds.coins500]);
      expect(rig.delivered, hasLength(1));
    });
  });

  group('الإتاحة', () {
    test('منتج بلا سعر لا يُباع', () async {
      final rig = _Rig(prefs);
      rig.gateway.prices.remove(SkuIds.coins16000);
      await rig.start();

      expect(rig.service.priceOf(SkuIds.coins16000), isNull);
      final result = await rig.service.buy(SkuIds.coins16000);
      expect(result.status, PurchaseStatus.unavailable);
      expect(rig.gateway.bought, isEmpty);
    });

    test('فشل التهيئة: لا أسعار ولا استثناء', () async {
      final rig = _Rig(prefs);
      rig.gateway.configureFails = true;
      await rig.start();

      expect(rig.service.priceOf(SkuIds.coins500), isNull);
    });
  });

  group('الإقلاع وإعادة التثبيت', () {
    test('حزمة عملات قديمة عادت بالاستعادة لا تُسلَّم ثانية', () async {
      final rig = _Rig(prefs);
      rig.gateway.add(SkuIds.coins4800, at: _old);
      await rig.start();

      expect(rig.delivered, isEmpty);
    });

    test('إزالة إعلانات قديمة: تُستعاد الملكية بلا هدايا', () async {
      final rig = _Rig(prefs);
      rig.gateway.add(SkuIds.removeAds, at: _old);
      await rig.start();

      expect(rig.delivered, ['${SkuIds.removeAds}:restore']);
    });

    test(
      'المملوك يصل بعد الإقلاع (مزامنة RevenueCat التلقائية): يُستعاد',
      () async {
        final rig = _Rig(prefs);
        await rig.start();

        rig.gateway.add(SkuIds.removeAds, at: _old);
        rig.gateway.emit();
        await _drain();

        expect(rig.delivered, ['${SkuIds.removeAds}:restore']);
      },
    );

    test('تاريخ غير مفهوم يُعامَل قديما', () async {
      final rig = _Rig(prefs);
      rig.gateway.add(SkuIds.coins500);
      await rig.start();

      expect(rig.delivered, isEmpty);
    });

    test('خطّ الأساس يُحفظ مرة واحدة ولا يتقدّم مع كل إقلاع', () async {
      await _Rig(prefs).start();
      final stored = prefs.getInt(RevenueCatIapService.baselineKey);
      expect(stored, isNotNull);

      await _Rig(prefs).start();
      expect(prefs.getInt(RevenueCatIapService.baselineKey), stored);
    });

    test(
      'سجلّ طويل لا يُقصّ: لا شيء يُسلَّم ثانية بعد مئات المشتريات',
      () async {
        final rig = _Rig(prefs)..gateway.updateBeforeResult = false;
        await rig.start();
        for (var i = 0; i < 205; i++) {
          await rig.service.buy(SkuIds.coins500);
        }
        await _drain();
        expect(rig.delivered, hasLength(205));

        final next = rig.relaunch();
        await next.start();
        expect(next.delivered, isEmpty);
      },
    );

    test('«البدء من جديد» لا يمسح السجلّ: لا تسليم ثان', () async {
      final rig = _Rig(prefs);
      await rig.start();
      await rig.service.buy(SkuIds.coins500);
      await rig.service.buy(SkuIds.removeAds);
      await _drain();
      final baseline = prefs.getInt(RevenueCatIapService.baselineKey);

      await ProgressStore(prefs).resetProgress();

      expect(prefs.getInt(RevenueCatIapService.baselineKey), baseline);
      final next = rig.relaunch();
      await next.start();
      expect(next.delivered, isEmpty);
    });

    test('ما اكتمل قبل وصول المُسلِّم ينتظر ثم يُسلَّم', () async {
      final rig = _Rig(prefs);
      await rig.start(attach: false);
      rig.gateway.add(SkuIds.coins500, at: _future);
      rig.gateway.emit();
      await _drain();
      expect(rig.delivered, isEmpty);

      rig.service.attachFulfiller(rig.fulfill);
      await _drain();
      expect(rig.delivered, ['${SkuIds.coins500}:full']);
    });

    test('منتج لا نبيعه لا يُلمس', () async {
      final rig = _Rig(prefs);
      await rig.start();
      rig.gateway.add('something_else', at: _future);
      rig.gateway.emit();
      await _drain();

      expect(rig.delivered, isEmpty);
    });
  });
}

/// بوّابة يبقى شراؤها معلّقا حتى يُفتح [gate]
class _SlowGateway implements RevenueCatGateway {
  _SlowGateway(this.inner, this.gate);

  final _FakeGateway inner;
  final Completer<void> gate;

  @override
  Future<RcBuyOutcome> buy(String sku) async {
    final outcome = await inner.buy(sku);
    await gate.future;
    return outcome;
  }

  @override
  Future<void> configure() => inner.configure();

  @override
  Future<Map<String, String>> queryPrices(Set<String> ids) =>
      inner.queryPrices(ids);

  @override
  Future<void> restore() => inner.restore();

  @override
  Future<List<RcTransaction>> transactions() => inner.transactions();

  @override
  Stream<List<RcTransaction>> get transactionUpdates =>
      inner.transactionUpdates;
}
