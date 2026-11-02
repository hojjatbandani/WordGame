import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/world_select_screen.dart';
import 'package:huruf/presentation/widgets/video_animation.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app() async {
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
      home: const WorldSelectScreen(),
    ),
  );
}

void main() {
  setUpAll(() => AudioService.disabled = true);

  testWidgets('اختبار قبول 1: كل الثمانية عوالم ظاهرة على تثبيت جديد، والعالم1 '
      'فقط قابل للدخول', (tester) async {
    // شاشة طويلة عمدا: القائمة صارت عمودا واحدا كسولا، فعلى ارتفاع
    // هاتف حقيقي تُبنى أربع بطاقات لا ثمان. هنا نريد قياس «كل العوالم
    // موجودة» لا «كم يظهر منها»، فنعطيها ارتفاعا يسع الثمانية.
    tester.view.physicalSize = const Size(720, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    // كل عالم مقفل يعرض أيقونة قفل مميّزة؛ العالم1 وحده بلا قفل.
    // نتحقق بعدد أيقونات القفل بدل نص الاسم (الأسماء مترجمة ولا نريد
    // اختبارا هشّا مرتبطا بصياغة نص بعينها)
    expect(find.byType(GestureDetector), findsWidgets);
    expect(
      find.byIcon(Icons.lock_rounded),
      findsNWidgets(7),
      reason: '7 عوالم مقفلة (2..8)، عالم1 وحده بلا قفل',
    );
  });

  testWidgets(
    'العمود الواحد يُظهر ثلاثة عوالم كاملة ورابعا مقتطعا — إشارة أن تحته مزيد',
    (tester) async {
      // أقصر شاشة ندعمها فعليا (360×640 منطقية)
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(await _app());
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      final viewport = tester.getRect(scrollable);
      final cards = find.byType(CharacterPortrait);

      // البطاقة الرابعة يجب أن تكون مبنيّة (أي دخلت النافذة) لكن قاعدتها
      // خارجها: هذا بالضبط «الاقتطاع» الذي يخبر اللاعب أن يمرّر
      expect(
        cards.evaluate().length,
        greaterThanOrEqualTo(4),
        reason: 'ثلاث بطاقات كاملة على الأقل ورابعة تبدأ في الظهور',
      );
      final fourth = tester.getRect(cards.at(3));
      expect(
        fourth.top,
        lessThan(viewport.bottom),
        reason: 'الرابعة بدأت داخل النافذة',
      );

      // وأن القائمة قابلة للتمرير فعلا حتى العالم الثامن
      await tester.drag(scrollable, const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    },
  );

  testWidgets('اختبار قبول 3: لمس عالم مقفل يعرض شرط الفتح الدقيق، لا '
      'تنبيها عاما مبهما', (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    // نلمس بطاقة العالم الثاني (ثاني GestureDetector قابل للّمس فعليا —
    // نستهدف عبر Opacity المميِّزة لبطاقات العوالم المقفلة بدل الاعتماد
    // على ترتيب هش؛ الأبسط: نجد كل أيقونات القفل ونلمس أب أول واحدة عبر
    // إيماءة على مركزها هي نفسها منطقة البطاقة القابلة للّمس)
    await tester.tap(find.byIcon(Icons.lock_rounded).first);
    await tester.pumpAndSettle();

    // الورقة يجب أن تسمّي الشرط الوحيد بالضبط: إتمام العالم السابق —
    // لا نص "مقفل" مجرّد بلا تفاصيل
    expect(
      find.textContaining('أكمل عالم'),
      findsWidgets,
      reason: 'يجب أن يُذكر العالم المطلوب إتمامه بالاسم، لا رسالة عامة',
    );
    expect(
      find.byIcon(Icons.radio_button_unchecked),
      findsWidgets,
      reason: 'شروط غير محقّقة تُعرض كعناصر قائمة، لا كنص واحد مبهم',
    );
  });
}
