// إتمام فصل يجب أن يكون حدثا مرئيا: اللاعب يعود إلى قائمة فصول عالمه
// ويرى تهنئة المرشد بجملة خليجية، لا أن ينزلق من المرحلة 12 إلى 13 بلا
// أي علامة على أنه عبر حدّ فصل.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression/chapter_celebration.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/chapter_select_screen.dart';
import 'package:huruf/presentation/widgets/chapter_chest_widget.dart';
import 'package:huruf/presentation/widgets/chapter_complete_celebration.dart';
import 'package:huruf/presentation/widgets/video_animation.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app({int? celebrateChapterId}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = ProgressStore(prefs);
  final progression = await ProgressionRepository.load(
    prefs: prefs,
    legacy: store,
  );
  return ProviderScope(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      progressionRepositoryProvider.overrideWithValue(progression),
    ],
    child: MaterialApp(
      theme: HurufTheme.build(),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: ChapterSelectScreen(
        worldId: 1,
        celebrateChapterId: celebrateChapterId,
      ),
    ),
  );
}

void main() {
  setUpAll(() => AudioService.disabled = true);

  test('جملة كل فصل ثابتة لا عشوائية — نفس الفصل ينطق نفس الجملة', () {
    for (var chapterId = 1; chapterId <= 40; chapterId++) {
      expect(
        chapterCelebrationLineFor(chapterId).ar,
        chapterCelebrationLineFor(chapterId).ar,
      );
      expect(chapterCelebrationLineFor(chapterId).ar, isNotEmpty);
      expect(chapterCelebrationLineFor(chapterId).en, isNotEmpty);
    }
  });

  testWidgets('قائمة الفصول بلا تهنئة حين لا فصل أُكمل للتوّ', (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    expect(find.byType(ChapterCompleteCelebration), findsNothing);
  });

  testWidgets('بعد إتمام الفصل الأول: تهنئة بجملة الفصل وزرّ الفصل التالي',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app(celebrateChapterId: 1));
    await tester.pumpAndSettle();

    expect(find.byType(ChapterCompleteCelebration), findsOneWidget);
    expect(
      find.text(chapterCelebrationLineFor(1).ar),
      findsOneWidget,
      reason: 'الجملة الخليجية نفسها يجب أن تظهر، لا نص عام',
    );
    expect(find.text('الفصل التالي'), findsOneWidget);

    // صندوق الجائزة الكبير وسط الشاشة — لا أيقونة صغيرة في زاوية
    final reveal = find.byWidgetPredicate(
      (w) => w is VideoAnimationWidget && w.assetPath == kChestAnimationAsset,
    );
    expect(reveal, findsOneWidget);
    final revealSize = tester.getSize(reveal);
    expect(
      revealSize.shortestSide,
      greaterThan(160),
      reason: 'الجائزة يجب أن تكون أكبر عنصر على الشاشة، لا شارة صغيرة',
    );
    final screen = tester.getSize(find.byType(ChapterCompleteCelebration));
    final revealCenter = tester.getCenter(reveal);
    expect(
      (revealCenter.dx - screen.width / 2).abs(),
      lessThan(2),
      reason: 'وسط الشاشة أفقيا',
    );
    expect(revealCenter.dy, lessThan(screen.height * 0.66));

    // "أشوف الخريطة" تُغلق التهنئة وتُبقي اللاعب على قائمة الفصول
    await tester.tap(find.text('أشوف الخريطة'));
    await tester.pumpAndSettle();
    expect(find.byType(ChapterCompleteCelebration), findsNothing);
    expect(find.byType(ChapterSelectScreen), findsOneWidget);
  });

  testWidgets('آخر فصل في العالم: المتابعة تقول "العالم التالي" لا "الفصل"',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // الفصل 5 هو آخر فصول العالم الأول
    await tester.pumpWidget(await _app(celebrateChapterId: 5));
    await tester.pumpAndSettle();

    expect(find.byType(ChapterCompleteCelebration), findsOneWidget);
    expect(find.text('الفصل التالي'), findsNothing);
    expect(find.text('العالم التالي'), findsOneWidget);
    expect(find.text('أشوف الخريطة'), findsOneWidget);
  });
}
