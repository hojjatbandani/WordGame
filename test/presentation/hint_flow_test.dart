// التلميح في شاشة اللعب (المواصفة §7، القرار D3): الأول مجاني في المراحل
// 1-10، المدفوع «الغالي» يُسأل عنه بالسعر والرصيد، والنقص يعرض الإعلان
// أولا بلا متجر في المراحل الأولى، والضغطة المزدوجة لا تشتري مرتين.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/analytics/analytics_event.dart';
import 'package:huruf/data/analytics/analytics_service.dart';
import 'package:huruf/data/models.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameLevel _level(int id) => GameLevel(
  id: id,
  letters: const ['ح', 'ل', 'م'],
  words: const [
    WordEntry(word: 'ملح', definition: 'ما يطيب به الطعام'),
    WordEntry(word: 'حلم', definition: 'ما يُرى في النوم'),
  ],
  bonusWords: const ['لحم'],
  difficulty: 1,
);

class _Rig {
  final ProviderContainer c;
  final List<AnalyticsEvent> events;
  _Rig(this.c, this.events);
  int get coins => c.read(pointsProvider);
  List<Map<String, Object?>> named(String n) => [
    for (final e in events)
      if (e.name == n) e.properties,
  ];
}

Future<_Rig> _pump(WidgetTester tester, {int stage = 5, int extraCoins = 0}) async {
  // شاشة هاتف حقيقية لا 800×600
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'player_name_asked': true,
    'onboarding_completed': true,
  });
  final store = ProgressStore(await SharedPreferences.getInstance());
  final events = <AnalyticsEvent>[];
  final level = _level(stage);
  final c = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      levelsProvider.overrideWith((ref) => [level]),
      analyticsProvider.overrideWithValue(AnalyticsService(sink: events.add)),
    ],
  );
  addTearDown(c.dispose);
  if (extraCoins > 0) c.read(pointsProvider.notifier).add(extraCoins);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: GameScreen(level: level, allLevels: [level]),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 4));
  events.clear();
  return _Rig(c, events);
}

final _ordered = find.bySemanticsLabel(RegExp('كشف الحرف التالي'));

/// فقاعة المرشد تُطفأ بمؤقّت — لا يبقى مؤقّت معلّق بعد الاختبار
Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

Future<void> _tapHint(WidgetTester tester) async {
  await tester.tap(_ordered);
  // إطار يبدأ فيه انزلاق الورقة، ثم إطار تكتمل فيه
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('first hint is free without sheet', (tester) async {
    final r = await _pump(tester);
    final before = r.coins;
    await _tapHint(tester);
    expect(find.byType(BottomSheet), findsNothing);
    final used = r.named(Ev.hintUsed).single;
    expect(used['paid_with'], 'free');
    expect(used['cost'], 0);
    expect(used['hint_type'], 'ordered_letter');
    expect(r.coins, before);
    await _settle(tester);
  });

  testWidgets('second hint asks with price and balance, cancel spends nothing',
      (tester) async {
    final r = await _pump(tester);
    await _tapHint(tester);
    await tester.pump(const Duration(seconds: 1));
    final before = r.coins;
    await _tapHint(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.textContaining('20'), findsWidgets);
    expect(find.textContaining('$before'), findsWidgets);
    expect(r.named(Ev.hintViewed).single['trigger'], 'confirm_sheet');
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(r.coins, before);
    expect(r.named(Ev.hintUsed), hasLength(1));
    await _settle(tester);
  });

  testWidgets('confirm spends 20 with reason hint', (tester) async {
    final r = await _pump(tester);
    await _tapHint(tester);
    await tester.pump(const Duration(seconds: 1));
    final before = r.coins;
    await _tapHint(tester);
    await tester.tap(find.text('استخدم التلميح'));
    await tester.pumpAndSettle();
    expect(r.coins, before - 20);
    final used = r.named(Ev.hintUsed).last;
    expect(used['paid_with'], 'coins');
    expect(used['cost'], 20);
    expect(r.named(Ev.coinsSpent).last['reason'], 'hint');
    await _settle(tester);
  });

  testWidgets('double tap buys once', (tester) async {
    final r = await _pump(tester);
    await tester.tap(_ordered);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(_ordered);
    await tester.pump(const Duration(milliseconds: 400));
    expect(r.named(Ev.hintUsed), hasLength(1));
    expect(find.byType(BottomSheet), findsNothing);
    await _settle(tester);
  });

  testWidgets('insufficient: ad option first, no shop link at stage 5',
      (tester) async {
    final r = await _pump(tester);
    await _tapHint(tester); // المجاني
    await tester.pump(const Duration(seconds: 1));
    r.c.read(pointsProvider.notifier).spend(r.coins - 5, reason: 'test');
    await _tapHint(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.textContaining('شاهد إعلانا'), findsOneWidget);
    expect(find.text('المتجر'), findsNothing);
    expect(r.named(Ev.hintUnavailable).single['reason'], 'insufficient_coins');
    expect(r.named(Ev.hintViewed).last['trigger'], 'insufficient_sheet');
    await _settle(tester);
  });

  testWidgets('stage 15 rich player buys without sheet', (tester) async {
    final r = await _pump(tester, stage: 15, extraCoins: 1000);
    final before = r.coins;
    await _tapHint(tester);
    expect(find.byType(BottomSheet), findsNothing);
    expect(r.coins, before - 40);
    expect(r.named(Ev.hintUsed).single['paid_with'], 'coins');
    await _settle(tester);
  });
}
