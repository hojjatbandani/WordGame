import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';

/// شبكة الكلمات: صف من الخانات لكل كلمة، تنقلب الحروف عند الحل
class WordGrid extends StatelessWidget {
  final List<WordEntry> words;
  final Set<String> solvedWords;
  final Map<String, Set<int>> revealedHints;

  const WordGrid({
    super.key,
    required this.words,
    required this.solvedWords,
    required this.revealedHints,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List.of(words)
      ..sort((a, b) => a.word.length.compareTo(b.word.length));
    return LayoutBuilder(builder: (context, constraints) {
      final maxLen = sorted.map((w) => w.word.length).reduce(max);
      final tile = min(52.0, (constraints.maxWidth - 16) / maxLen - 8);
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final entry in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: HurufTheme.s1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                textDirection: TextDirection.rtl,
                children: [
                  for (var i = 0; i < entry.word.length; i++)
                    _LetterTile(
                      letter: entry.word[i],
                      revealed: solvedWords.contains(entry.word) ||
                          (revealedHints[entry.word]?.contains(i) ?? false),
                      solved: solvedWords.contains(entry.word),
                      delayMs: i * 90,
                      size: tile,
                    ),
                ],
              ),
            ),
        ],
      );
    });
  }
}

class _LetterTile extends StatefulWidget {
  final String letter;
  final bool revealed;
  final bool solved;
  final int delayMs;
  final double size;

  const _LetterTile({
    required this.letter,
    required this.revealed,
    required this.solved,
    required this.delayMs,
    required this.size,
  });

  @override
  State<_LetterTile> createState() => _LetterTileState();
}

class _LetterTileState extends State<_LetterTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    if (widget.revealed) _flip.value = 1;
  }

  @override
  void didUpdateWidget(covariant _LetterTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revealed && !oldWidget.revealed) {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _flip.forward();
      });
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flip,
      builder: (context, _) {
        final t = Curves.easeInOutBack.transform(_flip.value);
        final showFace = t > 0.5;
        final angle = t * pi;
        return Container(
          margin: const EdgeInsets.all(HurufTheme.s1),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(angle),
            child: Container(
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(HurufTheme.rTile),
                gradient: showFace && widget.solved
                    ? HurufTheme.goldGradient
                    : null,
                color: showFace && widget.solved
                    ? null
                    : showFace
                        ? HurufTheme.tileEmpty
                        : HurufTheme.tileEmpty.withValues(alpha: 0.65),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                boxShadow: showFace && widget.solved
                    ? [
                        BoxShadow(
                          color: HurufTheme.gold.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: showFace
                  ? Transform(
                      // عكس الانقلاب حتى لا يظهر الحرف معكوسا
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(pi),
                      child: Text(
                        widget.letter,
                        style: TextStyle(
                          fontSize: widget.size * 0.55,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: widget.solved
                              ? HurufTheme.bgTop
                              : HurufTheme.gold,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}
