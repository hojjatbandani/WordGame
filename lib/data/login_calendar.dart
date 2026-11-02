// تقويم الدخول اليومي — منطق صرف بالكامل. دوري لا لمرة واحدة: كل
// استدعاء يأخذ "موضعا" رقميا يتزايد بمقدار 1 مع كل مطالبة ناجحة فقط
// (فوات يوم لا يُنقصه أبدا ولا يعيده لـ1 — راجع الشرح في providers.dart
// عند DailyRewardNotifier)، ويُترجمه إلى مكافأة عبر جداول
// BalanceConfig.loginCalendarWeek{1,2,3}Coins.

import '../config/balance_config.dart';

class LoginCalendarReward {
  final int coins;
  final int cosmeticShards;

  const LoginCalendarReward({required this.coins, required this.cosmeticShards});
}

class LoginCalendar {
  const LoginCalendar._();

  /// [position] 1-based، يتزايد للأبد (1، 2، 3...) — لا يُقصّ عند 7.
  static LoginCalendarReward rewardForPosition(int position) {
    assert(position >= 1);
    final zeroBased = position - 1;
    final weekNumber = zeroBased ~/ 7 + 1; // 1-based
    final dayInWeek = zeroBased % 7 + 1; // 1..7

    final table = switch (weekNumber) {
      1 => BalanceConfig.loginCalendarWeek1Coins,
      2 => BalanceConfig.loginCalendarWeek2Coins,
      _ => BalanceConfig.loginCalendarWeek3Coins, // الأسبوع 3 فما فوق يتكرر
    };
    final coins = table[dayInWeek - 1];

    final shards = weekNumber >= BalanceConfig.loginCalendarShardFromWeek &&
            dayInWeek == BalanceConfig.loginCalendarShardDayInWeek
        ? BalanceConfig.loginCalendarShardAmount
        : 0;

    return LoginCalendarReward(coins: coins, cosmeticShards: shards);
  }
}
