// مدرّب مراحل التعليم: يقرّر ما يراه اللاعب الجديد في كل لحظة — جملة
// التوجيه، إصبع العرض على العجلة، ظهور التلميح — بلا أي نافذة. Dart صرف
// بلا Flutter: الشاشة تغذّيه بالأحداث وترسم [CoachView] فقط.
//
// المواصفة §6. السبب في PostHog: لاعبون جدد لمسوا الحروف فلم يحدث شيء
// (العجلة سحب فقط)، فاشتروا التلميح ثلاث مرات في ثوانٍ قبل أي محاولة.

import '../../config/balance_config.dart';

/// نصوص المدرّب — شاشة اللعب عربية دوما
abstract final class CoachText {
  static const formWord = 'كوّن الكلمة من الحروف';
  static const swipe = 'اسحب إصبعك بين الحروف';
  static const useFreeHint = 'استخدم التلميح المجاني';
  static const great = 'رائع!';
  static const anotherWord = 'رائع! كوّن كلمة أخرى من نفس الحروف';
  static const bonusExplained = 'كلمة إضافية! تمنحك عملات';
  static const tryHint = 'جرّب التلميح';
  static const resumed = 'تابعت من حيث توقفت';
}

/// ما يُرسم الآن
class CoachView {
  final String? instruction;
  final bool showFingerDemo;
  final bool hintButtonsVisible;
  final bool highlightHint;
  final String? celebration;

  const CoachView({
    this.instruction,
    this.showFingerDemo = false,
    this.hintButtonsVisible = true,
    this.highlightHint = false,
    this.celebration,
  });

  /// خارج التعليم: الشاشة كما هي بلا أي توجيه
  static const none = CoachView();
}

class TutorialCoach {
  final int stageId;
  final bool onboardingCompleted;
  final bool bonusExplainedBefore;

  String? _instruction;
  bool _demo = false;
  bool _hintsVisible = true;
  bool _highlight = false;
  String? _celebration;
  int _wrong = 0;
  bool _demoOfferedForNoTouch = false;
  bool _hintRevealedByCoach = false;
  bool _bonusExplainedNow = false;

  TutorialCoach({
    required this.stageId,
    required this.onboardingCompleted,
    required this.bonusExplainedBefore,
  }) {
    if (!active) return;
    if (stageId == 1) {
      _instruction = CoachText.formWord;
      _demo = true;
      _hintsVisible = false;
    }
  }

  /// المدرّب يعمل فقط للاعب لم يُتمّ التعليم، وفي مراحل التعليم وحدها:
  /// لاعب قديم يعيد المرحلة الأولى يراها مرحلة عادية
  bool get active =>
      !onboardingCompleted && stageId <= BalanceConfig.onboardingStageCount;

  CoachView get view => active
      ? CoachView(
          instruction: _instruction,
          showFingerDemo: _demo,
          hintButtonsVisible: _hintsVisible,
          highlightHint: _highlight,
          celebration: _celebration,
        )
      : CoachView.none;

  /// المدرّب هو من أظهر عمود التلميح (المرحلة الأولى)
  bool get hintRevealedByCoach => _hintRevealedByCoach;

  /// شُرحت الكلمة الإضافية الآن — الشاشة تحفظ ذلك كي لا يتكرّر
  bool get bonusExplainedNow => _bonusExplainedNow;

  void onTouchStart() {
    if (!active) return;
    _demo = false;
  }

  /// رُفع الإصبع وحرف واحد مختار: لمسة لا سحب
  void onSingleLetter() {
    if (!active) return;
    _instruction = CoachText.swipe;
    _demo = true;
  }

  void onWrong() {
    if (!active) return;
    _wrong++;
    if (stageId != 1) return;
    _demo = true;
    if (_wrong >= BalanceConfig.tutorialRevealHintAfterWrongAttempts) {
      _revealHint();
    }
  }

  void onWordSolved({required int solvedCount, required int wordsTotal}) {
    if (!active) return;
    _demo = false;
    _highlight = false;
    if (stageId == 1) {
      _instruction = null;
      _celebration = CoachText.great;
      return;
    }
    if (stageId == 2 && solvedCount == 1 && wordsTotal > 1) {
      _instruction = CoachText.anotherWord;
      return;
    }
    _instruction = null;
  }

  void onBonusFound() {
    if (!active || bonusExplainedBefore || _bonusExplainedNow) return;
    _instruction = CoachText.bonusExplained;
    _bonusExplainedNow = true;
  }

  void onTick({
    required Duration sinceProgress,
    required Duration sinceStart,
    required bool touchedEver,
  }) {
    if (!active) return;
    if (stageId == 1 &&
        !_hintsVisible &&
        sinceProgress >= BalanceConfig.tutorialRevealHintAfterIdle) {
      _revealHint();
    }
    if (stageId == 2 &&
        !touchedEver &&
        !_demoOfferedForNoTouch &&
        sinceStart >= BalanceConfig.tutorialDemoIfNoTouchAfter) {
      _demoOfferedForNoTouch = true;
      _demo = true;
    }
  }

  /// التلميح التالي مجاني؟ تضبطه الشاشة قبل كل حدث — صياغة الإظهار
  /// «استخدم التلميح المجاني» لا تُقال حين لن يكون مجانيا
  bool freeHintAvailable = true;

  /// استُعمل تلميح: جملة الدعوة إليه وإبرازه انتهى دورهما
  void onHintUsed() {
    if (!active) return;
    _highlight = false;
    if (_instruction == CoachText.useFreeHint ||
        _instruction == CoachText.tryHint) {
      _instruction = null;
    }
  }

  void clearCelebration() => _celebration = null;

  void _revealHint() {
    if (_hintsVisible) return;
    _hintsVisible = true;
    _highlight = true;
    _instruction = freeHintAvailable
        ? CoachText.useFreeHint
        : CoachText.tryHint;
    _hintRevealedByCoach = true;
  }
}

/// مساعدة متدرّجة في كل المراحل: يُنبَّه زرّ التلميح ولا يُكشف شيء تلقائيا
bool shouldHighlightHint({
  required int wrongSinceProgress,
  required Duration sinceProgress,
}) =>
    wrongSinceProgress >= BalanceConfig.assistAfterWrongAttempts ||
    sinceProgress >= BalanceConfig.assistAfterIdle;
