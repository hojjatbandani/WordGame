// حوار اسم اللاعب: الإدخال بمفتاح Enter كان يُسقط التطبيق.
//
// السبب: المتحكّم كان يُتخلَّص منه فور اكتمال showDialog، أي *قبل*
// انتهاء حركة الإغلاق والحقل ما يزال مبنيّا، فينفجر تأكيد
// `_dependents.isEmpty` في framework.dart. يظهر مع Enter تحديدا لأن
// الإغلاق يقع داخل نداء onSubmitted.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/app_language.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _app(WidgetRef Function(WidgetRef) capture) async {
  SharedPreferences.setMockInitialValues({});
  final store = ProgressStore(await SharedPreferences.getInstance());
  return ProviderScope(
    overrides: [progressStoreProvider.overrideWithValue(store)],
    child: MaterialApp(
      theme: HurufTheme.build(),
      home: Consumer(
        builder: (context, ref, _) {
          capture(ref);
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    askPlayerName(context, ref, AppLanguage.ar),
                child: const Text('open'),
              ),
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  setUpAll(() => AudioService.disabled = true);

  testWidgets('الإدخال بمفتاح Enter يحفظ الاسم بلا أي استثناء', (tester) async {
    late WidgetRef ref;
    await tester.pumpWidget(await _app((r) => ref = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'فهد');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'لا تأكيد ينفجر');
    expect(find.byType(TextField), findsNothing, reason: 'الحوار أُغلق');
    expect(ref.read(playerNameProvider), 'فهد');
  });

  testWidgets('زرّ التأكيد يحفظ الاسم أيضا', (tester) async {
    late WidgetRef ref;
    await tester.pumpWidget(await _app((r) => ref = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'نورة');
    await tester.tap(find.text('يلا نبدأ'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(ref.read(playerNameProvider), 'نورة');
  });

  testWidgets('الإلغاء لا يحفظ اسما ولا يُسقط شيئا', (tester) async {
    late WidgetRef ref;
    await tester.pumpWidget(await _app((r) => ref = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(ref.read(playerNameProvider), isNull);
    expect(
      ref.read(progressStoreProvider).playerNameAsked,
      isTrue,
      reason: 'سُئل مرة، فلا يُسأل تلقائيا ثانية',
    );
  });
}
