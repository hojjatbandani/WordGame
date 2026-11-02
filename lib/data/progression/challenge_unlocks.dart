// بوّابات فتح الأنماط الأربعة (التحدّيات اللغوية) في الرئيسية. منطق صرف
// يأخذ مدخلاته صريحة، فيُختبر بلا شجرة ودجات ولا تخزين.
//
// القاعدة: النمط الأول يُفتح بإتمام فصلين (BalanceConfig)، ثم كل نمط
// بعده بإتمام عالمين إضافيين — 2 ثم 4 ثم 6 عوالم كاملة. الترتيب هنا هو
// ترتيب العرض نفسه في الرئيسية: ما يُفتح أولا يُعرض أولا.

import '../../config/balance_config.dart';
import '../challenge_models.dart';

/// شرط فتح نمط واحد: إمّا عدد فصول مكتملة أو عدد عوالم مكتملة — لا
/// يجتمعان في نمط واحد، فالشرط المركّب لا يمكن عرضه في سطر واحد للاعب.
class ChallengeGate {
  /// عدد الفصول المكتملة المطلوب (0 = لا شرط فصول)
  final int chapters;

  /// عدد العوالم المكتملة المطلوب (0 = لا شرط عوالم)
  final int worlds;

  const ChallengeGate({this.chapters = 0, this.worlds = 0});

  bool isOpen({required int chaptersCompleted, required int worldsCompleted}) =>
      chaptersCompleted >= chapters && worldsCompleted >= worlds;
}

class ChallengeUnlocks {
  const ChallengeUnlocks._();

  /// ترتيب الفتح = ترتيب العرض في الرئيسية
  static const order = <ChallengeCategory>[
    ChallengeCategory.proverb,
    ChallengeCategory.verse,
    ChallengeCategory.word,
    ChallengeCategory.gulfProverb,
  ];

  static ChallengeGate gateFor(ChallengeCategory category) {
    final position = order.indexOf(category);
    if (position <= 0) {
      return ChallengeGate(chapters: BalanceConfig.challengeFirstUnlockChapters);
    }
    return ChallengeGate(
      worlds: position * BalanceConfig.challengeUnlockWorldStep,
    );
  }

  static bool isUnlocked(
    ChallengeCategory category, {
    required int chaptersCompleted,
    required int worldsCompleted,
  }) => gateFor(category).isOpen(
    chaptersCompleted: chaptersCompleted,
    worldsCompleted: worldsCompleted,
  );
}
