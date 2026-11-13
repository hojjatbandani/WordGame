// مدرّب المرحلة الأولى (المواصفة §6): ما يُعرض للاعب في كل لحظة من مراحل
// التعليم، بلا أي نافذة.

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/onboarding/tutorial_coach.dart';

TutorialCoach _coach(int stage, {bool done = false, bool bonusBefore = false}) =>
    TutorialCoach(
      stageId: stage,
      onboardingCompleted: done,
      bonusExplainedBefore: bonusBefore,
    );

void _tick(TutorialCoach c, {int progress = 0, int start = 0, bool touched = false}) =>
    c.onTick(
      sinceProgress: Duration(seconds: progress),
      sinceStart: Duration(seconds: start),
      touchedEver: touched,
    );

void main() {
  test('stage 1 starts with instruction, demo, no hints', () {
    final c = _coach(1);
    expect(c.active, isTrue);
    expect(c.view.instruction, CoachText.formWord);
    expect(c.view.showFingerDemo, isTrue);
    expect(c.view.hintButtonsVisible, isFalse);
  });

  test('touch stops demo', () {
    final c = _coach(1)..onTouchStart();
    expect(c.view.showFingerDemo, isFalse);
    expect(c.view.instruction, CoachText.formWord);
  });

  test('single letter shows swipe and demo', () {
    final c = _coach(1)
      ..onTouchStart()
      ..onSingleLetter();
    expect(c.view.instruction, CoachText.swipe);
    expect(c.view.showFingerDemo, isTrue);
  });

  test('wrong attempt replays demo', () {
    final c = _coach(1)
      ..onTouchStart()
      ..onWrong();
    expect(c.view.showFingerDemo, isTrue);
    expect(c.view.hintButtonsVisible, isFalse);
  });

  test('two wrongs reveal highlighted free hint', () {
    final c = _coach(1)
      ..onWrong()
      ..onWrong();
    expect(c.view.hintButtonsVisible, isTrue);
    expect(c.view.highlightHint, isTrue);
    expect(c.view.instruction, CoachText.useFreeHint);
    expect(c.hintRevealedByCoach, isTrue);
  });

  test('20 s idle reveals hint', () {
    final c = _coach(1);
    _tick(c, progress: 19, start: 19, touched: true);
    expect(c.view.hintButtonsVisible, isFalse);
    _tick(c, progress: 20, start: 20, touched: true);
    expect(c.view.hintButtonsVisible, isTrue);
  });

  test('stage 1 word gives great', () {
    final c = _coach(1)..onWordSolved(solvedCount: 1, wordsTotal: 1);
    expect(c.view.celebration, CoachText.great);
    expect(c.view.showFingerDemo, isFalse);
    c.clearCelebration();
    expect(c.view.celebration, isNull);
  });

  test('stage 2 first word asks for another word', () {
    final c = _coach(2)..onWordSolved(solvedCount: 1, wordsTotal: 2);
    expect(c.view.instruction, CoachText.anotherWord);
    expect(c.view.hintButtonsVisible, isTrue);
  });

  test('stage 2 demo after 5 s without touch', () {
    final c = _coach(2);
    expect(c.view.showFingerDemo, isFalse);
    _tick(c, progress: 5, start: 5);
    expect(c.view.showFingerDemo, isTrue);
    c.onTouchStart();
    expect(c.view.showFingerDemo, isFalse);
  });

  test('stage 3 first bonus explains it once', () {
    final c = _coach(3)..onBonusFound();
    expect(c.view.instruction, CoachText.bonusExplained);
    expect(c.bonusExplainedNow, isTrue);
    final again = _coach(3, bonusBefore: true)..onBonusFound();
    expect(again.view.instruction, isNull);
  });

  test('veteran replay has no coach', () {
    final c = _coach(1, done: true);
    expect(c.active, isFalse);
    expect(c.view.instruction, isNull);
    expect(c.view.showFingerDemo, isFalse);
    expect(c.view.hintButtonsVisible, isTrue);
    c.onWrong();
    c.onSingleLetter();
    expect(c.view.instruction, isNull);
  });

  test('stage 4 is never coached', () {
    expect(_coach(4).active, isFalse);
  });

  test('assist after 3 wrongs or 30 s', () {
    expect(shouldHighlightHint(wrongSinceProgress: 2, sinceProgress: const Duration(seconds: 29)), isFalse);
    expect(shouldHighlightHint(wrongSinceProgress: 3, sinceProgress: Duration.zero), isTrue);
    expect(shouldHighlightHint(wrongSinceProgress: 0, sinceProgress: const Duration(seconds: 30)), isTrue);
  });
}
