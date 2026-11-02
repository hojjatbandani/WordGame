// مكافآت جرّة الكلمات الإضافية لكل عالم — منطق صرف بالكامل. الجرّة
// تستمر بالعدّ بعد عتبتها عمدا (لا تُقصّ أبدا — راجع progression_engine.dart)،
// فتُمنَح طبقة ثانية عند 150% من العتبة الأصلية. المكافأة تُمنَح تلقائيا
// لحظة بلوغ العتبة (لا خطوة "استلام" يدوية، خلافا لصندوق الفصل).

class JarTierReward {
  /// 1 (100% من العتبة) أو 2 (150%)
  final int tier;
  final int coins;

  /// معرّف عنصر زخرفي حصري بهذا العالم — لا كتالوج فعلي بعد (مهمة
  /// الأزياء المنفصلة)، يُحفَظ كـ"معلَّق" حتى يُبنى ذلك الكتالوج
  final String cosmeticRewardId;

  const JarTierReward({
    required this.tier,
    required this.coins,
    required this.cosmeticRewardId,
  });
}

class JarRewards {
  const JarRewards._();

  static const int tier1Coins = 150;

  /// عتبة الطبقة الثانية = 150% من عتبة الطبقة الأولى، معطاة حرفيا.
  static const double tier2ThresholdMultiplier = 1.5;

  /// مكافأة الطبقة الثانية لم تُعطَ رقما صريحا — امتداد صريح بنفس مضاعف
  /// العتبة (150 × 1.5 = 225)، لا رقم مخترَع بمعزل عن المعطى.
  static const int tier2Coins = 225;

  static int tier2Threshold(int tier1Threshold) =>
      (tier1Threshold * tier2ThresholdMultiplier).round();

  static String cosmeticIdFor(int worldId, int tier) =>
      'jar_tier${tier}_world_$worldId';

  /// كل الطبقات (1، 2، أو كلاهما إن قفز التقدّم فوقهما معا في محاولة
  /// واحدة) التي بلغها [jarProgress] حديثا ولم تُمنَح من قبل [claimedTier]
  static List<JarTierReward> newlyReachedTiers({
    required int worldId,
    required int jarProgress,
    required int tier1Threshold,
    required int claimedTier,
  }) {
    final result = <JarTierReward>[];
    if (claimedTier < 1 && jarProgress >= tier1Threshold) {
      result.add(JarTierReward(
        tier: 1,
        coins: tier1Coins,
        cosmeticRewardId: cosmeticIdFor(worldId, 1),
      ));
    }
    if (claimedTier < 2 && jarProgress >= tier2Threshold(tier1Threshold)) {
      result.add(JarTierReward(
        tier: 2,
        coins: tier2Coins,
        cosmeticRewardId: cosmeticIdFor(worldId, 2),
      ));
    }
    return result;
  }
}
