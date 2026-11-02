import 'package:flutter/foundation.dart';

import 'analytics_event.dart';

/// واجهة تسجيل الأحداث. PostHog هو نظام التحليلات الوحيد
/// (posthog_sink.dart)؛ هذه الطبقة تُلحق السياق (المستوى، المرحلة،
/// الرصيد) ثم تسلّم الحدث إلى [sink].
///
/// قاعدتان تحكمان كل ما هنا:
///  1) **لا يُسقِط التطبيق أبدا.** كل مسار محروس؛ فشل التحليلات لا يُرى
///     ولا يُشعر به اللاعب. حدث ضائع أهون من جلسة ضائعة.
///  2) **لا يُبطئ شيئا.** [log] لا ينتظر شيئا؛ الطابور وإعادة المحاولة
///     والإرسال داخل حزمة PostHog نفسها.
class AnalyticsService {
  AnalyticsService({this.sink});

  /// وجهة الأحداث (PostHogSink.track). null = لا تحليلات: سطح المكتب
  /// والاختبارات.
  final void Function(AnalyticsEvent event)? sink;

  /// سياق يُلحَق بكل حدث تلقائيا. تُحدَّث من طبقة الواجهة عند تغيّرها،
  /// فلا تحتاج كل نقطة نداء أن تمرّرها.
  int? _playerLevel;
  int? _stageId;
  int? _coinBalance;

  void updateContext({int? playerLevel, int? stageId, int? coinBalance}) {
    if (playerLevel != null) _playerLevel = playerLevel;
    if (stageId != null) _stageId = stageId;
    if (coinBalance != null) _coinBalance = coinBalance;
  }

  /// المرحلة تنتهي بمغادرة الشاشة — نمسحها كي لا تُنسب أحداث لاحقة
  /// (متجر، عجلة) إلى مرحلة لم يعد فيها اللاعب
  void clearStage() => _stageId = null;

  /// يسجّل حدثا. لا ينتظر شيئا ولا يرمي شيئا.
  void log(String name, [Map<String, Object?> properties = const {}]) {
    try {
      sink?.call(
        AnalyticsEvent(
          name: name,
          properties: properties,
          playerLevel: _playerLevel,
          stageId: _stageId,
          coinBalance: _coinBalance,
        ),
      );
    } catch (e) {
      debugPrint('التحليلات: تعذّر التسجيل — $e');
    }
  }
}
