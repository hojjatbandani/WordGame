import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/presentation/widgets/pressable.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: HurufTheme.build(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );

void main() {
  testWidgets('Pressable exposes its label to screen readers', (tester) async {
    await tester.pumpWidget(_wrap(
      Pressable(
        onTap: () {},
        semanticLabel: 'افتح المتجر',
        child: const Icon(Icons.storefront_rounded),
      ),
    ));

    expect(find.bySemanticsLabel('افتح المتجر'), findsOneWidget);
  });

  testWidgets('Pressable enforces a 48dp minimum touch target',
      (tester) async {
    await tester.pumpWidget(_wrap(
      Pressable(
        onTap: () {},
        semanticLabel: 'زر صغير',
        // محتوى أصغر من الحد الأدنى للمس
        child: const SizedBox(width: 12, height: 12),
      ),
    ));

    final size = tester.getSize(find.byType(Pressable));
    expect(size.width, greaterThanOrEqualTo(HurufTheme.minTouch));
    expect(size.height, greaterThanOrEqualTo(HurufTheme.minTouch));
  });

  testWidgets('Pressable fires its tap callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(
      Pressable(
        onTap: () => taps++,
        semanticLabel: 'اضغط',
        child: const SizedBox(width: 60, height: 60),
      ),
    ));

    await tester.tap(find.byType(Pressable));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('reduce-motion disables the press scale animation',
      (tester) async {
    await tester.pumpWidget(_wrap(
      reduceMotion: true,
      Pressable(
        onTap: () {},
        semanticLabel: 'بلا حركة',
        child: const SizedBox(width: 60, height: 60),
      ),
    ));

    // الضغط مع الاستمرار: يجب ألا يتغيّر المقياس عند تعطيل الحركة
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Pressable)));
    await tester.pump(HurufTheme.durFast);
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1.0);
    await gesture.up();
  });

  test('motion tokens follow the 150-300ms micro-interaction guideline', () {
    expect(HurufTheme.durFast.inMilliseconds, inInclusiveRange(120, 200));
    expect(HurufTheme.durBase.inMilliseconds, inInclusiveRange(150, 300));
    expect(HurufTheme.durSlow.inMilliseconds, lessThanOrEqualTo(400));
  });
}
