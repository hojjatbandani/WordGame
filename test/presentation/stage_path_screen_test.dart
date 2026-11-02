import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression/stage_progress.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/stage_path_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => AudioService.disabled = true);

  testWidgets(
      'اختبار قبول 2: فتح مسار المراحل يمرّر تلقائيا كي تظهر العقدتان '
      'السابقتان والعقدة الحالية والثلاث التالية معا',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // حالة "منتصف الفصل1": المراحل 1..5 مكتملة (نجمة1 لكل منها)، والمرحلة
    // الحالية 6 — عقدة ليست أول عقدة ولا آخر عقدة في الفصل (12 مرحلة)،
    // كي تُختبر إعادة التموضع الفعلية لا حالة حدّية عند طرفَي المسار
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = ProgressStore(prefs);
    final progression =
        await ProgressionRepository.load(prefs: prefs, legacy: store);
    final progress = <int, StageProgress>{
      for (var id = 1; id <= 5; id++)
        id: StageProgress(
          stageId: id,
          completed: true,
          bestTimeMs: null,
          hintsUsedBest: null,
          bonusWordsFound: const {},
          attempts: 1,
          lastPlayedAt: null,
        ),
    };
    progression.replaceState(
        progression.state.copyWith(currentStageId: 6), progress);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressStoreProvider.overrideWithValue(store),
          progressionRepositoryProvider.overrideWithValue(progression),
        ],
        child: MaterialApp(
          theme: HurufTheme.build(),
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: const StagePathScreen(chapterId: 1),
        ),
      ),
    );
    // لا pumpAndSettle هنا: عقدة "الحالية" تُشغّل نبضة (AnimationController)
    // متكرّرة للأبد (repeat(reverse: true))، فتنتظر pumpAndSettle إلى ما لا
    // نهاية. إطاران يكفيان: الأول يبني LayoutBuilder ويحسب النقاط، والثاني
    // يطبّق jumpTo المجدولة عبر addPostFrameCallback بعد أول تخطيط فعلي
    await tester.pump();
    await tester.pump();

    final viewport = tester.getRect(find.byType(SingleChildScrollView));

    bool centerWithinViewport(int stageId) {
      final rect = tester.getRect(find.byKey(ValueKey('stage_node_$stageId')));
      final centerY = rect.top + rect.height / 2;
      return centerY >= viewport.top && centerY <= viewport.bottom;
    }

    // العقدتان السابقتان (4، 5) + الحالية (6) + الثلاث التاليتان (7، 8، 9)
    // يجب أن تكون كلها ظاهرة فعلا داخل حدود منطقة التمرير المرئية فور
    // الفتح، بلا أي تمرير يدوي من اللاعب
    for (final stageId in [4, 5, 6, 7, 8, 9]) {
      expect(centerWithinViewport(stageId), isTrue,
          reason: 'المرحلة $stageId يجب أن تكون ظاهرة عند فتح المسار');
    }

    // ضمان أن تمريرا فعليا حدث (لا مجرد صدفة عرض الفصل كله في الشاشة):
    // أول مرحلة (1) وآخر مرحلة (12) في هذا الفصل يجب أن تكونا خارج
    // النطاق المرئي، بعيدتين بما يكفي عن نافذة الست عقد حول الحالية
    expect(centerWithinViewport(1), isFalse,
        reason: 'المرحلة 1 بعيدة عن النافذة الحالية ويجب ألا تظهر');
    expect(centerWithinViewport(12), isFalse,
        reason: 'المرحلة 12 بعيدة عن النافذة الحالية ويجب ألا تظهر');
  });
}
