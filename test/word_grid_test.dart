import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/models.dart';
import 'package:huruf/presentation/widgets/word_grid.dart';

Widget _wrap(Widget child, {required Size size}) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    );

/// مرحلة الذروة الفعلية: 6 كلمات (كما في مرحلة "مدارس" الأخيرة)
final _sixWords = const [
  WordEntry(word: 'مدارس', definition: ''),
  WordEntry(word: 'مدرس', definition: ''),
  WordEntry(word: 'مدار', definition: ''),
  WordEntry(word: 'درس', definition: ''),
  WordEntry(word: 'دار', definition: ''),
  WordEntry(word: 'سرد', definition: ''),
];

/// أقصى ما يولّده tool/generate_levels.dart حاليا: 8 كلمات حتى 10 حروف
/// (مثل ألغاز مخزون التحدي اليومي والتحدي الثنائي)
final _eightWords = const [
  WordEntry(word: 'اسم', definition: ''),
  WordEntry(word: 'قلم', definition: ''),
  WordEntry(word: 'كتب', definition: ''),
  WordEntry(word: 'كتاب', definition: ''),
  WordEntry(word: 'مكتب', definition: ''),
  WordEntry(word: 'مكاتب', definition: ''),
  WordEntry(word: 'استقبال', definition: ''),
  WordEntry(word: 'استقبالات', definition: ''),
];

void main() {
  testWidgets(
      'renders all letters of an 8-word puzzle in an AppBar-shrunk viewport',
      (tester) async {
    // يحاكي شاشة فيها AppBar فوق البطاقة (كالتحدي اليومي والتحدي الثنائي)
    // فتقل المساحة العمودية المتاحة للشبكة عمّا هو متاح في شاشة المرحلة
    await tester.pumpWidget(_wrap(
      WordGrid(
        words: _eightWords,
        solvedWords: const {},
        revealedHints: const {},
      ),
      size: const Size(360, 260),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final totalLetters =
        _eightWords.fold<int>(0, (sum, w) => sum + w.word.length);
    expect(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_LetterTile'),
        findsNWidgets(totalLetters));
  });

  testWidgets('renders every letter of every word even in a short box',
      (tester) async {
    // مساحة عمودية ضيّقة تحاكي ما يظهر فعليا في المراحل المتأخرة
    await tester.pumpWidget(_wrap(
      WordGrid(
        words: _sixWords,
        solvedWords: const {},
        revealedHints: const {},
      ),
      size: const Size(360, 220),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull); // لا فيضان تخطيط (overflow)

    final totalLetters =
        _sixWords.fold<int>(0, (sum, w) => sum + w.word.length);
    // كل الخانات موجودة في الشجرة (داخل تمرير إن لزم) وليست محذوفة
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_LetterTile'),
        findsNWidgets(totalLetters));
  });

  testWidgets('falls back to a scrollable view when content cannot fit',
      (tester) async {
    await tester.pumpWidget(_wrap(
      WordGrid(
        words: _sixWords,
        solvedWords: const {},
        revealedHints: const {},
      ),
      // ارتفاع أقل من الحد الأدنى الذي تتطلبه 6 صفوف حتى بأصغر مقاس خانة
      size: const Size(360, 120),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets(
      'stays centered and at rest (no scroll needed) when content fits',
      (tester) async {
    await tester.pumpWidget(_wrap(
      WordGrid(
        words: const [WordEntry(word: 'قلم', definition: '')],
        solvedWords: const {},
        revealedHints: const {},
      ),
      size: const Size(360, 400),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // الشبكة قابلة للتمرير دائما كشبكة أمان، لكن حين يتّسع المحتوى فعلا
    // يبقى مجال التمرير ضئيلا جدا (مجرد حشو الشبكة الرأسي) لا صفحة كاملة
    final position =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.maxScrollExtent, lessThan(20));
  });
}
