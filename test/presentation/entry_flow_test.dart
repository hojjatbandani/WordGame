// من الفتح إلى اللعب (المواصفة §5، القرار D1): التثبيت الجديد يدخل
// المرحلة الأولى مباشرة، وزرّ الرئيسية يفتح المرحلة الحالية بلا قوائم،
// وحوار الاسم ونقاط التنبيه تنتظر انتهاء التعليم.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/analytics/analytics_event.dart';
import 'package:huruf/data/analytics/analytics_service.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/models.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/game_screen.dart';
import 'package:huruf/presentation/screens/home_screen.dart';
import 'package:huruf/presentation/screens/map_entry.dart';
import 'package:huruf/presentation/screens/splash_screen.dart';
import 'package:huruf/presentation/screens/world_select_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameLevel _level(int id) => GameLevel(
  id: id,
  letters: const ['ق', 'ل', 'م'],
  words: const [WordEntry(word: 'قلم', definition: 'أداة الكتابة')],
  bonusWords: const [],
  difficulty: 1,
);

final _levels = [for (var i = 1; i <= 12; i++) _level(i)];

Future<List<AnalyticsEvent>> _pump(
  WidgetTester tester, {
  required Widget home,
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({...prefs});
  final sp = await SharedPreferences.getInstance();
  final store = ProgressStore(sp);
  final progression = await ProgressionRepository.load(prefs: sp, legacy: store);
  final events = <AnalyticsEvent>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        progressStoreProvider.overrideWithValue(store),
        progressionRepositoryProvider.overrideWithValue(progression),
        levelsProvider.overrideWith((ref) => _levels),
        analyticsProvider.overrideWithValue(AnalyticsService(sink: events.add)),
      ],
      child: MaterialApp(
        theme: HurufTheme.build(),
        navigatorObservers: [hurufRouteObserver],
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: home,
      ),
    ),
  );
  return events;
}

Future<void> _afterSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1800));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 4));
}

List<String> _names(List<AnalyticsEvent> e) => [for (final x in e) x.name];

void main() {
  setUpAll(() => AudioService.disabled = true);

  testWidgets('fresh install lands in stage 1', (tester) async {
    final events = await _pump(tester, home: const SplashScreen());
    await _afterSplash(tester);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('المرحلة 1'), findsOneWidget);
    expect(_names(events), isNot(contains(Ev.homeViewed)));
    final selected = events.firstWhere((e) => e.name == Ev.stageSelected);
    expect(selected.properties['source'], 'first_launch');
    await _drain(tester);
  });

  testWidgets('returning player sees Home with continue label', (tester) async {
    final events = await _pump(
      tester,
      home: const SplashScreen(),
      prefs: {'max_unlocked': 4, 'onboarding_completed': true,
          'player_name_asked': true},
    );
    await _afterSplash(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('تابع اللعب'), findsOneWidget);
    final viewed = events.firstWhere((e) => e.name == Ev.homeViewed);
    expect(viewed.properties['source'], 'launch');
    await _drain(tester);
  });

  testWidgets('CTA opens current stage directly', (tester) async {
    final events = await _pump(
      tester,
      home: const HomeScreen(),
      prefs: {'max_unlocked': 4, 'onboarding_completed': true,
          'player_name_asked': true},
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('تابع اللعب'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('المرحلة 4'), findsOneWidget);
    final click = events.firstWhere((e) => e.name == Ev.continuePlayClicked);
    expect(click.properties['stage_id'], 4);
    expect(click.properties['cta'], 'continue');
    final selected = events.firstWhere((e) => e.name == Ev.stageSelected);
    expect(selected.properties['source'], 'home_cta');
    await _drain(tester);
  });

  testWidgets('new player CTA says start', (tester) async {
    await _pump(tester, home: const HomeScreen());
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('ابدأ اللعب'), findsOneWidget);
    await _drain(tester);
  });

  testWidgets('name dialog waits for onboarding', (tester) async {
    await _pump(tester, home: const HomeScreen(), prefs: {'max_unlocked': 4});
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AlertDialog), findsNothing);
    await _drain(tester);

    await _pump(
      tester,
      home: const HomeScreen(),
      prefs: {'max_unlocked': 4, 'onboarding_completed': true},
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AlertDialog), findsOneWidget);
    await _drain(tester);
  });

  testWidgets('badges hidden before onboarding', (tester) async {
    await _pump(
      tester,
      home: const HomeScreen(),
      prefs: {'player_name_asked': true},
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(PulseDot), findsNothing);
    await _drain(tester);
  });

  testWidgets('locked world sheet offers play', (tester) async {
    await _pump(
      tester,
      home: const WorldSelectScreen(),
      prefs: {'player_name_asked': true},
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.bySemanticsLabel(RegExp('مقفل')).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final play = find.textContaining('تابع اللعب');
    expect(play, findsOneWidget);
    await tester.tap(play);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('المرحلة 1'), findsOneWidget);
    await _drain(tester);
  });
}
