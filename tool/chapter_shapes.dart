// شكل كلمات كل مرحلة: كم كلمة من كل طول.
//
// هذا الملف هو **مصدر الحقيقة** لمنحنى اللعبة. كان المولد يشتق الشكل
// من العجلة (يأخذ ما تصادف أن تكوّنه من كلمات) ثم يُعاد ترتيب المراحل
// بالصعوبة المحسوبة؛ صار الشكل مُعطى أولا والعجلة تُبحث لتناسبه.
//
// لكل فصل شكلُ بدايةٍ وشكلُ نهاية، وتُستنبط أشكال مراحله بينهما خطّيا
// ([shapesForChapter]). الفصل الأخير من العالم الثامن له شكل وسط أيضا
// لأن بدايته ونهايته متطابقتان: بلا نقطة وسطى يخرج الفصل كله مسطّحا.
//
// ملاحظة على المنحنى: بداية كل فصل أسهل من نهاية سابقه عمدا (تنفّس بعد
// الذروة). فليس المطلوب رتابة عامة عبر الـ500 مرحلة، بل مطابقة هذا
// الجدول — وهذا ما يفحصه test/levels_difficulty_curve_test.dart.

/// شكل مرحلة: طول الكلمة ← كم كلمة بهذا الطول
typedef WordShape = Map<int, int>;

class ChapterShape {
  final int worldId;

  /// ترتيب الفصل داخل عالمه (1..5)
  final int index;

  final WordShape start;
  final WordShape end;

  /// شكل منتصف الفصل — يُستعمل حين تتطابق [start] و[end]، وإلا فالفصل
  /// كله شكل واحد
  final WordShape? mid;

  const ChapterShape({
    required this.worldId,
    required this.index,
    required this.start,
    required this.end,
    this.mid,
  });

  /// معرّف الفصل عالميا (1..40) — نفس ترقيم ProgressionStructure
  int get id => (worldId - 1) * 5 + index;
}

const chapterShapes = <ChapterShape>[
  // ── العالم 1: الثلاثيات وحدها ──
  ChapterShape(worldId: 1, index: 1, start: {3: 1}, end: {3: 2}),
  ChapterShape(worldId: 1, index: 2, start: {3: 1}, end: {3: 3}),
  ChapterShape(worldId: 1, index: 3, start: {3: 2}, end: {3: 4}),
  ChapterShape(worldId: 1, index: 4, start: {3: 2}, end: {3: 2, 4: 1}),
  ChapterShape(worldId: 1, index: 5, start: {3: 3}, end: {3: 2, 4: 2}),

  // ── العالم 2: دخول الرباعيات ──
  ChapterShape(worldId: 2, index: 1, start: {3: 2}, end: {3: 2, 4: 1}),
  ChapterShape(worldId: 2, index: 2, start: {3: 2}, end: {3: 4}),
  ChapterShape(worldId: 2, index: 3, start: {3: 2, 4: 1}, end: {3: 3, 4: 1}),
  ChapterShape(worldId: 2, index: 4, start: {3: 2, 4: 1}, end: {3: 3, 4: 1}),
  ChapterShape(worldId: 2, index: 5, start: {3: 4}, end: {3: 2, 4: 2}),

  // ── العالم 3: الثلاثيات والرباعيات معا ──
  ChapterShape(worldId: 3, index: 1, start: {3: 3, 4: 1}, end: {3: 1, 4: 2}),
  ChapterShape(worldId: 3, index: 2, start: {3: 3, 4: 1}, end: {3: 3, 4: 2}),
  ChapterShape(worldId: 3, index: 3, start: {3: 2, 4: 1}, end: {3: 3, 4: 2}),
  ChapterShape(worldId: 3, index: 4, start: {3: 2, 4: 1}, end: {3: 3, 4: 2}),
  ChapterShape(worldId: 3, index: 5, start: {3: 2, 4: 1}, end: {3: 3, 4: 3}),

  // ── العالم 4: إتقان الثلاثي والرباعي بأعداد أكبر ──
  ChapterShape(worldId: 4, index: 1, start: {3: 3, 4: 1}, end: {3: 1, 4: 2}),
  ChapterShape(worldId: 4, index: 2, start: {3: 4, 4: 1}, end: {3: 4, 4: 2}),
  ChapterShape(worldId: 4, index: 3, start: {3: 4, 4: 1}, end: {3: 4, 4: 2}),
  ChapterShape(worldId: 4, index: 4, start: {3: 4, 4: 1}, end: {3: 4, 4: 2}),
  ChapterShape(worldId: 4, index: 5, start: {3: 4, 4: 2}, end: {3: 3, 4: 3}),

  // ── العالم 5: دخول الخماسيات ──
  ChapterShape(worldId: 5, index: 1, start: {3: 3, 4: 2}, end: {3: 2, 4: 3}),
  ChapterShape(
    worldId: 5,
    index: 2,
    start: {3: 2, 4: 3},
    end: {3: 2, 4: 2, 5: 1},
  ),
  ChapterShape(
    worldId: 5,
    index: 3,
    start: {3: 2, 4: 2, 5: 1},
    end: {3: 1, 4: 2, 5: 2},
  ),
  ChapterShape(
    worldId: 5,
    index: 4,
    start: {3: 1, 4: 2, 5: 2},
    end: {4: 1, 5: 3},
  ),
  ChapterShape(worldId: 5, index: 5, start: {4: 1, 5: 3}, end: {4: 1, 5: 4}),

  // ── العالم 6: دخول السداسيات ──
  ChapterShape(
    worldId: 6,
    index: 1,
    start: {3: 1, 4: 2, 5: 2},
    end: {4: 1, 5: 3},
  ),
  ChapterShape(
    worldId: 6,
    index: 2,
    start: {4: 1, 5: 3},
    end: {4: 1, 5: 2, 6: 1},
  ),
  ChapterShape(
    worldId: 6,
    index: 3,
    start: {4: 1, 5: 2, 6: 1},
    end: {4: 1, 5: 1, 6: 2},
  ),
  ChapterShape(
    worldId: 6,
    index: 4,
    start: {4: 1, 5: 1, 6: 2},
    end: {5: 1, 6: 3},
  ),
  ChapterShape(worldId: 6, index: 5, start: {5: 1, 6: 3}, end: {5: 1, 6: 4}),

  // ── العالم 7: دخول السباعيات ──
  ChapterShape(
    worldId: 7,
    index: 1,
    start: {4: 1, 5: 1, 6: 2},
    end: {5: 1, 6: 2, 7: 1},
  ),
  ChapterShape(
    worldId: 7,
    index: 2,
    start: {5: 1, 6: 2, 7: 1},
    end: {5: 1, 6: 1, 7: 2},
  ),
  ChapterShape(
    worldId: 7,
    index: 3,
    start: {5: 1, 6: 1, 7: 2},
    end: {5: 1, 6: 2, 7: 2},
  ),
  ChapterShape(
    worldId: 7,
    index: 4,
    start: {5: 1, 6: 2, 7: 2},
    end: {4: 1, 6: 1, 7: 3},
  ),
  ChapterShape(
    worldId: 7,
    index: 5,
    start: {4: 1, 6: 1, 7: 3},
    end: {4: 1, 6: 2, 7: 2},
  ),

  // ── العالم 8: الختام، من الرباعي إلى الثماني ──
  ChapterShape(
    worldId: 8,
    index: 1,
    start: {5: 1, 6: 2, 7: 1},
    end: {5: 1, 6: 1, 7: 2},
  ),
  ChapterShape(
    worldId: 8,
    index: 2,
    start: {5: 1, 6: 1, 7: 2},
    end: {4: 1, 6: 1, 7: 2, 8: 1},
  ),
  ChapterShape(
    worldId: 8,
    index: 3,
    start: {4: 1, 6: 1, 7: 2, 8: 1},
    end: {4: 1, 5: 1, 7: 2, 8: 1},
  ),
  ChapterShape(
    worldId: 8,
    index: 4,
    start: {4: 1, 5: 1, 7: 2, 8: 1},
    end: {4: 1, 6: 1, 7: 1, 8: 2},
  ),
  ChapterShape(
    worldId: 8,
    index: 5,
    start: {4: 1, 5: 1, 6: 1, 7: 1, 8: 1},
    mid: {4: 1, 6: 1, 7: 2, 8: 1},
    end: {4: 1, 5: 1, 6: 1, 7: 1, 8: 1},
  ),
];

final chapterShapeById = {for (final s in chapterShapes) s.id: s};

/// أشكال مراحل الفصل بالترتيب، [stageCount] مرحلة.
///
/// استيفاء خطّي لكل طول على حدة: المرحلة الأولى تطابق [ChapterShape.start]
/// والأخيرة تطابق [ChapterShape.end] بالضبط، وما بينهما يتدرّج. التقريب
/// `round` لا `floor` كي تقع نقطة التحوّل في منتصف الفصل لا في آخره.
///
/// وجود [ChapterShape.mid] يقسم الفصل نصفين: بداية←وسط ثم وسط←نهاية.
List<WordShape> shapesForChapter(ChapterShape chapter, int stageCount) {
  final mid = chapter.mid;
  if (mid == null) {
    return _interpolate(chapter.start, chapter.end, stageCount);
  }
  final firstHalf = (stageCount / 2).ceil();
  return [
    ..._interpolate(chapter.start, mid, firstHalf),
    ..._interpolate(mid, chapter.end, stageCount - firstHalf),
  ];
}

List<WordShape> _interpolate(WordShape from, WordShape to, int steps) {
  if (steps <= 0) return const [];
  if (steps == 1) return [Map.of(to)];

  final lengths = {...from.keys, ...to.keys}.toList()..sort();
  return [
    for (var i = 0; i < steps; i++)
      {
        for (final len in lengths)
          if (_countAt(from, to, len, i, steps) > 0)
            len: _countAt(from, to, len, i, steps),
      },
  ];
}

int _countAt(WordShape from, WordShape to, int len, int i, int steps) {
  final a = from[len] ?? 0;
  final b = to[len] ?? 0;
  return (a + (b - a) * i / (steps - 1)).round();
}

/// مجموع كلمات الشكل
int shapeWordCount(WordShape shape) =>
    shape.values.fold(0, (a, b) => a + b);

/// أطول كلمة في الشكل — تحدّد حجم العجلة المطلوب
int shapeMaxLength(WordShape shape) =>
    shape.keys.fold(0, (a, b) => a > b ? a : b);

/// نص مختصر للعرض في التقارير والرسائل: «3×3 + 1×4»
String shapeLabel(WordShape shape) => (shape.keys.toList()..sort())
    .map((len) => '${shape[len]}×$len')
    .join(' + ');
