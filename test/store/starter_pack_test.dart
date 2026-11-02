// أقساط حزمة البداية: الجدول، وحدّ القسط الواحد في اليوم، والقاعدة
// التي لا تُكسر — القسط لا يسقط بفوات يومه.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/app_language.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/store/starter_pack.dart';
import 'package:huruf/data/store/store_catalog.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/shop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _day1 = DateTime(2026, 8, 30, 10);
final _day2 = DateTime(2026, 8, 31, 10);
final _day3 = DateTime(2026, 9, 1, 10);

StarterPackStatus _status({
  bool owned = true,
  int claimed = 0,
  String? lastClaim,
  DateTime? now,
}) => StarterPackDelivery.status(
  owned: owned,
  claimedCount: claimed,
  lastClaimDate: lastClaim,
  now: now ?? _day1,
);

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
  group('جدول الحزمة', () {
    test('ثلاثة أقساط تنازلية بمجموع معلن', () {
      expect(StoreCatalog.starterPackDailyCoins, [400, 250, 150]);
      expect(StoreCatalog.starterPackCoins, 800);
      expect(StoreCatalog.starterPackDays, 3);
    });

    test('المجموع مشتقّ من الجدول لا رقم ثان يُنسى', () {
      final sum = StoreCatalog.starterPackDailyCoins
          .fold<int>(0, (a, b) => a + b);
      expect(StoreCatalog.starterPackCoins, sum);
    });

    test('السعر على أدنى شريحة حقيقية', () {
      expect(
        StoreCatalog.starterPackReferenceUsd,
        StoreCatalog.minimumStorePriceUsd,
      );
    });

    test('التلميحات كلها مع القسط الأول', () {
      expect(
        StarterPackDelivery.installment(1).hintCharges,
        StoreCatalog.starterPackHintCharges,
      );
      expect(StarterPackDelivery.installment(2).hintCharges, 0);
      expect(StarterPackDelivery.installment(3).hintCharges, 0);
    });

    test('رقم قسط خارج المدى خطأ برمجي لا قيمة صامتة', () {
      expect(() => StarterPackDelivery.installment(0), throwsArgumentError);
      expect(() => StarterPackDelivery.installment(4), throwsArgumentError);
    });
  });

  group('النصّ المعروض على البطاقة', () {
    test('يذكر كل يوم بمبلغه الفعلي — لا نصّ ثابت يعد بما لا يُمنح', () {
      for (final lang in AppLanguage.values) {
        final line = starterPackScheduleLine(lang);
        for (var i = 0; i < StoreCatalog.starterPackDailyCoins.length; i++) {
          expect(
            line,
            contains('${StoreCatalog.starterPackDailyCoins[i]}'),
            reason: 'مبلغ اليوم ${i + 1} غائب عن السطر ($lang): $line',
          );
        }
      }
    });

    test('المبلغ المذكور لكل يوم هو المبلغ الذي يمنحه القسط', () {
      for (var n = 1; n <= StarterPackDelivery.totalInstallments; n++) {
        expect(
          StarterPackDelivery.installment(n).coins,
          StoreCatalog.starterPackDailyCoins[n - 1],
        );
      }
    });
  });

  group('من لم يشترِ', () {
    test('لا قسط ولا بطاقة', () {
      final status = _status(owned: false);
      expect(status.hasClaimable, isFalse);
      expect(status.block, StarterPackBlock.notOwned);
    });
  });

  group('حدّ القسط الواحد في اليوم', () {
    test('القسط الأول مستحقّ فور التملّك', () {
      final status = _status(claimed: 0);
      expect(status.claimable?.number, 1);
      expect(status.claimable?.coins, 400);
    });

    test('بعد قبض قسط اليوم لا قسط ثان قبل الغد', () {
      final status = _status(
        claimed: 1,
        lastClaim: StarterPackDelivery.dateKey(_day1),
        now: _day1,
      );
      expect(status.hasClaimable, isFalse);
      expect(status.block, StarterPackBlock.claimedToday);
    });

    test('في اليوم التالي يُستحقّ القسط الذي يليه', () {
      final status = _status(
        claimed: 1,
        lastClaim: StarterPackDelivery.dateKey(_day1),
        now: _day2,
      );
      expect(status.claimable?.number, 2);
      expect(status.claimable?.coins, 250);
    });

    test('بعد الأقساط الثلاثة تنتهي الحزمة تماما', () {
      final status = _status(
        claimed: 3,
        lastClaim: StarterPackDelivery.dateKey(_day3),
        now: DateTime(2026, 9, 20),
      );
      expect(status.hasClaimable, isFalse);
      expect(status.isFullyDelivered, isTrue);
      expect(status.remaining, 0);
    });
  });

  // ═══ اختبار القبول ═══
  group('اختبار القبول: القسط لا يسقط بفوات يومه', () {
    test('من غاب أسبوعا يجد قسطه بانتظاره لا «فاتك»', () {
      final status = _status(
        claimed: 1,
        lastClaim: StarterPackDelivery.dateKey(_day1),
        now: _day1.add(const Duration(days: 7)),
      );
      expect(status.claimable?.number, 2, reason: 'الموضع يتقدّم بالقبض وحده');
      expect(status.claimable?.coins, 250);
      expect(status.remaining, 2);
    });

    test('الغياب الطويل لا يمنح الأقساط الباقية دفعة واحدة', () {
      // عاد بعد شهر: قسط واحد اليوم، والثالث غدا. الغياب لا يُسقط ولا
      // يُعجّل — الجدول موعد لا مهلة.
      final afterMonth = _day1.add(const Duration(days: 30));
      final first = _status(
        claimed: 1,
        lastClaim: StarterPackDelivery.dateKey(_day1),
        now: afterMonth,
      );
      expect(first.claimable?.number, 2);

      final sameDayAgain = _status(
        claimed: 2,
        lastClaim: StarterPackDelivery.dateKey(afterMonth),
        now: afterMonth,
      );
      expect(sameDayAgain.hasClaimable, isFalse);
      expect(sameDayAgain.block, StarterPackBlock.claimedToday);
    });
  });

  group('اختبار القبول: المنح عبر المزوّد', () {
    test('كل قسط يُضاف مرة واحدة، والتلميحات مع الأول وحده', () async {
      final container = await _container({'starter_pack_owned': true});
      addTearDown(container.dispose);
      final notifier = container.read(starterPackProvider.notifier);
      final pointsBefore = container.read(pointsProvider);

      final first = await notifier.claim(nowOverride: _day1);
      expect(first?.number, 1);
      expect(container.read(pointsProvider), pointsBefore + 400);
      expect(
        container.read(hintChargesProvider),
        StoreCatalog.starterPackHintCharges,
      );

      // نداء ثان في اليوم نفسه لا يمنح شيئا
      expect(await notifier.claim(nowOverride: _day1), isNull);
      expect(container.read(pointsProvider), pointsBefore + 400);

      final second = await notifier.claim(nowOverride: _day2);
      expect(second?.number, 2);
      expect(container.read(pointsProvider), pointsBefore + 650);
      expect(
        container.read(hintChargesProvider),
        StoreCatalog.starterPackHintCharges,
        reason: 'التلميحات مع القسط الأول وحده',
      );

      final third = await notifier.claim(nowOverride: _day3);
      expect(third?.number, 3);
      expect(container.read(pointsProvider), pointsBefore + 800);

      expect(
        await notifier.claim(nowOverride: DateTime(2026, 9, 5)),
        isNull,
        reason: 'لا قسط رابع',
      );
      expect(container.read(starterPackProvider).isFullyDelivered, isTrue);
    });

    test('ما قُبض ينجو من إعادة تشغيل التطبيق', () async {
      final container = await _container({'starter_pack_owned': true});
      await container.read(starterPackProvider.notifier).claim(
            nowOverride: _day1,
          );
      container.dispose();

      // نفس التخزين، حاوية جديدة — كإقلاع بارد
      final store = ProgressStore(await SharedPreferences.getInstance());
      final revived = ProviderContainer(
        overrides: [progressStoreProvider.overrideWithValue(store)],
      );
      addTearDown(revived.dispose);

      expect(store.starterPackClaimedDays, 1);
      expect(store.starterPackLastClaimDate, isNotNull);

      // `remaining` لا علاقة له بالتاريخ — يُقرأ من المزوّد كما تقرؤه
      // الشاشة، فهو ما يثبت أن الحالة نجت من الإقلاع
      expect(revived.read(starterPackProvider).remaining, 2);

      // أما «هل يستحقّ قسطا الآن؟» فسؤال عن *تاريخ*، ويجب أن يُسأل
      // بالساعة التي قُبض بها لا بساعة الجدار: قراءة المزوّد هنا كانت
      // تقارن قبضَ الأمس بيومِ التشغيل، فتمرّ يوم 2026-08-30 وحده
      // وتسقط كل يوم بعده. اختبار يمرّ بحسب تاريخ تشغيله ليس اختبارا.
      final status = StarterPackDelivery.status(
        owned: true,
        claimedCount: store.starterPackClaimedDays,
        lastClaimDate: store.starterPackLastClaimDate,
        now: _day1,
      );
      expect(status.remaining, 2);
      expect(
        status.hasClaimable,
        isFalse,
        reason: 'قُبض قسط اليوم قبل الإغلاق',
      );
    });

    test('من لم يشترِ لا يقبض شيئا', () async {
      final container = await _container();
      addTearDown(container.dispose);
      final before = container.read(pointsProvider);
      expect(
        await container.read(starterPackProvider.notifier).claim(),
        isNull,
      );
      expect(container.read(pointsProvider), before);
    });
  });
}
