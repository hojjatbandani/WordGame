// تقدّم التحدّيات اللغوية — منطق صرف بلا Flutter وبلا تخزين. الحالة
// تُمرَّر كاملة كمدخلات، فيبقى كل قرار (أي عقدة مفتوحة؟ هل اكتملت
// الفئة؟ هل يستحق الصندوق؟) قابلا للاختبار الحتمي.
//
// لماذا الفهرس معرّفا: عناصر challenges.json بلا معرّف خاص بها، وموضع
// العنصر في مصفوفة فئته هو الثابت الوحيد المتاح. أي إعادة ترتيب أو
// إدراج في وسط المصفوفة يزيح تقدّم اللاعب — لذا تُضاف العناصر الجديدة
// في نهاية المصفوفة دوما، لا في وسطها.

import 'challenge_models.dart';

/// حالة عقدة واحدة على خريطة الفئة. مطابقة لمنطق مسار المراحل: خطّي،
/// لا يُفتح تحدٍّ قبل حلّ ما قبله.
enum ChallengeNodeStatus { locked, current, completed }

class ChallengeNode {
  final int index;
  final ChallengeNodeStatus status;

  const ChallengeNode({required this.index, required this.status});
}

class ChallengeProgressRules {
  const ChallengeProgressRules._();

  /// معرّف ثابت لعنصر بعينه: اسم الفئة وموضعه في مصفوفتها
  static String idFor(ChallengeCategory category, int index) =>
      '${category.name}:$index';

  /// معرّف صندوق الفئة (يُستلَم مرة واحدة)
  static String chestIdFor(ChallengeCategory category) => category.name;

  /// عدد المحلولة في هذه الفئة
  static int solvedCount({
    required ChallengeCategory category,
    required int total,
    required Set<String> solvedIds,
  }) {
    var count = 0;
    for (var i = 0; i < total; i++) {
      if (solvedIds.contains(idFor(category, i))) count++;
    }
    return count;
  }

  /// عقد الخريطة بترتيب المصفوفة.
  ///
  /// «الحالية» هي أول غير محلولة — لا أكثر من واحدة، وما بعدها مقفل.
  /// اللاعب الذي حلّ كل شيء لا عقدة حالية له.
  static List<ChallengeNode> buildNodes({
    required ChallengeCategory category,
    required int total,
    required Set<String> solvedIds,
  }) {
    final nodes = <ChallengeNode>[];
    var currentAssigned = false;
    for (var i = 0; i < total; i++) {
      final ChallengeNodeStatus status;
      if (solvedIds.contains(idFor(category, i))) {
        status = ChallengeNodeStatus.completed;
      } else if (!currentAssigned) {
        status = ChallengeNodeStatus.current;
        currentAssigned = true;
      } else {
        status = ChallengeNodeStatus.locked;
      }
      nodes.add(ChallengeNode(index: i, status: status));
    }
    return nodes;
  }

  /// اكتملت الفئة: كل عناصرها محلولة
  static bool isCategoryComplete({
    required ChallengeCategory category,
    required int total,
    required Set<String> solvedIds,
  }) =>
      total > 0 &&
      solvedCount(category: category, total: total, solvedIds: solvedIds) ==
          total;

  /// الصندوق يستحقّ الاستلام: اكتملت الفئة ولم يُستلم بعد
  static bool isChestClaimable({
    required ChallengeCategory category,
    required int total,
    required Set<String> solvedIds,
    required Set<String> claimedChestIds,
  }) =>
      isCategoryComplete(
        category: category,
        total: total,
        solvedIds: solvedIds,
      ) &&
      !claimedChestIds.contains(chestIdFor(category));

  /// خلفية خريطة كل فئة. أسماء الملفات كما وردت من المولّد ولا تُقرأ،
  /// فتعيش هنا مرة واحدة لا متناثرة في الشيفرة.
  ///
  /// المشهد يخدم معنى الفئة لا الزينة: قرية طينية للمثل الشعبي، ومدينة
  /// قباب ومآذن للبيت الشعري، وسوق قافلة لتخمين الكلمة، وحصن ساحلي
  /// على بحر فيروزي للمثل الخليجي.
  static const _bgBase = 'assets/more-missions';

  static String backgroundFor(ChallengeCategory category) => switch (category) {
    ChallengeCategory.proverb =>
      '$_bgBase/u8558185671________________.__________________________._______3b9e3a10-fb67-4963-98a2-48e882cd1282_3.png',
    ChallengeCategory.verse =>
      '$_bgBase/u8558185671_____________________._____________________._______b6e009a2-2845-4fe1-90c0-dc5dff539aae_2.png',
    ChallengeCategory.word =>
      '$_bgBase/u8558185671________________.__________________________._______b772cdf4-52c7-4014-af34-db189ea7f697_1.png',
    ChallengeCategory.gulfProverb =>
      '$_bgBase/u8558185671__________________.___________________.____________10a3a76e-a42e-4747-be14-ae9c99cf5990_2.png',
  };

  /// شخصية مرشد كل فئة — أربع شخصيات مختلفة كي تُميَّز الخرائط الأربع
  /// بعضها عن بعض من أول نظرة، لا وجه واحد مكرّر أربع مرات
  static String guideFor(ChallengeCategory category) => switch (category) {
    ChallengeCategory.proverb => 'wise_oldman',
    ChallengeCategory.verse => 'story_teller',
    ChallengeCategory.word => 'clever_girl',
    ChallengeCategory.gulfProverb => 'friendly_grandma',
  };
}
