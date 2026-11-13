// ضبط الإعلانات للدخل (2026-11-09): لا طلب إعلان بيني قبل أن يقترب اللاعب
// من أول مرحلة يُسمح فيها، ولا إعادة محاولة بلا نهاية حين لا تملأ الشبكة،
// ومضاعفة الجائزة اليومية بإعلان يختاره اللاعب.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/ads/ad_format.dart';
import 'package:huruf/data/ads/ad_load_policy.dart';
import 'package:huruf/data/ads/rewarded_ads.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/shop_screen.dart';
import 'package:huruf/presentation/widgets/double_reward.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => AudioService.disabled = true);

  group('AdLoadPolicy', () {
    test('no interstitial load before the player nears stage 13', () {
      expect(AdLoadPolicy.wantsInterstitial(maxUnlocked: 1), isFalse);
      expect(AdLoadPolicy.wantsInterstitial(maxUnlocked: 11), isFalse);
      expect(AdLoadPolicy.wantsInterstitial(maxUnlocked: 12), isTrue);
      expect(AdLoadPolicy.wantsInterstitial(maxUnlocked: 40), isTrue);
    });

    test('automatic retries stop after three misses', () {
      expect(AdLoadPolicy.retryDelay(1), const Duration(seconds: 15));
      expect(AdLoadPolicy.retryDelay(2), const Duration(seconds: 30));
      expect(AdLoadPolicy.retryDelay(3), const Duration(seconds: 60));
      expect(AdLoadPolicy.retryDelay(4), isNull);
    });
  });

  test('daily reward surface is a long, chosen ad', () {
    expect(RewardedSurface.dailyReward.placement, 'daily_reward');
    expect(AdFormats.forSurface(RewardedSurface.dailyReward), AdLength.long);
  });

  testWidgets('claiming the daily reward offers to double it with an ad', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'player_name_asked': true});
    final sp = await SharedPreferences.getInstance();
    final store = ProgressStore(sp);
    final progression = await ProgressionRepository.load(
      prefs: sp,
      legacy: store,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressStoreProvider.overrideWithValue(store),
          progressionRepositoryProvider.overrideWithValue(progression),
        ],
        child: MaterialApp(theme: HurufTheme.build(), home: const ShopScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(DoubleRewardButton), findsNothing);

    final claim = find.ancestor(
      of: find.textContaining(RegExp(r'^\+\d+$')),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(claim);
    await tester.tap(claim);
    await tester.pump(const Duration(milliseconds: 600));

    final double = tester.widget<DoubleRewardButton>(
      find.byType(DoubleRewardButton),
    );
    expect(double.surface, RewardedSurface.dailyReward);
    expect(double.amount, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });
}
