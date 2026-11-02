import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/notifications/notification_engine.dart';
import 'package:huruf/data/notifications/notification_models.dart';

const _rewardTiers = {
  AppNotificationType.rewardTrackMonthlyReady,
  AppNotificationType.rewardTrackWeeklyReady,
  AppNotificationType.rewardTrackDailyReady,
};

const _allTypes = {
  AppNotificationType.dailyRewardReady,
  ..._rewardTiers,
  AppNotificationType.streakEndingTonight,
};

NotificationDecisionInput _input({
  bool dailyRewardUnclaimed = true,
  Set<AppNotificationType> readyRewardTiers = _rewardTiers,
  bool streakNotYetSecuredToday = true,
  Set<AppNotificationType> enabledTypes = _allTypes,
  DateTime? lastAppOpenedAt,
  required DateTime now,
  int sentCountToday = 0,
}) => NotificationDecisionInput(
  dailyRewardUnclaimed: dailyRewardUnclaimed,
  readyRewardTiers: readyRewardTiers,
  streakNotYetSecuredToday: streakNotYetSecuredToday,
  enabledTypes: enabledTypes,
  lastAppOpenedAt: lastAppOpenedAt,
  now: now,
  sentCountToday: sentCountToday,
);

void main() {
  group('اختبار قبول: لا أكثر من إشعارين في نافذة 24 ساعة', () {
    test(
      'كل الشروط محقّقة الساعة 8 صباحا — يُختار الأقدمان وقتا فقط (9 و11)',
      () {
        final result = NotificationEngine.eligibleNow(
          _input(now: DateTime(2026, 1, 5, 8)),
        );
        expect(result, [
          AppNotificationType.dailyRewardReady,
          AppNotificationType.rewardTrackMonthlyReady,
        ]);
      },
    );

    test('لا يظهر ثالث حتى مع تحقّق شرطه', () {
      final result = NotificationEngine.eligibleNow(
        _input(now: DateTime(2026, 1, 5, 8)),
      );
      expect(result.length, lessThanOrEqualTo(NotificationEngine.maxPerDay));
    });

    test('sentCountToday=1 يترك فرصة واحدة فقط للأقدم وقتا', () {
      final result = NotificationEngine.eligibleNow(
        _input(now: DateTime(2026, 1, 5, 8), sentCountToday: 1),
      );
      expect(result, [AppNotificationType.dailyRewardReady]);
    });

    test('sentCountToday=2 (بلغ الحد فعلا) لا يعيد شيئا', () {
      final result = NotificationEngine.eligibleNow(
        _input(now: DateTime(2026, 1, 5, 8), sentCountToday: 2),
      );
      expect(result, isEmpty);
    });
  });

  group('فوات الوقت خلال اليوم', () {
    test(
      'الساعة 10 (بعد 9، قبل 11): الأول فات، البقية مؤهَّلة بحدود السقف',
      () {
        final result = NotificationEngine.eligibleNow(
          _input(now: DateTime(2026, 1, 5, 10)),
        );
        expect(result, [
          AppNotificationType.rewardTrackMonthlyReady,
          AppNotificationType.rewardTrackWeeklyReady,
        ]);
      },
    );

    test('الساعة 14 (بعد كل طبقات المسار): يبقى تذكير السلسلة وحده', () {
      final result = NotificationEngine.eligibleNow(
        _input(now: DateTime(2026, 1, 5, 14)),
      );
      expect(result, [AppNotificationType.streakEndingTonight]);
    });

    test('الساعة 21 (بعد الجميع): لا شيء مؤهَّل', () {
      final result = NotificationEngine.eligibleNow(
        _input(now: DateTime(2026, 1, 5, 21)),
      );
      expect(result, isEmpty);
    });
  });

  group('فتح التطبيق مؤخرا يمنع كل شيء', () {
    test('فُتح قبل ساعة واحدة فقط — لا إشعار إطلاقا', () {
      final now = DateTime(2026, 1, 5, 9, 30);
      final result = NotificationEngine.eligibleNow(
        _input(
          now: now,
          lastAppOpenedAt: now.subtract(const Duration(hours: 1)),
        ),
      );
      expect(result, isEmpty);
    });

    test('فُتح قبل 3 ساعات بالضبط — الحد غير شامل، مسموح', () {
      final now = DateTime(2026, 1, 5, 9, 30);
      final result = NotificationEngine.eligibleNow(
        _input(
          now: now,
          lastAppOpenedAt: now.subtract(const Duration(hours: 3)),
        ),
      );
      expect(result, isNotEmpty);
    });

    test('فُتح قبل 3 ساعات وثانية واحدة — مسموح أيضا (تجاوز الحد فعليا)', () {
      final now = DateTime(2026, 1, 5, 9, 30);
      final result = NotificationEngine.eligibleNow(
        _input(
          now: now,
          lastAppOpenedAt: now.subtract(const Duration(hours: 3, seconds: 1)),
        ),
      );
      expect(result, isNotEmpty);
    });
  });

  group('كل شرط "فقط إن" يُحترَم لوحده', () {
    test('المكافأة اليومية مُطالَب بها بالفعل — لا يظهر dailyRewardReady', () {
      final result = NotificationEngine.eligibleNow(
        _input(now: DateTime(2026, 1, 5, 8), dailyRewardUnclaimed: false),
      );
      expect(result, isNot(contains(AppNotificationType.dailyRewardReady)));
    });

    test('طبقة غير جاهزة لا تُذكَّر، والجاهزة وحدها تُذكَّر', () {
      final result = NotificationEngine.eligibleNow(
        _input(
          now: DateTime(2026, 1, 5, 8),
          dailyRewardUnclaimed: false,
          streakNotYetSecuredToday: false,
          readyRewardTiers: {AppNotificationType.rewardTrackWeeklyReady},
        ),
      );
      expect(result, [AppNotificationType.rewardTrackWeeklyReady]);
    });

    test('لا طبقة جاهزة إطلاقا — لا إشعار من المسار', () {
      final result = NotificationEngine.eligibleNow(
        _input(
          now: DateTime(2026, 1, 5, 8),
          dailyRewardUnclaimed: false,
          streakNotYetSecuredToday: false,
          readyRewardTiers: const {},
        ),
      );
      expect(result, isEmpty);
    });

    test('السلسلة مؤمَّنة اليوم بالفعل — لا يظهر streakEndingTonight', () {
      final result = NotificationEngine.eligibleNow(
        _input(now: DateTime(2026, 1, 5, 8), streakNotYetSecuredToday: false),
      );
      expect(result, isNot(contains(AppNotificationType.streakEndingTonight)));
    });
  });

  test('نوع معطَّل يدويا لا يظهر حتى مع تحقّق شرطه', () {
    final result = NotificationEngine.eligibleNow(
      _input(
        now: DateTime(2026, 1, 5, 8),
        enabledTypes: {AppNotificationType.rewardTrackDailyReady},
      ),
    );
    expect(result, [AppNotificationType.rewardTrackDailyReady]);
  });

  group('NotificationEngine.shouldRequestPermission', () {
    test('لا يطلب قبل الجلسة الثالثة', () {
      expect(
        NotificationEngine.shouldRequestPermission(
          sessionCount: 2,
          alreadyRequested: false,
        ),
        isFalse,
      );
    });

    test('يطلب عند الجلسة الثالثة فما فوق إن لم يُطلَب من قبل', () {
      expect(
        NotificationEngine.shouldRequestPermission(
          sessionCount: 3,
          alreadyRequested: false,
        ),
        isTrue,
      );
      expect(
        NotificationEngine.shouldRequestPermission(
          sessionCount: 10,
          alreadyRequested: false,
        ),
        isTrue,
      );
    });

    test('لا يطلب مرتين حتى بعد الجلسة الثالثة', () {
      expect(
        NotificationEngine.shouldRequestPermission(
          sessionCount: 5,
          alreadyRequested: true,
        ),
        isFalse,
      );
    });
  });
  group('سلّم العودة: تذكيرات الأيام القادمة', () {
    test('يجدول تذكيرا لكل يوم في السلّم حين يكون مفعّلا', () {
      final plans = NotificationEngine.comebackPlan(enabled: true);
      expect(
        plans.map((p) => p.daysAhead).toList(),
        NotificationEngine.comebackDaysAhead,
      );
      expect(
        plans.every((p) => p.hour == NotificationEngine.comebackHour),
        isTrue,
      );
      expect(
        plans.every((p) => p.type == AppNotificationType.comebackReminder),
        isTrue,
      );
    });

    test('لا يجدول شيئا حين يكون معطّلا', () {
      expect(NotificationEngine.comebackPlan(enabled: false), isEmpty);
    });

    test('السلّم يتباعد ولا يلحّ — كل يوم أبعد من سابقه', () {
      final days = NotificationEngine.comebackDaysAhead;
      for (var i = 1; i < days.length; i++) {
        expect(
          days[i] - days[i - 1],
          greaterThanOrEqualTo(days[i - 1] - (i > 1 ? days[i - 2] : 0)),
        );
      }
    });

    test('معرّف كل تذكير فريد — وإلا دهس بعضها في نظام التشغيل', () {
      final ids = NotificationEngine.comebackPlan(
        enabled: true,
      ).map((p) => p.id);
      expect(ids.toSet().length, ids.length);
    });

    test('معرّفات العودة لا تصطدم بمعرّفات جدول اليوم', () {
      final todayIds = {
        for (final c in NotificationEngine.dailySchedule)
          ScheduledNotification(
            type: c.type,
            daysAhead: 0,
            hour: c.scheduledHour,
          ).id,
      };
      final comebackIds = NotificationEngine.comebackPlan(
        enabled: true,
      ).map((p) => p.id).toSet();
      expect(todayIds.intersection(comebackIds), isEmpty);
    });

    test('تذكير العودة ليس جزءا من جدول اليوم', () {
      expect(
        NotificationEngine.dailySchedule.any(
          (c) => c.type == AppNotificationType.comebackReminder,
        ),
        isFalse,
      );
      expect(
        NotificationEngine.eligibleNow(
          _input(
            now: DateTime(2026, 1, 5, 8),
            enabledTypes: {AppNotificationType.comebackReminder},
          ),
        ),
        isEmpty,
      );
    });
  });

  group('سلسلة مسار الجوائز: تذكيرات الأيام القادمة', () {
    List<ScheduledNotification> plan({
      List<int> daily = const [],
      List<int> weekly = const [],
      List<int> monthly = const [],
      bool enabled = true,
    }) => NotificationEngine.rewardTrackPlan(
      enabled: enabled,
      readyDaysAhead: {
        AppNotificationType.rewardTrackDailyReady: daily,
        AppNotificationType.rewardTrackWeeklyReady: weekly,
        AppNotificationType.rewardTrackMonthlyReady: monthly,
      },
    );

    test('لا يجدول شيئا حين يكون معطّلا', () {
      expect(plan(daily: const [1, 2, 3], enabled: false), isEmpty);
    });

    test('لا يجدول شيئا حين لا تكون أي طبقة جاهزة في الأفق', () {
      expect(plan(), isEmpty);
    });

    test('يوم واحد جاهز فيه طبقة واحدة — تذكير واحد بساعة نوعه', () {
      final plans = plan(daily: const [1, 2, 3]);
      expect(plans.map((p) => p.daysAhead), [1, 2, 3]);
      expect(
        plans.every(
          (p) => p.type == AppNotificationType.rewardTrackDailyReady,
        ),
        isTrue,
      );
      expect(
        plans.every(
          (p) =>
              p.hour ==
              NotificationEngine.scheduledHourOf(
                AppNotificationType.rewardTrackDailyReady,
              ),
        ),
        isTrue,
      );
    });

    test(
      'اجتماع طبقتين في يوم واحد — تذكير واحد فقط، للأثمن (الشهرية)',
      () {
        final plans = plan(
          daily: const [1, 2, 3],
          weekly: const [2, 3],
          monthly: const [3],
        );
        // يوم لكل يوم، لا ستّة تذكيرات
        expect(plans.map((p) => p.daysAhead), [1, 2, 3]);
        expect(plans.map((p) => p.type), [
          AppNotificationType.rewardTrackDailyReady, // اليوم 1: اليومية وحدها
          AppNotificationType.rewardTrackWeeklyReady, // اليوم 2: الأسبوعية تسبق
          AppNotificationType.rewardTrackMonthlyReady, // اليوم 3: الشهرية تسبق
        ]);
      },
    );

    test('يتجاهل الأيام خارج الأفق المعلن', () {
      final plans = plan(
        daily: [NotificationEngine.rewardTrackDaysAhead + 1, 0, -3],
      );
      expect(plans, isEmpty);
    });

    test('معرّف كل تذكير فريد — وإلا دهس بعضها في نظام التشغيل', () {
      final ids = plan(
        daily: const [1],
        weekly: const [2],
        monthly: const [3],
      ).map((p) => p.id);
      expect(ids.toSet().length, ids.length);
    });

    test('معرّفات المسار لا تصطدم بمعرّفات جدول اليوم ولا بسلّم العودة', () {
      final todayIds = {
        for (final c in NotificationEngine.dailySchedule)
          ScheduledNotification(
            type: c.type,
            daysAhead: 0,
            hour: c.scheduledHour,
          ).id,
      };
      final comebackIds = NotificationEngine.comebackPlan(
        enabled: true,
      ).map((p) => p.id).toSet();
      final trackIds = plan(
        daily: const [1, 2, 3],
        weekly: const [1, 2, 3],
        monthly: const [1, 2, 3],
      ).map((p) => p.id).toSet();

      expect(trackIds.intersection(todayIds), isEmpty);
      expect(trackIds.intersection(comebackIds), isEmpty);
    });
  });
}
