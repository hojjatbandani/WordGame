import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/challenge_models.dart';
import 'package:huruf/data/challenge_progress.dart';

const _cat = ChallengeCategory.proverb;

Set<String> _solved(Iterable<int> indices) =>
    {for (final i in indices) ChallengeProgressRules.idFor(_cat, i)};

void main() {
  group('عقد خريطة التحدّيات', () {
    test('لا شيء محلول: الأولى حالية والبقية مقفلة', () {
      final nodes = ChallengeProgressRules.buildNodes(
        category: _cat,
        total: 4,
        solvedIds: const {},
      );
      expect(nodes.map((n) => n.status).toList(), [
        ChallengeNodeStatus.current,
        ChallengeNodeStatus.locked,
        ChallengeNodeStatus.locked,
        ChallengeNodeStatus.locked,
      ]);
    });

    test('الحالية هي أول غير محلولة — لا أكثر من واحدة', () {
      final nodes = ChallengeProgressRules.buildNodes(
        category: _cat,
        total: 4,
        solvedIds: _solved([0, 1]),
      );
      expect(nodes.map((n) => n.status).toList(), [
        ChallengeNodeStatus.completed,
        ChallengeNodeStatus.completed,
        ChallengeNodeStatus.current,
        ChallengeNodeStatus.locked,
      ]);
    });

    test('حلّ متقطّع لا يفتح ما بعده: الفجوة تبقى هي الحالية', () {
      final nodes = ChallengeProgressRules.buildNodes(
        category: _cat,
        total: 4,
        solvedIds: _solved([0, 2]),
      );
      expect(nodes[1].status, ChallengeNodeStatus.current);
      expect(nodes[3].status, ChallengeNodeStatus.locked);
      // المحلولة تبقى محلولة حتى لو سبقتها فجوة
      expect(nodes[2].status, ChallengeNodeStatus.completed);
    });

    test('كل شيء محلول: لا عقدة حالية', () {
      final nodes = ChallengeProgressRules.buildNodes(
        category: _cat,
        total: 3,
        solvedIds: _solved([0, 1, 2]),
      );
      expect(
        nodes.every((n) => n.status == ChallengeNodeStatus.completed),
        isTrue,
      );
    });
  });

  group('صندوق الفئة', () {
    test('لا يستحقّ قبل اكتمال الفئة', () {
      expect(
        ChallengeProgressRules.isChestClaimable(
          category: _cat,
          total: 3,
          solvedIds: _solved([0, 1]),
          claimedChestIds: const {},
        ),
        isFalse,
      );
    });

    test('يستحقّ فور اكتمالها', () {
      expect(
        ChallengeProgressRules.isChestClaimable(
          category: _cat,
          total: 3,
          solvedIds: _solved([0, 1, 2]),
          claimedChestIds: const {},
        ),
        isTrue,
      );
    });

    test('لا يُستلَم مرّتين', () {
      expect(
        ChallengeProgressRules.isChestClaimable(
          category: _cat,
          total: 3,
          solvedIds: _solved([0, 1, 2]),
          claimedChestIds: {ChallengeProgressRules.chestIdFor(_cat)},
        ),
        isFalse,
      );
    });

    test('فئة فارغة لا تُعدّ مكتملة — وإلا مُنح صندوق بلا لعب', () {
      expect(
        ChallengeProgressRules.isCategoryComplete(
          category: _cat,
          total: 0,
          solvedIds: const {},
        ),
        isFalse,
      );
    });
  });

  test('معرّفات الفئات لا تتداخل', () {
    final ids = {
      for (final c in ChallengeCategory.values)
        ChallengeProgressRules.idFor(c, 0),
    };
    expect(ids.length, ChallengeCategory.values.length);
  });

  test('لكل فئة مرشد مختلف', () {
    final guides = {
      for (final c in ChallengeCategory.values)
        ChallengeProgressRules.guideFor(c),
    };
    expect(guides.length, ChallengeCategory.values.length);
  });
}
