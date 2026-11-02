import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/chapter_select_screen.dart';
import 'package:huruf/presentation/screens/world_unlock_ceremony_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ProgressStore, ProgressionRepository)> _repo() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = ProgressStore(prefs);
  final progression =
      await ProgressionRepository.load(prefs: prefs, legacy: store);
  return (store, progression);
}

Widget _ceremonyApp(ProgressStore store, ProgressionRepository progression) {
  return ProviderScope(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      progressionRepositoryProvider.overrideWithValue(progression),
    ],
    child: MaterialApp(
      theme: HurufTheme.build(),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const WorldUnlockCeremonyScreen(worldId: 2),
    ),
  );
}

void main() {
  setUpAll(() => AudioService.disabled = true);

  testWidgets(
      'اختبار قبول 5: اللمس قبل 1.5 ثانية لا يفعل شيئا، وبعدها يتخطّى '
      'ويسجّل عرض المراسم مرة واحدة', (tester) async {
    final (store, progression) = await _repo();
    await tester.pumpWidget(_ceremonyApp(store, progression));
    await tester.pump();

    // قبل 1.5 ثانية: اللمس لا يُغلق المراسم ولا يُسجّل عرضها
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(find.byType(WorldUnlockCeremonyScreen), findsOneWidget,
        reason: 'يجب ألا يُغلق قبل انتهاء مهلة 1.5 ثانية');
    expect(find.byType(ChapterSelectScreen), findsNothing);
    expect(progression.state.ceremonyShownForWorldIds.contains(2), isFalse,
        reason: 'لا يُسجَّل عرض المراسم قبل إغلاقها فعليا');

    // بعد تجاوز 1.5 ثانية إجمالا: اللمس يُغلق فورا
    await tester.pump(const Duration(milliseconds: 900)); // مجموع 1600مث
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ChapterSelectScreen), findsOneWidget,
        reason: 'اللمس بعد 1.5 ثانية يجب أن يتخطّى إلى شاشة اختيار الفصل');
    expect(progression.state.ceremonyShownForWorldIds.contains(2), isTrue,
        reason: 'يجب أن يُسجَّل عرض مراسم العالم2 عند التخطي');
  });

  testWidgets(
      'اختبار قبول 5: تُغلَق المراسم تلقائيا خلال نافذة 4-6 ثوان بلا أي '
      'لمس، وتُسجَّل مرة واحدة', (tester) async {
    final (store, progression) = await _repo();
    await tester.pumpWidget(_ceremonyApp(store, progression));
    await tester.pump();

    expect(progression.state.ceremonyShownForWorldIds.contains(2), isFalse);

    // بلا أي لمس إطلاقا — فقط تقدّم الزمن حتى تكتمل المدة الكلية
    // (5200مث، ضمن نافذة 4-6 ثوان المشترطة) ثم إطاران إضافيان للسماح
    // لـ_dismiss (async: markCeremonyShown ثم التنقّل) بإتمام عمله
    await tester.pump(const Duration(milliseconds: 5300));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ChapterSelectScreen), findsOneWidget,
        reason: 'يجب أن تُغلَق المراسم تلقائيا دون أي تدخّل من اللاعب');
    expect(progression.state.ceremonyShownForWorldIds.contains(2), isTrue,
        reason: 'يُسجَّل عرض المراسم عند الإغلاق التلقائي أيضا');
  });
}
