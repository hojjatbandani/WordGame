// المرحلة الأولى درسٌ داخل اللعب (المواصفة §6): جملة توجيه وإصبع على
// العجلة، والتلميح مخفي حتى يعلق اللاعب، ولاعب قديم يرى مرحلة عادية.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/models.dart';
import 'package:huruf/data/onboarding/tutorial_coach.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _stage1 = GameLevel(
  id: 1,
  letters: ['ق', 'ل', 'م'],
  words: [WordEntry(word: 'قلم', definition: 'أداة الكتابة')],
  bonusWords: [],
  difficulty: 1,
);

final _hintButton = find.bySemanticsLabel(RegExp('كشف الحرف التالي'));

Future<void> _pump(WidgetTester tester, {bool veteran = false}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'player_name_asked': true,
    if (veteran) 'onboarding_completed': true,
  });
  final store = ProgressStore(await SharedPreferences.getInstance());
  final c = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      levelsProvider.overrideWith((ref) => const [_stage1]),
    ],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        home: GameScreen(level: _stage1, allLevels: [_stage1]),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

/// مؤقّتات الشاشة (الفقاعة، الدقّات) لا تبقى معلّقة بعد الاختبار
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  testWidgets('stage 1 shows instruction and hides hints', (tester) async {
    await _pump(tester);
    expect(find.text(CoachText.formWord), findsOneWidget);
    expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
    expect(_hintButton, findsNothing);
    await _finish(tester);
  });

  testWidgets('hint appears as free after 20 s without progress',
      (tester) async {
    await _pump(tester);
    for (var i = 0; i < 21; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(_hintButton, findsOneWidget);
    expect(find.text('مجاني'), findsWidgets);
    expect(find.text(CoachText.useFreeHint), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('veteran replay has no coach', (tester) async {
    await _pump(tester, veteran: true);
    expect(find.text(CoachText.formWord), findsNothing);
    expect(find.byIcon(Icons.touch_app_rounded), findsNothing);
    expect(_hintButton, findsOneWidget);
    await _finish(tester);
  });
}
