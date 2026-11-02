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
import '../../data/models.dart';
import '../../data/analytics/analytics_event.dart';
import '../../data/analytics/analytics_service.dart';
import '../../data/progression/world_defs.dart';
import '../../data/store/near_miss.dart';
import '../../data/world_models.dart';
import '../providers.dart';
import '../widgets/achievement_toast.dart';
import '../widgets/bonus_milestone_burst.dart';
import '../widgets/character_bubble.dart';
import '../widgets/glass_card.dart';
import '../widgets/letter_wheel.dart';
import '../widgets/level_complete_overlay.dart';
import '../widgets/near_miss_sheet.dart';
import '../widgets/pressable.dart';
import '../widgets/word_grid.dart';
import 'chapter_select_screen.dart';
import 'shop_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  final GameLevel level;
  final List<GameLevel> allLevels;

  const GameScreen({super.key, required this.level, required this.allLevels});

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

  /// محاولات خاطئة في هذه المرحلة — أحد شروط محفّز الشراء الأول
  int _wrongAttempts = 0;

  /// لافتة «خمس كلمات إضافية = +20»: null إذا لا لافتة معروضة الآن.
  /// القيمة هي مجموع الكلمات الإضافية عند بلوغ المكافأة (5، 10، 15..)
  int? _bonusMilestoneTotal;

  /// لحظة دخول المرحلة — تُحسب منها مدّة الإتمام في حدث stage_complete
  final _startedAt = DateTime.now();

  /// عملات إتمام هذه المرحلة كما منحها محرّك الاقتصاد فعلا. تُملأ بعد
  /// [_recordProgressionCompletion]، وتُقرأ في شاشة الإتمام.
  int _earnedCoins = 0;

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

  /// كشف الحرف التالي بالترتيب من أول كلمة ناقصة — أغلى لأنه يختار
  /// الحرف المفيد لا حرفا عشوائيا
  int get _orderedHintCost => BalanceConfig.coinsHintOrderedLetter;

  /// كشف حرف عشوائي داخل أول كلمة ناقصة
  int get _randomHintCost => BalanceConfig.coinsHintRandomLetter;

  WorldModel get _world => worldForLevel(widget.level.id);

  @override
  void initState() {
    super.initState();
    // أول لعب في الجلسة — بلا هذا العلم يبقى الإعلان البيني ممنوعا
    // (قاعدة «لا إعلان على بداية باردة قبل أول لعب»)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(sessionGameplayProvider.notifier).markGameplayStarted();
      _analytics = ref.read(analyticsProvider);
      _analytics?.updateContext(stageId: widget.level.id);
      ref.logEvent(Ev.stageStart, {
        'stage_id': widget.level.id,
        'world_id': _world.id,
        'words': widget.level.words.length,
      });
    });
    // كلمات إضافية اكتُشفت في محاولة سابقة لنفس المرحلة تبدأ «موجودة»:
    // إعادة إيجادها ليست اكتشافا، فلا تمنح عملات ولا تقرّب من مكافأة
    // الخمس كلمات (وإلا صارت إعادة نفس المرحلة مزرعة عملات)
    final savedBonus = ref
        .read(progressionProvider)
        .stageProgress[widget.level.id]
        ?.bonusWordsFound;
    if (savedBonus != null) _bonusFound.addAll(savedBonus);

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
    _showBubble(CharacterEmotion.idle, const Duration(milliseconds: 3200));
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
    // يشمل كل مخارج الشاشة (إيماءة الرجوع، زرّ النظام، انتقال برمجي) —
    // ومعدّل التخلّي لكل مرحلة هو أعلى تقرير قيمة في المشروع، فلا يجوز
    // أن يفوته مخرج واحد.
    if (!_completed) {
      final props = {
        'stage_id': widget.level.id,
        'world_id': _world.id,
        'solved': _solved.length,
        'of': widget.level.words.length,
        'wrong_attempts': _wrongAttempts,
        'duration_ms': DateTime.now().difference(_startedAt).inMilliseconds,
      };
      _analytics?.log(Ev.stageAbandon, props);

      // لغز الكلمات لا «يُخسَر»: لا مؤقّت ولا محاولات محدودة، فالمخرج
      // السلبي الوحيد هو المغادرة. لكن المغادرة بعد تعثّر متكرّر شيء
      // مختلف تماما عن المغادرة لأن الهاتف رنّ — نميّزها بحدث الفشل كي
      // لا يختلط «تركها لأنه عجز» بـ«تركها لأنه انشغل»، وهذا التمييز
      // بالذات هو ما يجعل تقرير الصعوبة قابلا للتصرّف.
      if (_wrongAttempts >= BalanceConfig.safetyModeMinFailedAttempts) {
        _analytics?.log(Ev.stageFail, props);
      }
    }
    _analytics?.clearStage();
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
      _wrongAttempts++;
    });
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

    ref.logEvent(Ev.stageComplete, {
      'stage_id': widget.level.id,
      'world_id': _world.id,
      'wrong_attempts': _wrongAttempts,
      'hints_used': _revealed.length,
      'bonus_words': _bonusFound.length,
      'duration_ms': DateTime.now().difference(_startedAt).inMilliseconds,
      'perfect': _revealed.isEmpty,
    });
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
  /// «التالي» أو «الخريطة» بنفسه)، فالإعلان لا يقاطع مكافأة تُعدّ ولا
  /// عملات تتطاير.
  Future<void> _leaveLevel(VoidCallback proceed) async {
    // القالب مطفأ في هذا البناء (أو بمفتاح الإيقاف): انتقال فوري، بلا
    // تحميل مسبق ولا انتظار لإعلان لن يأتي
    if (!ref.read(interstitialAdsAvailableProvider)) {
      proceed();
      return;
    }
    final ads = ref.read(adServiceProvider);
    // لا نسأل وحدة الإيقاع إن لم يكن إعلان محمَّلا: قرارها يصفّر العدّاد
    // ويسجّل وقت الإعلان، وإعلان لم يُعرض يجب ألّا يستهلك دورة إيقاع.
    // نطلب التحميل ونمضي؛ الدورة التالية تجده جاهزا.
    if (!ads.isInterstitialReady) {
      unawaited(ads.preload());
      proceed();
      return;
    }

    final cue = ref
        .read(interstitialGateProvider.notifier)
        .requestInterstitial(
          stageNumber: widget.level.id,
          // المغادرة من شاشة الإتمام فقط تمرّ من هنا بـtrue؛ الخروج قبل
          // الحل يمرّ بمسار آخر لا يطلب إعلانا أصلا
          stageCleared: _completed,
          rewardSequenceComplete: true,
        );
    if (cue == AdCue.none) {
      proceed();
      return;
    }

    final result = await ads.showInterstitial(
      context,
      onOpenShop: () {
        if (!mounted) return;
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ShopScreen()));
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

  /// يخصم ثمن التلميح ويسجّل الحدث، أو يفتح ورقة الشحن السريع ويعيد
  /// false. الشحنة المجانية أولا: من اشترى تلميحات يجب أن يستهلكها قبل
  /// أن يُطلب منه عملة واحدة.
  bool _payForHint({
    required int cost,
    required String type,
    required VoidCallback retry,
  }) {
    if (ref.read(hintChargesProvider.notifier).consume()) {
      ref.read(achievementsProvider.notifier).bump(StatKey.hintsUsed);
      ref.logEvent(Ev.hintUsed, {
        'type': type,
        'cost': 0,
        'paid_with': 'charge',
        'index_in_stage': _hintsThisStage++,
        'stage_id': widget.level.id,
      });
      ref.read(audioServiceProvider).play(Sfx.hint);
      return true;
    }
    if (!ref.read(pointsProvider.notifier).spend(cost)) {
      // نقص صغير (ربع السعر أو أقل) يفتح ورقة الشحن السريع، وأكبر من
      // ذلك يعرض رسالة قصيرة فقط — القرار في NearMiss لا هنا
      showNearMissSheet(
        context,
        ref,
        price: cost,
        balance: ref.read(pointsProvider),
        target: NearMissTarget.hint,
        onAffordable: retry,
      );
      return false;
    }
    ref.read(achievementsProvider.notifier).bump(StatKey.hintsUsed);
    ref.logEvent(Ev.hintUsed, {
      'type': type,
      'cost': cost,
      'index_in_stage': _hintsThisStage++,
      'stage_id': widget.level.id,
    });
    ref.read(audioServiceProvider).play(Sfx.hint);
    return true;
  }

  /// كشف الحرف التالي بالترتيب من أول كلمة ناقصة: يبدأ من أول الكلمة
  /// (أقصى اليمين في العربية) ويتقدّم حرفا واحدا مع كل ضغطة
  void _useRevealHint() {
    final entry = _firstUnsolvedWord;
    if (entry == null) return;
    final hidden = _hiddenPositions(entry);
    // كل حروف الكلمة مكشوفة ولم تُحلّ بعد: لا شيء يُباع هنا، فلا يُخصم
    // شيء أيضا — الخصم قبل التحقّق كان يأخذ عملات بلا مقابل
    if (hidden.isEmpty) {
      _showToast('كل حروف الكلمة مكشوفة!');
      return;
    }
    if (!_payForHint(
      cost: _orderedHintCost,
      type: 'ordered_letter',
      retry: _useRevealHint,
    )) {
      return;
    }
    setState(
      () => _revealed.putIfAbsent(entry.word, () => {}).add(hidden.first),
    );
    HapticFeedback.lightImpact();
    _showBubble(CharacterEmotion.thinking, const Duration(milliseconds: 2400));
  }

  /// كشف حرف عشوائي داخل أول كلمة ناقصة
  void _useFirstLetterHint() {
    final entry = _firstUnsolvedWord;
    if (entry == null) return;
    final hidden = _hiddenPositions(entry);
    if (hidden.isEmpty) {
      _showToast('كل حروف الكلمة مكشوفة!');
      return;
    }
    if (!_payForHint(
      cost: _randomHintCost,
      type: 'random_letter',
      retry: _useFirstLetterHint,
    )) {
      return;
    }
    final pick = hidden[Random().nextInt(hidden.length)];
    setState(() => _revealed.putIfAbsent(entry.word, () => {}).add(pick));
    HapticFeedback.lightImpact();
    _showBubble(CharacterEmotion.thinking, const Duration(milliseconds: 2400));
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

  /// آخر مرحلة في فصلها — عندها لا "المرحلة التالية" بل قائمة الفصول
  bool get _isChapterFinale => _chapter?.stageEnd == widget.level.id;

  void _goToNext() {
    // إتمام فصل ليس مجرّد مرحلة أخرى: نعيد اللاعب إلى قائمة فصول عالمه
    // مع تهنئة المرشد، بدل الانزلاق من المرحلة 12 إلى 13 بلا أي علامة
    // على أنه عبر حدّ فصل. الفصل التالي يُفتح من هناك بزرّ صريح.
    final chapter = _chapter;
    if (_isChapterFinale && chapter != null) {
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
        builder: (_) =>
            GameScreen(level: next.first, allLevels: widget.allLevels),
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
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // خلفية العالم مع تعتيم قوي للقراءة. cacheWidth: الأصل
            // 1024×1024 ولا داعي لفكّه بأكبر من عرض الشاشة
            Image.asset(_world.background, fit: BoxFit.cover, cacheWidth: 1080),
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
                      isChapterFinale: _isChapterFinale,
                      onNext: () => _leaveLevel(_goToNext),
                      // آخر مرحلة في الفصل: أيّ خروج يمرّ بقائمة الفصول
                      // مع التهنئة، لا رجوعا صامتا إلى مسار فصل انتهى
                      onMap: () => _leaveLevel(
                        _isChapterFinale
                            ? _goToNext
                            : () => Navigator.of(context).pop(),
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
            onPressed: () => Navigator.of(context).pop(),
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
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ShopScreen())),
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
        if (text.isEmpty) return const SizedBox.shrink();

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
    return SizedBox(
      width: 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // رصيد الشحنات المجانية يظهر مكان السعر: من يملك شحنة لا
          // يدفع عملة، فعرض سعر لن يُخصم كذبة صغيرة تتكرّر كل تلميح
          _HintButton(
            icon: Icons.lightbulb_outline_rounded,
            label: _hintCharges > 0 ? '$_hintCharges' : '$_orderedHintCost',
            labelIcon: _hintCharges > 0
                ? Icons.confirmation_number_rounded
                : null,
            semanticLabel: _hintCharges > 0
                ? 'كشف الحرف التالي من أول كلمة ناقصة بشحنة مجانية، لديك $_hintCharges'
                : 'كشف الحرف التالي من أول كلمة ناقصة مقابل $_orderedHintCost نقطة',
            onTap: _useRevealHint,
          ),
          const SizedBox(height: HurufTheme.s3),
          _HintButton(
            icon: Icons.help_outline_rounded,
            label: _hintCharges > 0 ? '$_hintCharges' : '$_randomHintCost',
            labelIcon: _hintCharges > 0
                ? Icons.confirmation_number_rounded
                : null,
            semanticLabel: _hintCharges > 0
                ? 'كشف حرف عشوائي من أول كلمة ناقصة بشحنة مجانية، لديك $_hintCharges'
                : 'كشف حرف عشوائي من أول كلمة ناقصة مقابل $_randomHintCost نقطة',
            onTap: _useFirstLetterHint,
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

  const _HintButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.labelIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: HurufTheme.tileEmpty,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
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
