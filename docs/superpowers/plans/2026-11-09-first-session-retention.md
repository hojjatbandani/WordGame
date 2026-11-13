# First-session retention Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** New Huruf players reach a playable, self-teaching Stage 1 in seconds, waste no coins on hints while learning, flow stage → success → next, keep progress across exits, and every step (including the full ad lifecycle) is measurable in PostHog.

**Architecture:** Pure-Dart decision modules (stage session, hint pricing, tutorial coach) carry the logic and the unit tests; screens only wire them. Analytics names live in `Ev`; the ad service reports real SDK callbacks through an injected sink; content changes are produced by idempotent tools over `levels.json`.

**Tech Stack:** Flutter 3.47.5 / Dart 3.13.4, Riverpod 3, shared_preferences, google_mobile_ads 9.1, posthog_flutter 5.

**Spec:** `docs/superpowers/specs/2026-11-07-first-session-retention-design.md` (sections referenced as §n).

## Global Constraints

- Flutter binary: `/d/PersonalProjects/FlutterSDK/flutter/bin/flutter` (not on PATH). Git: `git -c safe.directory='D:/PersonalProjects/Words Game'`.
- Code comments in Arabic, matching the project. Game-screen copy is Arabic only; Home/overlay copy uses `lang.t(ar, en)`.
- Every balance number lives in `BalanceConfig` as a mutable static (remote-configurable).
- Families policy: every ad entry point shows `AdBadge` and says «إعلان»/"ad"; no purchase offers during stages 1–10.
- Event names only via `Ev`; property names snake_case exactly as in spec §4.
- No emoji in new UI text (app font IRANSans lacks them); use Material icons.
- Do not regenerate `levels.json`; only the tools of Task 6 may edit it.
- Commits: only when the user asks (user rule). "Commit" steps below are checkpoints — stage the files, do not commit unless authorised.

## Review Focus

1. A player who backgrounds the app mid-stage and returns after hours must continue the same stage with no `stage_abandon` logged (Task 7 test `background then resume logs no abandon`).
2. A veteran (onboarding done) replaying Stage 1 must see the normal stage — no coach, hint buttons visible (Task 9 test `veteran replay has no coach`).
3. A tap on a hint while the confirmation sheet is open must not buy twice (Task 8 test `double tap buys once`).
4. Restored resume data for a stage whose content changed (Task 6 reorder) must not crash or show impossible words (Task 7 test `resume ignores words not in level`).
5. A build with ads disabled (production v3 policy) must emit no ad events at all on stage exit (Task 5 test `disabled build stays silent`).

---

### Task 1: Analytics foundation and journey flags

**Files:**
- Modify: `lib/data/analytics/analytics_event.dart`, `lib/data/analytics/analytics_service.dart`, `lib/data/analytics/posthog_sink.dart`, `lib/data/progress_store.dart`, `lib/presentation/providers.dart` (`PointsNotifier.spend`)
- Test: `test/analytics/analytics_service_test.dart`, `test/analytics/posthog_sink_test.dart`, Create `test/progress_store_journey_test.dart`

**Interfaces:**
- Produces: `Ev` constants (spec §4.1) — `homeViewed, continuePlayClicked, newGameStarted, onboardingStarted, onboardingCompleted, stageSelected, nextStageClicked, hintViewed, hintUnavailable, coinsSpendFailed, worldViewed, rewardsViewed, shopViewed, purchaseFailed, adEligible, adSkipped, adLoaded, adLoadFailed, adClicked, adRewardEarned, adDismissed`; removed `adFailed`, `storeOpened`.
- Produces: `AnalyticsService.clearStage(int stageId)` — clears only if the context still holds `stageId`.
- Produces on `ProgressStore`: `int? get firstOpenAtMs` + `Future<void> ensureFirstOpenAt(int nowMs)`; `bool get firstStageStarted` + `setFirstStageStarted(bool)`; `bool get onboardingCompleted` + `setOnboardingCompleted(bool)`; `int? get onboardingStartedAtMs` + `setOnboardingStartedAtMs(int)`; `Future<int> bumpStageAttempt(int stageId)` (returns new count, JSON map key `stage_attempts`); `String? get activeStageSessionJson` + `setActiveStageSessionJson(String?)` (null removes); `String? get stageResumeJson` + `setStageResumeJson(String?)`; `bool get pendingRatingPrompt` + `setPendingRatingPrompt(bool)`; `bool get bonusWordExplained` + `setBonusWordExplained(bool)`. `first_open_at` and `first_stage_started` are in `_preservedOnReset`; the rest reset.

- [ ] **Step 1: Write failing tests**
  - `analytics_service_test`: `clearStage ignores another stage` — `updateContext(stageId: 5); clearStage(4); log('x')` → event has `stageId == 5`; `clearStage(5)` → null.
  - `analytics_service_test`: `Ev.all is unique snake_case and has no ad_failed` — every name matches `^[a-z]+(_[a-z]+)*$`, `Ev.all.toSet().length == Ev.all.length`, `!Ev.all.contains('ad_failed')`, contains `'ad_reward_earned'`, `'ad_loaded'`, `'ad_dismissed'`.
  - `posthog_sink_test`: `every event carries build_type` — `propertiesFor(AnalyticsEvent(name: 'x'))['build_type'] == 'debug'` under `flutter test`.
  - `progress_store_journey_test`: round-trip of every new accessor; `bumpStageAttempt(3)` twice → 2; `resetProgress()` keeps `firstOpenAtMs` and `firstStageStarted`, clears `onboardingCompleted`, `stageResumeJson`, `activeStageSessionJson`.
  - Add to an existing economy test (`test/economy/economy_wiring_test.dart`): failed spend logs `coins_spend_failed` and no `coins_spent`.
- [ ] **Step 2: Run** `flutter test test/analytics test/progress_store_journey_test.dart test/economy/economy_wiring_test.dart` — Expected: FAIL (missing members).
- [ ] **Step 3: Implement** the interfaces above; `build_type` = `kReleaseMode ? 'release' : kProfileMode ? 'profile' : 'debug'`; `GameScreen.dispose` call site becomes `clearStage(widget.level.id)`; fix compile errors where `Ev.adFailed`/`Ev.storeOpened` were referenced by switching them to the Task-5 names temporarily as `Ev.adSkipped` (Task 5 finalises props).
- [ ] **Step 4: Run** the same command — Expected: PASS.
- [ ] **Step 5: Checkpoint** (stage files).

### Task 2: StageSession module (pure Dart)

**Files:**
- Create: `lib/data/analytics/stage_session.dart`
- Test: Create `test/analytics/stage_session_test.dart`

**Interfaces:**
- Consumes: nothing from Flutter.
- Produces:
  - `enum ExitReason { backButton, systemBack, homeButton, appBackgrounded, appClosed, stageChanged, worldChanged, unknown }` with `String get wire` (`back_button`, `system_back`, …).
  - `enum SessionLifecycle { foreground, background, detached }`.
  - `class StageProgressState { Set<String> solved; Map<String, Set<int>> revealed; int wrongAttempts; int hintsUsed; bool freeHintUsed; int activeMs; List<String> rejectedWords; Map<String,Object?> toJson(); factory fromJson(Map); }`
  - `class StageSession` — ctor `({required String sessionId, required int stageId, required int worldId, required int chapterId, required String source, required int attempt, required bool isReplay, required bool tutorial, required int wordsTotal, required int nowMs, StageProgressState? restored})`; `bool get resumed`; `StageProgressState get progress`; `SessionLifecycle lifecycle`; `int lastSeenAtMs`; `bool ended`; methods `pause(int nowMs)`, `resume(int nowMs)`, `markDetached(int nowMs)`, `int activeMs(int nowMs)`, `addSolved(String)`, `addWrong(String word, {required int cap})` (counts every wrong, stores unique words of length ≥ 3 up to `cap`), `addHint({required String word, required int position, required bool free})`, `Map<String,Object?> props({required int nowMs, required int bonusWords})` → keys exactly: `stage_id, world_id, chapter_id, duration_ms, wrong_attempts, hints_used, words_total, words_solved, bonus_words, attempt, is_replay, source, resumed, tutorial`; `toJson()` / `fromJson()` (includes meta + lifecycle + `lastSeenAtMs` + `coinBalance`, `playerLevel`).
  - `List<(String, Map<String,Object?>)> recoveredExitEvents(String? activeJson, {required int nowMs, required int failThreshold})` — empty for null/ended; else `stage_abandon` (+ `stage_fail` when `wrongAttempts ≥ failThreshold`) with `props(...)` + `exit_reason` (`app_backgrounded` if lifecycle background, else `app_closed`), `last_state`, `recovered: true`, `ended_at_ms`, `rejected_words`, `player_level`, `coin_balance`.
  - `Map<int, StageProgressState> decodeResume(String?)` / `String encodeResume(Map<int, StageProgressState>, {required int keep, required List<int> recency})` keeping the `keep` most recent stage ids.

- [ ] **Step 1: Write failing tests** (`stage_session_test.dart`):
  - `active time excludes background` — start at 0, pause at 10 000, resume at 70 000, `activeMs(80 000) == 20 000`.
  - `props has exactly the standard keys` — set equality with the list above.
  - `rejected words unique, min length 3, capped` — 20 distinct 3-letter wrongs + one 2-letter + duplicates with cap 15 → `wrongAttempts` counts all, `rejectedWords.length == 15`, no 2-letter word.
  - `json round trip keeps progress and lifecycle`.
  - `recovery: background → app_backgrounded`, `detached → app_closed`, `foreground → app_closed with last_state foreground`, `ended → no events`, `fail threshold adds stage_fail`.
  - `resume keeps the 3 most recent stages`.
- [ ] **Step 2: Run** `flutter test test/analytics/stage_session_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement** per Interfaces.
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Checkpoint.**

### Task 3: Balance fields and HintPricing (pure Dart)

**Files:**
- Modify: `lib/config/balance_config.dart`
- Create: `lib/data/economy/hint_pricing.dart`
- Test: Create `test/economy/hint_pricing_test.dart`

**Interfaces:**
- Produces in `BalanceConfig` (spec §11): `onboardingStageCount = 3`, `earlyGameStageLimit = 10`, `coinsHintOrderedLetterEarly = 20`, `coinsHintRandomLetterEarly = 10`, `hintConfirmBalanceShare = 0.25`, `hintTapDebounce = Duration(milliseconds: 600)`, `tutorialRevealHintAfterWrongAttempts = 2`, `tutorialRevealHintAfterIdle = Duration(seconds: 20)`, `tutorialDemoIfNoTouchAfter = Duration(seconds: 5)`, `assistAfterWrongAttempts = 3`, `assistAfterIdle = Duration(seconds: 30)`, `rejectedWordsCap = 15`, `resumeStagesKept = 3`.
- Produces: `enum HintType { orderedLetter, randomLetter }` with `wire` (`ordered_letter`, `random_letter`); `enum HintPayment { free, charge, coins, ad }` with `wire`; `class HintQuote { HintType type; int cost; HintPayment paidWith; bool affordable; bool requiresConfirm; }`; `class HintPricing { static bool isEarlyGame(int stageId); static int price(HintType, int stageId); static HintQuote quote({required HintType type, required int stageId, required bool freeHintUsed, required int charges, required int balance}); }`. Order: free (early & !freeHintUsed) → charge (charges > 0) → coins.

- [ ] **Step 1: Write failing tests:** `stage 5 first hint is free` (cost 0, free, no confirm); `stage 5 second hint costs 20 and 10 and confirms`; `stage 11 costs 40 and 25`; `free beats charge, charge beats coins`; `stage 15 balance 1000 → no confirm`; `stage 15 balance 100 cost 40 → confirm` (40 ≥ 25); `unaffordable when balance < cost and no charges`.
- [ ] **Step 2: Run** `flutter test test/economy/hint_pricing_test.dart` — FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Checkpoint.**

### Task 4: TutorialCoach (pure Dart)

**Files:**
- Create: `lib/data/onboarding/tutorial_coach.dart`
- Test: Create `test/onboarding/tutorial_coach_test.dart`

**Interfaces:**
- Produces: `abstract final class CoachText { static const formWord = 'كوّن الكلمة من الحروف'; swipe = 'اسحب إصبعك بين الحروف'; useFreeHint = 'استخدم التلميح المجاني'; great = 'رائع!'; anotherWord = 'رائع! كوّن كلمة أخرى من نفس الحروف'; bonusExplained = 'كلمة إضافية! تمنحك عملات'; tryHint = 'جرّب التلميح'; resumed = 'تابعت من حيث توقفت'; }`
- Produces: `class CoachView { String? instruction; bool showFingerDemo; bool hintButtonsVisible; bool highlightHint; String? celebration; }` and `class TutorialCoach { TutorialCoach({required int stageId, required bool onboardingCompleted, required bool bonusExplainedBefore}); bool get active; CoachView get view; bool get hintRevealedByCoach; void onTouchStart(); void onSingleLetter(); void onWrong(); void onWordSolved({required int solvedCount}); void onBonusFound(); void onTick({required Duration sinceProgress, required Duration sinceStart, required bool touchedEver}); void clearCelebration(); }` — `active` iff `!onboardingCompleted && stageId <= BalanceConfig.onboardingStageCount`.
- Produces: `bool shouldHighlightHint({required int wrongSinceProgress, required Duration sinceProgress})` (all stages; thresholds `assistAfter*`).

- [ ] **Step 1: Write failing tests** following spec §6 table: `stage 1 starts with instruction, demo, no hints`; `touch stops demo`; `single letter shows swipe + demo`; `two wrongs reveal highlighted free hint`; `20 s idle reveals hint`; `stage 1 word → great`; `stage 2 first word → anotherWord`; `stage 2 demo after 5 s without touch`; `stage 3 first bonus → bonusExplained, not when explained before`; `veteran replay has no coach` (onboardingCompleted → `active == false`, view hints visible, no instruction); `stage 4 inactive`; `assist after 3 wrongs or 30 s`.
- [ ] **Step 2: Run** `flutter test test/onboarding/tutorial_coach_test.dart` — FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Checkpoint.**

### Task 5: Ads lifecycle events and early-game guard

**Files:**
- Modify: `lib/data/ad_service.dart`, `lib/data/ads/admob_ad_service.dart`, `lib/data/ads/policy_gated_ad_service.dart`, `lib/presentation/widgets/mock_ad_service.dart`, `lib/data/ads/rewarded_ads.dart`, `lib/data/ads/ad_format.dart`, `lib/data/ads/ad_pacing.dart`, `lib/presentation/providers.dart` (`InterstitialGateNotifier`, `RewardedAdsNotifier`, wheel spin), `lib/main.dart`, callers of `showRewarded` (`double_reward.dart`, `near_miss_sheet.dart`, `wheel_screen.dart`, `shop_screen.dart`)
- Test: Create `test/ads/ad_events_test.dart`; update `test/ads/ads_disabled_build_test.dart`, `test/ads/ad_policy_test.dart`, `test/ads/ads_disabled_ui_test.dart`, `test/global_ad_budget_test.dart`, `test/ads/ad_pacing_test.dart`

**Interfaces:**
- Produces: `typedef AdEventSink = void Function(String event, Map<String, Object?> props);` in `ad_service.dart`; `showInterstitial(BuildContext, {VoidCallback? onOpenShop, String? placement})`; `showRewarded(BuildContext, {required AdLength length, String? placement})`.
- Produces: `AdMobAdService({AdFormatPolicy policy, AdEventSink? onEvent})`, `MockAdService({AdEventSink? onEvent})` emitting spec §4.4 lifecycle table (`ad_loaded`, `ad_load_failed` phase load|show, `ad_shown`, `ad_clicked`, `ad_reward_earned`, `ad_dismissed` with `shown_ms` and `reward_earned`, `ad_skipped reason=not_loaded`).
- Produces: `RewardedSurface.hint` (AdLength.short); `extension RewardedSurfacePlacement on RewardedSurface { String get placement; }` (snake_case); `extension AdBlockReasonWire on AdBlockReason { String get wire; }`.
- Produces: `InterstitialGateNotifier.decideOnLeave({required int stageNumber, required String placement, required bool adReady}) → AdCue` — logs `ad_requested`, then `ad_skipped` (reason wire / `not_loaded`) or `ad_eligible`; commits (counter reset + `lastAdShownAt`) only when allowed and ready. `requestInterstitial` stays for existing callers but no longer logs.
- Produces: `RewardedAdsNotifier.begin` logs `ad_requested` + (`ad_skipped` reason | `ad_eligible`); `complete` logs `ad_reward_granted {ad_type: rewarded, placement, reward_type: coins, coins}`; `doubleReward` → `reward_type: double_reward`; `flush` → `recovered: true`; new `grantHintFromAd()` path is in Task 8. Providers no longer log `ad_shown`. Wheel ad spin logs `ad_reward_granted {placement: wheel, reward_type: spin}`.
- `main.dart`: `AdMobAdService(policy:…, onEvent: analytics.log)` / `MockAdService(onEvent: analytics.log)`.

- [ ] **Step 1: Write failing tests** (`ad_events_test.dart`, recording `AnalyticsService(sink: events.add)`):
  - `stage 5 leave → requested then skipped too_early_in_game`.
  - `stage 13 with cadence reached and ad ready → requested, eligible, counter reset`.
  - `allowed but not ready → skipped not_loaded, counter unchanged`.
  - `disabled build stays silent` — `interstitialAdsAvailableProvider` false path emits nothing (exercise via GameScreen leave in Task 11, here assert `decideOnLeave` is never called by checking provider-level helper `shouldRequestInterstitial` returns false).
  - `rewarded without budget → requested then skipped budget_exhausted`.
  - `rewarded complete → reward_granted with placement level_reward`.
  - `no interstitial before stage 13 or before first play` — loop stages 1..12 with every other condition allowed → `AdBlockReason.tooEarlyInGame`; stage 20 with `hadGameplayThisSession: false` → `coldStart` (spec §10).
  - `placement passes through PolicyGatedAdService` (recording inner service).
- [ ] **Step 2: Run** `flutter test test/ads test/global_ad_budget_test.dart` — FAIL (new + old tests referencing `ad_failed`).
- [ ] **Step 3: Implement**; update old tests to the new names/reasons (snake_case).
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Checkpoint.**

### Task 6: Content — accepted words, bonus sync, onboarding order

**Files:**
- Create: `tool/accepted_words.txt`, `tool/sync_bonus_words.dart`, `tool/reorder_onboarding_stages.dart`, `test/levels_bonus_words_test.dart`
- Modify: `assets/data/levels.json` (by running the tools only)

**Interfaces:**
- Produces: `tool/accepted_words.txt` with the words of spec §8.1 table (one per line, `#` comments allowed).
- Produces: `tool/sync_bonus_words.dart` — `List<String> missingBonus(Map level, Set<String> vocabulary)` (exported for the test) and `main()` that appends missing words (sorted) to each level's `bonus_words`, writes `levels.json` with `JsonEncoder.withIndent('  ')` + trailing newline, prints a per-level report.
- Produces: `tool/reorder_onboarding_stages.dart` with `const newToOld = {2:15, 3:6, 4:4, 5:5, 6:13, 7:21, 8:9, 9:18, 10:19, 11:14, 12:12, 13:3, 14:16, 15:17, 16:7, 17:8, 18:10, 19:20, 20:11, 21:2, 22:22}`; refuses to run if stage 2 is already حرف/فرح (idempotent).

- [ ] **Step 1: Write failing tests** (`levels_bonus_words_test.dart`): `every bonus word is formable and not core`; `sync invariant: no dictionary or accepted word is missing` (uses `missingBonus`); `stages 1–10: 3 letters, ≤ 2 core words`; `onboarding order is the approved one` (core word sets of stages 1–12 per spec §8.2); `stage 53 accepts سنام`.
- [ ] **Step 2: Run** `flutter test test/levels_bonus_words_test.dart` — FAIL.
- [ ] **Step 3: Run tools:** `dart run tool/reorder_onboarding_stages.dart` then `dart run tool/sync_bonus_words.dart` (via `/d/PersonalProjects/FlutterSDK/flutter/bin/dart`).
- [ ] **Step 4: Run** `flutter test test/levels_bonus_words_test.dart test/levels_validation_test.dart test/levels_difficulty_curve_test.dart test/wordlist_test.dart` — PASS.
- [ ] **Step 5: Checkpoint.**

### Task 7: GameScreen — sessions, exit reasons, resume, recovery

**Files:**
- Create: `lib/presentation/screens/game/stage_session_tracker.dart`
- Modify: `lib/presentation/screens/game_screen.dart`, `lib/main.dart`, `lib/presentation/screens/stage_path_screen.dart` (pass `source: 'map'`, log `stage_selected`)
- Test: Create `test/presentation/game_session_test.dart`

**Interfaces:**
- Consumes: Task 1 store/Ev, Task 2 `StageSession`, `recoveredExitEvents`, `decodeResume/encodeResume`.
- Produces: `GameScreen({required GameLevel level, required List<GameLevel> allLevels, String source = 'other'})`.
- Produces: `class StageSessionTracker` — `static StageSessionTracker start({required ProgressStore store, required AnalyticsService? analytics, required GameLevel level, required int worldId, required int chapterId, required String source, required bool isReplay, required bool tutorial, required int nowMs})` (bumps attempt, restores resume filtered to the level's words/positions, marks a still-active previous tracker `stageChanged`/`worldChanged`, logs `stage_start` + `new_game_started` (once per install, `ms_since_first_open`) + `onboarding_started` (stage 1, onboarding not complete)); `StageSession get session`; `void solved(String)`, `void wrong(String)`, `void hint({required String word, required int position, required bool free})`, `void lifecycle(AppLifecycleState)`, `void complete({required int bonusWords, required bool perfect})` (logs `stage_complete` with `is_first_completion`, `rejected_words`; clears resume + active; logs `onboarding_completed` on first completion of `onboardingStageCount`), `void exit(ExitReason reason, {required int bonusWords})` (logs `stage_abandon` (+ `stage_fail`), keeps resume, clears active). Every mutation persists active JSON + resume JSON.
- `main.dart`: after `ProgressStore.create()` and analytics creation: `store.ensureFirstOpenAt(now)`; log `recoveredExitEvents(store.activeStageSessionJson, …)` then `setActiveStageSessionJson(null)`.
- GameScreen: `PopScope(onPopInvokedWithResult)` sets `systemBack` when no reason set; back arrow sets `backButton`; `AppLifecycleListener` → `tracker.lifecycle`; restore `_solved`/`_revealed`/`_wrongAttempts` from `session.progress`; show `CoachText.resumed` toast when restored progress > 0; `_bonusFound` seeded only with saved words in `level.bonusWords` (§7.5); `stage_complete.hints_used` = revealed positions count.

- [ ] **Step 1: Write failing tests** (`game_session_test.dart`, harness like `test/ui/hint_button_label_test.dart` plus `analyticsProvider.overrideWithValue(AnalyticsService(sink: events.add))`, level id 17):
  - `back arrow logs stage_abandon back_button`.
  - `system back logs system_back` (`tester.binding.handlePopRoute()`).
  - `background then resume logs no abandon` (`tester.binding.handleAppLifecycleStateChanged(paused)` then `resumed`).
  - `stage events carry the standard props` (stage_start keys ⊇ spec §4.2 list).
  - `progress survives leaving and is restored` — reveal a hint, pop, pump GameScreen again → revealed letter still shown, `stage_start.resumed == true`.
  - `resume ignores words not in level` — seed `stage_resume` JSON with a foreign word → no crash, nothing restored for it.
  - `recovered session logs app_backgrounded` — call the main.dart recovery helper (`recoverStageSessions(store, analytics, nowMs)`, exported from `stage_session_tracker.dart`) on seeded JSON.
- [ ] **Step 2: Run** `flutter test test/presentation/game_session_test.dart` — FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** it plus `test/ui` — PASS.
- [ ] **Step 5: Checkpoint.**

### Task 8: GameScreen — hint UX

**Files:**
- Create: `lib/presentation/widgets/hint_sheet.dart`
- Modify: `lib/presentation/screens/game_screen.dart`, `lib/presentation/providers.dart` (`RewardedAdsNotifier.watchForHint`)
- Test: Create `test/presentation/hint_flow_test.dart`; update `test/ui/hint_button_label_test.dart`

**Interfaces:**
- Consumes: Task 3 `HintPricing`/`HintQuote`, Task 5 `RewardedSurface.hint`, Task 7 tracker `hint(...)`.
- Produces: `Future<bool> showHintConfirmSheet(BuildContext, {required HintQuote quote, required int balance})` (true = use); `Future<HintSheetOutcome> showHintInsufficientSheet(BuildContext, WidgetRef, {required HintQuote quote, required int balance, required bool showShopLink})` with `enum HintSheetOutcome { cancelled, adRewarded }`; `Future<bool> RewardedAdsNotifier.watchForHint(BuildContext context)` (begin(hint) → `showRewarded(placement: 'hint')` → `consumeViewWithoutCoins` → `ad_reward_granted reward_type=hint`).
- GameScreen: both hint buttons go through `quote`; labels «مجاني» when the next hint is free; `hint_viewed`/`hint_used {hint_type, cost, paid_with, index_in_stage, stage_id, early_game}`/`hint_unavailable` per spec §4.1; spend with `reason: 'hint'`; ignore taps within `hintTapDebounce` of the last served hint and while a sheet is open; shop link only when `stageId > earlyGameStageLimit`; insufficient copy «ليس لديك عملات كافية — أكمل المراحل لتجمع العملات»; hint buttons pulse when `shouldHighlightHint` (Task 4) and log `hint_viewed trigger=assist` once per attempt.

- [ ] **Step 1: Write failing tests** (`hint_flow_test.dart`, recording analytics, stage 5 unless stated):
  - `first hint is free without sheet` (`hint_used` paid_with free, cost 0, coins unchanged).
  - `second hint asks with price and balance` (sheet shows `20` and the balance; cancel → no spend).
  - `confirm spends 20 with reason hint`.
  - `double tap buys once` (two taps 100 ms apart → one sheet / one spend).
  - `insufficient: ad option only when rewarded available, no shop link at stage 5`.
  - `stage 15 rich player buys without sheet`.
- [ ] **Step 2: Run** `flutter test test/presentation/hint_flow_test.dart` — FAIL.
- [ ] **Step 3: Implement**; update `hint_button_label_test.dart` to stage id 17 (outside early game) so its charge-label assertions stay meaningful.
- [ ] **Step 4: Run** it plus `test/ui` and `test/economy` — PASS.
- [ ] **Step 5: Checkpoint.**

### Task 9: GameScreen — in-stage tutorial

**Files:**
- Create: `lib/presentation/widgets/coach_banner.dart`
- Modify: `lib/presentation/widgets/letter_wheel.dart`, `lib/presentation/screens/game_screen.dart`
- Test: Create `test/presentation/tutorial_test.dart`, `test/ui/letter_wheel_demo_test.dart`

**Interfaces:**
- Consumes: Task 4 `TutorialCoach`, `CoachText`.
- Produces: `LetterWheel({…existing, String? demoWord, bool demoActive = false, VoidCallback? onTouchStart, VoidCallback? onSingleLetter})` — `onSingleLetter` fires when a release has exactly one selected letter (inside today's pan flow; gesture arena unchanged); demo maps `demoWord` letters to distinct indices of the current (possibly shuffled) letters and loops a gold trail + `Icons.touch_app_rounded` along them (~1.6 s per pass, 0.6 s pause) while `demoActive`.
- Produces: `CoachBanner({required String text, bool emphasis = false})` shown in the 44 px preview slot when no preview/attempt text is showing; `celebration` rendered as a short gold scale-in over the grid.
- GameScreen: builds a `TutorialCoach` (onboardingCompleted from store), ticks it every second via a `Timer.periodic`, hides the hint column when `!view.hintButtonsVisible`, highlights per `view.highlightHint`, logs `hint_viewed trigger=tutorial` when the coach reveals the hint; sets `bonusWordExplained` when shown.

- [ ] **Step 1: Write failing tests:**
  - `letter_wheel_demo_test`: `single-letter release calls onSingleLetter, not onWordSubmitted`; `touch start calls onTouchStart`; `demo paints a touch_app icon when active` (find `Icons.touch_app_rounded`).
  - `tutorial_test` (stage 1 level قلم, fresh store): `stage 1 shows instruction and hides hints` (text `CoachText.formWord`, no hint semantic labels); `hint appears after 20 s` (pump 21 s → «مجاني» visible); `veteran replay has no coach` (store `onboarding_completed: true` → no instruction, hint buttons present).
- [ ] **Step 2: Run** `flutter test test/presentation/tutorial_test.dart test/ui/letter_wheel_demo_test.dart` — FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** plus `test/ui test/word_grid_test.dart` — PASS.
- [ ] **Step 5: Checkpoint.**

### Task 10: Success screen and chapter finale

**Files:**
- Modify: `lib/presentation/widgets/level_complete_overlay.dart`, `lib/presentation/screens/game_screen.dart`
- Test: Create `test/presentation/level_complete_flow_test.dart`

**Interfaces:**
- Consumes: Task 7 tracker, Task 5 `decideOnLeave`, Task 1 `pendingRatingPrompt`.
- Produces: `LevelCompleteOverlay({…existing minus onMap, required VoidCallback onHome, required String progressLabel, int chestCoins = 0, String? chapterLine, String primaryLabel})` — order per spec §9.1; `DoubleRewardButton` uses `surface: chestCoins > 0 ? chapterChest : levelReward`, `amount: chestCoins > 0 ? chestCoins : reward`.
- GameScreen: Next → `next_stage_clicked` → `_leaveLevel(placement: 'next_stage' | 'chapter_next')`; Home → `_leaveLevel(placement: 'home')` then `popUntil(isFirst)`; chapter finale (not world finale) auto-claims chest when `chapterCompletedThisRun`, sets `pendingRatingPrompt`, and `pushReplacement`s `GameScreen(first stage of next chapter, source: 'chapter_next')`; world finale keeps today's `ChapterSelectScreen` route. `_leaveLevel` = `if (!interstitialAdsAvailable) proceed; cue = gate.decideOnLeave(...); if none { if (!ready) preload; proceed } else show(placement)`.

- [ ] **Step 1: Write failing tests:** `success shows next before home` (both labels present; `المرحلة التالية` above `الرئيسية` by `tester.getTopLeft`); `home pops to the first route`; `next logs next_stage_clicked and opens next stage`; `chapter finale goes straight to next chapter` (stage 12 complete → GameScreen for 13, `pendingRatingPrompt == true`, chest line visible).
- [ ] **Step 2: Run** `flutter test test/presentation/level_complete_flow_test.dart` — FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** plus `test/presentation test/chest_and_double_test.dart` — PASS.
- [ ] **Step 5: Checkpoint.**

### Task 11: Entry points — splash, Home, world sheet, screen views

**Files:**
- Modify: `lib/presentation/screens/map_entry.dart`, `splash_screen.dart`, `home_screen.dart`, `world_select_screen.dart`, `rewards_screen.dart`, `shop_screen.dart`, `lib/main.dart` (`navigatorObservers: [hurufRouteObserver]`)
- Test: Create `test/presentation/entry_flow_test.dart`; update `test/home_screen_test.dart`, `test/presentation/name_dialog_test.dart`, `test/presentation/world_select_screen_test.dart`

**Interfaces:**
- Produces: `Future<void> openCurrentStage(BuildContext context, WidgetRef ref, {required String source})` and `final hurufRouteObserver = RouteObserver<ModalRoute<void>>()` in `map_entry.dart`.
- Splash: after delay `pushReplacement(Home)`; if `maxUnlocked == 1` → `openCurrentStage(source: 'first_launch')`.
- Home: CTA label «ابدأ اللعب»/"Start playing" when `maxUnlocked == 1`, else «تابع اللعب»; tap → `continue_play_clicked {stage_id, cta}` + `openCurrentStage('home_cta')`; link «خريطة المراحل» → `openMap`; `_NameGate` and nav badges wait for `onboardingCompleted`; `_HomeViewTracker` (RouteAware) logs `home_viewed {source, is_new_player, stages_completed}` only when Home is current, and runs `maybeAskForRating` when `pendingRatingPrompt` (then clears it).
- World select: `world_viewed`; locked sheet primary «تابع اللعب — المرحلة N» → `openCurrentStage('world_locked_sheet')`.
- `rewards_viewed`, `shop_viewed {source}` (ShopScreen gains `source` param, default `'other'`; callers pass `home_nav`, `game_top_bar`, `near_miss`, `interstitial_mock`), `purchase_failed {sku, reason}` for non-success/non-pending results.

- [ ] **Step 1: Write failing tests** (`entry_flow_test.dart`): `fresh install lands in stage 1` (pump `HurufApp` with fresh store → GameScreen stage 1 after splash; no `home_viewed`); `returning player sees Home with continue label`; `CTA opens current stage directly` (maxUnlocked 4 → GameScreen id 4, `continue_play_clicked` + `stage_selected source home_cta`); `name dialog waits for onboarding`; `badges hidden before onboarding`; `locked world sheet offers play`.
- [ ] **Step 2: Run** `flutter test test/presentation/entry_flow_test.dart` — FAIL.
- [ ] **Step 3: Implement**; update the three existing test files (seed `onboarding_completed: true` where they assert badges/name dialog/old CTA behaviour).
- [ ] **Step 4: Run** `flutter test test/presentation test/home_screen_test.dart test/language_toggle_test.dart test/rewards test/store` — PASS.
- [ ] **Step 5: Checkpoint.**

### Task 12: Full verification and web preview

**Files:** none new.

- [ ] **Step 1:** `/d/PersonalProjects/FlutterSDK/flutter/bin/flutter analyze` — Expected: `No issues found!` (or only pre-existing infos, compared with baseline).
- [ ] **Step 2:** `flutter test` (full) — Expected: all pass; count ≥ baseline (~800) + new tests.
- [ ] **Step 3:** Web preview in debug (mock ads visible): `flutter run -d web-server --web-port=8642` (no Supabase defines); open `http://localhost:8642`. Manual check: fresh profile lands in Stage 1 tutorial; hint free/confirm sheet; success screen order; back → Home with «تابع اللعب».
- [ ] **Step 4:** Report results and the follow-up (spec §4.6: PostHog filter, funnel, two dashboards after the release ships).
