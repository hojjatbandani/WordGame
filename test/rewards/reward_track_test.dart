// مسار الجوائز — المنطق الصرف وحده: لا Flutter ولا تخزين ولا مزوّدات.
// كل شيء يُقاس بـ«يوم» صريح يُمرَّر، فلا انتظار ستة أشهر حقيقية.

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/rewards/reward_track.dart';

final _start = DateTime(2026, 3, 1);

RewardTrackState _fresh() => RewardTrackState.fresh(_start);

DateTime _day(int n) => RewardTrackEngine.addDays(_start, n);

/// يطالب بكل طبقة جاهزة في اليوم [n]، ويعيد مجموع ما مُنح فيه
int _claimAllReady(List<RewardTrackState> box, int n) {
  var granted = 0;
  for (final status in RewardTrackEngine.statuses(box.single, _day(n))) {
    if (!status.isReady) continue;
    granted += status.coins;
    box[0] = RewardTrackEngine.claim(status.tier, box.single, _day(n));
  }
  return granted;
}

void main() {
  group('الأرقام المطلوبة حرفيا', () {
    test('20 يوميا ×30، و50 أسبوعيا ×4، و200 شهريا ×6', () {
      expect(RewardTier.daily.coins, 20);
      expect(RewardTier.daily.totalClaims, 30);
      expect(RewardTier.weekly.coins, 50);
      expect(RewardTier.weekly.totalClaims, 4);
      expect(RewardTier.monthly.coins, 200);
      expect(RewardTier.monthly.totalClaims, 6);
    });

    test('إيقاع كل طبقة: يوم، أسبوع، شهر', () {
      expect(RewardTier.daily.periodDays, 1);
      expect(RewardTier.weekly.periodDays, 7);
      expect(RewardTier.monthly.periodDays, 30);
    });

    test('مجموع المسار كله 2000 ألماسة', () {
      final total = RewardTier.values.fold<int>(
        0,
        (sum, tier) => sum + tier.totalCoins,
      );
      expect(total, 30 * 20 + 4 * 50 + 6 * 200);
      expect(total, 2000);
    });
  });

  group('اختبار القبول: الجدول الزمني للاعب منتظم', () {
    test('اليومية: جاهزة من اليوم صفر، وتنتهي بعد 30 يوما بالضبط', () {
      final box = [_fresh()];
      for (var day = 0; day < 30; day++) {
        final status = RewardTrackEngine.statusOf(
          RewardTier.daily,
          box.single,
          _day(day),
        );
        expect(status.isReady, isTrue, reason: 'اليوم $day');
        box[0] = RewardTrackEngine.claim(
          RewardTier.daily,
          box.single,
          _day(day),
        );
      }
      final after = RewardTrackEngine.statusOf(
        RewardTier.daily,
        box.single,
        _day(30),
      );
      expect(after.isComplete, isTrue);
      expect(after.isReady, isFalse);
      expect(after.claimed, 30);
      // ولا شيء بعدها أبدا مهما طال الوقت
      expect(
        RewardTrackEngine.statusOf(
          RewardTier.daily,
          box.single,
          _day(365),
        ).isReady,
        isFalse,
      );
    });

    test('اليومية لا تُطالَب مرتين في اليوم نفسه', () {
      var state = _fresh();
      state = RewardTrackEngine.claim(RewardTier.daily, state, _day(0));
      expect(
        RewardTrackEngine.statusOf(RewardTier.daily, state, _day(0)).isReady,
        isFalse,
      );
      expect(
        RewardTrackEngine.statusOf(RewardTier.daily, state, _day(1)).isReady,
        isTrue,
      );
    });

    test('الأسبوعية: أولها اليوم 7، ثم 14 و21 و28 — وتنتهي بعد شهر', () {
      var state = _fresh();
      // لا شيء قبل انقضاء أسبوع كامل
      for (final day in [0, 1, 6]) {
        expect(
          RewardTrackEngine.statusOf(
            RewardTier.weekly,
            state,
            _day(day),
          ).isReady,
          isFalse,
          reason: 'اليوم $day',
        );
      }
      for (final day in [7, 14, 21, 28]) {
        final status = RewardTrackEngine.statusOf(
          RewardTier.weekly,
          state,
          _day(day),
        );
        expect(status.isReady, isTrue, reason: 'اليوم $day');
        state = RewardTrackEngine.claim(RewardTier.weekly, state, _day(day));
      }
      final after = RewardTrackEngine.statusOf(
        RewardTier.weekly,
        state,
        _day(35),
      );
      expect(after.isComplete, isTrue);
      expect(after.claimed, 4);
    });

    test('الشهرية: أولها اليوم 30، وآخرها اليوم 180 — ستة أشهر بالضبط', () {
      var state = _fresh();
      expect(
        RewardTrackEngine.statusOf(
          RewardTier.monthly,
          state,
          _day(29),
        ).isReady,
        isFalse,
      );
      for (var claim = 1; claim <= 6; claim++) {
        final day = 30 * claim;
        final status = RewardTrackEngine.statusOf(
          RewardTier.monthly,
          state,
          _day(day),
        );
        expect(status.isReady, isTrue, reason: 'اليوم $day');
        state = RewardTrackEngine.claim(RewardTier.monthly, state, _day(day));
      }
      final after = RewardTrackEngine.statusOf(
        RewardTier.monthly,
        state,
        _day(210),
      );
      expect(after.isComplete, isTrue);
      expect(after.claimed, 6);
      // اليوم 180 هو آخر يوم منح فعليا — الستة أشهر
      expect(RewardTrackEngine.nextReadyDay(RewardTier.monthly, state), isNull);
    });

    test('لاعب لا يفوته يوم: 2000 ألماسة على 180 يوما، ثم لا شيء', () {
      final box = [_fresh()];
      var total = 0;
      for (var day = 0; day <= 180; day++) {
        total += _claimAllReady(box, day);
      }
      expect(total, 2000);
      expect(RewardTrackEngine.isTrackComplete(box.single), isTrue);

      // بعد اكتمال المسار لا يُمنح شيء إضافي مهما استمرّ اللعب
      var extra = 0;
      for (var day = 181; day <= 400; day++) {
        extra += _claimAllReady(box, day);
      }
      expect(extra, 0);
    });
  });

  group('اختبار القبول: الغياب يؤجّل ولا يُسقط', () {
    test('غياب أسبوعين ثم عودة: جوائز اليومية كلها ما زالت تنتظر', () {
      final box = [_fresh()];
      // يوم واحد فقط ثم غياب طويل
      expect(_claimAllReady(box, 0), 20);

      // العودة في اليوم 14: اليومية جاهزة (التسع والعشرون الباقية تنتظر)
      final daily = RewardTrackEngine.statusOf(
        RewardTier.daily,
        box.single,
        _day(14),
      );
      expect(daily.isReady, isTrue);
      expect(daily.claimed, 1);
      expect(daily.remainingClaims, 29);

      // والأسبوعية الأولى تنتظره أيضا — لم تُهدر بمرور موعدها
      expect(
        RewardTrackEngine.statusOf(
          RewardTier.weekly,
          box.single,
          _day(14),
        ).isReady,
        isTrue,
      );
    });

    test('الغائب ستة أشهر يجد كل جوائزه كاملة عند عودته', () {
      final box = [_fresh()];
      final granted = _claimAllReady(box, 200);
      // في اليوم 200 كل الطبقات مفتوحة، لكن مطالبة واحدة لكل طبقة
      expect(granted, 20 + 50 + 200);
      // ولا شيء ضاع: البقية تنتظر أيامها التالية
      expect(
        RewardTrackEngine.statuses(box.single, _day(200)).fold<int>(
          0,
          (sum, s) => sum + s.remainingClaims * s.coins,
        ),
        2000 - granted,
      );
    });

    test('العودة بعد غياب لا تُسرّع الطبقات: الأسبوعية تحترم أسبوعها', () {
      var state = _fresh();
      state = RewardTrackEngine.claim(RewardTier.weekly, state, _day(7));
      expect(
        RewardTrackEngine.statusOf(
          RewardTier.weekly,
          state,
          _day(13),
        ).daysUntilReady,
        1,
      );
      expect(
        RewardTrackEngine.statusOf(
          RewardTier.weekly,
          state,
          _day(14),
        ).isReady,
        isTrue,
      );
    });
  });

  group('المطالبة بطبقة غير جاهزة ترمي', () {
    test('الأسبوعية في يومها الأول', () {
      expect(
        () => RewardTrackEngine.claim(RewardTier.weekly, _fresh(), _day(0)),
        throwsStateError,
      );
    });

    test('اليومية بعد استنفادها', () {
      var state = _fresh();
      final total = RewardTier.daily.totalClaims;
      for (var day = 0; day < total; day++) {
        state = RewardTrackEngine.claim(RewardTier.daily, state, _day(day));
      }
      expect(
        () => RewardTrackEngine.claim(RewardTier.daily, state, _day(total + 1)),
        throwsStateError,
      );
    });
  });

  group('أيام السلسلة المسبقة للإشعارات', () {
    test('الجاهز اليوم جاهز في كل أيام الأفق (لا مطالبة تُسقطه)', () {
      expect(
        RewardTrackEngine.readyDaysAhead(
          RewardTier.daily,
          _fresh(),
          _day(0),
          horizonDays: 3,
        ),
        [1, 2, 3],
      );
    });

    test('ما يُفتح بعد يومين لا يُذكَّر به قبلهما', () {
      // الأسبوعية تُفتح اليوم 7، ونحن في اليوم 5
      expect(
        RewardTrackEngine.readyDaysAhead(
          RewardTier.weekly,
          _fresh(),
          _day(5),
          horizonDays: 3,
        ),
        [2, 3],
      );
    });

    test('الطبقة المنتهية لا تُذكِّر بشيء أبدا', () {
      var state = _fresh();
      for (var day = 0; day < RewardTier.daily.totalClaims; day++) {
        state = RewardTrackEngine.claim(RewardTier.daily, state, _day(day));
      }
      expect(
        RewardTrackEngine.readyDaysAhead(
          RewardTier.daily,
          state,
          _day(RewardTier.daily.totalClaims),
          horizonDays: 3,
        ),
        isEmpty,
      );
    });
  });

  group('التخزين', () {
    test('ترميز ثم فكّ يعيد نفس الحالة بالضبط', () {
      var state = _fresh();
      state = RewardTrackEngine.claim(RewardTier.daily, state, _day(0));
      state = RewardTrackEngine.claim(RewardTier.daily, state, _day(1));
      state = RewardTrackEngine.claim(RewardTier.weekly, state, _day(7));

      final decoded = RewardTrackState.decode(state.encode())!;
      expect(decoded.startDay, state.startDay);
      for (final tier in RewardTier.values) {
        expect(
          decoded.progressOf(tier).claimed,
          state.progressOf(tier).claimed,
          reason: tier.name,
        );
        expect(
          decoded.progressOf(tier).lastClaimDay,
          state.progressOf(tier).lastClaimDay,
          reason: tier.name,
        );
      }
    });

    test('نصّ غائب أو فارغ أو تالف يعطي null لا استثناء', () {
      expect(RewardTrackState.decode(null), isNull);
      expect(RewardTrackState.decode(''), isNull);
      expect(RewardTrackState.decode('{{{'), isNull);
      expect(RewardTrackState.decode('[]'), isNull);
      expect(RewardTrackState.decode('{"start":"لا-تاريخ"}'), isNull);
      expect(RewardTrackState.decode('{"nothing":1}'), isNull);
    });

    test('طبقة تالفة داخل حالة سليمة تُتجاهَل وحدها', () {
      final decoded = RewardTrackState.decode(
        '{"start":"2026-03-01","daily":"مش كائن","weekly":{"claimed":2}}',
      )!;
      expect(decoded.progressOf(RewardTier.daily).claimed, 0);
      expect(decoded.progressOf(RewardTier.weekly).claimed, 2);
      expect(decoded.progressOf(RewardTier.weekly).lastClaimDay, isNull);
    });
  });

  group('حساب الأيام يصمد أمام التوقيت الصيفي وحدود الشهور', () {
    test('عبور نهاية شهر: 31 يناير + يوم = 1 فبراير', () {
      final jan31 = DateTime(2026, 1, 31);
      expect(RewardTrackEngine.addDays(jan31, 1), DateTime(2026, 2, 1));
      expect(
        RewardTrackEngine.daysBetween(jan31, DateTime(2026, 2, 1)),
        1,
      );
    });

    test('30 يوما من 31 يناير تقع في 2 مارس (سنة غير كبيسة)', () {
      expect(
        RewardTrackEngine.addDays(DateTime(2026, 1, 31), 30),
        DateTime(2026, 3, 2),
      );
    });

    test('يوم تغيير التوقيت الصيفي يبقى يوما واحدا لا 23 ساعة', () {
      // الأحد الثاني من مارس 2026 في التوقيت الأمريكي — إن كان الجهاز
      // على توقيت بلا صيفي فالاختبار يبقى صحيحا (يوم = يوم)
      final before = DateTime(2026, 3, 8);
      expect(
        RewardTrackEngine.daysBetween(before, DateTime(2026, 3, 9)),
        1,
      );
      expect(RewardTrackEngine.addDays(before, 1).day, 9);
    });
  });

  group('الأرقام تتبع BalanceConfig فتقبل الضبط عن بعد', () {
    tearDown(() {
      BalanceConfig.rewardTrackDailyCoins = 20;
      BalanceConfig.rewardTrackDailyClaims = 7;
    });

    test('تغيير المبلغ والعدد ينعكس على المحرّك فورا', () {
      BalanceConfig.rewardTrackDailyCoins = 35;
      BalanceConfig.rewardTrackDailyClaims = 3;
      expect(RewardTier.daily.coins, 35);
      expect(RewardTier.daily.totalCoins, 105);

      var state = _fresh();
      for (var day = 0; day < 3; day++) {
        state = RewardTrackEngine.claim(RewardTier.daily, state, _day(day));
      }
      expect(
        RewardTrackEngine.statusOf(
          RewardTier.daily,
          state,
          _day(3),
        ).isComplete,
        isTrue,
      );
    });
  });
}
