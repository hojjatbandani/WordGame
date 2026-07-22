import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/world_models.dart';
import '../providers.dart';
import '../widgets/character_bubble.dart';
import '../widgets/glass_card.dart';
import '../widgets/letter_wheel.dart';
import '../widgets/level_complete_overlay.dart';
import '../widgets/word_grid.dart';
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
  bool _completed = false;
  String? _lastDefinition;

  // فقاعة المرشد: تظهر عند البداية والأخطاء والتلميحات
  CharacterEmotion? _bubbleEmotion;
  int _bubbleToken = 0;

  late final AnimationController _shake;
  late final AnimationController _flash;
  final GlobalKey<LetterWheelState> _wheelKey = GlobalKey();

  static const int hintCost = 25;
  static const int firstLetterCost = 15;

  WorldModel get _world => worldForLevel(widget.level.id);

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
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
    _shake.dispose();
    _flash.dispose();
    super.dispose();
  }

  void _onWord(String word) {
    final target = widget.level.words
        .where((w) => w.word == word && !_solved.contains(word))
        .toList();
    if (target.isNotEmpty) {
      setState(() {
        _solved.add(word);
        _lastDefinition = '${target.first.word}: ${target.first.definition}';
      });
      HapticFeedback.mediumImpact();
      if (_solved.length == widget.level.words.length) {
        _finishLevel();
      }
      return;
    }
    if (widget.level.bonusWords.contains(word) &&
        !_bonusFound.contains(word)) {
      setState(() => _bonusFound.add(word));
      ref.read(pointsProvider.notifier).add(5);
      ref.read(bonusJarProvider.notifier).add(1);
      HapticFeedback.mediumImpact();
      _showToast('🫙 كلمة إضافية! +5');
      _showBubble(
          CharacterEmotion.surprised, const Duration(milliseconds: 2200));
      return;
    }
    // كلمة خاطئة: اهتزاز + وميض أحمر + تشجيع من المرشد
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0);
    _flash.forward(from: 0);
    _showBubble(
        CharacterEmotion.encouraging, const Duration(milliseconds: 2400));
  }

  bool get _isWorldFinale => widget.level.id == _world.lastLevelId;

  void _finishLevel() {
    ref.read(pointsProvider.notifier).add(widget.level.completionReward);
    // مكافأة إتمام العالم عند آخر مرحلة فيه
    if (_isWorldFinale) {
      ref.read(pointsProvider.notifier).add(_world.completionReward);
    }
    ref.read(maxUnlockedProvider.notifier).unlockUpTo(widget.level.id + 1);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _completed = true);
    });
  }

  void _useRevealHint() {
    final unsolved =
        widget.level.words.where((w) => !_solved.contains(w.word)).toList();
    if (unsolved.isEmpty) return;
    if (!ref.read(pointsProvider.notifier).spend(hintCost)) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: const Text('لا تكفي النقاط!', textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
          backgroundColor: HurufTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HurufTheme.rButton),
          ),
          action: SnackBarAction(
            label: 'المتجر 💎',
            textColor: HurufTheme.gold,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShopScreen()),
            ),
          ),
        ));
      return;
    }
    final rng = Random();
    final entry = unsolved[rng.nextInt(unsolved.length)];
    final revealed = _revealed.putIfAbsent(entry.word, () => {});
    final hidden = [
      for (var i = 0; i < entry.word.length; i++)
        if (!revealed.contains(i)) i,
    ];
    if (hidden.isEmpty) return;
    setState(() => revealed.add(hidden[rng.nextInt(hidden.length)]));
    HapticFeedback.lightImpact();
    _showBubble(
        CharacterEmotion.thinking, const Duration(milliseconds: 2400));
  }

  /// كشف أول حرف من كلمة لم يكشف أولها بعد
  void _useFirstLetterHint() {
    final candidates = widget.level.words
        .where((w) =>
            !_solved.contains(w.word) &&
            !(_revealed[w.word]?.contains(0) ?? false))
        .toList();
    if (candidates.isEmpty) {
      _showToast('كل الأوائل مكشوفة!');
      return;
    }
    if (!ref.read(pointsProvider.notifier).spend(firstLetterCost)) {
      _showToast('لا تكفي النقاط!');
      return;
    }
    final entry = candidates[Random().nextInt(candidates.length)];
    setState(() => _revealed.putIfAbsent(entry.word, () => {}).add(0));
    HapticFeedback.lightImpact();
    _showBubble(
        CharacterEmotion.thinking, const Duration(milliseconds: 2400));
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        backgroundColor: HurufTheme.surface,
        duration: const Duration(milliseconds: 1400),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HurufTheme.rButton),
        ),
      ));
  }

  void _goToNext() {
    final next = widget.allLevels
        .where((l) => l.id == widget.level.id + 1)
        .toList();
    if (next.isEmpty) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) =>
          GameScreen(level: next.first, allLevels: widget.allLevels),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final points = ref.watch(pointsProvider);
    final isLast = widget.level.id >= widget.allLevels.length;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // خلفية العالم مع تعتيم قوي للقراءة
          Image.asset(_world.background, fit: BoxFit.cover),
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
                          horizontal: HurufTheme.s4),
                      child: GlassCard(
                        child: WordGrid(
                          words: widget.level.words,
                          solvedWords: _solved,
                          revealedHints: _revealed,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 44, child: Center(child: _buildPreview())),
                  if (_lastDefinition != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: HurufTheme.s5),
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
                                onSelectionChanged: (p) =>
                                    setState(() => _preview = p),
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
                  reward: widget.level.completionReward,
                  bonusFound: _bonusFound.length,
                  isLastLevel: isLast,
                  onNext: _goToNext,
                  onMap: () => Navigator.of(context).pop(),
                  characterId: _world.guideId,
                  worldBonus: _isWorldFinale ? _world.completionReward : 0,
                  worldName: _world.nameAr,
                ),
            ],
          ),
        ),
        ],
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
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_forward_ios_rounded,
                color: HurufTheme.textSecondary, size: 20),
          ),
          Expanded(
            child: Text(
              'المرحلة ${widget.level.id}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShopScreen()),
            ),
            child: GlassCard(
              radius: HurufTheme.rButton,
              padding: const EdgeInsets.symmetric(
                horizontal: HurufTheme.s3,
                vertical: HurufTheme.s1,
              ),
              child: Row(
                children: [
                  const Text('💎', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: HurufTheme.s1),
                  Text(
                    '$points',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: HurufTheme.gold,
                    ),
                  ),
                  const SizedBox(width: HurufTheme.s1),
                  const Icon(Icons.add_circle_rounded,
                      size: 16, color: HurufTheme.gold),
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
        final dx = sin(_shake.value * pi * 6) * 10 * (1 - _shake.value);
        final flashing = _flash.isAnimating;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: _preview.isEmpty && !flashing
              ? const SizedBox.shrink()
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HurufTheme.s4,
                    vertical: HurufTheme.s1,
                  ),
                  decoration: BoxDecoration(
                    color: flashing
                        ? HurufTheme.error.withValues(alpha: 0.25)
                        : HurufTheme.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(HurufTheme.rButton),
                  ),
                  child: Text(
                    _preview,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color:
                          flashing ? HurufTheme.error : HurufTheme.gold,
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
          _HintButton(
            icon: Icons.lightbulb_outline_rounded,
            label: '$hintCost',
            onTap: _useRevealHint,
          ),
          const SizedBox(height: HurufTheme.s3),
          _HintButton(
            icon: Icons.looks_one_outlined,
            label: '$firstLetterCost',
            onTap: _useFirstLetterHint,
          ),
          const SizedBox(height: HurufTheme.s3),
          _HintButton(
            icon: Icons.shuffle_rounded,
            label: 'مجاني',
            onTap: () => _wheelKey.currentState?.shuffle(),
          ),
        ],
      ),
    );
  }
}

class _HintButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HintButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: HurufTheme.tileEmpty,
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
