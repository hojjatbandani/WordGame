import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import 'glass_card.dart';
import 'letter_wheel.dart';
import 'pressable.dart';
import 'word_grid.dart';

/// لوحة اللعب المشتركة (شبكة الكلمات + المعاينة + عجلة الحروف).
///
/// لوح لعب مشترك بين الشاشات كي تبقى تجربة اللعب
/// مطابقة تماما للمراحل العادية بدل تكرار التخطيط في كل شاشة.
/// الحالة (المحلولة، التلميحات) يملكها الأب؛ هذه الودجة تدير المعاينة
/// والخلط فقط.
class PuzzlePlayField extends StatefulWidget {
  final List<String> letters;
  final List<WordEntry> words;
  final Set<String> solvedWords;
  final Map<String, Set<int>> revealedHints;
  final void Function(String word) onWordSubmitted;

  /// عند تمرير null يُخفى زر التلميح (كما في غرف التحدي الثنائي حيث
  /// التكافؤ بين اللاعبين مقصود)
  final VoidCallback? onHintRequested;

  /// كلفة التلميح بالعملات، أو 0 حين لا يكلّف عملات أصلا (النزال:
  /// كلفته خصم من نتيجة النزال لا من الرصيد). إلزامي لا افتراضي:
  /// افتراضُ 25 كان يطبع سعرا كاذبا على زرّ النزال المجاني.
  final int hintCost;

  /// لغة عناوين الأزرار وأوصافها الصوتية. ساحة الحروف نفسها عربية دوما،
  /// أما الأزرار حولها فتتبع لغة الشاشة المضيفة (الواجهة ثنائية
  /// اللغة) — كانت عربية مثبّتة وسط شاشة إنجليزية.
  final AppLanguage lang;

  const PuzzlePlayField({
    super.key,
    required this.letters,
    required this.words,
    required this.solvedWords,
    required this.revealedHints,
    required this.onWordSubmitted,
    this.onHintRequested,
    required this.hintCost,
    this.lang = AppLanguage.ar,
  });

  @override
  State<PuzzlePlayField> createState() => _PuzzlePlayFieldState();
}

class _PuzzlePlayFieldState extends State<PuzzlePlayField> {
  String _preview = '';
  final GlobalKey<LetterWheelState> _wheelKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: HurufTheme.s4),
            child: GlassCard(
              child: WordGrid(
                words: widget.words,
                solvedWords: widget.solvedWords,
                revealedHints: widget.revealedHints,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: Center(
            child: _preview.isEmpty
                ? const SizedBox.shrink()
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HurufTheme.s4,
                      vertical: HurufTheme.s1,
                    ),
                    decoration: BoxDecoration(
                      color: HurufTheme.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(HurufTheme.rButton),
                    ),
                    child: Text(
                      _preview,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: HurufTheme.gold,
                      ),
                    ),
                  ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(HurufTheme.s3),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.onHintRequested != null) ...[
                        _RoundAction(
                          icon: Icons.lightbulb_outline_rounded,
                          label: widget.hintCost > 0
                              ? '${widget.hintCost}'
                              : widget.lang.t('مجاني', 'Free'),
                          semanticLabel: widget.hintCost > 0
                              ? widget.lang.t(
                                  'كشف حرف مقابل ${widget.hintCost} نقطة',
                                  'Reveal a letter for ${widget.hintCost} points',
                                )
                              : widget.lang.t(
                                  'كشف حرف، مجاني',
                                  'Reveal a letter, free',
                                ),
                          onTap: widget.onHintRequested!,
                        ),
                        const SizedBox(height: HurufTheme.s3),
                      ],
                      _RoundAction(
                        icon: Icons.shuffle_rounded,
                        label: widget.lang.t('مجاني', 'Free'),
                        semanticLabel: widget.lang.t(
                          'خلط الحروف، مجاني',
                          'Shuffle letters, free',
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
                      letters: widget.letters,
                      onWordSubmitted: (w) {
                        setState(() => _preview = '');
                        widget.onWordSubmitted(w);
                      },
                      onSelectionChanged: (p) => setState(() => _preview = p),
                    ),
                  ),
                ),
                const SizedBox(width: 44),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  const _RoundAction({
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
