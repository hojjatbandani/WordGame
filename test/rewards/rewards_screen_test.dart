// شاشة مسار الجوائز: الحالات الثلاث (جاهزة / تنتظر / اكتملت) معروضة
// معا، والضغط يمنح فعلا، والتخطيط يصمد على أضيق جهاز ندعمه.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/data/rewards/reward_track.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/rewards_screen.dart';
import 'package:huruf/presentation/widgets/reward_burst_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime get _today => RewardTrackEngine.dayOf(DateTime.now());

DateTime _daysAgo(int days) => RewardTrackEngine.addDays(_today, -days);

late ProviderContainer _lastContainer;

Future<Widget> _app({String? track}) async {
  SharedPreferences.setMockInitialValues({
    'player_name_asked': true,
    'reward_track_json': ?track,
  });
  final store = await ProgressStore.create();
  final progression = await ProgressionRepository.load(
    prefs: store.prefs,
    legacy: store,
  );
  _lastContainer = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      progressionRepositoryProvider.overrideWithValue(progression),
    ],
  );
  addTearDown(_lastContainer.dispose);
  return UncontrolledProviderScope(
    container: _lastContainer,
    child: MaterialApp(
      theme: HurufTheme.build(),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const RewardsScreen(),
    ),
  );
}

void main() {
  setUpAll(() => AudioService.disabled = true);

  testWidgets('اليوم الأول: البطاقات الثلاث ظاهرة واليومية وحدها قابلة للاستلام',
      (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('الجائزة اليومية'), findsOneWidget);
    expect(find.text('الجائزة الأسبوعية'), findsOneWidget);
    expect(find.text('الجائزة الشهرية'), findsOneWidget);

    // زرّ واحد فقط يحمل مبلغا — البقية تعرض موعدها لا رقمها
    expect(find.text('+20'), findsOneWidget);
    expect(find.text('+50'), findsNothing);
    expect(find.text('+200'), findsNothing);
  });

  testWidgets('الضغط على «استلم» يمنح الألماس ويُظهر الاحتفال', (
    tester,
  ) async {
    await tester.pumpWidget(await _app());
    await tester.pump(const Duration(milliseconds: 400));
    final before = _lastContainer.read(pointsProvider);

    await tester.tap(find.text('+20'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_lastContainer.read(pointsProvider), before + 20);
    expect(find.textContaining('جائزة اليوم'), findsWidgets);

    // وبعد الاستلام لا يبقى زرّ جاهز
    await tester.tap(find.byType(RewardBurstOverlay));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('+20'), findsNothing);
  });

  testWidgets('الطبقة المنتهية تختفي ولا تعلن انتهاءها', (tester) async {
    final track = RewardTrackState(
      startDay: _daysAgo(40),
      tiers: {
        RewardTier.daily: RewardTierProgress(
          claimed: RewardTier.daily.totalClaims,
          lastClaimDay: _daysAgo(4),
        ),
      },
    ).encode();

    await tester.pumpWidget(await _app(track: track));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('الجائزة اليومية'), findsNothing);
    expect(find.text('اكتملت'), findsNothing);
    // والباقيتان ما زالتا تعملان
    expect(find.text('الجائزة الأسبوعية'), findsOneWidget);
    expect(find.text('الجائزة الشهرية'), findsOneWidget);
  });

  testWidgets('اكتمال المسار كله: شكر بلا إعلان نهاية', (tester) async {
    final track = RewardTrackState(
      startDay: _daysAgo(365),
      tiers: {
        for (final tier in RewardTier.values)
          tier: RewardTierProgress(
            claimed: tier.totalClaims,
            lastClaimDay: _daysAgo(30),
          ),
      },
    ).encode();

    await tester.pumpWidget(await _app(track: track));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('استلمت كل الجوائز المتاحة'), findsOneWidget);
    for (final title in ['الجائزة اليومية', 'الجائزة الأسبوعية',
        'الجائزة الشهرية']) {
      expect(find.text(title), findsNothing, reason: title);
    }
  });

  // الاختبار الحارس لطلب المنتج: لا شيء على هذه الشاشة يكشف أن المسار
  // محدود. عدّاد نازل («بقي لك N») أو «3 من 30» يعلّم اللاعب أن ما
  // يعود إليه كل يوم ينفد، وذلك يهدم سبب وجود المسار نفسه.
  testWidgets('لا رقم يكشف أن المسار ينتهي', (tester) async {
    final track = RewardTrackState(
      startDay: _daysAgo(3),
      tiers: {
        RewardTier.daily: RewardTierProgress(
          claimed: 3,
          lastClaimDay: _daysAgo(1),
        ),
      },
    ).encode();

    await tester.pumpWidget(await _app(track: track));
    await tester.pump(const Duration(milliseconds: 400));

    for (final forbidden in [
      '1540', // المجموع القديم
      '2000', // مجموع المسار كله
      '30', // عدد المطالبات اليومية
      'بقي', // «بقي لك N ألماسة»
      'من 30', // «3 من 30»
      'ستة أشهر',
    ]) {
      expect(
        find.textContaining(forbidden),
        findsNothing,
        reason: 'ظهر «$forbidden» على شاشة الجوائز',
      );
    }
  });

  testWidgets('الملخّص يعدّ ما جُمع صعودا لا ما بقي نزولا', (tester) async {
    final track = RewardTrackState(
      startDay: _daysAgo(3),
      tiers: {
        RewardTier.daily: RewardTierProgress(
          claimed: 3,
          lastClaimDay: _daysAgo(1),
        ),
      },
    ).encode();

    await tester.pumpWidget(await _app(track: track));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('جمعت 60'), findsOneWidget);
  });

  testWidgets('مسار لم يُطالَب فيه بشيء: دعوة لا صفر', (tester) async {
    await tester.pumpWidget(await _app());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('جوائزك بانتظارك'), findsOneWidget);
  });

  testWidgets('لا تجاوز تخطيط على أضيق جهاز ندعمه (360×640)', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app());
    await tester.pump(const Duration(milliseconds: 400));
    // تمرير حتى النهاية كي تُبنى كل البطاقات فعلا
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });
}
