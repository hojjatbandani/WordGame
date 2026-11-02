// ربط مسار الجوائز بالتطبيق: التخزين، ومنح الألماس، والنقطة الحمراء،
// ومفتاح الإشعار. المنطق الزمني نفسه مختبَر في reward_track_test.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/data/rewards/reward_track.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ProviderContainer, ProgressStore)> _container([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await ProgressStore.create();
  final progression = await ProgressionRepository.load(
    prefs: store.prefs,
    legacy: store,
  );
  final container = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      progressionRepositoryProvider.overrideWithValue(progression),
    ],
  );
  addTearDown(container.dispose);
  return (container, store);
}

/// حالة محفوظة تجعل الطبقات المطلوبة جاهزة اليوم
String _savedTrack({
  required int startDaysAgo,
  int dailyClaimed = 0,
  int? dailyLastClaimDaysAgo,
  int weeklyClaimed = 0,
  int? weeklyLastClaimDaysAgo,
}) {
  final today = RewardTrackEngine.dayOf(DateTime.now());
  DateTime? ago(int? days) =>
      days == null ? null : RewardTrackEngine.addDays(today, -days);
  return RewardTrackState(
    startDay: RewardTrackEngine.addDays(today, -startDaysAgo),
    tiers: {
      RewardTier.daily: RewardTierProgress(
        claimed: dailyClaimed,
        lastClaimDay: ago(dailyLastClaimDaysAgo),
      ),
      RewardTier.weekly: RewardTierProgress(
        claimed: weeklyClaimed,
        lastClaimDay: ago(weeklyLastClaimDaysAgo),
      ),
    },
  ).encode();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('بداية المسار', () {
    test('أول قراءة تبدأ المسار من اليوم وتكتبه فورا', () async {
      final (c, store) = await _container();
      final state = c.read(rewardTrackProvider);

      expect(state.startDay, RewardTrackEngine.dayOf(DateTime.now()));
      expect(RewardTrackState.decode(store.rewardTrackJson), isNotNull);
    });

    test('اللاعب القديم يبدأ مساره كاملا الآن لا منتهيا', () async {
      final (c, _) = await _container();
      final statuses = c.read(rewardTrackProvider.notifier).statusesNow();

      expect(statuses.every((s) => s.claimed == 0), isTrue);
      expect(
        statuses.fold<int>(0, (sum, s) => sum + s.remainingClaims * s.coins),
        2000,
      );
    });

    test('اليومية وحدها جاهزة في اليوم الأول', () async {
      final (c, _) = await _container();
      final statuses = c.read(rewardTrackProvider.notifier).statusesNow();

      expect(statuses.where((s) => s.isReady).map((s) => s.tier), [
        RewardTier.daily,
      ]);
    });

    test('حالة محفوظة تالفة تبدأ مسارا جديدا بدل أن تُسقط التطبيق', () async {
      final (c, _) = await _container({'reward_track_json': 'ليس JSON'});
      expect(c.read(rewardTrackProvider).startDay, isNotNull);
      expect(c.read(rewardTrackProvider.notifier).statusesNow(), hasLength(3));
    });
  });

  group('المطالبة', () {
    test('تمنح الألماس وتزيد الرصيد فعلا', () async {
      final (c, _) = await _container();
      final before = c.read(pointsProvider);

      final granted = c.read(rewardTrackProvider.notifier).claim(
        RewardTier.daily,
      );

      expect(granted, RewardTier.daily.coins);
      expect(c.read(pointsProvider), before + RewardTier.daily.coins);
    });

    test('تُحفظ فورا فتنجو من إعادة التشغيل', () async {
      final (c, store) = await _container();
      c.read(rewardTrackProvider.notifier).claim(RewardTier.daily);

      final saved = RewardTrackState.decode(store.rewardTrackJson)!;
      expect(saved.progressOf(RewardTier.daily).claimed, 1);
      expect(
        saved.progressOf(RewardTier.daily).lastClaimDay,
        RewardTrackEngine.dayOf(DateTime.now()),
      );
    });

    test('المطالبة الثانية في نفس اليوم تُرفض بلا منح ولا انهيار', () async {
      final (c, _) = await _container();
      final notifier = c.read(rewardTrackProvider.notifier);
      notifier.claim(RewardTier.daily);
      final balance = c.read(pointsProvider);

      expect(notifier.claim(RewardTier.daily), isNull);
      expect(c.read(pointsProvider), balance);
    });

    test('المطالبة بطبقة غير جاهزة تُرفض بلا منح', () async {
      final (c, _) = await _container();
      final before = c.read(pointsProvider);

      expect(
        c.read(rewardTrackProvider.notifier).claim(RewardTier.weekly),
        isNull,
      );
      expect(c.read(pointsProvider), before);
    });

    test('الأسبوعية بعد سبعة أيام تمنح 50 لا 20', () async {
      final (c, _) = await _container({
        'reward_track_json': _savedTrack(startDaysAgo: 7),
      });

      expect(
        c.read(rewardTrackProvider.notifier).claim(RewardTier.weekly),
        50,
      );
    });
  });

  group('النقطة الحمراء على تبويب الجوائز', () {
    test('مضاءة حين تكون جائزة جاهزة', () async {
      final (c, _) = await _container();
      expect(c.read(rewardTrackPendingProvider), isTrue);
    });

    test('تنطفئ فور استلام كل الجاهز', () async {
      final (c, _) = await _container();
      expect(c.read(rewardTrackPendingProvider), isTrue);

      c.read(rewardTrackProvider.notifier).claim(RewardTier.daily);
      expect(c.read(rewardTrackPendingProvider), isFalse);
    });

    test('تبقى مضاءة ما دامت طبقة أخرى جاهزة', () async {
      // اليوم السابع: اليومية جاهزة (آخر مطالبة أمس) والأسبوعية أيضا
      final (c, _) = await _container({
        'reward_track_json': _savedTrack(
          startDaysAgo: 7,
          dailyClaimed: 1,
          dailyLastClaimDaysAgo: 1,
        ),
      });

      c.read(rewardTrackProvider.notifier).claim(RewardTier.daily);
      expect(c.read(rewardTrackPendingProvider), isTrue);
    });

    test('تنطفئ نهائيا بعد اكتمال المسار كله', () async {
      final (c, _) = await _container({
        'reward_track_json': RewardTrackState(
          startDay: RewardTrackEngine.addDays(
            RewardTrackEngine.dayOf(DateTime.now()),
            -365,
          ),
          tiers: {
            for (final tier in RewardTier.values)
              tier: RewardTierProgress(
                claimed: tier.totalClaims,
                lastClaimDay: RewardTrackEngine.dayOf(DateTime.now()),
              ),
          },
        ).encode(),
      });

      expect(c.read(rewardTrackPendingProvider), isFalse);
      expect(
        RewardTrackEngine.isTrackComplete(c.read(rewardTrackProvider)),
        isTrue,
      );
    });
  });

  group('مفتاح إشعار مسار الجوائز في الإعدادات', () {
    test('مفعّل افتراضيا', () async {
      final (c, _) = await _container();
      expect(c.read(notificationSettingsProvider).rewardTrackEnabled, isTrue);
    });

    test('الإطفاء يُحفظ وينجو من إعادة التشغيل', () async {
      final (c, store) = await _container();
      c.read(notificationSettingsProvider.notifier).setRewardTrackEnabled(
        false,
      );

      expect(c.read(notificationSettingsProvider).rewardTrackEnabled, isFalse);
      expect(store.notifRewardTrackEnabled, isFalse);
    });

    test('لا يمسّ بقية المفاتيح', () async {
      final (c, _) = await _container();
      c.read(notificationSettingsProvider.notifier).setRewardTrackEnabled(
        false,
      );
      final settings = c.read(notificationSettingsProvider);

      expect(settings.dailyRewardEnabled, isTrue);
      expect(settings.streakEnabled, isTrue);
    });

    test('«البدء من جديد» يمسح المسار ويبقي مفتاح إشعاره', () async {
      final (c, store) = await _container();
      c.read(notificationSettingsProvider.notifier).setRewardTrackEnabled(
        false,
      );
      c.read(rewardTrackProvider.notifier).claim(RewardTier.daily);

      await store.resetProgress();

      expect(store.rewardTrackJson, isNull);
      expect(store.notifRewardTrackEnabled, isFalse);
    });
  });
}
