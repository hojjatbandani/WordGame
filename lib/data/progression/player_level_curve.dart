// منحنى مستوى اللاعب — منطق صرف، بلا حالة، بلا استيراد Flutter.
//
// XP اللازمة للانتقال من المستوى n إلى n+1:
//   xpBaseForLevel + xpIncrementPerLevel * (n - 1)
// أي أن الوصول إلى المستوى n (من الصفر) يحتاج مجموع تكاليف كل المستويات
// من 1 حتى n-1.

import '../../config/balance_config.dart';

class PlayerLevelCurve {
  const PlayerLevelCurve._();

  /// XP اللازمة للانتقال من [level] إلى [level] + 1
  static int xpToAdvanceFrom(int level) {
    assert(level >= 1, 'المستوى يبدأ من 1');
    return BalanceConfig.xpBaseForLevel +
        BalanceConfig.xpIncrementPerLevel * (level - 1);
  }

  /// مجموع XP اللازم للوصول إلى [level] بدءا من صفر عند المستوى 1
  static int cumulativeXpToReach(int level) {
    assert(level >= 1, 'المستوى يبدأ من 1');
    var total = 0;
    for (var n = 1; n < level; n++) {
      total += xpToAdvanceFrom(n);
    }
    return total;
  }

  /// المستوى الحالي بحسب [xp] الكلي المتراكم (لا يُستهلك أبدا)
  static int currentLevel(int xp) {
    assert(xp >= 0, 'XP لا يمكن أن تكون سالبة');
    var level = 1;
    // حارس أمان بحت ضد حلقة لا نهائية لو انكسر افتراض التزايد يوما ما؛
    // لا يُتوقع بلوغه فعليا في أي سيناريو لعب حقيقي
    const safetyMaxLevel = 100000;
    while (level < safetyMaxLevel &&
        cumulativeXpToReach(level + 1) <= xp) {
      level++;
    }
    return level;
  }

  /// كم من XP دخل ضمن المستوى الحالي (لا يشمل ما استُهلك في مستويات سابقة)
  static int xpIntoCurrentLevel(int xp) =>
      xp - cumulativeXpToReach(currentLevel(xp));

  /// XP اللازمة لإتمام المستوى الحالي والانتقال للتالي
  static int xpNeededForNextLevel(int xp) => xpToAdvanceFrom(currentLevel(xp));

  /// نسبة التقدّم داخل المستوى الحالي، بين 0 و1
  static double levelProgress01(int xp) {
    final needed = xpNeededForNextLevel(xp);
    if (needed <= 0) return 1; // حارس دفاعي، لا يقع فعليا بقيم التوازن الحالية
    return (xpIntoCurrentLevel(xp) / needed).clamp(0.0, 1.0);
  }
}
