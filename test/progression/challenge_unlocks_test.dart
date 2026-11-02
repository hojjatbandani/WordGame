import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/challenge_models.dart';
import 'package:huruf/data/progression/challenge_unlocks.dart';

void main() {
  bool open(
    ChallengeCategory c, {
    int chapters = 0,
    int worlds = 0,
  }) => ChallengeUnlocks.isUnlocked(
    c,
    chaptersCompleted: chapters,
    worldsCompleted: worlds,
  );

  group('بوّابات الأنماط اللغوية', () {
    test('اللاعب الجديد لا يملك أيّ نمط', () {
      for (final c in ChallengeUnlocks.order) {
        expect(open(c), isFalse, reason: c.name);
      }
    });

    test('النمط الأول بفصلين لا بعالم كامل', () {
      expect(open(ChallengeCategory.proverb, chapters: 1), isFalse);
      expect(open(ChallengeCategory.proverb, chapters: 2), isTrue);
      // فصول عالم واحد خمسة: النمط الأول يسبق أول عالم بكثير
      expect(BalanceConfig.challengeFirstUnlockChapters,
          lessThan(BalanceConfig.chaptersPerWorld));
    });

    test('كل نمط بعده يحتاج عالمين إضافيين', () {
      expect(open(ChallengeCategory.verse, chapters: 40, worlds: 1), isFalse);
      expect(open(ChallengeCategory.verse, worlds: 2), isTrue);

      expect(open(ChallengeCategory.word, worlds: 3), isFalse);
      expect(open(ChallengeCategory.word, worlds: 4), isTrue);

      expect(open(ChallengeCategory.gulfProverb, worlds: 5), isFalse);
      expect(open(ChallengeCategory.gulfProverb, worlds: 6), isTrue);
    });

    test('آخر نمط يُفتح قبل نهاية اللعبة لا عندها', () {
      final last = ChallengeUnlocks.gateFor(ChallengeUnlocks.order.last);
      expect(last.worlds, lessThan(BalanceConfig.worldCount));
    });

    test('الترتيب يغطّي الفئات الأربع بلا تكرار', () {
      expect(ChallengeUnlocks.order.toSet(), ChallengeCategory.values.toSet());
      expect(ChallengeUnlocks.order.length, ChallengeCategory.values.length);
    });
  });
}
