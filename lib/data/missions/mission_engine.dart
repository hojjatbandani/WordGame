// اختيار مهمات اليوم/الأسبوع وسحب صندوق المهمات — منطق صرف بالكامل، بلا
// استيراد Flutter. [rng] يُمرَّر صراحة دوما (بدل Random() داخلي) كي
// يُختبر حتميا، تماما كنمط economy/chapter_chest.dart وwheel_engine.dart.

import 'dart:math';

import 'mission_models.dart';

class MissionEngine {
  const MissionEngine._();

  /// يختار مهمة واحدة من كل مستوى صعوبة (سهل/متوسط/صعب) — 3 إجمالا.
  /// المهمات التي تشترط مستوى لاعب أعلى من [playerLevel] تُستبعَد من
  /// المجمّع *قبل* الاختيار العشوائي، فلا تظهر أصلا لمن لا يستحقّها
  /// (حرفيا: "لا تُسنَد أبدا"، لا "تُسنَد ثم تُخفى").
  static List<MissionDef> selectDaily({
    required int playerLevel,
    required Random rng,
  }) {
    MissionDef pickFrom(List<MissionDef> pool) {
      final eligible = pool
          .where((m) => m.minPlayerLevel == null || playerLevel >= m.minPlayerLevel!)
          .toList();
      return eligible[rng.nextInt(eligible.length)];
    }

    return [
      pickFrom(dailyEasyPool),
      pickFrom(dailyMediumPool),
      pickFrom(dailyHardPool),
    ];
  }

  /// 3 مهمات مختلفة من مجمّع الأسبوعية (لا شرط مستوى فيه حاليا)
  static List<MissionDef> selectWeekly({required Random rng}) {
    final shuffled = List<MissionDef>.from(weeklyPool)..shuffle(rng);
    return shuffled.take(3).toList();
  }

  static const int dailyChestMinCoins = 50;
  static const int dailyChestMaxCoins = 120;

  /// احتمال شحنة التلميح الإضافية لم يُعطَ رقما صريحا — 50% افتراض صريح
  /// وسط معقول لـ"فرصة" (chance) بلا مزيد من التفصيل
  static const double hintChargeChance = 0.5;

  static DailyChestReward rollDailyChest(Random rng) {
    final span = dailyChestMaxCoins - dailyChestMinCoins + 1;
    final coins = dailyChestMinCoins + rng.nextInt(span);
    return DailyChestReward(
      coins: coins,
      hintCharge: rng.nextDouble() < hintChargeChance,
    );
  }

  /// بداية أقرب اثنين محليين (يوم الاثنين نفسه إن كان اليوم هو الاثنين)
  static DateTime mostRecentMonday(DateTime now) {
    final dateOnly = DateTime(now.year, now.month, now.day);
    final daysSinceMonday = (dateOnly.weekday - DateTime.monday) % 7;
    // طرح أيام تقويمية لا Duration: عبر يوم تغيير التوقيت الصيفي كان
    // الطرح يهبط على الأحد 23:00 فيتغيّر مفتاح الأسبوع في منتصفه
    // وتُعاد مهمات الأسبوع من الصفر
    return DateTime(now.year, now.month, now.day - daysSinceMonday);
  }
}
