import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/balance_config.dart';
import '../../core/app_icons.dart';
import '../../core/share_templates.dart';
import '../../core/theme.dart';
import '../../data/achievement_models.dart';
import '../../data/ad_service.dart';
import '../../data/audio_service.dart';
import '../../data/economy/hint_pricing.dart';
import '../../data/models.dart';
import '../../data/analytics/analytics_event.dart';
import '../../data/analytics/analytics_service.dart';
import '../../data/analytics/stage_session.dart';
import '../../data/onboarding/tutorial_coach.dart';
import '../../data/progression/chapter_celebration.dart';
import '../../data/progression/world_defs.dart';
import '../../data/world_models.dart';
import '../providers.dart';
import '../widgets/achievement_toast.dart';
import '../widgets/bonus_milestone_burst.dart';
import '../widgets/character_bubble.dart';
import '../widgets/coach_banner.dart';
import '../widgets/glass_card.dart';
import '../widgets/letter_wheel.dart';
import '../widgets/level_complete_overlay.dart';
import '../widgets/hint_sheet.dart';
import '../widgets/pressable.dart';
import '../widgets/word_grid.dart';
import 'chapter_select_screen.dart';
import 'game/stage_session_tracker.dart';
import 'shop_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  final GameLevel level;
  final List<GameLevel> allLevels;

  /// من أين دخل اللاعب: first_launch، home_cta، map، next_stage،
  /// chapter_next، world_locked_sheet، other — خاصية source لأحداث المرحلة
  final String source;

  const GameScreen({
    super.key,
    required this.level,
    required this.allLevels,
    this.source = 'other',
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin {
  final Set<String> _solved = {};
  final Set<String> _bonusFound = {};
  final Map<String, Set<int>> _revealed = {};
  String _preview = '';

  /// آخر كلمة خاطئة جرّبها اللاعب — تُعرض بالأحمر ثم تتلاشى
  String _lastAttempt = '';
  bool _completed = false;
  String? _lastDefinition;

  /// لافتة «خمس كلمات إضافية = +20»: null إذا لا لافتة معروضة الآن.
  /// القيمة هي مجموع الكلمات الإضافية عند بلوغ المكافأة (5، 10، 15..)
  int? _bonusMilestoneTotal;

  /// لحظة دخول المرحلة — تُحسب منها مدّة الإتمام في حدث stage_complete
  final _startedAt = DateTime.now();

  /// عملات إتمام هذه المرحلة كما منحها محرّك الاقتصاد فعلا. تُملأ بعد
  /// [_recordProgressionCompletion]، وتُقرأ في شاشة الإتمام.
  int _earnedCoins = 0;

  /// صندوق الفصل المستلَم تلقائيا حين أكملت هذه المحاولة فصلا (لا عالما)
  int _chestCoins = 0;

  /// أُكمل العالم بهذه المحاولة تحديدا — بحسب محرّك التقدّم لا بحسب رقم
  /// المرحلة: إعادة لعب المرحلة الأخيرة تقع على «آخر مرحلة في العالم»
  /// أيضا لكنها لا تدفع مكافأة إتمام، فعرضها كان وعدا بلا قبض.
  bool _worldCompletedThisRun = false;

  /// تلميحات هذه المرحلة، للترقيم داخل حدث hint_used
  int _hintsThisStage = 0;

  // فقاعة المرشد: تظهر عند البداية والأخطاء والتلميحات
  CharacterEmotion? _bubbleEmotion;
  int _bubbleToken = 0;

  late final AnimationController _shake;
  late final AnimationController _flash;
  final GlobalKey<LetterWheelState> _wheelKey = GlobalKey();

  WorldModel get _world => worldForLevel(widget.level.id);

  /// جلسة هذه المرحلة: أحداثها الموحّدة وحفظ التقدّم للاستئناف
  late final StageSessionTracker _tracker;

  /// لماذا تُغادَر الشاشة — يُضبط قبل الخروج ويُقرأ في dispose
  ExitReason? _exitReason;
  AppLifecycleListener? _lifecycle;

  /// مدرّب مراحل التعليم (المواصفة §6) — خامل خارجها
  late final TutorialCoach _coach;

  /// دقّة كل ثانية: مهل المدرّب والمساعدة المتدرّجة. عدّاد ثوانٍ لا ساعة
  /// حقيقية: يتبع زمن الإطار في الاختبار والجهاز معا
  Timer? _ticker;
  int _secondsSinceStart = 0;
  int _secondsSinceProgress = 0;
  int _wrongSinceProgress = 0;
  bool _touchedEver = false;

  /// المساعدة المتدرّجة (المواصفة §7.4): نبض زرّ التلميح بعد تعثّر — لا
  /// كشف تلقائي أبدا. تُسجَّل مرة لكل محاولة
  bool _assistHighlight = false;
  bool _assistLogged = false;
  late final AnimationController _pulse;
  Timer? _celebrationTimer;

  /// تلميح «اسحب لا تنقر» خارج مراحل التعليم: مرة في الجلسة
  static bool _tapTipShownThisSession = false;

  @override
  void initState() {
    super.initState();
    _analytics = ref.read(analyticsProvider);
    final store = ref.read(progressStoreProvider);
    _coach = TutorialCoach(
      stageId: widget.level.id,
      onboardingCompleted: store.onboardingCompleted,
      bonusExplainedBefore: store.bonusWordExplained,
    );
    _tracker = StageSessionTracker.start(
      store: store,
      analytics: _analytics,
      level: widget.level,
      worldId: _world.id,
      chapterId: _chapter?.id ?? 0,
      source: widget.source,
      // مرحلة دون أعلى مفتوح = أُتمّت من قبل
      isReplay: widget.level.id < ref.read(maxUnlockedProvider),
      tutorial: _coach.active,
      readCoins: () => ref.read(pointsProvider),
    );
    // التقدّم المحفوظ (مغادرة سابقة أو إغلاق النظام للتطبيق) يعود كما كان
    final progress = _tracker.session.progress;
    _solved.addAll(progress.solved);
    for (final e in progress.revealed.entries) {
      _revealed[e.key] = Set.of(e.value);
    }
    _hintsThisStage = progress.hintsUsed;
    _lifecycle = AppLifecycleListener(onStateChange: _tracker.lifecycle);

    // أول لعب في الجلسة — بلا هذا العلم يبقى الإعلان البيني ممنوعا
    // (قاعدة «لا إعلان على بداية باردة قبل أول لعب»)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(sessionGameplayProvider.notifier).markGameplayStarted();
      if (_tracker.session.resumed) _showToast(CoachText.resumed);
    });
    // كلمات إضافية اكتُشفت في محاولة سابقة لنفس المرحلة تبدأ «موجودة»:
    // إعادة إيجادها ليست اكتشافا، فلا تمنح عملات ولا تقرّب من مكافأة
    // الخمس كلمات (وإلا صارت إعادة نفس المرحلة مزرعة عملات). وتُنقّى بما
    // في المرحلة الآن: محتوى المرحلة قد يتغيّر (إعادة ترتيب) فلا تُعدّ
    // كلمات لا تتكوّن من حروفها
    final savedBonus = ref
        .read(progressionProvider)
        .stageProgress[widget.level.id]
        ?.bonusWordsFound;
    if (savedBonus != null) {
      _bonusFound.addAll(savedBonus.where(widget.level.bonusWords.contains));
    }

    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _flash =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 500),
        )..addStatusListener((s) {
          // بعد انتهاء التلاشي نزيل الكلمة الخاطئة نهائيا
          if (s == AnimationStatus.completed && mounted && _preview.isEmpty) {
            setState(() => _lastAttempt = '');
          }
        });
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    // مرحلة التعليم: الجملة والإصبع يكفيان، والفقاعة فوق اللوح تشويش
    if (!_coach.active) {
      _showBubble(CharacterEmotion.idle, const Duration(milliseconds: 3200));
    }
  }

  /// كل ثانية: مهل المدرّب (إظهار التلميح، عرض الإصبع) والمساعدة
  void _tick() {
    if (!mounted || _completed) return;
    _secondsSinceStart++;
    _secondsSinceProgress++;
    final before = _coach.view;
    _coachEvent(
      () => _coach.onTick(
        sinceProgress: Duration(seconds: _secondsSinceProgress),
        sinceStart: Duration(seconds: _secondsSinceStart),
        touchedEver: _touchedEver,
      ),
      rebuild: false,
    );
    final after = _coach.view;
    var assistChanged = false;
    if (!_assistHighlight &&
        after.hintButtonsVisible &&
        shouldHighlightHint(
          wrongSinceProgress: _wrongSinceProgress,
          sinceProgress: Duration(seconds: _secondsSinceProgress),
        )) {
      _assistHighlight = true;
      assistChanged = true;
      if (!_assistLogged) {
        _assistLogged = true;
        _logHintViewed(_quoteFor(HintType.orderedLetter), 'assist');
      }
    }
    if (assistChanged ||
        before.instruction != after.instruction ||
        before.showFingerDemo != after.showFingerDemo ||
        before.hintButtonsVisible != after.hintButtonsVisible ||
        before.highlightHint != after.highlightHint) {
      _syncPulse();
      setState(() {});
    }
  }

  /// كل حدث للمدرّب يمرّ من هنا: إظهار التلميح يُسجَّل (hint_viewed
  /// trigger=tutorial) ويبدأ نبضه أيًّا كان سببه — خطآن أو مهلة — لا من
  /// الدقّة وحدها كما كان
  void _coachEvent(VoidCallback event, {bool rebuild = true}) {
    final before = _coach.view;
    _coach.freeHintAvailable = _nextHintFree;
    event();
    if (!before.hintButtonsVisible && _coach.view.hintButtonsVisible) {
      _logHintViewed(_quoteFor(HintType.orderedLetter), 'tutorial');
    }
    _syncPulse();
    if (rebuild && mounted) setState(() {});
  }

  /// تقدّم حقيقي (كلمة، كلمة إضافية، تلميح): تُصفَّر مهل المساعدة
  void _markProgress() {
    _secondsSinceProgress = 0;
    _wrongSinceProgress = 0;
    _assistHighlight = false;
    _syncPulse();
  }

  bool get _highlightHint => _assistHighlight || _coach.view.highlightHint;

  void _syncPulse() {
    if (_highlightHint && !_completed) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating || _pulse.value != 0) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  void _onTouchStart() {
    _touchedEver = true;
    if (!_coach.active) return;
    setState(_coach.onTouchStart);
  }

  /// حرف واحد ثم رُفع الإصبع: لاعب ينقر لا يسحب
  void _onSingleLetter() {
    if (_coach.active) {
      setState(_coach.onSingleLetter);
      return;
    }
    if (_tapTipShownThisSession ||
        widget.level.id > BalanceConfig.earlyGameStageLimit) {
      return;
    }
    _tapTipShownThisSession = true;
    _showToast(CoachText.swipe);
  }

  void _showBubble(CharacterEmotion emotion, Duration duration) {
    final token = ++_bubbleToken;
    setState(() => _bubbleEmotion = emotion);
    Future.delayed(duration, () {
      if (mounted && _bubbleToken == token) {
        setState(() => _bubbleEmotion = null);
      }
    });
  }

  @override
  void dispose() {
    // مغادرة قبل الحل = تخلٍّ. يُسجَّل من dispose لا من زرّ الرجوع كي
    // يشمل كل مخارج الشاشة، وسببه ما ضُبط قبل الخروج (سهم الرجوع، رجوع
    // النظام، مرحلة أخرى فُتحت) — التقدّم يبقى محفوظا للاستئناف.
    // الخلفية المؤقتة لا تمرّ من هنا أصلا: الشاشة باقية.
    _tracker.exit(
      _exitReason ?? ExitReason.unknown,
      bonusWords: _bonusFound.length,
    );
    _lifecycle?.dispose();
    _hintCooldown?.cancel();
    _ticker?.cancel();
    _celebrationTimer?.cancel();
    _pulse.dispose();
    _analytics?.clearStage(widget.level.id);
    _shake.dispose();
    _flash.dispose();
    super.dispose();
  }

  /// مرجع محفوظ: قراءة المزوّدات داخل dispose غير مسموحة
  AnalyticsService? _analytics;

  Future<void> _onWord(String word) async {
    final target = widget.level.words
        .where((w) => w.word == word && !_solved.contains(word))
        .toList();
    if (target.isNotEmpty) {
      setState(() {
        _solved.add(word);
        _lastDefinition = '${target.first.word}: ${target.first.definition}';
      });
      _tracker.solved(word);
      _markProgress();
      _coach.onWordSolved(
        solvedCount: _solved.length,
        wordsTotal: widget.level.words.length,
      );
      if (_coach.view.celebration != null) {
        _celebrationTimer?.cancel();
        _celebrationTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) setState(_coach.clearCelebration);
        });
      }
      final achievements = ref.read(achievementsProvider.notifier);
      achievements.bump(StatKey.wordsFound);
      achievements.reportBest(StatKey.longestWord, word.length);
      ref.read(missionsProvider.notifier).reportWordsFound(1);
      _flushAchievements();
      ref.read(audioServiceProvider).play(Sfx.correct);
      HapticFeedback.mediumImpact();
      if (_solved.length == widget.level.words.length) {
        _finishLevel();
      }
      return;
    }
    if (widget.level.bonusWords.contains(word) && !_bonusFound.contains(word)) {
      setState(() => _bonusFound.add(word));

      // تثبيت فوري في الدفتر المحفوظ قبل الدفع.
      //
      // `_bonusFound` حقلٌ في حالة الودجت يُزرَع في initState من
      // StageProgress.bonusWordsFound، وتلك كانت لا تُكتب إلا عند
      // إتمام المرحلة. فمن يجد كلمة إضافية ثم يخرج من المرحلة قبل
      // حلّها يعود فيجد المجموعة فارغة، فيُدفع له على نفس الكلمة مرة
      // بعد مرة بلا حدّ. الآن يُكتب الدفتر لحظة الاكتشاف، فتُرفض
      // الثانية.
      final isNewBonus = await ref
          .read(progressionProvider.notifier)
          .recordBonusWordFound(widget.level.id, word);
      if (!mounted || !isNewBonus) return;

      // السعر من محرّك الاقتصاد لا رقما مكتوبا هنا: كان 5 ثابتة تتجاهل
      // BalanceConfig.coinsPerBonusWord ومضاعف كسب العالم معا
      final bonusCoins = ref
          .read(progressionRepositoryProvider)
          .runEconomy((economy) => economy.quoteBonusWordCoins(_world.id));
      ref.earnPoints(bonusCoins);
      ref.read(bonusJarProvider.notifier).add(1);
      // كل خمس كلمات جديدة: مكافأة دفعة واحدة بلافتة وسط الشاشة
      final milestone = ref.read(bonusWordCounterProvider.notifier).register();
      ref.logEvent(Ev.bonusWordFound, {
        'stage_id': widget.level.id,
        'world_id': _world.id,
        'length': word.length,
      });
      final achievements = ref.read(achievementsProvider.notifier);
      achievements.bump(StatKey.bonusWords);
      achievements.reportBest(StatKey.longestWord, word.length);
      ref.read(missionsProvider.notifier).reportBonusWordFound();
      _markProgress();
      _coach.onBonusFound();
      if (_coach.bonusExplainedNow) {
        unawaited(ref.read(progressStoreProvider).setBonusWordExplained(true));
      }
      _flushAchievements();
      ref.read(audioServiceProvider).play(Sfx.bonus);
      HapticFeedback.mediumImpact();
      if (milestone != null) {
        ref.earnPoints(BalanceConfig.coinsBonusWordMilestone);
        ref.read(audioServiceProvider).play(Sfx.achievement);
        setState(() => _bonusMilestoneTotal = milestone);
      } else {
        _showToast('🫙 كلمة إضافية! +$bonusCoins');
      }
      _showBubble(
        CharacterEmotion.surprised,
        const Duration(milliseconds: 2200),
      );
      return;
    }
    // كلمة إضافية سبق اكتشافها في هذه المرحلة: لا عملات ولا عدّاد،
    // لكن لا تُعامَل كخطأ أيضا — إجابتها صحيحة فعلا
    if (widget.level.bonusWords.contains(word)) {
      _showToast('سبق أن اكتشفت هذه الكلمة');
      return;
    }
    // كلمة خاطئة: تُعرض بالأحمر مهتزّة ثم تتلاشى + تشجيع من المرشد
    setState(() {
      _lastAttempt = word;
    });
    _tracker.wrong(word);
    _wrongSinceProgress++;
    _coachEvent(_coach.onWrong);
    ref.read(audioServiceProvider).play(Sfx.wrong);
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0);
    _flash.forward(from: 0);
    _showBubble(
      CharacterEmotion.encouraging,
      const Duration(milliseconds: 2400),
    );
    // لا عرض شراء هنا: كان شريط «حزمة البداية بخصم ٪ لمدة 24 ساعة» يظهر
    // وسط اللعب بعد التعثّر، بخصم لا يعرضه المتجر — عرض شراء يقاطع اللعب
    // ولا يتميّز عنه، وهو ما رُفضت به النسخة 9 (سياسة العائلات).
  }

  bool get _isWorldFinale => widget.level.id == _world.lastLevelId;

  /// يعرض بطاقات أي إنجازات فُتحت للتوّ فوق الشاشة
  void _flushAchievements() {
    final unlocked = ref.read(achievementsProvider.notifier).takeJustUnlocked();
    if (unlocked.isEmpty || !mounted) return;
    showAchievementUnlocked(context, unlocked);
  }

  void _finishLevel() {
    ref.read(audioServiceProvider).play(Sfx.levelComplete);
    // لا مكافأة تُحسب هنا: كل عملات إتمام المرحلة (المرحلة، الكلمات
    // الأساسية، الإتقان، الزعيم، إتمام الفصل، إتمام العالم) تأتي من
    // EconomyService داخل recordStageCompletion أدناه، بمضاعف عالمها
    // وأرقام BalanceConfig. كان هنا رقمان محليان (completionReward
    // و_world.completionReward) يتجاهلان ملف التوازن كلّه.
    ref.read(maxUnlockedProvider.notifier).unlockUpTo(widget.level.id + 1);
    // تسجيل الإتمام في نظام التقدّم الجديد (v2) يقع هنا، حيث يقع
    // الحلّ فعلا. كان في شاشة المسار بعد عودة اللاعب منها، وذلك
    // يفوّت كل مرحلة تُحلّ بزرّ «التالي»: الزرّ يستبدل مسار شاشة
    // اللعب (pushReplacement) فتستأنف الخريطة بعد المرحلة الأولى
    // ولا ترى شيئا مما بعدها، فتبقى تلك المراحل غير مكتملة على
    // الخريطة رغم حلّها.
    unawaited(_recordProgressionCompletion());

    final achievements = ref.read(achievementsProvider.notifier);
    achievements.bump(StatKey.levelsCompleted);
    // «مرحلة نظيفة»: لم يُكشف فيها أي حرف بتلميح مدفوع
    if (_revealed.isEmpty) achievements.bump(StatKey.perfectLevels);
    if (_isWorldFinale) achievements.bump(StatKey.worldsCompleted);
    _flushAchievements();

    final missions = ref.read(missionsProvider.notifier);
    missions.reportStageCompleted();
    if (_revealed.isEmpty) missions.reportStageCompletedNoHints();

    // إتمام أي مرحلة (حتى إعادة لعب مرحلة سابقة) يُحتسب كنشاط اليوم
    // لسلسلة الأيام المتتالية وهدف "أيام مختلفة" الأسبوعي معا — راجع
    // lib/data/streak/streak_engine.dart
    ref.read(streakProvider.notifier).recordActivityToday();
    missions.reportActivityToday();

    // قرار الإعلان يُتخذ في وحدة واحدة (InterstitialGateNotifier →
    // AdPacing) لا هنا. هنا نسجّل الإتمام فقط كي يتقدّم عدّاد الإيقاع؛
    // الطلب الفعلي يقع عند المغادرة، بعد اكتمال تسلسل المكافأة.
    ref.read(interstitialGateProvider.notifier).recordStageCleared();

    _tracker.complete(
      bonusWords: _bonusFound.length,
      perfect: _revealed.isEmpty,
    );
    // حدث world_unlocked يصدر من ProgressionNotifier.recordStageCompletion
    // وحده (مقارنة ما قبل وما بعد في المحرّك) — إصداره هنا أيضا كان
    // يسجّله مرتين لكل عالم

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _completed = true);
    });
  }

  /// جسر التقدّم الجديد (v2) — مرة واحدة لكل حلّ فعلي. راجع الشرح في
  /// progression_repository.dart:recordBasicCompletionFromLegacyBridge
  Future<void> _recordProgressionCompletion() async {
    // تُقرأ كلها قبل await: الشاشة قد تُستبدل بزرّ «التالي» قبل أن
    // تكتمل الكتابة، وref يصير غير صالح بعد التخلّص من الحالة
    final progression = ref.read(progressionProvider.notifier);
    final achievements = ref.read(achievementsProvider.notifier);
    final points = ref.read(pointsProvider.notifier);
    final store = ref.read(progressStoreProvider);
    final chapter = _chapter;
    final worldFinale = _isWorldFinale;

    // كل تلميح يكشف حرفا واحدا، فمجموع المواضع المكشوفة عبر كل الكلمات
    // هو عدد التلميحات المستعملة في هذه المحاولة
    final hintsUsed = _revealed.values.fold<int>(
      0,
      (sum, positions) => sum + positions.length,
    );

    // الأداء الحقيقي لا قيم ثابتة: التلميحات والكلمات الإضافية الفعلية
    // لهذه المحاولة (تغذّي جرّة العالم وإحصاءات المرحلة)
    final result = await progression.recordStageCompletion(
      stageId: widget.level.id,
      bonusWordsFoundThisRun: Set.of(_bonusFound),
      hintsUsedThisRun: hintsUsed,
      timeMs: DateTime.now().difference(_startedAt).inMilliseconds,
      coreWordsFound: widget.level.words.length,
    );

    // ما دخل المحفظة فعلا — تعرضه شاشة الإتمام وتضاعفه بمشاهدة إعلان،
    // بدل رقم كانت تحسبه بنفسها ولا يطابق ما قُبض
    if (mounted) {
      setState(() {
        _earnedCoins = progression.lastStageCoinsAwarded;
        _worldCompletedThisRun = result.worldCompletedThisRun;
      });
    }

    // مرة واحدة لكل فصل: المحاولة التي أكملت آخر مرحلة ناقصة فيه
    if (result.chapterCompletedThisRun) {
      achievements.bump(StatKey.chaptersCompleted);
      // الفصل اكتمل والعالم لم يكتمل: الصندوق يُستلم هنا على شاشة النجاح
      // (لا تمرّ المتابعة بقائمة الفصول بعد الآن — القرار D2)، وطلب
      // التقييم يُؤجَّل إلى أول عودة للرئيسية لا بين مرحلتين
      if (chapter != null && !worldFinale) {
        final chest = await progression.claimChapterChest(chapter.id);
        unawaited(store.setPendingRatingPrompt(true));
        if (mounted && chest > 0) setState(() => _chestCoins = chest);
      }
    }

    // مكافآت طبقة جرّة العالم (إن بُلغت عتبتها للتوّ) تُمنح فورا بلا
    // خطوة استلام يدوية — راجع jar_rewards.dart
    for (final jarReward in result.jarRewardsGained) {
      points.add(jarReward.coins);
      store.addPendingCosmeticUnlock(jarReward.cosmeticRewardId);
    }
  }

  /// يعرض إعلانا بينيا إن سمحت وحدة الإيقاع، قبل تنفيذ الانتقال المطلوب.
  ///
  /// هذه هي اللحظة الصحيحة للسؤال: تسلسل المكافأة انتهى (اللاعب ضغط
  /// «التالي» أو «الرئيسية» بنفسه)، فالإعلان لا يقاطع مكافأة تُعدّ ولا
  /// عملات تتطاير. [placement] يحمله كل حدث من دورة حياة الإعلان.
  Future<void> _leaveLevel(
    VoidCallback proceed, {
    required String placement,
  }) async {
    // القالب مطفأ في هذا البناء (أو بمفتاح الإيقاف): انتقال فوري صامت،
    // بلا تحميل مسبق ولا حدث ولا انتظار لإعلان لن يأتي
    if (!ref.read(interstitialAdsAvailableProvider)) {
      proceed();
      return;
    }
    final ads = ref.read(adServiceProvider);
    // الطلب والأهلية أو سبب التخطّي يُسجَّلان هنا؛ إعلان لم يُحمَّل لا
    // يستهلك دورة إيقاع (not_loaded) — نطلب التحميل ونمضي
    final ready = ads.isInterstitialReady;
    final cue = ref
        .read(interstitialGateProvider.notifier)
        .decideOnLeave(
          stageNumber: widget.level.id,
          placement: placement,
          adReady: ready,
        );
    if (cue == AdCue.none) {
      if (!ready) unawaited(ads.preload());
      proceed();
      return;
    }

    final result = await ads.showInterstitial(
      context,
      placement: placement,
      onOpenShop: () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ShopScreen(source: 'interstitial_mock'),
          ),
        );
      },
    );
    if (!mounted) return;
    // من غادر إلى المتجر يبقى على شاشة الإتمام حتى يعود — لا انتقال خلفه
    if (result != InterstitialResult.leftForShop) proceed();
  }

  /// أول كلمة لم تُحلّ بعد **بترتيب اللوح** — كلا التلميحين يعملان عليها
  /// وحدها: تلميح يكشف حرفا في كلمة عشوائية لا يُقرأ مساعدة، بل تشتيتا.
  ///
  /// `wordsInBoardOrder` لا `widget.level.words`: اللوح يعرض الأقصر أولا،
  /// فأول عنصر في الملف قد يكون الصف الأخير على الشاشة.
  WordEntry? get _firstUnsolvedWord {
    for (final w in wordsInBoardOrder(widget.level.words)) {
      if (!_solved.contains(w.word)) return w;
    }
    return null;
  }

  /// مواضع الحروف غير المكشوفة في [entry]، بالترتيب من أول الكلمة
  List<int> _hiddenPositions(WordEntry entry) {
    final revealed = _revealed[entry.word] ?? const <int>{};
    return [
      for (var i = 0; i < entry.word.length; i++)
        if (!revealed.contains(i)) i,
    ];
  }

  /// شحنات التلميح المجانية المملوكة (عجلة الحظ، صندوق المهمات، حزمة
  /// البداية) — تُستهلك قبل أي عملة
  int get _hintCharges => ref.watch(hintChargesProvider);

  /// مؤقّت ما بعد آخر تلميح: لمسة ثانية خلال [BalanceConfig.hintTapDebounce]
  /// تُهمل — لاعبون جدد اشتروا ثلاثة تلميحات في ثانيتين. مؤقّت لا مقارنة
  /// ساعات: يتبع زمن الإطار نفسه في الاختبار والجهاز
  Timer? _hintCooldown;
  bool _hintSheetOpen = false;

  bool get _earlyGame => HintPricing.isEarlyGame(widget.level.id);

  /// التلميح التالي مجاني (أول تلميح في محاولة من مراحل البداية)
  bool get _nextHintFree =>
      _earlyGame && !_tracker.session.progress.freeHintUsed;

  void _logHintViewed(HintQuote quote, String trigger) =>
      ref.logEvent(Ev.hintViewed, {
        'hint_type': quote.type.wire,
        'cost': quote.cost,
        'coin_balance': ref.read(pointsProvider),
        'trigger': trigger,
        'stage_id': widget.level.id,
      });

  HintQuote _quoteFor(HintType type) => HintPricing.quote(
    type: type,
    stageId: widget.level.id,
    freeHintUsed: _tracker.session.progress.freeHintUsed,
    charges: ref.read(hintChargesProvider),
    balance: ref.read(pointsProvider),
  );

  void _logHintUnavailable(HintType type, String reason, int cost) =>
      ref.logEvent(Ev.hintUnavailable, {
        'hint_type': type.wire,
        'reason': reason,
        'cost': cost,
        'coin_balance': ref.read(pointsProvider),
        'stage_id': widget.level.id,
      });

  /// تلميح واحد: التسعير من [HintPricing] (مجاني ← شحنة ← عملات)، والمدفوع
  /// «الغالي» يُسأل عنه، والنقص يعرض الإعلان أولا (المواصفة §7)
  Future<void> _requestHint(HintType type) async {
    if (_hintSheetOpen || (_hintCooldown?.isActive ?? false)) return;
    final entry = _firstUnsolvedWord;
    if (entry == null) {
      _logHintUnavailable(type, 'no_unsolved_word', 0);
      return;
    }
    // كل حروف الكلمة مكشوفة ولم تُحلّ بعد: لا شيء يُباع هنا
    if (_hiddenPositions(entry).isEmpty) {
      _showToast('كل حروف الكلمة مكشوفة!');
      _logHintUnavailable(type, 'word_fully_revealed', 0);
      return;
    }

    final balance = ref.read(pointsProvider);
    final quote = HintPricing.quote(
      type: type,
      stageId: widget.level.id,
      freeHintUsed: _tracker.session.progress.freeHintUsed,
      charges: ref.read(hintChargesProvider),
      balance: balance,
    );
    var paidWith = quote.paidWith;

    if (paidWith == HintPayment.coins && !quote.affordable) {
      _logHintViewed(quote, 'insufficient_sheet');
      _logHintUnavailable(type, 'insufficient_coins', quote.cost);
      _hintSheetOpen = true;
      final outcome = await showHintInsufficientSheet(
        context,
        ref,
        quote: quote,
        balance: balance,
        // لا عرض شراء في مراحل البداية
        showShopLink: !_earlyGame,
      );
      _hintSheetOpen = false;
      if (!mounted || outcome != HintSheetOutcome.adRewarded) return;
      paidWith = HintPayment.ad;
    } else if (paidWith == HintPayment.coins) {
      if (quote.requiresConfirm) {
        _logHintViewed(quote, 'confirm_sheet');
        _hintSheetOpen = true;
        final ok = await showHintConfirmSheet(
          context,
          quote: quote,
          balance: balance,
        );
        _hintSheetOpen = false;
        if (!mounted || !ok) return;
      }
      if (!ref
          .read(pointsProvider.notifier)
          .spend(quote.cost, reason: 'hint')) {
        return;
      }
    } else if (paidWith == HintPayment.charge) {
      if (!ref.read(hintChargesProvider.notifier).consume()) return;
    }

    // الكلمة قد تكون حُلّت والورقة مفتوحة
    final target = _firstUnsolvedWord;
    if (target == null) return;
    final hidden = _hiddenPositions(target);
    if (hidden.isEmpty) return;
    final position = type == HintType.orderedLetter
        ? hidden.first
        : hidden[Random().nextInt(hidden.length)];
    setState(() => _revealed.putIfAbsent(target.word, () => {}).add(position));
    _tracker.hint(
      word: target.word,
      position: position,
      free: paidWith == HintPayment.free,
    );
    _hintCooldown?.cancel();
    _hintCooldown = Timer(BalanceConfig.hintTapDebounce, () {});
    _coach.onHintUsed();
    _markProgress();
    ref.read(achievementsProvider.notifier).bump(StatKey.hintsUsed);
    ref.logEvent(Ev.hintUsed, {
      'hint_type': type.wire,
      'cost': paidWith == HintPayment.coins ? quote.cost : 0,
      'paid_with': paidWith.wire,
      'index_in_stage': _hintsThisStage++,
      'stage_id': widget.level.id,
      'early_game': _earlyGame,
    });
    // التلميح بإعلان: المنح يُسجَّل هنا، بعد أن كُشف الحرف فعلا
    if (paidWith == HintPayment.ad) {
      ref.logEvent(Ev.adRewardGranted, {
        'ad_type': 'rewarded',
        'placement': 'hint',
        'reward_type': 'hint',
        'stage_id': widget.level.id,
      });
    }
    ref.read(audioServiceProvider).play(Sfx.hint);
    HapticFeedback.lightImpact();
    _showBubble(CharacterEmotion.thinking, const Duration(milliseconds: 2400));
  }

  /// سطر الزرّ: «مجاني» أو رصيد الشحنات أو السعر في هذه المرحلة
  String _hintLabel(HintType type) => _nextHintFree
      ? 'مجاني'
      : _hintCharges > 0
      ? '$_hintCharges'
      : '${HintPricing.price(type, widget.level.id)}';

  String _hintSemantics(HintType type) {
    final what = type == HintType.orderedLetter
        ? 'كشف الحرف التالي من أول كلمة ناقصة'
        : 'كشف حرف عشوائي من أول كلمة ناقصة';
    if (_nextHintFree) return '$what، مجانا';
    if (_hintCharges > 0) return '$what بشحنة مجانية، لديك $_hintCharges';
    return '$what مقابل ${HintPricing.price(type, widget.level.id)} نقطة';
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
          backgroundColor: HurufTheme.surface,
          duration: const Duration(milliseconds: 1400),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HurufTheme.rButton),
          ),
        ),
      );
  }

  /// تعريف الفصل الذي تنتمي إليه هذه المرحلة في نظام التقدّم (v2)، أو
  /// null إن كانت خارج مداه (محتوى قديم أبعد من الشجرة المولَّدة)
  ChapterDef? get _chapter {
    final structure = ref.read(progressionStructureProvider);
    if (widget.level.id < 1 || widget.level.id > BalanceConfig.totalStages) {
      return null;
    }
    return structure.chapterById(
      structure.stageById(widget.level.id).chapterId,
    );
  }

  /// آخر مرحلة في فصلها
  bool get _isChapterFinale => _chapter?.stageEnd == widget.level.id;

  /// سطر التقدّم على شاشة النجاح
  String? _progressLabel() {
    final chapter = _chapter;
    if (chapter == null) return null;
    final index = widget.level.id - chapter.stageStart + 1;
    final total = chapter.stageEnd - chapter.stageStart + 1;
    return ref
        .read(languageProvider)
        .t(
          'المرحلة $index من $total · الفصل ${chapter.index}',
          'Stage $index of $total · Chapter ${chapter.index}',
        );
  }

  String _primaryLabel(bool isLast) {
    final lang = ref.read(languageProvider);
    if (isLast) return lang.t('خريطة المراحل', 'Level Map');
    if (_isChapterFinale && _isWorldFinale) {
      return lang.t('أتممت الفصل!', 'Chapter complete!');
    }
    if (_isChapterFinale) return lang.t('الفصل التالي', 'Next chapter');
    return lang.t('المرحلة التالية', 'Next Level');
  }

  void _onNextPressed() {
    ref.logEvent(Ev.nextStageClicked, {
      'stage_id': widget.level.id,
      'next_stage_id': widget.level.id + 1,
      'chapter_finale': _isChapterFinale,
    });
    _leaveLevel(
      _goToNext,
      placement: _isChapterFinale ? 'chapter_next' : 'next_stage',
    );
  }

  void _goToNext() {
    // إتمام عالم كامل لحظة كبيرة: قائمة الفصول مع التهنئة ثم مراسم فتح
    // العالم التالي. أما الفصل داخل العالم فيُكمل مباشرة إلى أول مراحل
    // الفصل التالي — كانت قائمة الفصول هنا ثلاث لمسات بين مرحلتين
    // (القرار D2)، والتهنئة والصندوق صارا على شاشة النجاح نفسها.
    final chapter = _chapter;
    if (_isChapterFinale && _isWorldFinale && chapter != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ChapterSelectScreen(
            worldId: chapter.worldId,
            celebrateChapterId: chapter.id,
          ),
        ),
        (route) => route.isFirst,
      );
      return;
    }

    final next = widget.allLevels
        .where((l) => l.id == widget.level.id + 1)
        .toList();
    if (next.isEmpty) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          level: next.first,
          allLevels: widget.allLevels,
          source: _isChapterFinale ? 'chapter_next' : 'next_stage',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = ref.watch(pointsProvider);
    final isLast = widget.level.id >= widget.allLevels.length;

    // شاشة الحدس (العجلة والشبكة) تبقى عربية RTL دوما، بصرف النظر عن لغة
    // القوائم المختارة
    return Directionality(
      textDirection: TextDirection.rtl,
      // رجوع النظام (زرّ أو إيماءة الحافة) يُميَّز عن سهم الشاشة: الإيماءة
      // قد تقع خطأً أثناء سحب الحروف، وهذا ما يجب أن يظهر في البيانات
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _exitReason ??= ExitReason.systemBack;
        },
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              // خلفية العالم مع تعتيم قوي للقراءة. cacheWidth: الأصل
              // 1024×1024 ولا داعي لفكّه بأكبر من عرض الشاشة
              Image.asset(
                _world.background,
                fit: BoxFit.cover,
                cacheWidth: 1080,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      HurufTheme.bgTop.withValues(alpha: 0.93),
                      HurufTheme.bgTop.withValues(alpha: 0.86),
                      HurufTheme.bgBottom.withValues(alpha: 0.94),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _buildTopBar(points),
                        const SizedBox(height: HurufTheme.s2),
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: HurufTheme.s4,
                            ),
                            child: GlassCard(
                              child: WordGrid(
                                words: widget.level.words,
                                solvedWords: _solved,
                                revealedHints: _revealed,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 44,
                          child: Center(child: _buildPreview()),
                        ),
                        if (_lastDefinition != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: HurufTheme.s5,
                            ),
                            child: Text(
                              _lastDefinition!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: HurufTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        Expanded(
                          flex: 6,
                          child: Padding(
                            padding: const EdgeInsets.all(HurufTheme.s3),
                            child: Row(
                              children: [
                                _buildHintColumn(),
                                Expanded(
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: LetterWheel(
                                      key: _wheelKey,
                                      letters: widget.level.letters,
                                      onWordSubmitted: _onWord,
                                      onTouchStart: _onTouchStart,
                                      onSingleLetter: _onSingleLetter,
                                      demoWord: _firstUnsolvedWord?.word,
                                      demoActive:
                                          _coach.view.showFingerDemo &&
                                          !_completed,
                                      onSelectionChanged: (p) => setState(() {
                                        _preview = p;
                                        // بدء تكوين جديد يُخفي الكلمة الخاطئة فورا
                                        if (p.isNotEmpty) _lastAttempt = '';
                                      }),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 44),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // «رائع!» على اللوح عند أول كلمة في مرحلة التعليم
                    if (_coach.view.celebration != null && !_completed)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 120,
                        child: IgnorePointer(
                          child: Center(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.4, end: 1),
                              duration: const Duration(milliseconds: 420),
                              curve: Curves.elasticOut,
                              builder: (context, scale, child) =>
                                  Transform.scale(scale: scale, child: child),
                              child: Text(
                                _coach.view.celebration!,
                                style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  color: HurufTheme.gold,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 16,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // فقاعة المرشد فوق منطقة اللعب
                    if (_bubbleEmotion != null && !_completed)
                      Positioned(
                        left: HurufTheme.s4,
                        right: HurufTheme.s4,
                        top: 56,
                        child: CharacterBubble(
                          characterId: _world.guideId,
                          emotion: _bubbleEmotion!,
                          characterSize: 64,
                        ),
                      ),
                    if (_completed)
                      LevelCompleteOverlay(
                        levelId: widget.level.id,
                        // بترتيب اللوح أيضا: شبكة النتيجة المُشارَكة يجب
                        // أن تطابق الصفوف التي رآها اللاعب لحظة الحل
                        wordResults: [
                          for (final w in wordsInBoardOrder(widget.level.words))
                            (_revealed[w.word]?.isNotEmpty ?? false)
                                ? ShareWordStatus.hinted
                                : ShareWordStatus.solved,
                        ],
                        reward: _earnedCoins,
                        bonusFound: _bonusFound.length,
                        isLastLevel: isLast,
                        isChapterFinale: _isChapterFinale && !_isWorldFinale,
                        primaryLabel: _primaryLabel(isLast),
                        progressLabel: _progressLabel(),
                        chestCoins: _chestCoins,
                        chapterLine:
                            _isChapterFinale &&
                                !_isWorldFinale &&
                                _chapter != null
                            ? ref
                                  .watch(languageProvider)
                                  .t(
                                    chapterCelebrationLineFor(_chapter!.id).ar,
                                    chapterCelebrationLineFor(_chapter!.id).en,
                                  )
                            : null,
                        onNext: _onNextPressed,
                        onHome: () => _leaveLevel(
                          () => Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst),
                          placement: 'home',
                        ),
                        onMap: () => _leaveLevel(
                          () => Navigator.of(context).pop(),
                          placement: 'home',
                        ),
                        characterId: _world.guideId,
                        worldBonus: _worldCompletedThisRun
                            ? BalanceConfig.coinsWorldComplete
                            : 0,
                        worldName: ref
                            .watch(languageProvider)
                            .t(_world.nameAr, _world.nameEn),
                      ),
                    // لافتة مكافأة الخمس كلمات — فوق كل شيء عدا الإعلان،
                    // ولا تلتقط لمسا فاللعب يستمرّ تحتها
                    if (_bonusMilestoneTotal != null)
                      BonusMilestoneBurst(
                        key: ValueKey(_bonusMilestoneTotal),
                        coins: BalanceConfig.coinsBonusWordMilestone,
                        totalBonusWords: _bonusMilestoneTotal!,
                        lang: ref.watch(languageProvider),
                        onFinished: () {
                          if (mounted) {
                            setState(() => _bonusMilestoneTotal = null);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(int points) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HurufTheme.s4,
        vertical: HurufTheme.s2,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'رجوع',
            onPressed: () {
              _exitReason = ExitReason.backButton;
              Navigator.of(context).pop();
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: HurufTheme.textSecondary,
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              'المرحلة ${widget.level.id}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          Pressable(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ShopScreen(source: 'game_top_bar'),
              ),
            ),
            semanticLabel: 'رصيدك $points نقطة، افتح المتجر',
            child: GlassCard(
              radius: HurufTheme.rButton,
              padding: const EdgeInsets.symmetric(
                horizontal: HurufTheme.s3,
                vertical: HurufTheme.s1,
              ),
              child: Row(
                children: [
                  const AppIcon(AppIcons.gems, size: 26),
                  const SizedBox(width: HurufTheme.s1),
                  Text(
                    '$points',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: HurufTheme.gold,
                    ),
                  ),
                  const SizedBox(width: HurufTheme.s1),
                  const Icon(
                    Icons.add_circle_rounded,
                    size: 16,
                    color: HurufTheme.gold,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return AnimatedBuilder(
      animation: Listenable.merge([_shake, _flash]),
      builder: (context, _) {
        // أثناء التكوين نعرض ما يكوّنه اللاعب، وبعد محاولة خاطئة نُبقي
        // الكلمة نفسها بالأحمر وهي تهتزّ ثم تتلاشى — بدل فقاعة فارغة
        final showingAttempt = _preview.isEmpty;
        final text = showingAttempt ? _lastAttempt : _preview;
        if (text.isEmpty) {
          // الخانة فارغة: جملة المدرّب أو المساعدة إن وُجدت
          final hint =
              _coach.view.instruction ??
              (_assistHighlight ? CoachText.tryHint : null);
          return hint == null || _completed
              ? const SizedBox.shrink()
              : CoachBanner(text: hint);
        }

        final dx = sin(_shake.value * pi * 6) * 10 * (1 - _shake.value);
        final opacity = showingAttempt
            ? (1 - _flash.value).clamp(0.0, 1.0)
            : 1.0;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: HurufTheme.s4,
                vertical: HurufTheme.s1,
              ),
              decoration: BoxDecoration(
                color: showingAttempt
                    ? HurufTheme.error.withValues(alpha: 0.22)
                    : HurufTheme.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(HurufTheme.rButton),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: showingAttempt ? HurufTheme.error : HurufTheme.gold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHintColumn() {
    // مرحلة التعليم الأولى: لا تلميح قبل أن يعلق اللاعب — كان التلميح
    // أول ما يلمسه لاعب جديد، ثلاث مرات في ثانيتين
    if (!_coach.view.hintButtonsVisible) return const SizedBox(width: 44);
    return SizedBox(
      width: 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // رصيد الشحنات المجانية يظهر مكان السعر: من يملك شحنة لا
          // يدفع عملة، فعرض سعر لن يُخصم كذبة صغيرة تتكرّر كل تلميح
          _HintButton(
            icon: Icons.lightbulb_outline_rounded,
            label: _hintLabel(HintType.orderedLetter),
            labelIcon: !_nextHintFree && _hintCharges > 0
                ? Icons.confirmation_number_rounded
                : null,
            semanticLabel: _hintSemantics(HintType.orderedLetter),
            onTap: () => _requestHint(HintType.orderedLetter),
            pulse: _highlightHint ? _pulse : null,
          ),
          const SizedBox(height: HurufTheme.s3),
          _HintButton(
            icon: Icons.help_outline_rounded,
            label: _hintLabel(HintType.randomLetter),
            labelIcon: !_nextHintFree && _hintCharges > 0
                ? Icons.confirmation_number_rounded
                : null,
            semanticLabel: _hintSemantics(HintType.randomLetter),
            onTap: () => _requestHint(HintType.randomLetter),
          ),
          const SizedBox(height: HurufTheme.s3),
          _HintButton(
            icon: Icons.shuffle_rounded,
            label: 'مجاني',
            semanticLabel: 'خلط الحروف، مجاني',
            onTap: () => _wheelKey.currentState?.shuffle(),
          ),
        ],
      ),
    );
  }
}

class _HintButton extends StatelessWidget {
  final IconData icon;

  /// نص السطر أسفل الزر — **أرقام أو حروف فقط**. لا رمز تعبيري هنا
  /// أبدا: خط التطبيق (IRANSans) لا يحوي أي محرف تعبيري، والسطر مقاسه
  /// 10 بكسل، فأي رمز يظهر مربّعا صغيرا لا يقرؤه أحد — وهو ما حدث
  /// فعليا بـ`'🎟$charges'` حين صار منح الشحنات المجانية يعمل. الرمز
  /// يُمرَّر عبر [labelIcon] لأنه خط أيقونات مضمّن يُرسم متجهيا.
  final String label;

  /// أيقونة صغيرة قبل [label] — تُستخدم لتمييز «رصيد شحنات» عن «سعر
  /// بالعملات». null يعني السطر رقم فقط.
  final IconData? labelIcon;
  final String semanticLabel;
  final VoidCallback onTap;

  /// نبض الإبراز (تعليم/مساعدة متدرّجة) — null بلا إبراز
  final Animation<double>? pulse;

  const _HintButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.labelIcon,
    this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulse ?? const AlwaysStoppedAnimation(0.0),
            builder: (context, child) {
              final glow = pulse == null ? 0.0 : pulse!.value;
              return Transform.scale(
                scale: 1 + 0.12 * glow,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: HurufTheme.tileEmpty,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: pulse == null
                          ? Colors.white.withValues(alpha: 0.15)
                          : HurufTheme.gold,
                      width: pulse == null ? 1 : 2,
                    ),
                    boxShadow: [
                      if (pulse != null)
                        BoxShadow(
                          color: HurufTheme.gold.withValues(
                            alpha: 0.25 + 0.35 * glow,
                          ),
                          blurRadius: 14,
                        ),
                    ],
                  ),
                  child: child,
                ),
              );
            },
            child: Icon(icon, color: HurufTheme.gold, size: 22),
          ),
          const SizedBox(height: 2),
          // FittedBox: عرض العمود 44 بكسل ثابت، و«مجاني» أو «أيقونة+رقم»
          // قد يتجاوزه عند تكبير خط النظام — التصغير أوضح من قصّ المحتوى
          //
          // وترتيب صريح من اليسار لليمين: الأيقونة محايدة الاتجاه والرقم
          // لاتيني، فلو تُركا لاتجاه الواجهة العربي لانعكس ترتيبهما
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (labelIcon != null) ...[
                    Icon(labelIcon, size: 11, color: HurufTheme.textSecondary),
                    const SizedBox(width: 2),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: HurufTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
