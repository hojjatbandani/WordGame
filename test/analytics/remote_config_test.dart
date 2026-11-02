import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/config/balance_overrides.dart';
import 'package:huruf/data/config/feature_flags.dart';
import 'package:huruf/data/config/remote_config_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// كل اختبار يعبث بحالة BalanceConfig الساكنة، فنعيدها بعده
void _restoreBalance(void Function() restore) => addTearDown(restore);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('تطبيق مفاتيح التوازن', () {
    test('اختبار القبول: تغيير كلفة التلميح يغيّر التسعير', () {
      final original = List<int>.from(BalanceConfig.hintEscalationLadder);
      final originalWorld =
          Map<int, double>.from(BalanceConfig.hintCostMultiplierByWorld);
      _restoreBalance(() {
        BalanceConfig.hintEscalationLadder = original;
        BalanceConfig.hintCostMultiplierByWorld = originalWorld;
      });

      final applied = BalanceOverrides.applyAll({
        'hintEscalationLadder': [10, 20, 30],
      });

      expect(applied, 1);
      expect(BalanceConfig.hintEscalationLadder, [10, 20, 30]);
      // والتسعير المشتق يتبع فورا
      expect(BalanceConfig.hintBaseCostForPosition(0), 10);
      expect(BalanceConfig.hintBaseCostForPosition(1), 20);
    });

    test('يقبل الأعداد نصّا وكسورا — لوحات التحكّم لا ترسل نوعا واحدا', () {
      final original = BalanceConfig.coinsStageClear;
      _restoreBalance(() => BalanceConfig.coinsStageClear = original);

      BalanceOverrides.applyAll({'coinsStageClear': '42'});
      expect(BalanceConfig.coinsStageClear, 42);

      BalanceOverrides.applyAll({'coinsStageClear': 55.0});
      expect(BalanceConfig.coinsStageClear, 55);
    });

    test('المدد بالثواني', () {
      final original = BalanceConfig.adGlobalCooldown;
      _restoreBalance(() => BalanceConfig.adGlobalCooldown = original);

      BalanceOverrides.applyAll({'adGlobalCooldownSeconds': 45});
      expect(BalanceConfig.adGlobalCooldown, const Duration(seconds: 45));
    });

    test('الخرائط والقوائم', () {
      final originalCadence =
          Map<int, int>.from(BalanceConfig.interstitialCadenceByStage);
      final originalLadder =
          List<int>.from(BalanceConfig.rewardedRewardLadder);
      _restoreBalance(() {
        BalanceConfig.interstitialCadenceByStage = originalCadence;
        BalanceConfig.rewardedRewardLadder = originalLadder;
      });

      BalanceOverrides.applyAll({
        'interstitialCadenceByStage': {'20': 6, '100': 4},
        'rewardedRewardLadder': [5, 10],
      });

      expect(BalanceConfig.interstitialCadenceForStage(20), 6);
      expect(BalanceConfig.interstitialCadenceForStage(100), 4);
      expect(BalanceConfig.rewardedRewardForView(1), 5);
      expect(BalanceConfig.rewardedRewardForView(9), 10);
    });

    test('قيمة لا تصلح تُتجاهل ويبقى الافتراضي', () {
      final original = BalanceConfig.coinsStageClear;
      _restoreBalance(() => BalanceConfig.coinsStageClear = original);

      BalanceOverrides.applyAll({'coinsStageClear': 'ليس رقما'});
      expect(BalanceConfig.coinsStageClear, original);
    });

    test('مفتاح مجهول لا يرمي ويُبلَّغ عنه', () {
      expect(
        () => BalanceOverrides.applyAll({'مفتاح_غير_موجود': 5}),
        returnsNormally,
      );
      expect(
        BalanceOverrides.unknownKeys({'مفتاح_غير_موجود': 5, 'worldCount': 8}),
        ['مفتاح_غير_موجود'],
      );
    });

    test('كل الأرقام الحسّاسة لها مفاتيح', () {
      // ليست كل حقول BalanceConfig (بعضها مشتقّ)، بل التي يُتوقّع ضبطها
      // عن بعد فعلا — أي رقم اقتصادي أو بوّابة
      const mustHave = [
        'coinsStageClear', 'coinsPerCoreWord', 'coinsPerBonusWord',
        'hintEscalationLadder', 'hintCostRoundingUnit',
        'xpBaseForLevel', 'xpIncrementPerLevel',
        'levelGateReferral',
        'referralRewardInviter', 'referralRewardInvitee',
        'shareRewardCoins', 'shareRewardMaxTotal',
        'interstitialFirstEligibleStage', 'interstitialCadenceByStage',
        'adGlobalCooldownSeconds', 'rewardedDailyBudget',
        'rewardedRewardLadder', 'nearMissMaxDeficitRatio',
        'firstPurchaseMaxCoinBalance', 'firstPurchaseMinStagesCompleted',
        'maxFriends', 'referralMaxPaidPerAccount',
      ];
      for (final key in mustHave) {
        expect(BalanceOverrides.registry, contains(key),
            reason: 'مفتاح ناقص: $key');
      }
    });
  });

  group('مفاتيح الإيقاف', () {
    test('كلها مُشغَّلة افتراضيا بلا استثناء محلّي', () {
      const flags = FeatureFlags.allOn();
      for (final key in FeatureFlags.all) {
        expect(flags.isOn(key), isTrue, reason: key);
      }
      // مسار الجوائز يعمل محليا بالكامل، فلا يحتاج إطفاءً محليا — مفتاحه
      // أداة إيقاف للاقتصاد عند الحاجة (راجع _localDefaults)
      expect(flags.rewardTrack, isTrue);
    });

    test('الخادم يُبقيه مُشغَّلا حين يقول true صراحة', () {
      final flags = FeatureFlags.fromConfig(
        const {'reward_track_enabled': true},
      );
      expect(flags.rewardTrack, isTrue);
    });

    test('مطفأ فقط بـfalse صريحة', () {
      final flags = FeatureFlags.fromConfig({'reward_track_enabled': false});
      expect(flags.rewardTrack, isFalse);
      expect(flags.store, isTrue);
    });

    test('تقبل النصّ والرقم — لوحات التحكّم ترسل أشكالا مختلفة', () {
      expect(
        FeatureFlags.fromConfig({'store_enabled': 'false'}).store,
        isFalse,
      );
      expect(FeatureFlags.fromConfig({'store_enabled': 0}).store, isFalse);
      expect(FeatureFlags.fromConfig({'store_enabled': 1}).store, isTrue);
      expect(
        FeatureFlags.fromConfig({'store_enabled': 'ربما'}).store,
        isTrue,
        reason: 'قيمة غير مفهومة لا تطفئ ميزة',
      );
    });

    test('كل ميزة تعتمد على خادم لها مفتاح', () {
      expect(FeatureFlags.all, containsAll([
        'ads_interstitial_enabled',
        'ads_rewarded_enabled',
        'reward_track_enabled',
        'store_enabled',
        'referral_enabled',
      ]));
    });
  });

  group('اختبار القبول: الإقلاع بلا خادم', () {
    test('بلا شبكة وبلا نسخة محفوظة: الأرقام المُصرَّفة، بلا انتظار',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = RemoteConfigRepository(prefs);

      final started = DateTime.now();
      final result = await repo.loadAndApply(appVersion: '1.0.0');
      final elapsed = DateTime.now().difference(started);

      expect(result.source, RemoteConfigSource.defaults);
      expect(result.flags.store, isTrue);
      // Supabase غير مضبوط في الاختبار فيعود فورا؛ الحدّ الأعلى في كل
      // الأحوال هو المهلة المعلنة
      expect(elapsed, lessThan(RemoteConfigRepository.timeout));
    });

    test('نسخة محفوظة تُستخدم حين تتعذّر الشبكة', () async {
      final original = BalanceConfig.coinsStageClear;
      _restoreBalance(() => BalanceConfig.coinsStageClear = original);

      SharedPreferences.setMockInitialValues({
        'remote_config_cache_v1': jsonEncode({
          'coinsStageClear': 99,
        }),
      });
      final prefs = await SharedPreferences.getInstance();

      final result =
          await RemoteConfigRepository(prefs).loadAndApply(appVersion: '1.0.0');

      expect(result.source, RemoteConfigSource.cache);
      expect(BalanceConfig.coinsStageClear, 99);
    });

    test('نسخة محفوظة تالفة تسقط على المُصرَّف بدل الانهيار', () async {
      SharedPreferences.setMockInitialValues({
        'remote_config_cache_v1': 'ليس JSON إطلاقا',
      });
      final prefs = await SharedPreferences.getInstance();

      final result =
          await RemoteConfigRepository(prefs).loadAndApply(appVersion: '1.0.0');

      expect(result.source, RemoteConfigSource.defaults);
    });

    test('المهلة ثانيتان كما نصّت المهمة', () {
      expect(RemoteConfigRepository.timeout, const Duration(seconds: 2));
    });
  });
}
