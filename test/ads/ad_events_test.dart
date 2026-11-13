// دورة حياة الإعلان في PostHog (المواصفة §4.4): القرار المقصود («مبكّر
// جدا»، «لم يحن الدور») ad_skipped لا ad_failed، والعرض يُسجَّل حين يحدث
// فعلا. ومنع البيني في بداية اللعبة (المواصفة §10).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/ad_service.dart';
import 'package:huruf/data/ads/ad_format.dart';
import 'package:huruf/data/ads/ad_pacing.dart';
import 'package:huruf/data/ads/ad_policy.dart';
import 'package:huruf/data/ads/policy_gated_ad_service.dart';
import 'package:huruf/data/ads/rewarded_ads.dart';
import 'package:huruf/data/analytics/analytics_event.dart';
import 'package:huruf/data/analytics/analytics_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Rig {
  final ProviderContainer c;
  final ProgressStore store;
  final List<AnalyticsEvent> events;
  _Rig(this.c, this.store, this.events);

  List<String> get names => [for (final e in events) e.name];
  Map<String, Object?> last(String name) =>
      events.lastWhere((e) => e.name == name).properties;
}

Future<_Rig> _rig({int completions = 0, bool played = true}) async {
  SharedPreferences.setMockInitialValues({});
  final store = ProgressStore(await SharedPreferences.getInstance());
  await store.setCompletionsSinceInterstitial(completions);
  final events = <AnalyticsEvent>[];
  final c = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      analyticsProvider.overrideWithValue(AnalyticsService(sink: events.add)),
    ],
  );
  addTearDown(c.dispose);
  if (played) c.read(sessionGameplayProvider.notifier).markGameplayStarted();
  return _Rig(c, store, events);
}

void main() {
  group('interstitial on leaving a completed stage', () {
    test('stage 5 → requested then skipped too_early_in_game', () async {
      final r = await _rig(completions: 9);
      final cue = r.c
          .read(interstitialGateProvider.notifier)
          .decideOnLeave(stageNumber: 5, placement: 'next_stage', adReady: true);
      expect(cue, AdCue.none);
      expect(r.names, [Ev.adRequested, Ev.adSkipped]);
      expect(r.last(Ev.adSkipped)['reason'], 'too_early_in_game');
      expect(r.last(Ev.adSkipped)['ad_type'], 'interstitial');
      expect(r.last(Ev.adSkipped)['placement'], 'next_stage');
      expect(r.last(Ev.adSkipped)['stage_id'], 5);
    });

    test('stage 13 with cadence reached and ad ready → eligible', () async {
      final r = await _rig(completions: 5);
      final cue = r.c
          .read(interstitialGateProvider.notifier)
          .decideOnLeave(stageNumber: 13, placement: 'next_stage', adReady: true);
      expect(cue, AdCue.interstitial);
      expect(r.names, [Ev.adRequested, Ev.adEligible]);
      expect(r.store.completionsSinceInterstitial, 0);
      expect(r.store.lastAdShownAt, isNotNull);
    });

    test('allowed but not ready → skipped not_loaded, counter unchanged',
        () async {
      final r = await _rig(completions: 5);
      final cue = r.c
          .read(interstitialGateProvider.notifier)
          .decideOnLeave(stageNumber: 13, placement: 'home', adReady: false);
      expect(cue, AdCue.none);
      expect(r.last(Ev.adSkipped)['reason'], 'not_loaded');
      expect(r.store.completionsSinceInterstitial, 5);
      expect(r.store.lastAdShownAt, isNull);
    });

    test('cadence not reached is a skip, not a failure', () async {
      final r = await _rig(completions: 1);
      r.c
          .read(interstitialGateProvider.notifier)
          .decideOnLeave(stageNumber: 20, placement: 'next_stage', adReady: true);
      expect(r.last(Ev.adSkipped)['reason'], 'cadence_not_reached');
    });
  });

  group('rewarded', () {
    test('without budget → requested then skipped budget_exhausted', () async {
      final r = await _rig();
      final budget = r.c.read(globalAdBudgetProvider.notifier);
      while (budget.consume()) {}
      r.events.clear(); // ما سُجّل أثناء الاستهلاك ليس موضوع الاختبار
      final request = r.c
          .read(rewardedAdsProvider.notifier)
          .begin(RewardedSurface.coinTopUp);
      expect(request, isNull);
      expect(r.names, [Ev.adRequested, Ev.adSkipped]);
      expect(r.last(Ev.adSkipped)['reason'], 'budget_exhausted');
      expect(r.last(Ev.adSkipped)['placement'], 'coin_top_up');
    });

    test('complete → reward_granted with placement level_reward', () async {
      final r = await _rig();
      final rewarded = r.c.read(rewardedAdsProvider.notifier);
      final request = rewarded.begin(RewardedSurface.levelReward)!;
      expect(r.names, [Ev.adRequested, Ev.adEligible]);
      final granted = rewarded.complete(request);
      expect(granted, greaterThan(0));
      final props = r.last(Ev.adRewardGranted);
      expect(props['placement'], 'level_reward');
      expect(props['reward_type'], 'coins');
      expect(props['coins'], granted);
      expect(
        r.names,
        isNot(contains(Ev.adShown)),
        reason: 'ad_shown comes only from the ad service callback',
      );
    });

    test('placements are snake_case', () {
      expect(RewardedSurface.coinTopUp.placement, 'coin_top_up');
      expect(RewardedSurface.chapterChest.placement, 'chapter_chest');
      expect(RewardedSurface.hint.placement, 'hint');
      expect(AdFormats.forSurface(RewardedSurface.hint), AdLength.short);
    });
  });

  group('no interstitial in the opening stages (spec §10)', () {
    InterstitialRequest req(int stage, {bool played = true}) =>
        InterstitialRequest(
          stageNumber: stage,
          completionsSinceLastInterstitial: 99,
          formatAllowed: true,
          adsRemoved: false,
          stageCleared: true,
          rewardSequenceComplete: true,
          hadGameplayThisSession: played,
          now: DateTime(2026, 11, 9),
        );

    test('stages 1..12 are always too early', () {
      for (var stage = 1; stage <= 12; stage++) {
        expect(
          AdPacing.decideInterstitial(req(stage)).reason,
          AdBlockReason.tooEarlyInGame,
          reason: 'stage $stage',
        );
      }
    });

    test('no interstitial before the first play of a session', () {
      expect(
        AdPacing.decideInterstitial(req(20, played: false)).reason,
        AdBlockReason.coldStart,
      );
    });

    test('block reasons have snake_case wire names', () {
      expect(AdBlockReason.tooEarlyInGame.wire, 'too_early_in_game');
      expect(AdBlockReason.cadenceNotReached.wire, 'cadence_not_reached');
      expect(AdBlockReason.globalCooldown.wire, 'global_cooldown');
      expect(AdBlockReason.coldStart.wire, 'cold_start');
    });
  });

  testWidgets('placement passes through PolicyGatedAdService', (tester) async {
    final inner = _RecordingAds();
    final gate = PolicyGatedAdService(
      inner,
      policy: AdFormatPolicy.currentBuild,
    );
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    await gate.showInterstitial(context, placement: 'next_stage');
    await gate.showRewarded(context, length: AdLength.short, placement: 'hint');
    expect(inner.placements, ['next_stage', 'hint']);
  });
}

class _RecordingAds implements AdService {
  final placements = <String?>[];
  @override
  Future<void> init() async {}
  @override
  Future<void> preload() async {}
  @override
  bool get isInterstitialReady => true;
  @override
  bool get isRewardedReady => true;
  @override
  Future<InterstitialResult> showInterstitial(
    BuildContext context, {
    VoidCallback? onOpenShop,
    String? placement,
  }) async {
    placements.add(placement);
    return InterstitialResult.dismissed;
  }

  @override
  Future<bool> showRewarded(
    BuildContext context, {
    required AdLength length,
    String? placement,
  }) async {
    placements.add(placement);
    return true;
  }
}
