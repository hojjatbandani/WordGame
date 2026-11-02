// جُمل تهنئة إتمام الفصل — خليجية عامية عمدا (لا فصحى): هذه لحظة
// احتفال يقولها مرشد العالم بصوته، والفصحى فيها تبدو نشرة أخبار لا
// تشجيعا. منطق صرف بلا أي استيراد Flutter كي تُختبر مباشرة.
//
// الاختيار حتمي بمعرّف الفصل (لا Random): نفس الفصل يعطي نفس الجملة في
// كل عرض، فلا تتبدّل الجملة تحت عين اللاعب مع كل إعادة رسم للودجة.

class ChapterCelebrationLine {
  /// خليجي عامّي
  final String ar;
  final String en;

  const ChapterCelebrationLine(this.ar, this.en);
}

const chapterCelebrationLines = <ChapterCelebrationLine>[
  ChapterCelebrationLine(
    'عفيّة عليك! خلّصت الفصل كامل 👏',
    'Nicely done! A whole chapter finished 👏',
  ),
  ChapterCelebrationLine(
    'ما شاء الله عليك، ما وقفت لين خلّصت!',
    'You did not stop until it was done!',
  ),
  ChapterCelebrationLine(
    'يا بطل! والفصل الياي بعد بينهزم منك',
    'Champion! The next chapter does not stand a chance',
  ),
  ChapterCelebrationLine(
    'حيّاك الله، تراك ماشي زين وسريع!',
    'You are moving fast and moving well!',
  ),
  ChapterCelebrationLine(
    'الله يعطيك العافية، فصل كامل بجيبك!',
    'A full chapter in the bag. Well played!',
  ),
  ChapterCelebrationLine(
    'كفو والله! حروفك ما تغلط',
    'Outstanding! Your letters never miss',
  ),
];

/// جملة ثابتة لكل [chapterId] — لا عشوائية، فالعرض يتكرّر بنفس الجملة
ChapterCelebrationLine chapterCelebrationLineFor(int chapterId) =>
    chapterCelebrationLines[chapterId.abs() % chapterCelebrationLines.length];
