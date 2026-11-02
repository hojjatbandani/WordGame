/// كل ما قد يُذكَّر به اللاعب. المجموعات قابلة للتفعيل/التعطيل من
/// الإعدادات (راجع home_screen.dart): مفتاح للمكافأة اليومية، ومفتاح
/// لطبقات مسار الجوائز الثلاث معا، ومفتاح للسلسلة.
enum AppNotificationType {
  dailyRewardReady,

  /// طبقات مسار الجوائز الثلاث — «جائزة اليوم/الأسبوع/الشهر جاهزة».
  /// ثلاثة أنواع لا نوع واحد بنصّ متغيّر: النصّ يُثبَّت في نظام التشغيل
  /// لحظة الجدولة، ونوع واحد يعني معرّفا واحدا يدهس نفسه فلا ينجو من
  /// يوم اجتمعت فيه طبقتان إلا آخرها.
  rewardTrackMonthlyReady,
  rewardTrackWeeklyReady,
  rewardTrackDailyReady,

  streakEndingTonight,

  /// تذكير العودة — النوع الوحيد الذي يُجدول لأيام قادمة لا لبقية اليوم.
  /// الثلاثة أعلاه تموت بنهاية اليوم، فمن يتوقّف عن فتح اللعبة لا يصله
  /// منها شيء أبدا. يتبع مفتاح «المكافأة اليومية» في الإعدادات لأنه
  /// عنها يتحدّث (راجع _notificationTypeEnabled في providers.dart).
  comebackReminder,
}

/// تذكير مجدول بعينه: النوع، وبعد كم يوم من اليوم، وأي ساعة محلية.
class ScheduledNotification {
  final AppNotificationType type;
  final int daysAhead;
  final int hour;

  const ScheduledNotification({
    required this.type,
    required this.daysAhead,
    required this.hour,
  });

  /// معرّف فريد لكل (نوع، يوم). مؤجَّلات من نفس النوع تعيش معا في نظام
  /// التشغيل، فمعرّف مبني على النوع وحده يدهس بعضه ولا يبقى إلا الأخير.
  int get id => type.index * 100 + daysAhead;
}

/// موعد إشعار واحد ضمن الجدول اليومي الثابت — الساعة محلية (24س)
class NotificationCandidate {
  final AppNotificationType type;
  final int scheduledHour;
  const NotificationCandidate({
    required this.type,
    required this.scheduledHour,
  });
}

/// كل مدخلات القرار صراحة — لا قراءة حالة ضمنية، فيبقى القرار قابلا
/// للاختبار الحتمي بلا SharedPreferences ولا شبكة ولا وقت حقيقي
class NotificationDecisionInput {
  final bool dailyRewardUnclaimed;

  /// طبقات مسار الجوائز الجاهزة للمطالبة الآن — يحسبها
  /// `RewardTrackEngine.statusOf`. تُمرَّر كأنواع إشعارات لا كطبقات كي
  /// يبقى هذا الملف بلا معرفة بنموذج المسار (منطق الإشعار لا يعرف من
  /// أين جاء الشرط، تماما كبقية الحقول هنا).
  final Set<AppNotificationType> readyRewardTiers;

  final bool streakNotYetSecuredToday;
  final Set<AppNotificationType> enabledTypes;
  final DateTime? lastAppOpenedAt;
  final DateTime now;

  /// كم إشعارا أُرسل/جُدول فعلا اليوم حتى هذه اللحظة (لتطبيق الحد 2)
  final int sentCountToday;

  const NotificationDecisionInput({
    required this.dailyRewardUnclaimed,
    required this.readyRewardTiers,
    required this.streakNotYetSecuredToday,
    required this.enabledTypes,
    required this.lastAppOpenedAt,
    required this.now,
    required this.sentCountToday,
  });
}
