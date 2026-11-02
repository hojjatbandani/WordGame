import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// لغة الواجهة تُبدَّل من الرئيسية وتُحفظ، بينما لغة الحدس تبقى عربية.
Future<Widget> _app() async {
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
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        theme: HurufTheme.build(),
        builder: (context, child) => Directionality(
          textDirection: ref.watch(languageProvider).textDirection,
          child: child!,
        ),
        home: const HomeScreen(),
      ),
    ),
  );
}

void main() {
  setUpAll(() => AudioService.disabled = true);

  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'points': 120, 'bonus_jar': 3, 'player_name_asked': true}),
  );

  testWidgets('تبديل اللغة من ورقة الإعدادات يترجم الرئيسية ويعود', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('تابع اللعب'), findsOneWidget);

    // فتح ورقة الإعدادات ثم اختيار الإنجليزية
    await tester.tap(find.text('⚙️'));
    // لا pumpAndSettle: وميض زرّ المتجر رسم دائم لا يسكن أبدا
    await tester.pump(const Duration(milliseconds: 400));
    // الورقة قابلة للتمرير: الصفّ موجود في الشجرة وقد يكون خارج المساحة
    // القابلة للنقر بلا تمرير إليه
    await tester.ensureVisible(find.text('English'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('English'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Continue Playing'), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('تابع اللعب'), findsNothing);

    // الرجوع للعربية من نفس الورقة
    await tester.ensureVisible(find.text('العربية'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('العربية'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('تابع اللعب'), findsOneWidget);
  });

  testWidgets('اللغة المختارة تُحفظ فتظهر إنجليزية عند إعادة الفتح', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
    'player_name_asked': true,
      'points': 120,
      'bonus_jar': 3,
      'ui_language': 'en',
    });

    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Continue Playing'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('Continue Playing'))),
      TextDirection.ltr,
    );
  });

  // الكلمات الإنجليزية أطول من العربية، فالرصيف السفلي هو أول ما يفيض
  for (final size in const [Size(360, 640), Size(360, 592), Size(430, 932)]) {
    testWidgets('لا فيضان بالإنجليزية على مقاس ${size.width}x${size.height}', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
    'player_name_asked': true,
        'points': 120,
        'bonus_jar': 3,
        'ui_language': 'en',
      });

      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(await _app());
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
    });
  }
}
