// تسعير التلميح (المواصفة §7.1، القرار D3): الأول مجاني في كل محاولة من
// المراحل 1-10، ثم نصف السعر تقريبا، ثم السعر العادي من المرحلة 11.

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/economy/hint_pricing.dart';

HintQuote _q(
  HintType type, {
  int stage = 5,
  bool freeUsed = false,
  int charges = 0,
  int balance = 200,
}) => HintPricing.quote(
  type: type,
  stageId: stage,
  freeHintUsed: freeUsed,
  charges: charges,
  balance: balance,
);

void main() {
  test('stage 5 first hint is free', () {
    final q = _q(HintType.orderedLetter);
    expect(q.paidWith, HintPayment.free);
    expect(q.cost, 0);
    expect(q.requiresConfirm, isFalse);
    expect(q.affordable, isTrue);
  });

  test('stage 5 second hint costs 20 and 10 and confirms', () {
    final ordered = _q(HintType.orderedLetter, freeUsed: true);
    final random = _q(HintType.randomLetter, freeUsed: true);
    expect(ordered.cost, 20);
    expect(random.cost, 10);
    expect(ordered.paidWith, HintPayment.coins);
    expect(ordered.requiresConfirm, isTrue);
    expect(random.requiresConfirm, isTrue);
  });

  test('stage 11 costs 40 and 25 with no free hint', () {
    expect(_q(HintType.orderedLetter, stage: 11).cost, 40);
    expect(_q(HintType.randomLetter, stage: 11).cost, 25);
    expect(_q(HintType.orderedLetter, stage: 11).paidWith, HintPayment.coins);
  });

  test('free beats charge, charge beats coins', () {
    expect(_q(HintType.orderedLetter, charges: 2).paidWith, HintPayment.free);
    final charge = _q(HintType.orderedLetter, charges: 2, freeUsed: true);
    expect(charge.paidWith, HintPayment.charge);
    expect(charge.cost, 0);
    expect(charge.requiresConfirm, isFalse);
  });

  test('stage 15 rich player buys without confirmation', () {
    expect(
      _q(HintType.orderedLetter, stage: 15, balance: 1000).requiresConfirm,
      isFalse,
    );
  });

  test('stage 15 confirms when cost is at least a quarter of balance', () {
    expect(
      _q(HintType.orderedLetter, stage: 15, balance: 100).requiresConfirm,
      isTrue,
    );
  });

  test('unaffordable when balance is short and no charges', () {
    final q = _q(HintType.orderedLetter, stage: 15, balance: 10);
    expect(q.affordable, isFalse);
    expect(q.cost, 40);
  });

  test('wire names', () {
    expect(HintType.orderedLetter.wire, 'ordered_letter');
    expect(HintType.randomLetter.wire, 'random_letter');
    expect(HintPayment.ad.wire, 'ad');
  });
}
