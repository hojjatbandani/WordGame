// نصوص الودجة الجاهزة للعرض. منطق صرف، بلا استيراد Flutter.
//
// **لماذا تُبنى هنا لا في كوتلن/سويفت:** الودجة تعيش في ثلاث منصّات
// (أندرويد، iOS، واختبارات Dart)، وصياغة عربية واحدة مكتوبة ثلاث مرات
// تتباعد بعد أول تعديل. الجانب الأصلي يرسم ما يصله حرفيا ولا يؤلّف
// جملة واحدة — فتبقى كل كلمة عربية في اللعبة قابلة للتغيير من مكان
// واحد ومُختبَرة بلا محاكي.
//
// وهذا يحلّ كذلك أصعب ما في التعريب داخل ودجة: صيغ المثنى والجمع
// العربية («يوم/يومان/أيام») لا يعرفها RemoteViews ولا SwiftUI.

import '../rewards/reward_track.dart';
import 'widget_data.dart';

/// النصوص المعروضة في كل أحجام الودجة
class WidgetText {
  final String appName;

  /// عنوان البطاقة المُبرَزة: «المكافأة اليومية»
  final String focusTitle;

  /// «🎁 +20 💎» — المبلغ مع رمزه
  final String focusAmount;

  /// «جاهزة للاستلام» أو «✓ تم الاستلام» أو «بعد 3 أيام»
  final String focusStatus;

  /// سطر مساعد يشرح ما بعدها: «غدا مكافأة جديدة»
  final String focusHint;

  /// «4 / 7 أيام» أو «12 / 30 يوم» — فارغ للطبقة اليومية
  final String focusProgress;

  /// نصّ الزرّ: «استلمها الآن» أو «افتح اللعبة»
  final String cta;

  /// «🔥 12 يوما متتالية»
  final String streak;

  /// أسطر الطبقات الثلاث في الحجم الكبير
  final List<String> tierTitles;
  final List<String> tierStatuses;

  /// «المكافآت» — عنوان الحجم الكبير
  final String allTitle;

  /// «137 مرحلة · 11 فصلا · 2 عالم»
  final String stats;

  /// يُعرض حين لا تُقرأ أي بيانات (تثبيت جديد، أو بيانات تالفة)
  final String emptyTitle;
  final String emptyHint;

  const WidgetText({
    required this.appName,
    required this.focusTitle,
    required this.focusAmount,
    required this.focusStatus,
    required this.focusHint,
    required this.focusProgress,
    required this.cta,
    required this.streak,
    required this.tierTitles,
    required this.tierStatuses,
    required this.allTitle,
    required this.stats,
    required this.emptyTitle,
    required this.emptyHint,
  });

  Map<String, Object?> toJson() => {
    'appName': appName,
    'focusTitle': focusTitle,
    'focusAmount': focusAmount,
    'focusStatus': focusStatus,
    'focusHint': focusHint,
    'focusProgress': focusProgress,
    'cta': cta,
    'streak': streak,
    'tierTitles': tierTitles,
    'tierStatuses': tierStatuses,
    'allTitle': allTitle,
    'stats': stats,
    'emptyTitle': emptyTitle,
    'emptyHint': emptyHint,
  };

  // ─────────────────────── الصياغة ───────────────────────

  static String _tierTitle(RewardTier tier, bool ar) => switch (tier) {
    RewardTier.daily => ar ? 'المكافأة اليومية' : 'Daily reward',
    RewardTier.weekly => ar ? 'المكافأة الأسبوعية' : 'Weekly reward',
    RewardTier.monthly => ar ? 'المكافأة الشهرية' : 'Monthly reward',
  };

  /// صيغة عربية سليمة للأيام: المفرد والمثنى والجمع لكلٍّ لفظه
  static String _days(int n, bool ar) {
    if (!ar) return n == 1 ? '1 day' : '$n days';
    return switch (n) {
      1 => 'يوم واحد',
      2 => 'يومان',
      >= 3 && <= 10 => '$n أيام',
      _ => '$n يوما',
    };
  }

  static String _inDays(int n, bool ar) {
    if (n <= 0) return ar ? 'الآن' : 'now';
    if (!ar) return n == 1 ? 'tomorrow' : 'in $n days';
    return switch (n) {
      1 => 'غدا',
      2 => 'بعد يومين',
      >= 3 && <= 10 => 'بعد $n أيام',
      _ => 'بعد $n يوما',
    };
  }

  static String _statusOf(WidgetTierState tier, bool ar) {
    if (tier.isComplete) return ar ? 'اكتملت' : 'Complete';
    if (tier.isReady) return ar ? 'جاهزة للاستلام' : 'Ready to claim';
    if (tier.claimedToday) return ar ? '✓ تم الاستلام' : '✓ Claimed';
    return _inDays(tier.daysUntilReady ?? 0, ar);
  }

  /// «4 / 7 أيام» — فارغ لليومية (دورتها يوم واحد، فلا تقدّم يُعرض)
  /// وللمنتهية
  static String _progressOf(WidgetTierState tier, bool ar) {
    if (tier.isComplete || tier.cyclePeriodDays <= 1) return '';
    final done = tier.cycleElapsedDays;
    final total = tier.cyclePeriodDays;
    return ar ? '$done / ${_days(total, true)}' : '$done / $total days';
  }

  static WidgetText of(HomeWidgetData data) {
    final ar = data.isRtl;
    final focus = data.focus;

    final focusTitle = focus == null
        ? (ar ? 'اكتمل مسار الجوائز' : 'Reward track complete')
        : _tierTitle(focus.tier, ar);

    final focusAmount = focus == null
        ? ''
        // النجمة الذهبية والألماسة حول الرقم: الرقم لاتيني ويبقى
        // بترتيبه داخل جملة عربية بلا انقلاب
        : '🎁 +${focus.coins} 💎';

    final focusHint = switch (focus) {
      null => ar ? 'استلمت كل الجوائز المتاحة' : 'All rewards claimed',
      _ when focus.isComplete =>
        ar ? 'انتهت هذه المكافأة' : 'This reward has ended',
      _ when focus.claimedToday && focus.tier == RewardTier.daily =>
        ar ? 'غدا مكافأة جديدة' : 'A new reward tomorrow',
      _ when focus.isReady => ar ? 'افتح اللعبة واستلمها' : 'Open and claim it',
      _ => ar ? 'مكافأتك القادمة' : 'Your next reward',
    };

    return WidgetText(
      appName: ar ? 'حروف' : 'Huruf',
      focusTitle: focusTitle,
      focusAmount: focusAmount,
      focusStatus: focus == null ? '' : _statusOf(focus, ar),
      focusHint: focusHint,
      focusProgress: focus == null ? '' : _progressOf(focus, ar),
      cta: data.hasClaimable
          ? (ar ? 'استلمها الآن' : 'Claim now')
          : (ar ? 'افتح اللعبة' : 'Open the game'),
      streak: data.streakDays <= 0
          ? (ar ? 'ابدأ سلسلتك اليوم' : 'Start your streak today')
          : '🔥 ${_days(data.streakDays, ar)}'
                '${ar ? ' متتالية' : ' streak'}',
      tierTitles: [for (final t in data.tiers) _tierTitle(t.tier, ar)],
      tierStatuses: [
        for (final t in data.tiers)
          () {
            final progress = _progressOf(t, ar);
            final status = _statusOf(t, ar);
            return progress.isEmpty ? status : '$status · $progress';
          }(),
      ],
      allTitle: ar ? 'المكافآت' : 'Rewards',
      stats: ar
          ? '${data.stagesCompleted} مرحلة · '
                '${data.chaptersCompleted} فصلا · '
                '${data.worldsCompleted} عالما'
          : '${data.stagesCompleted} stages · '
                '${data.chaptersCompleted} chapters · '
                '${data.worldsCompleted} worlds',
      emptyTitle: ar ? 'حروف' : 'Huruf',
      emptyHint: ar ? 'افتح اللعبة لتبدأ' : 'Open the game to start',
    );
  }
}
