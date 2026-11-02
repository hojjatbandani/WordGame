import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/app_language.dart';
import 'package:huruf/presentation/widgets/points_message.dart';

/// كانت شاشة التحدي اليومي ترفض التلميح بصمت عند نفاد النقاط، فيظن
/// اللاعب أن الزر معطّل. هذه الاختبارات تثبّت أن الرسالة تظهر وتشرح
/// الرقم وتعطي مخرجا إلى المتجر.
void main() {
  Widget harness(void Function(BuildContext) onPressed) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => onPressed(context),
                  child: const Text('تلميح'),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('تظهر رسالة تشرح كم يحتاج اللاعب وكم معه', (tester) async {
    await tester.pumpWidget(harness(
      (context) => showNotEnoughPoints(context,
          cost: 25, balance: 10, lang: AppLanguage.ar),
    ));

    // لا شيء قبل الضغط
    expect(find.textContaining('نقاطك ما تكفي'), findsNothing);

    await tester.tap(find.text('تلميح'));
    await tester.pump();

    expect(find.text('نقاطك ما تكفي'), findsOneWidget);
    // الرقم الناقص محسوب ومعروض لا مجرد "لا تكفي"
    expect(find.text('التلميح بـ 25 ومعك 10 — ينقصك 15'), findsOneWidget);
  });

  testWidgets('الرسالة تعرض مخرجا إلى المتجر', (tester) async {
    await tester.pumpWidget(harness(
      (context) => showNotEnoughPoints(context,
          cost: 35, balance: 0, lang: AppLanguage.ar),
    ));

    await tester.tap(find.text('تلميح'));
    await tester.pump();

    expect(find.widgetWithText(SnackBarAction, 'المتجر'), findsOneWidget);
  });

  testWidgets('رسالة واحدة فقط مهما تكرّر الضغط', (tester) async {
    await tester.pumpWidget(harness(
      (context) => showNotEnoughPoints(context,
          cost: 25, balance: 5, lang: AppLanguage.ar),
    ));

    await tester.tap(find.text('تلميح'));
    await tester.pump();
    await tester.tap(find.text('تلميح'));
    await tester.pump();

    expect(find.text('نقاطك ما تكفي'), findsOneWidget);
  });
}
