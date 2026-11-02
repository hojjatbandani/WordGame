import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// التصميم الجديد للرئيسية عمود ثابت بلا تمرير، فيجب إثبات أنه لا يفيض
/// على الشاشات القصيرة — وأن كل المداخل المهمة ظاهرة.
Future<Widget> _app({Map<String, Object> extraPrefs = const {}}) async {
  SharedPreferences.setMockInitialValues({
    'points': 120,
    'bonus_jar': 3,
    'player_name_asked': true,
    ...extraPrefs,
  });
  final prefs = await SharedPreferences.getInstance();
  final store = ProgressStore(prefs);
  // الرئيسية تقرأ التقدّم فعلا الآن (بوّابة ترويج المتجر تتوقّف على
  // إتمام الفصل الأول)، فلا يكفي تجاوز ProgressStore وحده
  final progression = await ProgressionRepository.load(
    prefs: prefs,
    legacy: store,
  );
  return ProviderScope(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      progressionRepositoryProvider.overrideWithValue(progression),
    ],
    child: MaterialApp(
      theme: HurufTheme.build(),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const HomeScreen(),
    ),
  );
}

void main() {
  // لا إضافة صوت في بيئة الاختبار، فنعطّل المشغّل بدل أن يرمي
  setUpAll(() => AudioService.disabled = true);

  for (final size in const [Size(360, 640), Size(360, 592), Size(430, 932)]) {
    testWidgets('لا فيضان على مقاس ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(await _app());
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('المداخل الأساسية كلها ظاهرة على الشاشة', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('حروف'), findsOneWidget);
    expect(find.text('تابع اللعب'), findsOneWidget);
    // العجلة: تبويب واحد في الشريط السفلي (حلّ محلّ الزرّ العائم الذي
    // كان يكرّر نفس المدخل فوق لوح اللعب)
    expect(find.text('🎡'), findsOneWidget);
    expect(find.text('🛒'), findsOneWidget);
    // المتجر: تبويب واحد في الشريط السفلي (زرّ الترويسة أُزيل)
    expect(find.text('المتجر'), findsOneWidget);
    // سطر «أنت في العالم» أُزيل من الترويسة
    expect(find.textContaining('أنت في'), findsNothing);
    expect(find.text('إنجازات'), findsOneWidget);
  });

  testWidgets('تحية الترويسة تحاذي مركز الصورة الرمزية عموديا', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app());
    await tester.pump(const Duration(milliseconds: 600));

    // Pressable يفرض 48 كأدنى مساحة لمس ويرسم طفله في أعلى صندوقه، فبلا
    // محاذاة صريحة يعلو النصّ مركز الصورة بنحو 15 بكسل
    final greeting = tester.getCenter(find.text('أهلاً بك'));
    final avatar = tester.getCenter(find.text('🙂'));
    expect(
      (greeting.dy - avatar.dy).abs(),
      lessThan(2),
      reason: 'فارق أكبر من بكسلين يُقرأ نصّا مائلا للأعلى',
    );
  });

  testWidgets('لا مدخل مكرّر: مدخلان فقط فوق شريط التنقّل', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app());
    await tester.pump(const Duration(milliseconds: 600));

    // بطاقات الشبكة 2×2 حُذفت: لكلٍّ منها مدخل آخر، وبطاقتان تفتحان
    // الشيء نفسه تُعلّمان اللاعب تجاهل نصفهما
    expect(find.text('تحدّيات'), findsNothing);
    expect(find.text('تحدّيات لغوية'), findsNothing);
    expect(find.text('نزال سريع'), findsNothing);
    expect(find.text('التحدي اليومي'), findsNothing);
  });

  testWidgets('لا مدخل للتحدّيات اللغوية في الإعدادات — أيقوناتها في الرئيسية', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('⚙️'));
    // لا pumpAndSettle: وميض زرّ المتجر رسم دائم لا يسكن أبدا
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('تحدّيات لغوية'), findsNothing);
    // الإعدادات نفسها فُتحت فعلا (كي لا يمرّ الاختبار لمجرّد أن الورقة
    // لم تُفتح أصلا)
    expect(find.text('الإعدادات'), findsOneWidget);
  });

  testWidgets('الأنماط الأربعة مقفلة للاعب الجديد وتعرض شرط فتحها', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app());
    // صفّ الأيقونات ينتظر تحميل challenges.json من الأصول
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // لاعب جديد: لا فصل مكتمل ولا عالم — الأربعة كلها مقفلة، وكل
    // أيقونة تعرض شرطها بدل اسمها
    expect(find.text('أتمم فصلين'), findsOneWidget);
    expect(find.text('أتمم عالمين'), findsOneWidget);
    expect(find.text('أتمم 4 عوالم'), findsOneWidget);
    expect(find.text('أتمم 6 عوالم'), findsOneWidget);
    expect(find.text('أكمل المثل'), findsNothing);
    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(4));

    // النقر على المقفل يشرح شرطه بدل أن يفتح شيئا
    await tester.tap(find.text('أتمم فصلين'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('أكمل المثل'), findsOneWidget);
  });

  group('نقطة «هنا شيء بانتظارك»', () {
    // النقطة إشارة نادرة عمدا: تظهر حين *يُستلَم* شيء، وتختفي فور
    // استلامه. نقطةٌ لا تختفي تُعلّم اللاعب تجاهل النقاط كلها.
    String today() {
      final d = DateTime.now();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    testWidgets('المتجر يحمل نقطة حين تنتظر جائزة الدخول اليومية', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(await _app());
      await tester.pump(const Duration(milliseconds: 600));

      // لاعب جديد: جائزة اليوم لم تُستلم بعد ⇒ الجوائز والمتجر والعجلة
      // كلها تحمل نقطة
      expect(find.byType(PulseDot), findsNWidgets(3));
    });

    testWidgets('استلام جائزة اليوم يطفئ نقطة المتجر', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        await _app(extraPrefs: {'daily_last_claim': today()}),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // بقيت نقطتا الجوائز والعجلة وحدهما
      expect(find.byType(PulseDot), findsNWidgets(2));
    });

    testWidgets('النقطة تنبض ولا تُغيّر مساحتها بين إطار وآخر', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(await _app());
      await tester.pump(const Duration(milliseconds: 600));

      final dot = find.byType(PulseDot).first;
      final sizeA = tester.getSize(dot);
      await tester.pump(const Duration(milliseconds: 400));
      final sizeB = tester.getSize(dot);

      // مربّع ثابت يتّسع لأقصى حلقة: بلاه تُعاد تخطيط الخانة مع كل إطار
      expect(sizeA, sizeB);
      expect(sizeA.width, greaterThan(0));
    });
  });
}
