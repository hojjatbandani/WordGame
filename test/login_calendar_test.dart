import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/login_calendar.dart';

void main() {
  group('LoginCalendar.rewardForPosition — الجداول الثلاثة', () {
    test('الأسبوع الأول يطابق الجدول المعطى بالضبط', () {
      const expected = [20, 30, 40, 50, 75, 100, 200];
      for (var day = 1; day <= 7; day++) {
        expect(LoginCalendar.rewardForPosition(day).coins, expected[day - 1],
            reason: 'اليوم $day من الأسبوع الأول');
      }
    });

    test('الأسبوع الثاني (المواضع 8..14) يطابق الجدول المعطى بالضبط', () {
      const expected = [25, 35, 50, 60, 80, 120, 250];
      for (var day = 1; day <= 7; day++) {
        expect(LoginCalendar.rewardForPosition(7 + day).coins, expected[day - 1],
            reason: 'اليوم $day من الأسبوع الثاني (موضع ${7 + day})');
      }
    });

    test('الأسبوع الثالث (المواضع 15..21) يطابق الجدول المعطى بالضبط', () {
      const expected = [30, 40, 55, 70, 90, 140, 300];
      for (var day = 1; day <= 7; day++) {
        expect(LoginCalendar.rewardForPosition(14 + day).coins, expected[day - 1],
            reason: 'اليوم $day من الأسبوع الثالث (موضع ${14 + day})');
      }
    });

    test('الأسبوع الرابع فما فوق يكرّر قيم الأسبوع الثالث', () {
      const week3 = [30, 40, 55, 70, 90, 140, 300];
      // الأسبوع 4 (مواضع 22..28) والأسبوع 7 (مواضع 43..49) كلاهما = week3
      for (var day = 1; day <= 7; day++) {
        expect(LoginCalendar.rewardForPosition(21 + day).coins, week3[day - 1]);
        expect(LoginCalendar.rewardForPosition(42 + day).coins, week3[day - 1]);
      }
    });

    test('لا قطع أزياء في الأسابيع 1-3، حتى في يوم 7', () {
      expect(LoginCalendar.rewardForPosition(7).cosmeticShards, 0);
      expect(LoginCalendar.rewardForPosition(14).cosmeticShards, 0);
      expect(LoginCalendar.rewardForPosition(21).cosmeticShards, 0);
    });

    test('قطعة أزياء واحدة في يوم 7 من الأسبوع 4 فصاعدا فقط', () {
      expect(LoginCalendar.rewardForPosition(28).cosmeticShards, // أسبوع4 يوم7
          BalanceConfig.loginCalendarShardAmount);
      expect(LoginCalendar.rewardForPosition(27).cosmeticShards, 0); // أسبوع4 يوم6
      expect(LoginCalendar.rewardForPosition(35).cosmeticShards, // أسبوع5 يوم7
          BalanceConfig.loginCalendarShardAmount);
    });
  });

  group('اختبار قبول: كسر يوم في التقويم يستأنف من اليوم التالي، لا من الصفر', () {
    test('الوصول لليوم5 ثم فوات يوم يستأنف عند اليوم6 لا اليوم1', () {
      // هذا الاختبار يوثّق العقد المطلوب من DailyRewardNotifier نفسه
      // (providers.dart)، لا من LoginCalendar وحده: "موضع" اللاعب
      // (calendarPosition) يجب أن يتقدّم فقط بمطالبات ناجحة (+1 لكل
      // مطالبة)، ولا يُصفَّر أبدا بمرور الوقت — راجع
      // test/daily_reward_test.dart للاختبار الفعلي عبر Notifier الحقيقي
      // مع SharedPreferences. هنا فقط نتحقّق أن دالة المكافأة نفسها بلا
      // حالة (stateless) وتقبل أي موضع مباشرة بلا أي منطق "تصفير":
      final position5 = LoginCalendar.rewardForPosition(5);
      final position6 = LoginCalendar.rewardForPosition(6);
      expect(position5.coins, 75); // اليوم5 من الأسبوع1
      expect(position6.coins, 100); // اليوم6 من الأسبوع1 — لا إعادة لليوم1 (20)
    });
  });
}
