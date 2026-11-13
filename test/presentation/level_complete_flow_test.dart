// شاشة النجاح (المواصفة §9): «المرحلة التالية» هي الزرّ الأوضح وتفتح
// المرحلة التالية فورا، و«الرئيسية» ثانوي، ونهاية الفصل لا تمرّ بقائمة
// الفصول بل تكمل إلى أول مراحل الفصل التالي (القرار D2).

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/analytics/analytics_event.dart';
import 'package:huruf/data/analytics/analytics_service.dart';
import 'package:huruf/data/models.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/game_screen.dart';
import 'package:huruf/presentation/widgets/letter_wheel.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameLevel _level(int id) => GameLevel(
  id: id,
  letters: const ['ق', 'ل', 'م'],
  words: const [WordEntry(word: 'قلم', definition: 'أداة الكتابة')],
  bonusWords: const [],
  difficulty: 1,
);

class _Rig {
  final ProgressStore store;
  final List<AnalyticsEvent> events;
  _Rig(this.store, this.events);
}

Future<_Rig> _pump(WidgetTester tester, {required int stage}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'player_name_asked': true,
    'onboarding_completed': true,
  });
  final store = ProgressStore(await SharedPreferences.getInstance());
  final events = <AnalyticsEvent>[];
  final levels = [for (var i = 1; i <= 14; i++) _level(i)];
  final c = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      levelsProvider.overrideWith((ref) => levels),
      analyticsProvider.overrideWithValue(AnalyticsService(sink: events.add)),
    ],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GameScreen(
                    level: levels[stage - 1],
                    allLevels: levels,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return _Rig(store, events);
}

/// يحلّ «قلم» بسحب حقيقي على العجلة (نفس هندسة LetterWheel)
Future<void> _solve(WidgetTester tester) async {
  final rect = tester.getRect(find.byType(LetterWheel));
  final side = rect.shortestSide;
  final tile = side * 0.115;
  final radius = side / 2 - tile - 6;
  Offset at(int i) {
    final angle = -pi / 2 + 2 * pi * i / 3;
    return rect.center + Offset(cos(angle) * radius, sin(angle) * radius);
  }

  final g = await tester.startGesture(at(0));
  await tester.pump();
  for (final i in [1, 2]) {
    await g.moveTo(at(i));
    await tester.pump();
  }
  await g.up();
  await tester.pump();
  await tester.pump(const Duration(seconds: 2)); // تأخّر إظهار شاشة النجاح
  // إطار تبدأ فيه حركة البطاقة، ثم اكتمالها
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  testWidgets('success shows next before home', (tester) async {
    await _pump(tester, stage: 5);
    await _solve(tester);
    final next = find.text('المرحلة التالية');
    final home = find.text('الرئيسية');
    expect(next, findsOneWidget);
    expect(home, findsOneWidget);
    expect(tester.getTopLeft(next).dy, lessThan(tester.getTopLeft(home).dy));
    expect(find.textContaining('من 12'), findsOneWidget); // سطر التقدّم
    await _drain(tester);
  });

  testWidgets('home pops to the first route', (tester) async {
    await _pump(tester, stage: 5);
    await _solve(tester);
    await tester.tap(find.text('الرئيسية'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('open'), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
    await _drain(tester);
  });

  testWidgets('next logs next_stage_clicked and opens next stage',
      (tester) async {
    final r = await _pump(tester, stage: 5);
    await _solve(tester);
    await tester.tap(find.text('المرحلة التالية'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final click = r.events.lastWhere((e) => e.name == Ev.nextStageClicked);
    expect(click.properties['stage_id'], 5);
    expect(click.properties['next_stage_id'], 6);
    expect(click.properties['chapter_finale'], isFalse);
    expect(find.text('المرحلة 6'), findsOneWidget);
    final start = r.events.lastWhere((e) => e.name == Ev.stageStart);
    expect(start.properties['source'], 'next_stage');
    await _drain(tester);
  });

  testWidgets('chapter finale goes straight to the next chapter',
      (tester) async {
    final r = await _pump(tester, stage: 12);
    await _solve(tester);
    expect(find.text('الفصل التالي'), findsOneWidget);
    await tester.tap(find.text('الفصل التالي'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('المرحلة 13'), findsOneWidget);
    final start = r.events.lastWhere((e) => e.name == Ev.stageStart);
    expect(start.properties['source'], 'chapter_next');
    await _drain(tester);
  });
}
