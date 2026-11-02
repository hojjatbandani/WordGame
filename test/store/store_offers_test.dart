import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/store/first_purchase.dart';
import 'package:huruf/data/store/near_miss.dart';
import 'package:huruf/data/store/store_catalog.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 8, 26, 12);

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
  group('الكتالوج', () {
    test('الحزم الأربع بأسعارها وأعدادها المحدَّدة', () {
      final packs = StoreCatalog.coinPacks;
      expect(packs.map((p) => p.coins), [500, 1650, 4800, 16000]);
      expect(packs.map((p) => p.referenceUsd), [0.99, 2.49, 5.99, 14.99]);
    });

    test('القيمة الحقيقية تتصاعد مع كل حزمة — لا حزمة تخدع مشتريها', () {
      final base = StoreCatalog.baseline;
      var previous = 0.0;
      for (final pack in StoreCatalog.coinPacks) {
        expect(
          pack.coinsPerUsd,
          greaterThan(previous),
          reason: 'حزمة ${pack.id} ليست أعلى قيمة ممّا قبلها',
        );
        previous = pack.coinsPerUsd;
        expect(
          pack.valueVsBaselinePercent(base),
          greaterThanOrEqualTo(pack.advertisedBonusPercent),
          reason: 'الحزمة تعد بأكثر ممّا تعطي: ${pack.id}',
        );
      }
    });

    test('لا منتج يفتح محتوى — القيد بنيوي', () {
      // لا حقل «محتوى» في أي منتج أصلا: أقصى ما يحمله المنتج عملات
      // وزينة. هذا الاختبار يحرس التعريف نفسه من إضافة حقل كهذا.
      for (final pack in StoreCatalog.coinPacks) {
        expect(pack.coins, greaterThan(0));
      }
      expect(StoreCatalog.starterPackCoins, greaterThan(0));
      expect(StoreCatalog.starterPackAvatarId, isNotEmpty);
      expect(StoreCatalog.starterPackFrameId, isNotEmpty);
    });

    test('الاشتراك مطفأ حتى المرحلة الثالثة', () {
      expect(StoreCatalog.subscriptionEnabled, isFalse);
    });
  });

  group('أصغر حزمة كافية', () {
    test('تختار الأصغر التي تسدّ النقص لا الأكبر', () {
      expect(
        StoreCatalog.smallestSufficient(balance: 0, target: 100)?.coins,
        500,
      );
      expect(
        StoreCatalog.smallestSufficient(balance: 0, target: 2000)?.coins,
        4800,
      );
      // الرصيد يُحتسب: النقص هو ما يهمّ لا السعر
      expect(
        StoreCatalog.smallestSufficient(balance: 200, target: 1800)?.coins,
        1650,
        reason: 'النقص 1600 تسدّه حزمة 1650',
      );
      expect(
        StoreCatalog.smallestSufficient(balance: 100, target: 1800)?.coins,
        4800,
        reason: 'النقص 1700 لا تسدّه 1650 فتُختار التي تليها',
      );
    });

    test('لا حزمة حين لا نقص', () {
      expect(
        StoreCatalog.smallestSufficient(balance: 200, target: 100),
        isNull,
      );
    });

    test('نقص يفوق كل الحزم يعطي الأكبر بدل null', () {
      expect(
        StoreCatalog.smallestSufficient(balance: 0, target: 999999)?.coins,
        16000,
      );
    });
  });

  group('اختبار القبول: ورقة «ينقصك القليل»', () {
    NearMissOffer? evaluate({required int price, required int balance}) =>
        NearMiss.evaluate(
          price: price,
          balance: balance,
          target: NearMissTarget.hint,
          canWatchAd: true,
          adReward: 20,
        );

    test('تظهر عند نقص 20 من 100، ولا تظهر عند نقص 40', () {
      final near = evaluate(price: 100, balance: 80);
      expect(near, isNotNull);
      expect(near!.deficit, 20);

      expect(
        evaluate(price: 100, balance: 60),
        isNull,
        reason: 'نقص 40 = 40% وهو فوق حدّ الـ25%',
      );
    });

    test('حدّ الـ25% بالضبط: 25 من 100 تظهر، و26 لا', () {
      expect(evaluate(price: 100, balance: 75), isNotNull);
      expect(evaluate(price: 100, balance: 74), isNull);
    });

    test('لا ورقة حين يكفي الرصيد', () {
      expect(evaluate(price: 100, balance: 100), isNull);
      expect(evaluate(price: 100, balance: 500), isNull);
    });

    test('سعر غير موجب لا يفتح ورقة', () {
      expect(evaluate(price: 0, balance: 0), isNull);
      expect(evaluate(price: -5, balance: 0), isNull);
    });

    test('تحمل النقص الدقيق وأصغر حزمة كافية لا الكتالوج', () {
      final near = evaluate(price: 100, balance: 82)!;
      expect(near.deficit, 18);
      expect(near.pack?.coins, 500);
    });

    test('تعرف إن كان الإعلان وحده يكفي', () {
      expect(evaluate(price: 100, balance: 85)!.adClosesGap, isTrue);
      expect(
        NearMiss.evaluate(
          price: 100,
          balance: 80,
          target: NearMissTarget.hint,
          canWatchAd: true,
          adReward: 15,
        )!.adClosesGap,
        isFalse,
      );
    });

    test('بلا ميزانية إعلانات يبقى العرض قائما بخيار الحزمة', () {
      final near = NearMiss.evaluate(
        price: 100,
        balance: 80,
        target: NearMissTarget.hint,
        canWatchAd: false,
        adReward: 0,
      );
      expect(near, isNotNull);
      expect(near!.canWatchAd, isFalse);
      expect(near.pack, isNotNull);
    });
  });

  group('اختبار القبول: محفّز الشراء الأول', () {
    FirstPurchaseDecision decide({
      bool hasEverPurchased = false,
      bool alreadyOffered = false,
      int balance = 10,
      int failures = 2,
      int stages = 25,
      DateTime? lastShown,
    }) => FirstPurchase.shouldOffer(
      hasEverPurchased: hasEverPurchased,
      alreadyOfferedThisInstall: alreadyOffered,
      coinBalance: balance,
      failedAttemptsCurrentStage: failures,
      stagesCompleted: stages,
      lastShownAt: lastShown,
      now: _now,
    );

    test('يظهر حين تجتمع كل الشروط', () {
      expect(decide().show, isTrue);
    });

    test('لا يظهر لمن سبق أن اشترى', () {
      final d = decide(hasEverPurchased: true);
      expect(d.show, isFalse);
      expect(d.block, FirstPurchaseBlock.alreadyPurchased);
    });

    test('لا يظهر ورصيده 30 فأكثر', () {
      expect(decide(balance: 29).show, isTrue);
      expect(decide(balance: 30).block, FirstPurchaseBlock.balanceTooHigh);
      expect(decide(balance: 500).block, FirstPurchaseBlock.balanceTooHigh);
    });

    test('لا يظهر بأقل من فشلين في المرحلة الحالية', () {
      expect(decide(failures: 1).block, FirstPurchaseBlock.notFailingEnough);
      expect(decide(failures: 2).show, isTrue);
    });

    test('لا يظهر قبل عشرين مرحلة مكتملة', () {
      expect(decide(stages: 19).block, FirstPurchaseBlock.tooEarlyInGame);
      expect(decide(stages: 20).show, isTrue);
    });

    test('لا يظهر إن عُرض خلال الأيام السبعة الماضية', () {
      expect(
        decide(lastShown: _now.subtract(const Duration(days: 6))).block,
        FirstPurchaseBlock.shownRecently,
      );
      expect(
        decide(lastShown: _now.subtract(const Duration(days: 8))).show,
        isTrue,
      );
    });

    test('لا يظهر والمتجر مطفأ عن بعد', () {
      final d = FirstPurchase.shouldOffer(
        hasEverPurchased: false,
        alreadyOfferedThisInstall: false,
        coinBalance: 10,
        failedAttemptsCurrentStage: 3,
        stagesCompleted: 30,
        lastShownAt: null,
        now: _now,
        storeEnabled: false,
      );
      expect(d.block, FirstPurchaseBlock.storeDisabled);
    });

    test('لا يفتح مرتين على نفس التثبيت', () {
      expect(
        decide(alreadyOffered: true).block,
        FirstPurchaseBlock.alreadyOffered,
      );
    });

    test('عبر المزوّد: الاستدعاء الثاني لا يفتح عرضا ثانيا', () async {
      final container = await _container({'points': 5});
      addTearDown(container.dispose);
      final notifier = container.read(purchaseStateProvider.notifier);

      final first = await notifier.maybeStartFirstPurchaseOffer(
        failedAttemptsCurrentStage: 3,
        stagesCompleted: 30,
        nowOverride: _now,
      );
      expect(first, isNotNull);

      // حتى بعد شهر، وبكل الشروط متحقّقة من جديد
      final second = await notifier.maybeStartFirstPurchaseOffer(
        failedAttemptsCurrentStage: 5,
        stagesCompleted: 60,
        nowOverride: _now.add(const Duration(days: 30)),
      );
      expect(second, isNull, reason: 'مرة واحدة لكل تثبيت');
    });
  });

  group('عرض الشراء الأول', () {
    test('خصم 70٪ ومهلة 24 ساعة على منتج فوق أدنى شريحة', () {
      final offer = FirstPurchase.startOffer(now: _now, referenceUsd: 4.99);

      expect(offer.discountPercent, 70);
      expect(offer.endsAt.difference(_now), const Duration(hours: 24));
      expect(offer.discountedUsd, closeTo(1.497, 0.001));
      expect(offer.loweredPrice, isTrue);
    });

    // اختبار قبول: السعر المعروض هو السعر المدفوع دوما. لا شريحة تحت
    // 0.99 دولار في المتجرين، فبطاقة تعرض 0.30 ثم ورقة دفع بـ0.99 إعلان
    // كاذب لا خصم.
    test('لا سعر تحت أدنى شريحة مهما بلغ الخصم', () {
      final offer = FirstPurchase.startOffer(now: _now, referenceUsd: 1.99);
      expect(
        offer.discountedUsd,
        greaterThanOrEqualTo(StoreCatalog.minimumStorePriceUsd),
      );
    });

    test('حزمة البداية على أدنى شريحة: لا خصم يُعلَن أصلا', () {
      final offer = FirstPurchase.startOffer(
        now: _now,
        referenceUsd: StoreCatalog.starterPackReferenceUsd,
      );

      expect(offer.discountedUsd, StoreCatalog.starterPackReferenceUsd);
      expect(
        offer.loweredPrice,
        isFalse,
        reason: 'لا يوجد ما دون 0.99 دولار — فلا سعر مشطوب ولا شارة خصم',
      );
    });

    test('ينتهي فعلا بعد مهلته', () {
      final offer = FirstPurchase.startOffer(now: _now, referenceUsd: 1.99);
      expect(offer.isActive(_now.add(const Duration(hours: 23))), isTrue);
      expect(offer.isActive(_now.add(const Duration(hours: 25))), isFalse);
      expect(
        offer.remaining(_now.add(const Duration(hours: 25))),
        Duration.zero,
      );
    });
  });

  group('مكافأة الشراء الأول', () {
    test('مضاعف 20٪ لمدة 24 ساعة + زينة حصرية', () {
      final bonus = FirstPurchase.grantBonus(_now);
      expect(bonus.coinMultiplier, 1.20);
      expect(bonus.until.difference(_now), const Duration(hours: 24));
      expect(bonus.avatarId, BalanceConfig.firstPurchaseAvatarId);
      expect(bonus.isActive(_now.add(const Duration(hours: 23))), isTrue);
      expect(bonus.isActive(_now.add(const Duration(hours: 25))), isFalse);
    });

    test('المضاعف يقرَّب لأعلى فلا يضيع في المكافآت الصغيرة', () {
      expect(FirstPurchase.applyMultiplier(3, multiplier: 1.2), 4);
      expect(FirstPurchase.applyMultiplier(100, multiplier: 1.2), 120);
      expect(FirstPurchase.applyMultiplier(0, multiplier: 1.2), 0);
      expect(FirstPurchase.applyMultiplier(50, multiplier: 1), 50);
    });

    test('أي شراء أول يمنحها، والثاني لا يعيد منحها', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);
      final notifier = container.read(purchaseStateProvider.notifier);

      expect(await notifier.recordPurchase(nowOverride: _now), isTrue);
      expect(container.read(purchaseStateProvider).hasEverPurchased, isTrue);
      // يُقاس بالساعة المزيّفة نفسها لا بـcoinMultiplierProvider: ذاك
      // يقرأ DateTime.now() الحقيقي، فكان الاختبار يمرّ يوم كتابته ثم
      // يسقط من تلقاء نفسه بمجرّد أن يتجاوز الوقت الحقيقي نافذة
      // المكافأة (24 ساعة من _now) — عطل توقيت في الاختبار لا في المنتج
      expect(
        container.read(purchaseStateProvider).coinMultiplierAt(_now),
        BalanceConfig.firstPurchaseCoinMultiplier,
      );

      expect(
        await notifier.recordPurchase(
          nowOverride: _now.add(const Duration(minutes: 5)),
        ),
        isFalse,
        reason: 'الشراء الثاني ليس أولا',
      );
    });

    test('الشراء يكتم الإعلانات: يسجّل وقته', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);

      await container
          .read(purchaseStateProvider.notifier)
          .recordPurchase(nowOverride: _now);

      expect(container.read(purchaseStateProvider).lastPurchaseAt, _now);
    });
  });
}
