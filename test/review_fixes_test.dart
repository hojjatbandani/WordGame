// إصلاحات المراجعة النهائية (C1، I1–I7). كل اختبار هنا فشل قبل إصلاحه.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/ad_service.dart';
import 'package:huruf/data/ads/ad_format.dart';
import 'package:huruf/data/ads/ad_policy.dart';
import 'package:huruf/data/analytics/analytics_event.dart';
import 'package:huruf/data/analytics/analytics_service.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/models.dart';
import 'package:huruf/data/onboarding/tutorial_coach.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/game_screen.dart';
import 'package:huruf/presentation/screens/home_screen.dart';
import 'package:huruf/presentation/screens/map_entry.dart';
import 'package:huruf/presentation/widgets/letter_wheel.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameLevel _level(int id, {List<WordEntry>? words, List<String>? letters}) =>
    GameLevel(
      id: id,
      letters: letters ?? const ['ق', 'ل', 'م'],
      words:
          words ?? const [WordEntry(word: 'قلم', definition: 'أداة الكتابة')],
      bonusWords: const [],
      difficulty: 1,
    );

class _AlwaysWatchedAds implements AdService {
  @override
  Future<void> init() async {}
  @override
  Future<void> preload() async {}
  @override
  bool get isInterstitialReady => false;
  @override
  bool get isRewardedReady => true;
  @override
  Future<InterstitialResult> showInterstitial(
    BuildContext context, {
    VoidCallback? onOpenShop,
    String? placement,
  }) async => InterstitialResult.unavailable;
  @override
  Future<bool> showRewarded(
    BuildContext context, {
    required AdLength length,
    String? placement,
  }) async => true;
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 4));
}

/// يسحب الإصبع على العجلة عبر [indices] (هندسة LetterWheel)
Future<void> _drag(WidgetTester tester, List<int> indices, int n) async {
  final rect = tester.getRect(find.byType(LetterWheel));
  final side = rect.shortestSide;
  final radius = side / 2 - side * 0.115 - 6;
  Offset at(int i) {
    final angle = -pi / 2 + 2 * pi * i / n;
    return rect.center + Offset(cos(angle) * radius, sin(angle) * radius);
  }

  final g = await tester.startGesture(at(indices.first));
  await tester.pump();
  for (final i in indices.skip(1)) {
    await g.moveTo(at(i));
    await tester.pump();
  }
  await g.up();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() => AudioService.disabled = true);

  // ───── C1: لاعب قديم يحدّث التطبيق ليس لاعبا جديدا
  group('C1 upgrade migration', () {
    Future<ProgressStore> store(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      return ProgressStore(await SharedPreferences.getInstance());
    }

    test('player past onboarding is migrated', () async {
      final s = await store({'max_unlocked': 40});
      await s.migrateJourneyFlags();
      expect(s.onboardingCompleted, isTrue);
      expect(s.firstStageStarted, isTrue);
    });

    test('player mid-onboarding keeps the tutorial', () async {
      final s = await store({'max_unlocked': 2});
      await s.migrateJourneyFlags();
      expect(s.onboardingCompleted, isFalse);
      expect(s.firstStageStarted, isTrue);
    });

    test('brand-new install is untouched', () async {
      final s = await store({});
      await s.migrateJourneyFlags();
      expect(s.onboardingCompleted, isFalse);
      expect(s.firstStageStarted, isFalse);
    });
  });

  // ───── I1: إغلاق نافذة فوق الرئيسية ليس «عودة إلى الرئيسية»
  testWidgets('I1 closing a dialog on Home is not a home view', (tester) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({
      'max_unlocked': 4,
      'onboarding_completed': true,
      'player_name_asked': true,
    });
    final sp = await SharedPreferences.getInstance();
    final store = ProgressStore(sp);
    final progression = await ProgressionRepository.load(
      prefs: sp,
      legacy: store,
    );
    final events = <AnalyticsEvent>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressStoreProvider.overrideWithValue(store),
          progressionRepositoryProvider.overrideWithValue(progression),
          analyticsProvider.overrideWithValue(
            AnalyticsService(sink: events.add),
          ),
        ],
        child: MaterialApp(
          theme: HurufTheme.build(),
          navigatorObservers: [hurufRouteObserver],
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final context = tester.element(find.byType(HomeScreen));
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: Text('x')),
    );
    await tester.pump(const Duration(milliseconds: 400));
    Navigator.of(context).pop();
    await tester.pump(const Duration(milliseconds: 400));
    expect(events.where((e) => e.name == Ev.homeViewed), hasLength(1));
    await _drain(tester);
  });

  // ───── I2، I3: تلميح بإعلان
  group('hint ad', () {
    Future<List<AnalyticsEvent>> pumpPoorStage5(WidgetTester tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues({
        'player_name_asked': true,
        'onboarding_completed': true,
      });
      final store = ProgressStore(await SharedPreferences.getInstance());
      final events = <AnalyticsEvent>[];
      final level = _level(
        5,
        letters: const ['ح', 'ل', 'م'],
        words: const [
          WordEntry(word: 'ملح', definition: 'ما يطيب به الطعام'),
          WordEntry(word: 'حلم', definition: 'ما يُرى في النوم'),
        ],
      );
      final c = ProviderContainer(
        overrides: [
          progressStoreProvider.overrideWithValue(store),
          levelsProvider.overrideWith((ref) => [level]),
          analyticsProvider.overrideWithValue(
            AnalyticsService(sink: events.add),
          ),
          adServiceProvider.overrideWithValue(_AlwaysWatchedAds()),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: GameScreen(level: level, allLevels: [level]),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      final hint = find.bySemanticsLabel(RegExp('كشف الحرف التالي'));
      await tester.tap(hint); // المجاني
      await tester.pump(const Duration(seconds: 1));
      c.read(pointsProvider.notifier).spend(c.read(pointsProvider) - 5);
      await tester.tap(hint);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return events;
    }

    testWidgets('I2 insufficient sheet cannot be dismissed by the barrier', (
      tester,
    ) async {
      await pumpPoorStage5(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tapAt(const Offset(180, 60));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BottomSheet), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('I2 grant is logged after the hint is applied', (tester) async {
      final events = await pumpPoorStage5(tester);
      await tester.tap(find.byKey(const ValueKey('hint_ad_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final names = [for (final e in events) e.name];
      final used = names.lastIndexOf(Ev.hintUsed);
      final granted = names.lastIndexOf(Ev.adRewardGranted);
      expect(events[used].properties['paid_with'], 'ad');
      expect(granted, greaterThan(used));
      expect(events[granted].properties['placement'], 'hint');
      await _drain(tester);
    });

    testWidgets('I3 hint ad button is not styled as a game reward', (
      tester,
    ) async {
      await pumpPoorStage5(tester);
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('hint_ad_button')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).gradient, isNull);
      await _drain(tester);
    });
  });

  // ───── I4: جملة «التلميح المجاني» تختفي بعد استعماله
  group('I4 coach wording', () {
    test('using the hint clears the free-hint instruction', () {
      final c =
          TutorialCoach(
              stageId: 1,
              onboardingCompleted: false,
              bonusExplainedBefore: false,
            )
            ..onWrong()
            ..onWrong();
      expect(c.view.instruction, CoachText.useFreeHint);
      c.onHintUsed();
      expect(c.view.instruction, isNull);
      expect(c.view.highlightHint, isFalse);
    });

    test('reveal without a free hint says try the hint', () {
      final c = TutorialCoach(
        stageId: 1,
        onboardingCompleted: false,
        bonusExplainedBefore: false,
      )..freeHintAvailable = false;
      c
        ..onWrong()
        ..onWrong();
      expect(c.view.instruction, CoachText.tryHint);
    });
  });

  // ───── I5: كشف التلميح بعد خطأين يُسجَّل
  testWidgets('I5 tutorial reveal after two wrongs is logged', (tester) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({'player_name_asked': true});
    final store = ProgressStore(await SharedPreferences.getInstance());
    final events = <AnalyticsEvent>[];
    final level = _level(1);
    final c = ProviderContainer(
      overrides: [
        progressStoreProvider.overrideWithValue(store),
        levelsProvider.overrideWith((ref) => [level]),
        analyticsProvider.overrideWithValue(AnalyticsService(sink: events.add)),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: GameScreen(level: level, allLevels: [level]),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await _drag(tester, [1, 0], 3); // «لق» خطأ
    await _drag(tester, [2, 1], 3); // «مل» خطأ
    final viewed = events.where((e) => e.name == Ev.hintViewed).toList();
    expect(viewed, hasLength(1));
    expect(viewed.single.properties['trigger'], 'tutorial');
    await _drain(tester);
  });

  // ───── I6: إعلان دورة العجلة يُسجَّل طلبه وأهليته
  test('I6 wheel ad spin logs requested then eligible', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore(await SharedPreferences.getInstance());
    final events = <AnalyticsEvent>[];
    final c = ProviderContainer(
      overrides: [
        progressStoreProvider.overrideWithValue(store),
        analyticsProvider.overrideWithValue(AnalyticsService(sink: events.add)),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(wheelProvider.notifier).beginAdSpin(), isTrue);
    expect([for (final e in events) e.name], [Ev.adRequested, Ev.adEligible]);
    expect(events.last.properties['placement'], 'wheel');
  });

  // ───── I7: بناء بلا إعلانات صامت تماما عند مغادرة المرحلة
  testWidgets('I7 ads-off build stays silent on stage exit', (tester) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({
      'player_name_asked': true,
      'onboarding_completed': true,
    });
    final store = ProgressStore(await SharedPreferences.getInstance());
    final events = <AnalyticsEvent>[];
    final levels = [for (var i = 1; i <= 20; i++) _level(i)];
    final c = ProviderContainer(
      overrides: [
        progressStoreProvider.overrideWithValue(store),
        levelsProvider.overrideWith((ref) => levels),
        analyticsProvider.overrideWithValue(AnalyticsService(sink: events.add)),
        adFormatPolicyProvider.overrideWithValue(AdFormatPolicy.none),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: GameScreen(level: levels[14], allLevels: levels),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await _drag(tester, [0, 1, 2], 3);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('المرحلة التالية'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('المرحلة 16'), findsOneWidget);
    expect(
      [for (final e in events) e.name].where((n) => n.startsWith('ad_')),
      isEmpty,
    );
    await _drain(tester);
  });
}
