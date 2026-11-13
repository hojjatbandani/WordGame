// عجلة الحروف للمرحلة الأولى (المواصفة §6): لمسة حرف واحد تُعرف (لا
// تُبتلع بصمت)، وبدء اللمس يُعرف، وإصبع العرض يُرسم حين يُطلب.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/presentation/widgets/letter_wheel.dart';

Future<void> _pump(
  WidgetTester tester, {
  void Function(String)? onWord,
  VoidCallback? onTouch,
  VoidCallback? onSingle,
  bool demo = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 300,
          height: 300,
          child: LetterWheel(
            letters: const ['ق', 'ل', 'م'],
            onWordSubmitted: onWord ?? (_) {},
            onSelectionChanged: (_) {},
            onTouchStart: onTouch,
            onSingleLetter: onSingle,
            demoWord: 'قلم',
            demoActive: demo,
          ),
        ),
      ),
    ),
  );
}

/// مركز الحرف الأول (أعلى العجلة) — نفس هندسة LetterWheel
Offset _firstLetter(WidgetTester tester) {
  final topLeft = tester.getTopLeft(find.byType(LetterWheel));
  const size = 300.0;
  const tile = size * 0.115;
  const radius = size / 2 - tile - 6;
  return topLeft + const Offset(size / 2, size / 2 - radius);
}

void main() {
  testWidgets('single-letter release calls onSingleLetter, not onWordSubmitted',
      (tester) async {
    var single = 0;
    final words = <String>[];
    await _pump(tester, onWord: words.add, onSingle: () => single++);
    await tester.tapAt(_firstLetter(tester));
    await tester.pump();
    expect(single, 1);
    expect(words, isEmpty);
  });

  testWidgets('touch start calls onTouchStart', (tester) async {
    var touches = 0;
    await _pump(tester, onTouch: () => touches++);
    await tester.tapAt(_firstLetter(tester));
    await tester.pump();
    expect(touches, 1);
  });

  testWidgets('demo paints a touch_app icon only when active', (tester) async {
    await _pump(tester, demo: true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);

    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.touch_app_rounded), findsNothing);
  });
}
