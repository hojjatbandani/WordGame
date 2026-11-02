// نصّ الإشعار يجب أن يتبع لغة الواجهة المختارة، لا أن يبقى بلغة واحدة.
// (إعادة صياغة ما هو مجدول عند تبديل اللغة تعيش في
// relocalizeScheduledNotifications، وتستدعي نفس الدالة المختبَرة هنا.)

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/core/app_language.dart';
import 'package:huruf/data/notifications/notification_models.dart';
import 'package:huruf/presentation/providers.dart';

void main() {
  // كل ما يُجدول فعلا: جدول اليوم كاملا. تذكير العودة نصّه في
  // _scheduleComebackChain لا هنا (نصّه يتدرّج مع طول الغياب).
  final scheduledTypes = [
    for (final type in AppNotificationType.values)
      if (type != AppNotificationType.comebackReminder) type,
  ];

  test('كل نوع مجدول له نصّ غير فارغ في اللغتين، ومختلف بينهما', () {
    for (final type in scheduledTypes) {
      final (arTitle, arBody) = notificationTitleBody(
        type: type,
        lang: AppLanguage.ar,
        streakDays: 4,
      );
      final (enTitle, enBody) = notificationTitleBody(
        type: type,
        lang: AppLanguage.en,
        streakDays: 4,
      );

      expect(arTitle, isNotEmpty, reason: type.name);
      expect(arBody, isNotEmpty, reason: type.name);
      expect(enTitle, isNotEmpty, reason: type.name);
      expect(enBody, isNotEmpty, reason: type.name);
      expect(enTitle, isNot(arTitle), reason: '${type.name}: عنوان غير مترجم');
      expect(enBody, isNot(arBody), reason: '${type.name}: نصّ غير مترجم');
    }
  });

  test('النصّ الإنجليزي بلا حروف عربية والعكس', () {
    final arabic = RegExp(r'[؀-ۿ]');
    for (final type in scheduledTypes) {
      final (enTitle, enBody) = notificationTitleBody(
        type: type,
        lang: AppLanguage.en,
        streakDays: 3,
      );
      expect(arabic.hasMatch(enTitle), isFalse, reason: type.name);
      expect(arabic.hasMatch(enBody), isFalse, reason: type.name);
    }
  });

  test('الأرقام الحيّة تدخل النصّ فعلا: طول السلسلة', () {
    final (_, streakBody) = notificationTitleBody(
      type: AppNotificationType.streakEndingTonight,
      lang: AppLanguage.en,
      streakDays: 7,
    );
    expect(streakBody, contains('7'));
  });

  test('كل طبقة من المسار تحمل مبلغها هي لا مبلغ غيرها', () {
    final cases = {
      AppNotificationType.rewardTrackDailyReady:
          BalanceConfig.rewardTrackDailyCoins,
      AppNotificationType.rewardTrackWeeklyReady:
          BalanceConfig.rewardTrackWeeklyCoins,
      AppNotificationType.rewardTrackMonthlyReady:
          BalanceConfig.rewardTrackMonthlyCoins,
    };
    for (final entry in cases.entries) {
      final (_, body) = notificationTitleBody(
        type: entry.key,
        lang: AppLanguage.ar,
        streakDays: 0,
      );
      expect(body, contains('${entry.value}'), reason: entry.key.name);
    }
  });

  test('عناوين الطبقات الثلاث مختلفة — لا «جائزة جاهزة» ثلاث مرات', () {
    final titles = {
      for (final type in const [
        AppNotificationType.rewardTrackDailyReady,
        AppNotificationType.rewardTrackWeeklyReady,
        AppNotificationType.rewardTrackMonthlyReady,
      ])
        notificationTitleBody(
          type: type,
          lang: AppLanguage.ar,
          streakDays: 0,
        ).$1,
    };
    expect(titles.length, 3);
  });
}
