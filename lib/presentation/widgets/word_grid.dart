import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';

/// ترتيب الكلمات كما يراها اللاعب على اللوح: الأقصر أولا، وعند تساوي
/// الطول يبقى ترتيب levels.json.
///
/// مُصدَّرة عمدا لا محصورة داخل [WordGrid.build]: «أول كلمة» عند اللاعب
/// هي أول صف على اللوح، لا أول عنصر في الملف. التلميح المرتّب كان يبدأ
/// من `level.words.first` بينما اللوح يعرض مرتّبا بالطول، فكان الحرف
/// يظهر في صف عشوائي — غالبا أسفل اللوح، فبدا وكأن التلميح يبدأ من آخر
/// كلمة. أي شيء يتكلّم عن «الكلمة الأولى» يجب أن يمرّ من هنا.
///
/// الترتيب كامل (طول ثم موضع أصلي) لا جزئي: `List.sort` في دارت غير
/// مستقرّ، فبلا فاصل التعادل قد يختلف صفّان متساويا الطول بين نداءين.
List<WordEntry> wordsInBoardOrder(List<WordEntry> words) {
  final indexed = [for (var i = 0; i < words.length; i++) (i, words[i])];
  indexed.sort((a, b) {
    final byLength = a.$2.word.length.compareTo(b.$2.word.length);
    return byLength != 0 ? byLength : a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexed) entry.$2];
}

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

  // أصغر مقاس مقروء للخانة، وأكبر مقاس نسمح به
  static const double _minTile = 30;
  static const double _maxTile = 52;
  // كل خانة تحمل هامشا s1 من كل جهة (من _LetterTile)، فارتفاع الصف الفعلي = tile + 2*s1
  static const double _tileMargin = HurufTheme.s1 * 2;

  @override
  Widget build(BuildContext context) {
    final sorted = wordsInBoardOrder(words);
    final rowCount = sorted.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxLen = sorted.map((w) => w.word.length).reduce(max);

        // نحسب المقاس بالاعتماد على العرض (عدد حروف أطول كلمة) وعلى
        // الارتفاع (عدد الكلمات) معا، لا على العرض وحده كما كان سابقا —
        // فمرحلة بست كلمات كانت تفيض عموديا وتُخفي الصفوف السفلية
        final tileFromWidth =
            (constraints.maxWidth - HurufTheme.s4) / maxLen - _tileMargin;
        final tileFromHeight = rowCount > 0
            ? constraints.maxHeight / rowCount - _tileMargin
            : _maxTile;
        final tile = [
          tileFromWidth,
          tileFromHeight,
          _maxTile,
        ].reduce(min).clamp(_minTile, _maxTile);

        final grid = Column(
          mainAxisSize: MainAxisSize.min,
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
                        revealed:
                            solvedWords.contains(entry.word) ||
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

        // قابلة للتمرير دائما (لا فقط حين يتوقع الحساب أعلاه فيضانا) —
        // فلو أخطأ التقدير أو تغيّرت المساحة المتاحة لأي سبب (شريط علوي
        // إضافي، اختلاف تخطيط بين شاشة وأخرى...) يبقى المستخدم قادرا على
        // رؤية كل الكلمات بالتمرير بدل أن تُقصّ صفوفها بصمت داخل البطاقة
        return ScrollbarTheme(
          data: ScrollbarThemeData(
            thumbColor: WidgetStatePropertyAll(
              HurufTheme.gold.withValues(alpha: 0.6),
            ),
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: HurufTheme.s2),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(child: grid),
              ),
            ),
          ),
        );
      },
    );
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
