// قرار جدولة الإشعارات المحلية — منطق صرف بالكامل، بلا استيراد Flutter
// وبلا أي DateTime.now() داخلي. لا يجدول ولا يطلب صلاحية بنفسه — فقط
// يقرّر "ماذا يجب أن يكون مجدولا الآن"؛ notification_service.dart هو من
// يترجم هذا القرار إلى استدعاءات فعلية لـflutter_local_notifications.
//
// لماذا "الآن" لا وقت الإطلاق: الإشعارات المحلية لا تستطيع استشارة حالة
// حيّة (هل طالب اللاعب بالمكافأة؟) في لحظة إطلاقها فعليا من نظام
// التشغيل بلا بنية تحتية خلفية معقدة (WorkManager/BGTaskScheduler) خارج
// نطاق هذه المهمة. الحل العملي المتّبع هنا: يُعاد تقييم كل شيء وتُعاد
// الجدولة من الصفر (إلغاء ثم جدولة) في كل فتح/استئناف للتطبيق — فإن عاد
// اللاعب وطالب بالمكافأة ثم أعاد فتح التطبيق، يُلغى إشعارها المجدول قبل
// أن يصل موعده. الثمن الوحيد: نص "N لاعب حلّوه بالفعل" يُجمَّد برقم لحظة
// الجدولة لا لحظة الإطلاق الفعلية — تفاوت بسيط معلن، لا مخفي.

import 'notification_models.dart';

class NotificationEngine {
  const NotificationEngine._();

  static const Duration openedRecentlyThreshold = Duration(hours: 3);
  static const int maxPerDay = 2;

  /// مرتّب بالساعة تصاعديا — [eligibleNow] تمرّ عليه بهذا الترتيب
  /// وتتوقّف عند السقف اليومي، فالأقدم وقتا يفوز بالحصة. وترتيب طبقات
  /// المسار بينها ليس اعتباطيا: الشهرية قبل الأسبوعية قبل اليومية، فمن
  /// اجتمعت عنده الثلاث يصله خبر الأثمن لا الأرخص.
  static const List<NotificationCandidate> dailySchedule = [
    NotificationCandidate(
      type: AppNotificationType.dailyRewardReady,
      scheduledHour: 9,
    ),
    NotificationCandidate(
      type: AppNotificationType.rewardTrackMonthlyReady,
      scheduledHour: 11,
    ),
    NotificationCandidate(
      type: AppNotificationType.rewardTrackWeeklyReady,
      scheduledHour: 12,
    ),
    NotificationCandidate(
      type: AppNotificationType.rewardTrackDailyReady,
      scheduledHour: 13,
    ),
    NotificationCandidate(
      type: AppNotificationType.streakEndingTonight,
      scheduledHour: 20,
    ),
  ];

  /// أنواع مسار الجوائز مرتّبة من الأثمن إلى الأرخص — تُستعمل حيث لا
  /// تكفي فتحة واحدة إلا لواحد (راجع [rewardTrackPlan])
  static const List<AppNotificationType> rewardTrackTypes = [
    AppNotificationType.rewardTrackMonthlyReady,
    AppNotificationType.rewardTrackWeeklyReady,
    AppNotificationType.rewardTrackDailyReady,
  ];

  /// ساعة النوع ضمن [dailySchedule]
  static int scheduledHourOf(AppNotificationType type) =>
      dailySchedule.firstWhere((c) => c.type == type).scheduledHour;

  /// الإشعارات التي يجب أن تكون مجدولة الآن لبقية هذا اليوم — بترتيب
  /// الوقت (9 ثم 13 ثم 20)، متوقّفا فور بلوغ الحد الأقصى اليومي: الأقدم
  /// وقتا يفوز بحصص الحد حرفيا كما نصّت المهمة ("hard cap: 2 per day")
  static List<AppNotificationType> eligibleNow(
    NotificationDecisionInput input,
  ) {
    final last = input.lastAppOpenedAt;
    if (last != null && input.now.difference(last) < openedRecentlyThreshold) {
      return const [];
    }

    var remaining = maxPerDay - input.sentCountToday;
    if (remaining <= 0) return const [];

    final result = <AppNotificationType>[];
    for (final candidate in dailySchedule) {
      if (remaining <= 0) break;
      if (candidate.scheduledHour <= input.now.hour) continue; // فات وقته اليوم
      if (!input.enabledTypes.contains(candidate.type)) continue;

      final conditionMet = switch (candidate.type) {
        AppNotificationType.dailyRewardReady => input.dailyRewardUnclaimed,
        AppNotificationType.rewardTrackMonthlyReady ||
        AppNotificationType.rewardTrackWeeklyReady ||
        AppNotificationType.rewardTrackDailyReady => input.readyRewardTiers
            .contains(candidate.type),
        AppNotificationType.streakEndingTonight =>
          input.streakNotYetSecuredToday,
        // ليس من جدول اليوم أصلا (غير مذكور في dailySchedule)، وهذا
        // الفرع موجود لأن switch على enum يجب أن يكون شاملا
        AppNotificationType.comebackReminder => false,
      };
      if (!conditionMet) continue;

      result.add(candidate.type);
      remaining--;
    }
    return result;
  }

  /// بعد كم يوم من *اليوم* يُذكَّر اللاعب إن لم يفتح اللعبة مرة أخرى.
  /// يومان ثم أربعة ثم أسبوع: يتباعد بدل أن يلحّ.
  static const List<int> comebackDaysAhead = [2, 4, 7];

  /// مساء، لا صباحا: التذكير الصباحي (9) مخصّص لمن يفتح اللعبة أصلا
  static const int comebackHour = 19;

  /// تذكيرات الأيام القادمة.
  ///
  /// [eligibleNow] وحدها لا تكفي: كل ما تجدوله ينتهي بنهاية اليوم، فمن
  /// يتوقّف عن فتح اللعبة لا يصله شيء بعد ذلك أبدا — وهو بالضبط اللاعب
  /// الذي يُراد تذكيره. هذه تجدول سلسلة مسبقة تُطلق نفسها بلا فتح.
  ///
  /// كلها تُلغى وتُعاد جدولتها من الصفر عند كل فتح (راجع الشرح أعلى
  /// الملف)، فمن يلعب يوميا لا يرى منها شيئا: تذكير اليوم الثاني يُلغى
  /// قبل موعده كلما فُتحت اللعبة.
  static List<ScheduledNotification> comebackPlan({required bool enabled}) {
    if (!enabled) return const [];
    return [
      for (final days in comebackDaysAhead)
        ScheduledNotification(
          type: AppNotificationType.comebackReminder,
          daysAhead: days,
          hour: comebackHour,
        ),
    ];
  }

  /// تذكيرات مسار الجوائز للأيام القادمة.
  ///
  /// [eligibleNow] وحدها تجعلها تذكيرا لمن *فتح اللعبة قبل ساعة النوع في
  /// نفس اليوم* فقط: من يفتحها مساءً فات موعد اليوم عنده، ومن لا يفتحها
  /// إطلاقا لا يصله شيء — وهو المقصود بالتذكير أصلا. هذه تجدول سلسلة
  /// مسبقة تُطلق نفسها بلا فتح، فيصل تذكير الجائزة فعلا.
  ///
  /// وكما في [comebackPlan]: تُلغى وتُعاد الجدولة من الصفر عند كل فتح،
  /// فمن طالب بجائزة اليوم صباحا لا يصله تذكيرها بعد الظهر.
  static const int rewardTrackDaysAhead = 3;

  /// [readyDaysAhead]: لكل نوع، الأيام القادمة التي ستكون جائزته جاهزة
  /// فيها لو لم تُفتح اللعبة — يحسبها `RewardTrackEngine.readyDaysAhead`.
  ///
  /// تذكير واحد على الأكثر لكل يوم: من اجتمعت عنده طبقتان في يوم واحد
  /// يصله خبر الأثمن وحده ([rewardTrackTypes] مرتّبة لهذا). ثلاثة
  /// إشعارات في يوم واحد عن ثلاث جوائز تنتظر في *نفس الشاشة* إزعاج بلا
  /// مقابل، وفتحة واحدة تكفي لجرّه إليها.
  static List<ScheduledNotification> rewardTrackPlan({
    required bool enabled,
    required Map<AppNotificationType, List<int>> readyDaysAhead,
  }) {
    if (!enabled) return const [];
    final bestPerDay = <int, AppNotificationType>{};
    for (final type in rewardTrackTypes) {
      for (final days in readyDaysAhead[type] ?? const <int>[]) {
        if (days < 1 || days > rewardTrackDaysAhead) continue;
        bestPerDay.putIfAbsent(days, () => type);
      }
    }
    final days = bestPerDay.keys.toList()..sort();
    return [
      for (final day in days)
        ScheduledNotification(
          type: bestPerDay[day]!,
          daysAhead: day,
          hour: scheduledHourOf(bestPerDay[day]!),
        ),
    ];
  }

  /// "بعد الجلسة الثالثة، لا عند الإطلاق" — [sessionCount] يشمل الجلسة
  /// الحالية (أول فتح = 1)
  static bool shouldRequestPermission({
    required int sessionCount,
    required bool alreadyRequested,
  }) => !alreadyRequested && sessionCount >= 3;
}
