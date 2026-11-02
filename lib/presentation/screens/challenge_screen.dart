import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../data/challenge_progress.dart';
import '../../data/achievement_models.dart';
import '../../data/audio_service.dart';
import '../../data/economy/economy_models.dart';
import '../../data/economy/economy_service.dart';
import '../../data/progression/player_state.dart';
import '../../data/challenge_models.dart';
import '../../data/world_models.dart';
import '../providers.dart';
import '../widgets/achievement_toast.dart';
import '../widgets/animated_background.dart';
import '../widgets/character_bubble.dart';
import '../widgets/glass_card.dart';
import '../widgets/letter_wheel.dart';
import '../../data/store/near_miss.dart';
import '../widgets/near_miss_sheet.dart';
import '../widgets/pressable.dart';

/// جلسة تحدٍّ: يمرّ اللاعب على عناصر فئة واحدة، يكوّن الكلمة الناقصة
/// من عجلة الحروف. يعيد استخدام مكانيك اللعب الأساسية.
class ChallengeScreen extends ConsumerStatefulWidget {
  final ChallengeCategory category;
  final List<ChallengeItem> items;

  /// من أي عنصر يبدأ (موضعه في [items]). الخريطة تفتح عقدة بعينها.
  final int startIndex;

  /// الخلط مناسب لقائمة تشغيل حرّة، وكارثة حين تَعِد الخريطة بعقدة
  /// بعينها: الموضع في [items] هو معرّف العنصر المحفوظ.
  final bool shuffle;

  /// يُستدعى بموضع العنصر في [items] عند كل حلّ — الخريطة تثبّته
  final void Function(int index)? onSolved;

  const ChallengeScreen({
    super.key,
    required this.category,
    required this.items,
    this.startIndex = 0,
    this.shuffle = true,
    this.onSolved,
  });

  @override
  ConsumerState<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends ConsumerState<ChallengeScreen>
    with TickerProviderStateMixin {
  // التحديات أصعب، لذا التلميح أغلى قليلا من مراحل اللعب العادية
  /// محرّك الاقتصاد للحساب فقط: quoteHintCost لا يمسّ المحفظة،
  /// ودفتر العملات يبقى pointsProvider. كان هنا رقم ثابت يتجاهل
  /// سلّم التصعيد في BalanceConfig (15/25/40/70).
  final _economy = EconomyService(wallet: PlayerWallet.initial());

  /// التحدّيات خارج تقدّم العوالم، فتُسعَّر بمضاعف العالم الأول:
  /// التصعيد داخل التحدّي الواحد هو المقصود هنا لا صعوبة العالم
  int get _hintCost => _economy.quoteHintCost(
    HintType.revealRandomLetter,
    hintsUsedThisStage: _revealed.length,
    worldId: 1,
  );

  // المرشد في التحديات: الحكيم (wise_oldman)
  static const String guideId = 'wise_oldman';

  late List<ChallengeItem> _order;
  int _index = 0;
  int _solvedCount = 0;

  late List<String> _letters;
  final Set<int> _revealed = {}; // مواضع الحروف المكشوفة بالتلميح
  String _preview = '';

  /// آخر كلمة خاطئة جرّبها اللاعب — تُعرض بالأحمر ثم تتلاشى
  String _lastAttempt = '';
  bool _solved = false;
  CharacterEmotion _emotion = CharacterEmotion.idle;

  late final AnimationController _shake;
  late final AnimationController _flash;
  final GlobalKey<LetterWheelState> _wheelKey = GlobalKey();

  ChallengeItem get _item => _order[_index];

  @override
  void initState() {
    super.initState();
    _order = widget.shuffle
        ? (List.of(widget.items)..shuffle())
        : List.of(widget.items);
    _index = widget.startIndex.clamp(0, _order.length - 1);
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _flash =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 500),
        )..addStatusListener((st) {
          if (st == AnimationStatus.completed && mounted && _preview.isEmpty) {
            setState(() => _lastAttempt = '');
          }
        });
    _prepareCurrent();
  }

  void _prepareCurrent() {
    _letters = _item.buildWheelLetters();
    _revealed.clear();
    _preview = '';
    _lastAttempt = '';
    _solved = false;
    _emotion = CharacterEmotion.idle;
  }

  @override
  void dispose() {
    _shake.dispose();
    _flash.dispose();
    super.dispose();
  }

  /// هل هذا أول حلّ لهذا العنصر على الإطلاق (لا في هذه الجلسة فقط)؟
  ///
  /// المصدر هو نفس المجموعة المحفوظة التي تعتمدها [markSolved]، فلا
  /// يفترق «ما يُحسب محلولا» عن «ما يُدفع عليه». مع الخلط لا يصحّ
  /// اشتقاق المعرّف من الموضع، فيُعامَل الحلّ كأول مرة — الخلط قائمة
  /// تشغيل حرّة لا تفتحها الخريطة، ولا موضع ثابت فيها أصلا.
  bool _isFirstSolve() {
    if (widget.shuffle) return true;
    final id = ChallengeProgressRules.idFor(widget.category, _index);
    return !ref.read(challengeProgressProvider).solvedIds.contains(id);
  }

  void _onWord(String word) {
    if (_solved) return;
    if (word == _item.answer) {
      setState(() {
        _solved = true;
        _emotion = CharacterEmotion.celebrating;
      });
      _solvedCount++;
      // الموضع في القائمة الأصلية هو المعرّف المحفوظ — لا يصحّ إلا
      // حين لا خلط، وهو بالضبط الوضع الذي تفتح فيه الخريطة الشاشة
      final firstTime = _isFirstSolve();
      if (!widget.shuffle) widget.onSolved?.call(_index);

      // العملات والعدّادات لأول حلّ وحده.
      //
      // كان الدفع معلّقا على `_solved` وحده، وهو حقل في حالة الودجت
      // يعود false في كل مرة تُفتح فيها الشاشة (initState). وخريطة
      // التحدّيات تُبقي العقد المحلولة قابلة للنقر، فكان إعادةُ حلّ
      // المثل نفسه تدفع 20–30 عملة في كل مرة بلا حدّ — مزرعة عملات
      // مفتوحة، وترقية مجانية لعدّاد challengesSolved معها.
      if (firstTime) {
        ref.earnPoints(_item.reward);
      }
      ref.read(audioServiceProvider).play(Sfx.correct);
      final achievements = ref.read(achievementsProvider.notifier);
      if (firstTime) achievements.bump(StatKey.challengesSolved);
      achievements.reportBest(StatKey.longestWord, _item.answer.length);
      showAchievementUnlocked(context, achievements.takeJustUnlocked());
      HapticFeedback.mediumImpact();
    } else {
      setState(() {
        _emotion = CharacterEmotion.encouraging;
        _lastAttempt = word;
      });
      ref.read(audioServiceProvider).play(Sfx.wrong);
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
      _flash.forward(from: 0);
    }
  }

  void _useHint() {
    final hidden = [
      for (var i = 0; i < _item.answer.length; i++)
        if (!_revealed.contains(i)) i,
    ];
    if (hidden.isEmpty) return;
    if (!ref.read(pointsProvider.notifier).spend(_hintCost)) {
      showNearMissSheet(
        context,
        ref,
        price: _hintCost,
        balance: ref.read(pointsProvider),
        target: NearMissTarget.hint,
        onAffordable: _useHint,
      );
      return;
    }
    ref.read(achievementsProvider.notifier).bump(StatKey.hintsUsed);
    setState(() {
      _revealed.add(hidden[Random().nextInt(hidden.length)]);
      _emotion = CharacterEmotion.thinking;
    });
    HapticFeedback.lightImpact();
  }

  void _next() {
    if (_index >= _order.length - 1) {
      _showSummary();
      return;
    }
    setState(() {
      _index++;
      _prepareCurrent();
    });
  }

  AppLanguage get _lang => ref.watch(languageProvider);

  void _showSummary() {
    final lang = _lang;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: lang.textDirection,
        child: Dialog(
          backgroundColor: HurufTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HurufTheme.rCard),
          ),
          child: Padding(
            padding: const EdgeInsets.all(HurufTheme.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 48)),
                const SizedBox(height: HurufTheme.s3),
                Text(
                  lang.t('أكملت التحدي!', 'Challenge complete!'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: HurufTheme.gold,
                  ),
                ),
                const SizedBox(height: HurufTheme.s2),
                Text(
                  lang.t(
                    'حللت $_solvedCount من ${_order.length}',
                    'You solved $_solvedCount of ${_order.length}',
                  ),
                  style: const TextStyle(color: HurufTheme.textSecondary),
                ),
                const SizedBox(height: HurufTheme.s5),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: HurufTheme.gold,
                    foregroundColor: HurufTheme.bgTop,
                    padding: const EdgeInsets.symmetric(
                      horizontal: HurufTheme.s7,
                      vertical: HurufTheme.s3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(HurufTheme.rButton),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(); // الحوار
                    Navigator.of(context).pop(); // الشاشة
                  },
                  child: Text(
                    lang.t('تم', 'Done'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = ref.watch(pointsProvider);
    // التحدّيات عربية المحتوى (أمثال وشعر وكلمات) فتبقى الشاشة RTL دوما
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: AnimatedBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(points),
                // الحكيم يرافق اللاعب طوال التحدي (فيديو متحرك + رسالة حسب الحالة)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HurufTheme.s4,
                    0,
                    HurufTheme.s4,
                    HurufTheme.s2,
                  ),
                  child: CharacterBubble(
                    key: ValueKey(_emotion),
                    characterId: guideId,
                    emotion: _emotion,
                    animated: true,
                    characterSize: 64,
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HurufTheme.s4,
                    ),
                    child: _buildPromptCard(),
                  ),
                ),
                SizedBox(height: 44, child: Center(child: _buildPreview())),
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(HurufTheme.s3),
                    child: _solved ? _buildSolvedActions() : _buildWheelRow(),
                  ),
                ),
              ],
            ),
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
            tooltip: _lang.t('رجوع', 'Back'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: HurufTheme.textSecondary,
              size: 20,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _lang.t(widget.category.titleAr, widget.category.titleEn),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${_index + 1} / ${_order.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: HurufTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GlassCard(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptCard() {
    return GlassCard(
      padding: const EdgeInsets.all(HurufTheme.s5),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(widget.category.iconAsset, size: 62),
              const SizedBox(height: HurufTheme.s4),
              if (_item.category == ChallengeCategory.word)
                _buildWordPrompt()
              else
                _buildFillPrompt(),
              if (_solved) ...[
                const Divider(height: HurufTheme.s6, color: Colors.white24),
                _buildRevealBlock(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// نمط الكلمة: يعرض المعنى، واللاعب يكوّن الكلمة
  Widget _buildWordPrompt() {
    return Column(
      children: [
        Text(
          _lang.t('ما الكلمة التي تعني؟', 'Which Arabic word means this?'),
          style: const TextStyle(fontSize: 14, color: HurufTheme.textSecondary),
        ),
        const SizedBox(height: HurufTheme.s3),
        Text(
          _item.clue,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  /// نمط المثل/البيت: يعرض النص مع فراغ ذهبي مكان الجواب
  Widget _buildFillPrompt() {
    return Column(
      children: [
        if (_item.clue.isNotEmpty) ...[
          Text(
            _item.clue,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              height: 1.7,
              color: HurufTheme.textSecondary,
            ),
          ),
          const SizedBox(height: HurufTheme.s3),
        ],
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 8,
          textDirection: TextDirection.rtl,
          children: [
            if (_item.before.isNotEmpty) Text(_item.before, style: _fillStyle),
            _buildBlank(),
            if (_item.after.isNotEmpty) Text(_item.after, style: _fillStyle),
          ],
        ),
      ],
    );
  }

  static const _fillStyle = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w800,
    height: 1.7,
  );

  /// الفراغ: مربّعات صغيرة بعدد حروف الجواب، تُكشف تدريجيا بالتلميح
  Widget _buildBlank() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [
        for (var i = 0; i < _item.answer.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 22,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HurufTheme.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: HurufTheme.gold.withValues(alpha: 0.5)),
            ),
            child: Text(
              _solved || _revealed.contains(i) ? _item.answer[i] : '',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: HurufTheme.gold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRevealBlock() {
    return Column(
      children: [
        Text(
          _item.reveal,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            height: 1.8,
            color: HurufTheme.gold,
          ),
        ),
        if (_item.attribution.isNotEmpty) ...[
          const SizedBox(height: HurufTheme.s2),
          Text(
            '— ${_item.attribution}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
        if (_item.meaning.isNotEmpty) ...[
          const SizedBox(height: HurufTheme.s3),
          Text(
            _item.meaning,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: HurufTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreview() {
    return AnimatedBuilder(
      animation: Listenable.merge([_shake, _flash]),
      builder: (context, _) {
        // نفس سلوك شاشة اللعب: الكلمة الخاطئة تبقى حمراء مهتزّة ثم تتلاشى
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

  Widget _buildWheelRow() {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HintButton(
                icon: Icons.lightbulb_outline_rounded,
                label: '$_hintCost',
                semanticLabel: _lang.t(
                  'كشف حرف مقابل $_hintCost نقطة',
                  'Reveal a letter for $_hintCost points',
                ),
                onTap: _useHint,
              ),
              const SizedBox(height: HurufTheme.s3),
              _HintButton(
                icon: Icons.shuffle_rounded,
                label: _lang.t('مجاني', 'Free'),
                semanticLabel: _lang.t(
                  'خلط الحروف، مجاني',
                  'Shuffle the letters, free',
                ),
                onTap: () => _wheelKey.currentState?.shuffle(),
              ),
            ],
          ),
        ),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: LetterWheel(
              key: _wheelKey,
              letters: _letters,
              onWordSubmitted: _onWord,
              onSelectionChanged: (p) => setState(() {
                _preview = p;
                if (p.isNotEmpty) _lastAttempt = '';
              }),
            ),
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }

  Widget _buildSolvedActions() {
    final isLast = _index >= _order.length - 1;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _lang.t('+${_item.reward} نقطة', '+${_item.reward} points'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: HurufTheme.success,
            ),
          ),
          const SizedBox(height: HurufTheme.s4),
          Pressable(
            onTap: _next,
            semanticLabel: isLast
                ? _lang.t('إنهاء التحدي', 'Finish the challenge')
                : _lang.t('التحدي التالي', 'Next challenge'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: HurufTheme.s7,
                vertical: HurufTheme.s4,
              ),
              decoration: BoxDecoration(
                gradient: HurufTheme.goldGradient,
                borderRadius: BorderRadius.circular(HurufTheme.rCard),
                boxShadow: [
                  BoxShadow(
                    color: HurufTheme.gold.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Text(
                isLast ? _lang.t('إنهاء', 'Finish') : _lang.t('التالي', 'Next'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: HurufTheme.bgTop,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  const _HintButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: HurufTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
