import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/economy/economy_models.dart';
import 'package:huruf/data/economy/economy_service.dart';
import 'package:huruf/data/progression/player_state.dart';

EconomyService _service() =>
    EconomyService(wallet: PlayerWallet.initial());

void main() {
  group('كلفة التلميحات', () {
    test('أربعة تلميحات في مرحلة واحدة بالعالم 1 تكلّف 15+25+40+70=150 '
        '(اختبار قبول)', () {
      final economy = _service();
      final costs = [
        economy.quoteHintCost(HintType.revealRandomLetter,
            hintsUsedThisStage: 0, worldId: 1),
        economy.quoteHintCost(HintType.revealRandomLetter,
            hintsUsedThisStage: 1, worldId: 1),
        economy.quoteHintCost(HintType.revealRandomLetter,
            hintsUsedThisStage: 2, worldId: 1),
        economy.quoteHintCost(HintType.revealRandomLetter,
            hintsUsedThisStage: 3, worldId: 1),
      ];
      expect(costs, [15, 25, 40, 70]);
      expect(costs.reduce((a, b) => a + b), 150);
    });

    test('نفس الأربعة تلميحات في العالم 8 تكلّف 30+55+85+145=315 '
        '(اختبار قبول)', () {
      final economy = _service();
      final costs = [
        economy.quoteHintCost(HintType.revealRandomLetter,
            hintsUsedThisStage: 0, worldId: 8),
        economy.quoteHintCost(HintType.revealRandomLetter,
            hintsUsedThisStage: 1, worldId: 8),
        economy.quoteHintCost(HintType.revealRandomLetter,
            hintsUsedThisStage: 2, worldId: 8),
        economy.quoteHintCost(HintType.revealRandomLetter,
            hintsUsedThisStage: 3, worldId: 8),
      ];
      expect(costs, [30, 55, 85, 145]);
      expect(costs.reduce((a, b) => a + b), 315);
    });

    test('التلميح الخامس فما فوق يبقى بسعر الرابع (70 في عالم1)', () {
      final economy = _service();
      final fifth = economy.quoteHintCost(HintType.revealRandomLetter,
          hintsUsedThisStage: 4, worldId: 1);
      final tenth = economy.quoteHintCost(HintType.revealRandomLetter,
          hintsUsedThisStage: 9, worldId: 1);
      expect(fifth, 70);
      expect(tenth, 70);
    });

    test('مغادرة المرحلة وإعادة دخولها تصفّر التصعيد إلى 15 (اختبار قبول): '
        'الدالة لا تحتفظ بأي عدّاد داخلي بين الاستدعاءات', () {
      final economy = _service();
      // محاكاة استخدام 3 تلميحات في مرحلة...
      economy.quoteHintCost(HintType.revealRandomLetter,
          hintsUsedThisStage: 0, worldId: 1);
      economy.quoteHintCost(HintType.revealRandomLetter,
          hintsUsedThisStage: 1, worldId: 1);
      economy.quoteHintCost(HintType.revealRandomLetter,
          hintsUsedThisStage: 2, worldId: 1);
      // ...ثم مغادرة والعودة: المستدعي يعيد hintsUsedThisStage إلى صفر
      final afterReentry = economy.quoteHintCost(HintType.revealRandomLetter,
          hintsUsedThisStage: 0, worldId: 1);
      expect(afterReentry, 15);
    });

    test('نوعا كشف الحرف الأول والحرف العشوائي يتقاسمان نفس سلّم '
        'التصعيد — النوع لا يغيّر السعر، الترتيب هو ما يغيّره', () {
      final economy = _service();
      final first = economy.quoteHintCost(HintType.revealFirstLetter,
          hintsUsedThisStage: 0, worldId: 1);
      final second = economy.quoteHintCost(HintType.revealRandomLetter,
          hintsUsedThisStage: 0, worldId: 1);
      expect(first, second);
      expect(first, 15);
    });

    test('كشف الكلمة كاملة: 120 أساسا، متاح من التلميح الثاني فصاعدا فقط',
        () {
      final economy = _service();
      expect(
        () => economy.quoteHintCost(HintType.revealEntireWord,
            hintsUsedThisStage: 0, worldId: 1),
        throwsStateError,
        reason: 'غير متاح كأول تلميح في المرحلة',
      );
      final cost = economy.quoteHintCost(HintType.revealEntireWord,
          hintsUsedThisStage: 1, worldId: 1);
      expect(cost, 120);
    });

    test('شحنة تلميح مجانية تُستهلك دون أي مساس بالعملات', () {
      final economy = EconomyService(
        wallet: PlayerWallet.initial().copyWith(coins: 100, hintCharges: 2),
      );
      final consumed = economy.consumeHintCharge();
      expect(consumed, isTrue);
      expect(economy.wallet.hintCharges, 1);
      expect(economy.wallet.coins, 100, reason: 'استهلاك شحنة لا يمسّ العملات');
    });

    test('لا شحنات متبقية: consumeHintCharge تعيد false ولا تغيّر شيئا', () {
      final economy = EconomyService(wallet: PlayerWallet.initial());
      expect(economy.consumeHintCharge(), isFalse);
      expect(economy.wallet.hintCharges, 0);
    });

    test('شحنة مجانية واحدة كل 5 مراحل، بحد أقصى 3', () {
      final economy = EconomyService(wallet: PlayerWallet.initial());
      for (var stage = 1; stage <= 4; stage++) {
        economy.grantFreeHintChargeIfEarned(stage);
      }
      expect(economy.wallet.hintCharges, 0, reason: 'لم تكتمل 5 مراحل بعد');

      economy.grantFreeHintChargeIfEarned(5);
      expect(economy.wallet.hintCharges, 1);

      for (final n in [10, 15, 20, 25]) {
        economy.grantFreeHintChargeIfEarned(n);
      }
      expect(economy.wallet.hintCharges, 3, reason: 'لا يتجاوز الحد الأقصى 3');
    });
  });
}
