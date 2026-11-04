// بناء لقطة ودجة الشاشة الرئيسية: قواعد الأولوية، وانتقالات الحالة،
// وعقد JSON الذي يقرؤه الجانبان الأصليان. منطق صرف — بلا منصّة ولا
// قناة أصلية ولا انتظار يوم حقيقي.

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/rewards/reward_track.dart';
import 'package:huruf/data/widget/widget_data.dart';
import 'package:huruf/data/widget/widget_data_builder.dart';

final _start = DateTime(2026, 5, 1);

DateTime _day(int n) => RewardTrackEngine.addDays(_start, n);

RewardTrackState _track({
  int dailyClaimed = 0,
  int? dailyLastDay,
  int weeklyClaimed = 0,
  int? weeklyLastDay,
  int monthlyClaimed = 0,
  int? monthlyLastDay,
}) => RewardTrackState(
  startDay: _start,
  tiers: {
    RewardTier.daily: RewardTierProgress(
      claimed: dailyClaimed,
      lastClaimDay: dailyLastDay == null ? null : _day(dailyLastDay),
    ),
    RewardTier.weekly: RewardTierProgress(
      claimed: weeklyClaimed,
      lastClaimDay: weeklyLastDay == null ? null : _day(weeklyLastDay),
    ),
    RewardTier.monthly: RewardTierProgress(
      claimed: monthlyClaimed,
      lastClaimDay: monthlyLastDay == null ? null : _day(monthlyLastDay),
    ),
  },
);

HomeWidgetData _build({
  RewardTrackState? track,
  int onDay = 0,
  int diamonds = 1250,
  int streak = 12,
  int stages = 137,
  int chapters = 11,
  int worlds = 2,
  String lang = 'ar',
}) => WidgetDataBuilder.build(
  track: track ?? _track(),
  now: _day(onDay),
  diamonds: diamonds,
  streakDays: streak,
  stagesCompleted: stages,
  chaptersCompleted: chapters,
  worldsCompleted: worlds,
  languageCode: lang,
);

void main() {
  group('اختبار القبول: أولوية ما تعرضه الودجة', () {
    test('اليومية جاهزة ⇒ هي المُبرَزة', () {
      final data = _build();
      expect(data.focusTier, RewardTier.daily);
      expect(data.focus!.isReady, isTrue);
      expect(data.hasClaimable, isTrue);
    });

    test('اليومية استُلمت اليوم ⇒ تُبرَز الأسبوعية بتقدّمها', () {
      // اليوم الرابع، وطُولب باليومية اليوم نفسه
      final data = _build(
        onDay: 4,
        track: _track(dailyClaimed: 5, dailyLastDay: 4),
      );
      expect(data.focusTier, RewardTier.weekly);
      expect(data.focus!.isReady, isFalse);
      expect(data.hasClaimable, isFalse);
      // «4 / 7 أيام» — التقدّم داخل دورة الأسبوع
      expect(data.focus!.cycleElapsedDays, 4);
      expect(data.focus!.cyclePeriodDays, 7);
    });

    test('اليومية والأسبوعية انتهتا ⇒ تُبرَز الشهرية', () {
      final data = _build(
        onDay: 40,
        track: _track(
          dailyClaimed: RewardTier.daily.totalClaims,
          dailyLastDay: 6,
          weeklyClaimed: RewardTier.weekly.totalClaims,
          weeklyLastDay: 28,
          monthlyClaimed: 1,
          monthlyLastDay: 30,
        ),
      );
      expect(data.focusTier, RewardTier.monthly);
      expect(data.focus!.cyclePeriodDays, 30);
      expect(data.focus!.cycleElapsedDays, 10);
    });

    test('الجاهز يسبق التقدّم مهما كانت الطبقة', () {
      // اليومية استُلمت اليوم، لكن الأسبوعية جاهزة الآن
      final data = _build(
        onDay: 7,
        track: _track(dailyClaimed: 8, dailyLastDay: 7),
      );
      expect(data.focusTier, RewardTier.weekly);
      expect(data.focus!.isReady, isTrue);
    });

    test('اكتمال المسار كله ⇒ لا طبقة مُبرَزة، ورابط عام', () {
      final data = _build(
        onDay: 200,
        track: _track(
          dailyClaimed: RewardTier.daily.totalClaims,
          weeklyClaimed: RewardTier.weekly.totalClaims,
          monthlyClaimed: RewardTier.monthly.totalClaims,
        ),
      );
      expect(data.focusTier, isNull);
      expect(data.trackComplete, isTrue);
      expect(data.hasClaimable, isFalse);
      expect(data.deepLink, 'huruf://rewards');
    });
  });

  group('انتقالات الحالة', () {
    test('قبل الاستلام: جاهزة وغير مستلَمة اليوم', () {
      final daily = _build().tierOf(RewardTier.daily)!;
      expect(daily.isReady, isTrue);
      expect(daily.claimedToday, isFalse);
      expect(daily.claimed, 0);
    });

    test('بعد الاستلام مباشرة: لا جاهزة، ومستلَمة اليوم', () {
      final daily = _build(
        track: _track(dailyClaimed: 1, dailyLastDay: 0),
      ).tierOf(RewardTier.daily)!;
      expect(daily.isReady, isFalse);
      expect(daily.claimedToday, isTrue);
      expect(daily.claimed, 1);
    });

    test('يوم جديد بعد الاستلام: تعود جاهزة ولم تعد «مستلَمة اليوم»', () {
      final daily = _build(
        onDay: 1,
        track: _track(dailyClaimed: 1, dailyLastDay: 0),
      ).tierOf(RewardTier.daily)!;
      expect(daily.isReady, isTrue);
      expect(daily.claimedToday, isFalse);
    });

    test('استنفاد الطبقة: منتهية لا جاهزة ولا تنتظر', () {
      final daily = _build(
        onDay: 10,
        track: _track(
          dailyClaimed: RewardTier.daily.totalClaims,
          dailyLastDay: 6,
        ),
      ).tierOf(RewardTier.daily)!;
      expect(daily.isComplete, isTrue);
      expect(daily.isReady, isFalse);
      expect(daily.daysUntilReady, isNull);
    });
  });

  group('تقدّم الدورة كما يرسمه شريط النقاط', () {
    test('الجاهزة تعرض دورتها مكتملة لا صفرا', () {
      // الأسبوعية الأولى تُفتح اليوم السابع
      final weekly = _build(onDay: 7).tierOf(RewardTier.weekly)!;
      expect(weekly.isReady, isTrue);
      expect(weekly.cycleElapsedDays, weekly.cyclePeriodDays);
    });

    test('اليومية دورتها يوم واحد فلا نقاط لها', () {
      expect(_build().tierOf(RewardTier.daily)!.cyclePeriodDays, 1);
    });

    test('التقدّم لا يتجاوز طول الدورة ولا ينزل تحت الصفر', () {
      for (final day in [0, 1, 6, 7, 8, 29, 30, 31, 200]) {
        for (final tier in _build(onDay: day).tiers) {
          expect(tier.cycleElapsedDays, inInclusiveRange(0, tier.cyclePeriodDays),
              reason: '${tier.tier.name} في اليوم $day');
        }
      }
    });
  });

  group('حالات حدّية', () {
    test('لاعب جديد بلا سلسلة ولا تقدّم', () {
      final data = _build(diamonds: 100, streak: 0, stages: 0, chapters: 0, worlds: 0);
      expect(data.streakDays, 0);
      expect(data.focusTier, RewardTier.daily);
      expect(data.diamonds, 100);
    });

    test('لاعب لم يلعب اليوم: الودجة تعرض جائزة تنتظره', () {
      final data = _build(onDay: 3, track: _track(dailyClaimed: 1, dailyLastDay: 0));
      expect(data.hasClaimable, isTrue);
      expect(data.focusTier, RewardTier.daily);
    });

    test('اللغة الإنجليزية تُخرج تخطيطا يسارا-إلى-يمين', () {
      expect(_build(lang: 'en').isRtl, isFalse);
      expect(_build(lang: 'ar').isRtl, isTrue);
    });

    test('لغة غير معروفة تسقط على العربية لا على شاشة فارغة', () {
      expect(_build(lang: 'zz').isRtl, isTrue);
    });
  });

  group('عقد JSON مع الجانب الأصلي', () {
    test('دورة ترميز/فكّ تحفظ كل ما ترسمه الودجة', () {
      final data = _build(onDay: 7);
      final decoded = HomeWidgetData.decode(data.encode())!;

      expect(decoded.diamonds, data.diamonds);
      expect(decoded.streakDays, data.streakDays);
      expect(decoded.focusTier, data.focusTier);
      expect(decoded.stagesCompleted, data.stagesCompleted);
      expect(decoded.chaptersCompleted, data.chaptersCompleted);
      expect(decoded.worldsCompleted, data.worldsCompleted);
      expect(decoded.languageCode, data.languageCode);
      expect(decoded.tiers.length, 3);
      for (var i = 0; i < 3; i++) {
        expect(decoded.tiers[i].tier, data.tiers[i].tier);
        expect(decoded.tiers[i].coins, data.tiers[i].coins);
        expect(decoded.tiers[i].isReady, data.tiers[i].isReady);
        expect(decoded.tiers[i].isComplete, data.tiers[i].isComplete);
        expect(decoded.tiers[i].claimedToday, data.tiers[i].claimedToday);
        expect(decoded.tiers[i].cycleElapsedDays, data.tiers[i].cycleElapsedDays);
        expect(decoded.tiers[i].cyclePeriodDays, data.tiers[i].cyclePeriodDays);
      }
    });

    test('كل مفتاح يقرؤه الجانب الأصلي موجود فعلا', () {
      final json = _build().toJson();
      // أسماء المفاتيح مكتوبة حرفيا في HurufWidgetProvider.kt
      // وHurufWidget.swift — تغييرها هنا وحده يترك الودجة فارغة بصمت
      for (final key in [
        'v', 'diamonds', 'streak', 'tiers', 'focusIndex', 'hasClaimable',
        'rtl', 'deepLink', 'tierDeepLinks', 'text',
      ]) {
        expect(json.containsKey(key), isTrue, reason: 'المفتاح $key مفقود');
      }
      for (final key in [
        'coins', 'ready', 'done', 'cycleDone', 'cycleLen',
      ]) {
        expect((json['tiers'] as List).first, contains(key));
      }
    });

    test('focusIndex يشير إلى الطبقة المُبرَزة نفسها', () {
      final data = _build(onDay: 4, track: _track(dailyClaimed: 5, dailyLastDay: 4));
      final json = data.toJson();
      final index = json['focusIndex'] as int;
      expect(data.tiers[index].tier, data.focusTier);
    });

    test('اكتمال المسار يعطي focusIndex = -1 لا انهيارا', () {
      final json = _build(
        onDay: 200,
        track: _track(
          dailyClaimed: RewardTier.daily.totalClaims,
          weeklyClaimed: RewardTier.weekly.totalClaims,
          monthlyClaimed: RewardTier.monthly.totalClaims,
        ),
      ).toJson();
      expect(json['focusIndex'], -1);
    });

    test('بيانات غائبة أو تالفة تُقرأ null لا استثناء', () {
      expect(HomeWidgetData.decode(null), isNull);
      expect(HomeWidgetData.decode(''), isNull);
      expect(HomeWidgetData.decode('{{{'), isNull);
      expect(HomeWidgetData.decode('[]'), isNull);
      expect(HomeWidgetData.decode('{"v":1}'), isNull);
      expect(HomeWidgetData.decode('{"v":1,"tiers":[]}'), isNull);
    });

    test('نسخة عقد مختلفة تُرفض بدل رسم أرقام بشكل خاطئ', () {
      final raw = _build().encode().replaceFirst('"v":1', '"v":99');
      expect(HomeWidgetData.decode(raw), isNull);
    });
  });

  group('الروابط العميقة', () {
    test('لكل طبقة رابطها', () {
      expect(WidgetDeepLink.forTier(RewardTier.daily), 'huruf://rewards/daily');
      expect(WidgetDeepLink.forTier(RewardTier.weekly), 'huruf://rewards/weekly');
      expect(
        WidgetDeepLink.forTier(RewardTier.monthly),
        'huruf://rewards/monthly',
      );
      expect(WidgetDeepLink.forTier(null), 'huruf://rewards');
    });

    test('تُفكّ إلى الطبقة نفسها', () {
      for (final tier in RewardTier.values) {
        final uri = Uri.parse(WidgetDeepLink.forTier(tier));
        expect(WidgetDeepLink.parse(uri), (true, tier));
      }
    });

    test('رابط الجوائز بلا طبقة يفتح الشاشة بلا إبراز', () {
      expect(WidgetDeepLink.parse(Uri.parse('huruf://rewards')), (true, null));
      expect(WidgetDeepLink.parse(Uri.parse('huruf://rewards/')), (true, null));
    });

    test('طبقة مجهولة تفتح الشاشة بلا إبراز لا أن تُسقط شيئا', () {
      expect(
        WidgetDeepLink.parse(Uri.parse('huruf://rewards/yearly')),
        (true, null),
      );
    });

    test('روابط الدعوة لا تُلتقط هنا — لكلٍّ مساره', () {
      expect(
        WidgetDeepLink.parse(Uri.parse('https://huruf.site/i/ABCD2345')).$1,
        isFalse,
      );
      expect(WidgetDeepLink.parse(Uri.parse('huruf://invite/ABCD')).$1, isFalse);
    });
  });

  group('تغيّر التاريخ والمنطقة الزمنية', () {
    test('عبور نهاية الشهر لا يكسر حساب الدورة', () {
      final track = RewardTrackState(
        startDay: DateTime(2026, 1, 28),
        tiers: const {},
      );
      final data = WidgetDataBuilder.build(
        track: track,
        now: DateTime(2026, 2, 4),
        diamonds: 0,
        streakDays: 0,
        stagesCompleted: 0,
        chaptersCompleted: 0,
        worldsCompleted: 0,
        languageCode: 'ar',
      );
      // مرّ سبعة أيام تقويمية عبر حدّ الشهر ⇒ الأسبوعية جاهزة
      expect(data.tierOf(RewardTier.weekly)!.isReady, isTrue);
    });

    test('ساعة اليوم لا تغيّر شيئا — العبرة باليوم التقويمي', () {
      final morning = _build(onDay: 3);
      final evening = WidgetDataBuilder.build(
        track: _track(),
        now: _day(3).add(const Duration(hours: 23, minutes: 59)),
        diamonds: 1250,
        streakDays: 12,
        stagesCompleted: 137,
        chaptersCompleted: 11,
        worldsCompleted: 2,
        languageCode: 'ar',
      );
      expect(evening.focusTier, morning.focusTier);
      for (var i = 0; i < 3; i++) {
        expect(
          evening.tiers[i].cycleElapsedDays,
          morning.tiers[i].cycleElapsedDays,
        );
      }
    });
  });
}
