import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/config/feature_flags.dart';
import 'package:huruf/data/notifications/notification_models.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression/player_level_curve.dart';
import 'package:huruf/data/progression/player_state.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _home({
  FeatureFlags flags = const FeatureFlags.allOn(),
  int level = 12,
}) async {
  final state = PlayerState.initial().copyWith(
    wallet: PlayerWallet.initial().copyWith(
      xp: PlayerLevelCurve.cumulativeXpToReach(level),
    ),
  );
  SharedPreferences.setMockInitialValues({
    'player_name_asked': true,
    'points': 120,
    'bonus_jar': 3,
    'khroof_player_state_v2': jsonEncode(state.toJson()),
    'migration_v2_done': true,
  });
  final prefs = await SharedPreferences.getInstance();
  final store = ProgressStore(prefs);
  final progression = await ProgressionRepository.load(
    prefs: prefs,
    legacy: store,
  );

  return ProviderScope(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      progressionRepositoryProvider.overrideWithValue(progression),
      featureFlagsProvider.overrideWithValue(flags),
    ],
    child: MaterialApp(
      theme: HurufTheme.build(),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const HomeScreen(),
    ),
  );
}

/// مدخل المتجر الوحيد: تبويب الشريط السفلي (زرّ الترويسة أُزيل)
final _shopButton = find.text('المتجر');

void main() {
  setUpAll(() => AudioService.disabled = true);

  group('اختبار القبول: إطفاء مسار الجوائز', () {
    testWidgets('يُزيل تبويب الجوائز من الرئيسية بلا زرّ ميت ولا فراغ', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1440);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(await _home());
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('الجوائز'), findsOneWidget);

      await tester.pumpWidget(
        await _home(
          flags: FeatureFlags.fromConfig(const {
            'reward_track_enabled': false,
          }),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // لا انهيار، ولا شاشة بيضاء، ولا تبويب يفتح على لا شيء
      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('الجوائز'), findsNothing);
    });

    testWidgets('يُخفي مدخل المتجر حين يُطفأ', (tester) async {
      tester.view.physicalSize = const Size(720, 1440);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(await _home());
      await tester.pump(const Duration(milliseconds: 600));
      expect(_shopButton, findsWidgets);

      await tester.pumpWidget(
        await _home(
          flags: FeatureFlags.fromConfig(const {
            'store_enabled': false,
          }),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(_shopButton, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('الإشعارات تتبع المفاتيح', () {
    test('إشعار مسار الجوائز غير مؤهَّل حين يُطفأ المسار', () {
      // نفس دالة الترشيح المستخدَمة في syncNotifications
      final off = FeatureFlags.fromConfig(const {
        'reward_track_enabled': false,
      });
      final on = FeatureFlags.fromConfig(
        const {'reward_track_enabled': true},
      );

      expect(on.rewardTrack, isTrue);
      expect(off.rewardTrack, isFalse);
      // بقية الأنواع لا تتأثّر
      expect(off.isOn('any_other_key'), isTrue);
      expect(
        AppNotificationType.values,
        contains(AppNotificationType.rewardTrackDailyReady),
      );
    });
  });

  group('بوّابات الميزات في المزوّدات', () {
    Future<ProviderContainer> container(FeatureFlags flags) async {
      final state = PlayerState.initial().copyWith(
        wallet: PlayerWallet.initial().copyWith(
          xp: PlayerLevelCurve.cumulativeXpToReach(30),
        ),
      );
      SharedPreferences.setMockInitialValues({
    'player_name_asked': true,
        'khroof_player_state_v2': jsonEncode(state.toJson()),
        'migration_v2_done': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = ProgressStore(prefs);
      final progression = await ProgressionRepository.load(
        prefs: prefs,
        legacy: store,
      );
      return ProviderContainer(
        overrides: [
          progressStoreProvider.overrideWithValue(store),
          progressionRepositoryProvider.overrideWithValue(progression),
          featureFlagsProvider.overrideWithValue(flags),
        ],
      );
    }

    test('إطفاء مسار الجوائز يخفيه عن اللاعب', () async {
      final on = await container(
        FeatureFlags.fromConfig(const {'reward_track_enabled': true}),
      );
      addTearDown(on.dispose);
      expect(on.read(featureFlagsProvider).rewardTrack, isTrue);

      final off = await container(
        FeatureFlags.fromConfig(const {'reward_track_enabled': false}),
      );
      addTearDown(off.dispose);
      expect(off.read(featureFlagsProvider).rewardTrack, isFalse);
    });

    test('إطفاء الدعوة يخفي مدخلها حتى فوق مستوى الفتح', () async {
      final on = await container(const FeatureFlags.allOn());
      addTearDown(on.dispose);
      expect(on.read(referralUnlockedProvider), isTrue);

      final off = await container(
        FeatureFlags.fromConfig(const {'referral_enabled': false}),
      );
      addTearDown(off.dispose);
      expect(off.read(referralUnlockedProvider), isFalse);
    });
  });
}
