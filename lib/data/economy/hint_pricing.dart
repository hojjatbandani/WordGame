// تسعير تلميحات شاشة اللعب. Dart صرف: كل قرار (مجاني؟ شحنة؟ كم؟ أيُسأل
// اللاعب قبل الدفع؟) هنا، والشاشة تعرض النتيجة فقط.
//
// المواصفة §7.1 (القرار D3): في المراحل 1..earlyGameStageLimit أول تلميح
// في كل محاولة مجاني والبقية بنحو نصف السعر. ترتيب الدفع: المجاني ثم
// الشحنات المملوكة ثم العملات — من اشترى شحنات لا تُستهلك منه في موضع
// كان مجانيا أصلا.

import '../../config/balance_config.dart';

enum HintType { orderedLetter, randomLetter }

extension HintTypeWire on HintType {
  String get wire => switch (this) {
    HintType.orderedLetter => 'ordered_letter',
    HintType.randomLetter => 'random_letter',
  };
}

enum HintPayment { free, charge, coins, ad }

extension HintPaymentWire on HintPayment {
  String get wire => name;
}

class HintQuote {
  final HintType type;

  /// ما سيُخصم من العملات (0 للمجاني والشحنة)
  final int cost;
  final HintPayment paidWith;
  final bool affordable;

  /// تُعرض ورقة التأكيد قبل الدفع
  final bool requiresConfirm;

  const HintQuote({
    required this.type,
    required this.cost,
    required this.paidWith,
    required this.affordable,
    required this.requiresConfirm,
  });
}

class HintPricing {
  const HintPricing._();

  static bool isEarlyGame(int stageId) =>
      stageId <= BalanceConfig.earlyGameStageLimit;

  /// سعر التلميح بالعملات في هذه المرحلة
  static int price(HintType type, int stageId) {
    final early = isEarlyGame(stageId);
    return switch (type) {
      HintType.orderedLetter =>
        early
            ? BalanceConfig.coinsHintOrderedLetterEarly
            : BalanceConfig.coinsHintOrderedLetter,
      HintType.randomLetter =>
        early
            ? BalanceConfig.coinsHintRandomLetterEarly
            : BalanceConfig.coinsHintRandomLetter,
    };
  }

  static HintQuote quote({
    required HintType type,
    required int stageId,
    required bool freeHintUsed,
    required int charges,
    required int balance,
  }) {
    if (isEarlyGame(stageId) && !freeHintUsed) {
      return HintQuote(
        type: type,
        cost: 0,
        paidWith: HintPayment.free,
        affordable: true,
        requiresConfirm: false,
      );
    }
    if (charges > 0) {
      return HintQuote(
        type: type,
        cost: 0,
        paidWith: HintPayment.charge,
        affordable: true,
        requiresConfirm: false,
      );
    }
    final cost = price(type, stageId);
    return HintQuote(
      type: type,
      cost: cost,
      paidWith: HintPayment.coins,
      affordable: balance >= cost,
      // «غالٍ» = في بداية اللعبة دوما، وبعدها حين يأكل ربع الرصيد أو أكثر
      requiresConfirm:
          isEarlyGame(stageId) ||
          cost >= BalanceConfig.hintConfirmBalanceShare * balance,
    );
  }
}
