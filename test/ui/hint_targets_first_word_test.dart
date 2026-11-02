// التلميح المرتّب كان يبدأ من `level.words.first` — أول كلمة في
// levels.json — بينما اللوح يعرض الكلمات مرتّبة بالطول. فحين يكون أول
// عنصر في الملف هو الأطول، يظهر الحرف المكشوف في آخر صف على الشاشة،
// وهو ما يراه اللاعب: «التلميح يبدأ من آخر كلمة».
//
// الإصلاح: مصدر ترتيب واحد (`wordsInBoardOrder`) يستعمله اللوح
// والتلميح معا. هذا الاختبار يمنع افتراقهما ثانية.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/models.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/game_screen.dart';
import 'package:huruf/presentation/widgets/word_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// الكلمة الأطول أولا في الملف عمدا — الترتيب الذي كان يكشف العيب:
/// اللوح يعرض «ملح» في الصف الأول، والملف يضع «مسجد» أولا
const _level = GameLevel(
  id: 1,
  letters: ['م', 'س', 'ج', 'د', 'ل', 'ح'],
  words: [
    WordEntry(word: 'مسجد', definition: 'بيت الصلاة'),
    WordEntry(word: 'ملح', definition: 'ما يطيب به الطعام'),
    WordEntry(word: 'سجد', definition: 'خرّ ساجدا'),
  ],
  bonusWords: [],
  difficulty: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AudioService.disabled = true;

  test('ترتيب اللوح: الأقصر أولا، والتعادل بترتيب الملف', () {
    final ordered = wordsInBoardOrder(_level.words).map((w) => w.word).toList();
    expect(ordered, ['ملح', 'سجد', 'مسجد']);
    expect(
      ordered.first,
      isNot(_level.words.first.word),
      reason: 'وإلا فالمرحلة لا تفحص العيب أصلا',
    );

    // الترتيب حتميّ: النداء مرتين يعطي النتيجة نفسها (فاصل التعادل
    // بالموضع الأصلي، لأن List.sort في دارت غير مستقرّ)
    expect(wordsInBoardOrder(_level.words).map((w) => w.word), ordered);
  });

  testWidgets('التلميح المرتّب يكشف حرفا من كلمة الصف الأول لا من آخر صف', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'player_name_asked': true});
    final store = ProgressStore(await SharedPreferences.getInstance());
    final container = ProviderContainer(
      overrides: [
        progressStoreProvider.overrideWithValue(store),
        levelsProvider.overrideWith((ref) => const [_level]),
      ],
    );
    addTearDown(container.dispose);
    // رصيد يكفي التلميح
    container.read(pointsProvider.notifier).add(500, reason: 'test');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const GameScreen(level: _level, allLevels: [_level]),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 4)); // فقاعة المرشد

    // زر «كشف الحرف التالي بالترتيب»
    await tester.tap(find.byIcon(Icons.lightbulb_outline_rounded));
    await tester.pumpAndSettle();

    // نقرأ حالة اللوح نفسها لا النصّ المرسوم: عجلة الحروف تعرض الحروف
    // مفردة أيضا، فعدّ الأحرف على الشاشة يخلط بينها وبين اللوح
    final grid = tester.widget<WordGrid>(find.byType(WordGrid));
    expect(
      grid.revealedHints,
      {
        'ملح': {0},
      },
      reason:
          'الكشف يقع على «ملح» (الصف الأول على اللوح) في موضعها الأول — '
          'لا على «مسجد» أول عنصر في levels.json',
    );

    // ضغطة ثانية تتقدّم حرفا داخل الكلمة نفسها لا تقفز إلى كلمة أخرى
    await tester.tap(find.byIcon(Icons.lightbulb_outline_rounded));
    await tester.pumpAndSettle();
    expect(tester.widget<WordGrid>(find.byType(WordGrid)).revealedHints, {
      'ملح': {0, 1},
    });

    // تصريف فقاعة المرشد المؤجّلة (2.4 ثانية) وإلا فشل الاختبار
    // بـ"A Timer is still pending" بعد نجاح كل تحقّقاته
    await tester.pump(const Duration(seconds: 3));
  });
}
