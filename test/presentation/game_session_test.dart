// جلسة المرحلة في شاشة اللعب (المواصفة §4.3، §9.3): سبب المغادرة،
// الخلفية المؤقتة لا تُعدّ تخلّيا، والتقدّم يُستأنف بعد المغادرة.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/analytics/analytics_event.dart';
import 'package:huruf/data/analytics/analytics_service.dart';
import 'package:huruf/data/analytics/stage_session.dart';
import 'package:huruf/data/models.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/game/stage_session_tracker.dart';
import 'package:huruf/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _level = GameLevel(
  id: 17,
  letters: ['ح', 'ل', 'م'],
  words: [
    WordEntry(word: 'ملح', definition: 'ما يطيب به الطعام'),
    WordEntry(word: 'حلم', definition: 'ما يُرى في النوم'),
  ],
  bonusWords: ['لحم'],
  difficulty: 1,
);

class _Rig {
  final ProgressStore store;
  final List<AnalyticsEvent> events;
  _Rig(this.store, this.events);

  List<AnalyticsEvent> named(String n) =>
      [for (final e in events) if (e.name == n) e];
}

Future<_Rig> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'player_name_asked': true,
    'onboarding_completed': true,
    ...prefs,
  });
  final store = ProgressStore(await SharedPreferences.getInstance());
  final events = <AnalyticsEvent>[];
  final container = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      levelsProvider.overrideWith((ref) => const [_level]),
      analyticsProvider.overrideWithValue(AnalyticsService(sink: events.add)),
    ],
  );
  addTearDown(container.dispose);
  // رصيد وافر: التلميح يُشترى بلا ورقة تأكيد
  container.read(pointsProvider.notifier).add(1000);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GameScreen(
                    level: _level,
                    allLevels: [_level],
                    source: 'map',
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
  return _Rig(store, events);
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 4));
}

Future<void> _leaveWithArrow(WidgetTester tester) async {
  await tester.tap(find.byTooltip('رجوع'));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('back arrow logs stage_abandon back_button', (tester) async {
    final r = await _pump(tester);
    await _open(tester);
    await _leaveWithArrow(tester);
    final abandon = r.named(Ev.stageAbandon).single.properties;
    expect(abandon['exit_reason'], 'back_button');
    expect(abandon['stage_id'], 17);
  });

  testWidgets('system back logs system_back', (tester) async {
    final r = await _pump(tester);
    await _open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(
      r.named(Ev.stageAbandon).single.properties['exit_reason'],
      'system_back',
    );
  });

  testWidgets('background then resume logs no abandon', (tester) async {
    final r = await _pump(tester);
    await _open(tester);
    // المسار الحقيقي للانتقالات (AppLifecycleListener يرفض القفز)
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump(const Duration(seconds: 30));
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(r.named(Ev.stageAbandon), isEmpty);
    expect(r.store.activeStageSessionJson, isNotNull);
  });

  testWidgets('stage events carry the standard props', (tester) async {
    final r = await _pump(tester);
    await _open(tester);
    final start = r.named(Ev.stageStart).single.properties;
    expect(
      start.keys.toSet(),
      containsAll([
        'stage_id', 'world_id', 'chapter_id', 'duration_ms', 'wrong_attempts',
        'hints_used', 'words_total', 'words_solved', 'bonus_words', 'attempt',
        'is_replay', 'source', 'resumed', 'tutorial',
      ]),
    );
    expect(start['source'], 'map');
    expect(start['words_total'], 2);
    expect(start['attempt'], 1);
  });

  testWidgets('progress survives leaving and is restored', (tester) async {
    final r = await _pump(tester);
    await _open(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('كشف الحرف التالي')));
    await tester.pump(const Duration(seconds: 3));
    await _leaveWithArrow(tester);
    await _open(tester);

    final second = r.named(Ev.stageStart).last.properties;
    expect(second['resumed'], isTrue);
    expect(second['hints_used'], 1);
    expect(second['attempt'], 2);
  });

  testWidgets('resume ignores words not in level', (tester) async {
    final r = await _pump(
      tester,
      prefs: {
        'stage_resume': jsonEncode({
          '17': StageProgressState(
            solved: {'كتب'},
            revealed: {'كتب': {0}},
            hintsUsed: 1,
          ).toJson(),
        }),
      },
    );
    await _open(tester);
    final start = r.named(Ev.stageStart).single.properties;
    expect(start['words_solved'], 0);
    expect(start['hints_used'], 0);
    expect(tester.takeException(), isNull);
  });

  test('recovered session logs app_backgrounded', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore(await SharedPreferences.getInstance());
    final session = StageSession(
      sessionId: 'x',
      stageId: 5,
      worldId: 1,
      chapterId: 1,
      source: 'map',
      attempt: 1,
      isReplay: false,
      tutorial: false,
      wordsTotal: 2,
      nowMs: 1000,
    )..pause(9000);
    await store.setActiveStageSessionJson(jsonEncode(session.toJson()));
    final events = <AnalyticsEvent>[];

    recoverStageSessions(store, AnalyticsService(sink: events.add), 500000);

    final abandon = events.single;
    expect(abandon.name, Ev.stageAbandon);
    expect(abandon.properties['exit_reason'], 'app_backgrounded');
    expect(abandon.properties['recovered'], isTrue);
    expect(store.activeStageSessionJson, isNull);
  });
}
