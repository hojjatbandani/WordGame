// السطر الصغير أسفل زرّي التلميح كان `'🎟$charges'` — رمز تعبيري داخل
// نص مقاسه 10 بكسل بخطّ (IRANSans) لا يحوي محرفا تعبيريا واحدا. النتيجة
// على الجهاز: مربّع صغير لا يُقرأ بجانب الرقم.
//
// ولم يظهر إلا «أحيانا» لأن الفرع لا يُرسم إلا حين يملك اللاعب شحنة
// مجانية، والشحنات لم تكن تُمنح من اللعب أصلا قبل وصل الاقتصاد. أول ما
// صار المنح يعمل (شحنة كل خمس مراحل) ظهر العيب لكل لاعب بعد المرحلة
// الخامسة.
//
// هذا الاختبار يقفل الطرفين: لا محرف تعبيري في أي نص تُظهره شاشة اللعب،
// وشارة الشحنة تُرسم أيقونة متجهية من خط الأيقونات المضمّن.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/models.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _level = GameLevel(
  id: 7,
  letters: ['ح', 'ل', 'م'],
  words: [
    WordEntry(word: 'ملح', definition: 'ما يطيب به الطعام'),
    WordEntry(word: 'حلم', definition: 'ما يُرى في النوم'),
  ],
  bonusWords: ['لحم'],
  difficulty: 1,
);

/// كل ما هو خارج الأبجدية والأرقام مما لا يغطّيه خطّ التطبيق
bool _isPictographic(int rune) =>
    (rune >= 0x1F000 && rune <= 0x1FAFF) ||
    (rune >= 0x2600 && rune <= 0x27BF) ||
    (rune >= 0x2B00 && rune <= 0x2BFF);

Future<ProgressStore> _seed() async {
  SharedPreferences.setMockInitialValues({'player_name_asked': true});
  return ProgressStore(await SharedPreferences.getInstance());
}

Future<void> _pumpGame(
  WidgetTester tester,
  ProgressStore store, {
  required int hintCharges,
}) async {
  final container = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      levelsProvider.overrideWith((ref) => const [_level]),
    ],
  );
  addTearDown(container.dispose);

  if (hintCharges > 0) {
    container
        .read(progressionRepositoryProvider)
        .runEconomy((economy) => economy.grantHintCharges(hintCharges));
    container.read(hintChargesProvider.notifier).refresh();
  }
  expect(container.read(hintChargesProvider), hintCharges);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const GameScreen(level: _level, allLevels: [_level]),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 4)); // فقاعة المرشد
}

/// كل نصوص الشجرة المرسومة فعلا
Iterable<String> _renderedTexts(WidgetTester tester) sync* {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final data = text.data;
    if (data != null) yield data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AudioService.disabled = true;

  testWidgets('لا رمز تعبيري في أي نص على شاشة اللعب — ولا حين يملك شحنة', (
    tester,
  ) async {
    for (final charges in [0, 1]) {
      final store = await _seed();
      await _pumpGame(tester, store, hintCharges: charges);

      for (final text in _renderedTexts(tester)) {
        final bad = text.runes.where(_isPictographic).toList();
        expect(
          bad,
          isEmpty,
          reason:
              'نص «$text» يحوي محرفا تعبيريا (${bad.map((r) => 'U+${r.toRadixString(16).toUpperCase()}').join(', ')}) '
              'وخط التطبيق لا يرسمه — استعمل أيقونة Icons.* بدله',
        );
      }
    }
  });

  testWidgets('رصيد الشحنة يظهر أيقونة تذكرة + رقم لا رمزا تعبيريا', (
    tester,
  ) async {
    final store = await _seed();
    await _pumpGame(tester, store, hintCharges: 2);

    // زرّان يعرضان الرصيد نفسه (الكشف المرتّب والعشوائي)
    expect(find.byIcon(Icons.confirmation_number_rounded), findsNWidgets(2));
    expect(find.text('2'), findsNWidgets(2));
  });

  testWidgets('بلا شحنة يظهر السعر بالعملات ولا أيقونة تذكرة', (tester) async {
    final store = await _seed();
    await _pumpGame(tester, store, hintCharges: 0);

    expect(find.byIcon(Icons.confirmation_number_rounded), findsNothing);
    // السعران الثابتان لتلميحَي شاشة اللعب — من ملف التوازن لا مكتوبين
    // هنا، وإلا كسر الاختبارَ كلُّ تعديل سعر ولو كان مقصودا
    expect(
      find.text('${BalanceConfig.coinsHintOrderedLetter}'),
      findsOneWidget,
    );
    expect(find.text('${BalanceConfig.coinsHintRandomLetter}'), findsOneWidget);
  });
}
