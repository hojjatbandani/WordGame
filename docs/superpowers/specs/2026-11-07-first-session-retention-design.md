# Huruf — First-session retention: design spec

**Date:** 2026-11-07
**Status:** Design approved in conversation (4 decisions below); this document awaits review.
**Goal:** Increase the share of new players who reach gameplay quickly, finish their
first stages, continue to the next stage, and come back. Not a visual redesign.

## 1. Decisions taken (user, 2026-11-07)

| # | Question | Decision |
|---|----------|----------|
| D1 | First launch of a brand-new install | Skip Home: after the splash go straight into Stage 1 (with the in-stage tutorial). Back returns to Home. |
| D2 | "Next" after the last stage of a chapter | Go straight into the first stage of the next chapter. Chapter celebration + chapter chest move onto the success screen. World finale (every 60 stages) keeps today's ceremony flow. |
| D3 | Hint pricing in stages 1–10 | First hint of each stage free; further hints at roughly half price (20 / 10 instead of 40 / 25); normal prices from stage 11. All values in `BalanceConfig`. |
| D4 | PostHog | After the new build ships, create the Priority-12 funnel, a "Stages 1–10" dashboard and an emulator test-account filter in project 298148. |

Additions I made inside the approved design (flagged so they can be vetoed):
`exit_reason = system_back` (separate from the in-app `back_button`), the
`rejected_words` property, a `build_type` property, and the `ad_skipped`
reason `not_loaded`.

## 2. Evidence this design rests on

Sources: code read on 2026-11-07, PostHog project 298148 (all events since
2026-10-27, ~1,100 events).

**Data quality first.** The Nov 4–6 headline numbers include test devices:
8900c1 is an emulator; 8b5f2c (the Stage 53 sessions) was at stage 53 with
~18,400 coins 30 s after "install" (restored backup or test phone); all
locked-world tapping came from emulators or the OnePlus8Pro used for ~10
installs. Of the 4 genuinely new installs on Nov 4–6, 3 started a stage and 2
completed one. Sample sizes are tiny; nothing below is tuned to a single level
number.

| # | Finding | Where |
|---|---------|-------|
| E1 | "تابع اللعب" calls `openMap()`: World → Chapter → Stage path → Stage = 4 taps. Before that, `_NameGate` shows a non-dismissible "وش اسمك؟" dialog with the keyboard up. Install → first `stage_start` for real players: 13–132 s, median ≈ 50 s. | `home_screen.dart` `_JourneyCard`, `_NameGate`; `map_entry.dart` |
| E2 | Hint bursts: 3 people bought 2–3 hints within 1–8 s of starting Stage 1/2, before any attempt. One went from 100 → 10 coins in 8 s and never finished Stage 1. | PostHog `hint_used` timing |
| E3 | `LetterWheel` only handles pan. A tap flashes one letter, length-1 words are silently dropped, nothing explains it. The only reactive controls next to the wheel are the paid hint buttons, which charge on first tap with no confirmation. | `letter_wheel.dart`, `game_screen.dart` `_payForHint` |
| E4 | Stage 1 content (قلم) is fine; one player had all three letters revealed by hints and still made 7 wrong attempts — an interaction problem. | PostHog |
| E5 | Fast abandons (1.5–3.7 s): two were followed by a replay of the same stage 1–3 s later (accidental exit); two went straight to Wheel/Shop for coins. None indicates difficulty. | PostHog |
| E6 | When Android kills the app during a stage, no event is sent and stage progress is lost; the most engaged real player restarted stages 33, 35 and 42 from zero. Ads and the in-app review sheet also emit `Application Backgrounded`. | `game_screen.dart` `dispose()` |
| E7 | After "Next", the old screen's `dispose()` calls `clearStage()` after the new screen set its stage → later events of the new stage lose `stage_id` (visible on `coins_spent`). | `game_screen.dart` L173, `analytics_service.dart` |
| E8 | Hint spends logged as `coins_spent reason=unspecified`; failed spends are also logged as `coins_spent` (`failed: true`). | `game_screen.dart` L486, `providers.dart` L399–420 |
| E9 | Ads: interstitial `ad_shown` is logged at decision time, before the ad shows; pacing blocks are logged as `ad_failed`; the double-reward flow never logs `ad_shown`; real AdMob load/show failures are not logged. | `providers.dart` L1050–1076, L1136–1172; `admob_ad_service.dart` |
| E10 | `store_opened` is defined but never sent; `stage_complete.hints_used` counts *words* that got a hint, not hints. | `analytics_event.dart`, `game_screen.dart` L328 |
| E11 | Stages 2–22 all share one structure (3 letters, 2 anagram targets, `difficultyScore` = 430): difficulty there is vocabulary only. Stage 2 requires رهن. | `levels.json`, `tool/rebalance_levels.dart` |
| E12 | Valid words are rejected as "wrong": St. 9 بقر/قبر and St. 15 حفر are in `tool/wordlist.txt` but missing from `bonus_words` (wordlist edited after `levels.json` was generated); St. 1 قمل/لقم, St. 4 كرب, … are in neither. | `levels.json`, `tool/wordlist.txt` |
| E13 | Stage 53 (ا س م ن): the obvious 4-letter سنام and ماس، نما، مسن، سما are rejected. Stages 31–51 trained players that the longest target uses every letter. Spelling, definitions and hint logic are correct. | `levels.json` |
| E14 | Chapter finale: "Next" → chapter list + celebration + rating prompt → stage path → stage (3–4 taps). 2 of 3 players who finished stage 12 left within seconds (tiny sample). | `game_screen.dart` `_goToNext`, `chapter_select_screen.dart` |
| E15 | Interstitials are already impossible before stage 13 and before the first play of a session; Priority 10 holds today. | `balance_config.dart` L444, `ad_pacing.dart` |

## 3. Scope

In scope: priorities 1–13 of the brief, implemented in one release, in the order
of sections 4–9 (measurement first so every UX change is instrumented from day one).

Out of scope: visual redesign of Home/Map/Shop; new modes, rewards or
monetization; changing the world/chapter structure; regenerating `levels.json`;
interstitial pacing changes (already compliant, guarded by a test only).

Constraints carried from earlier work: Google Play Families policy — every ad
entry point is labelled as an ad (`AdBadge`), no game-reward styling on ads, no
in-gameplay purchase prompts; code comments in Arabic; all balance numbers live
in `BalanceConfig`.

## 4. Measurement (Priorities 5, 9, 11, 12, 13)

### 4.1 Event taxonomy (`lib/data/analytics/analytics_event.dart`)

`Ev.all` stays the single source of names; a test keeps it duplicate-free.

| Group | Events | Change |
|-------|--------|--------|
| Journey | `home_viewed`, `continue_play_clicked`, `new_game_started`, `onboarding_started`, `onboarding_completed` | new |
| Gameplay | `stage_selected`, `next_stage_clicked` | new |
| | `stage_start`, `stage_complete`, `stage_fail`, `stage_abandon` | properties standardised (4.2) |
| Hints | `hint_viewed`, `hint_unavailable` | new |
| | `hint_used` | `type` → `hint_type`; always `cost` + `paid_with` |
| Economy | `coins_earned`, `coins_spent` | `coins_spent` only for successful spends |
| | `coins_spend_failed` | new (replaces `coins_spent failed:true`) |
| Progression | `world_viewed` | new |
| | `world_unlocked`, `world_gate_blocked`, `chapter_unlocked` | unchanged |
| Rewards | `rewards_viewed` | new |
| | `daily_reward_claimed`, `wheel_spun`, `reward_track_claimed` | unchanged |
| Shop | `shop_viewed` | new, replaces unused `store_opened` |
| | `purchase_failed` | new |
| | `purchase_started`, `purchase_completed` | unchanged |
| Ads | `ad_eligible`, `ad_skipped`, `ad_loaded`, `ad_load_failed`, `ad_clicked`, `ad_reward_earned`, `ad_dismissed` | new (user request 2026-11-09: full ad lifecycle) |
| | `ad_requested`, `ad_shown`, `ad_reward_granted` | redefined (4.4) |
| | `ad_failed` | removed |

Definitions:

- `home_viewed` — Home is the *current* route: first time after the splash
  (`source: launch`) and every return to it (`source: return`). Not sent when
  Home is immediately covered (D1 auto-start). Props: `is_new_player`
  (no stage ever completed), `stages_completed`.
- `continue_play_clicked` — Home primary CTA tapped. Props: `stage_id`,
  `cta: start | continue`.
- `stage_selected` — any UI chose a stage, before navigation. Props:
  `stage_id`, `source` (see 4.2).
- `new_game_started` — first `stage_start` ever on this install. Props:
  `ms_since_first_open` (persisted `first_open_at`, survives "Start over"),
  `source`.
- `onboarding_started` — first `stage_start` of stage 1 while onboarding is not
  complete. `onboarding_completed` — first completion of stage
  `BalanceConfig.onboardingStageCount` (= 3). Props: `duration_ms` since
  `onboarding_started`, `ms_since_first_open`.
- `next_stage_clicked` — primary CTA on the success screen. Props: `stage_id`
  (the completed one), `next_stage_id`, `chapter_finale` (bool).
- `hint_viewed` — a hint offer was shown: confirmation sheet, insufficient-coins
  sheet, or the tutorial revealing the hint button. Props: `hint_type`, `cost`,
  `coin_balance`, `trigger: confirm_sheet | insufficient_sheet | tutorial | assist`.
- `hint_unavailable` — a hint tap that could not be served. Props: `hint_type`,
  `reason: insufficient_coins | word_fully_revealed | no_unsolved_word`, `cost`,
  `coin_balance`.
- `world_viewed` / `rewards_viewed` / `shop_viewed` — screen opened. `shop_viewed`
  has `source` (`home_nav`, `game_top_bar`, `near_miss`, `interstitial_mock`).
- `purchase_failed` — Props: `sku`, `reason` (from the IAP result: cancelled,
  error, already_owned, …).

### 4.2 Standard stage properties

All of `stage_start`, `stage_complete`, `stage_fail`, `stage_abandon` carry:

`stage_id, world_id, chapter_id, player_level, coin_balance, duration_ms,
wrong_attempts, hints_used, words_total, words_solved, bonus_words, attempt,
is_replay, source, resumed, tutorial`

- `duration_ms` = *active* time in the stage (background time excluded).
- `hints_used` = number of hint uses (revealed letters), restored state included.
- `attempt` = how many times this stage has been started on this install
  (persisted map).
- `is_replay` = the stage had been completed before this start.
- `source` ∈ `first_launch, home_cta, map, next_stage, chapter_next,
  world_locked_sheet, other` — how the player navigated in.
- `resumed` = progress was restored from a previous session (9.3); independent
  of `source`.
- `tutorial` = onboarding coach active for this stage.
- `stage_complete` adds `perfect`, `is_first_completion`, `rejected_words`.
- `stage_abandon` adds `exit_reason`, `rejected_words`; `stage_fail` is sent
  together with `stage_abandon` when `wrong_attempts ≥
  BalanceConfig.safetyModeMinFailedAttempts`, with the same properties (today's
  semantics, now with `exit_reason`).
- `rejected_words` = unique wrong words of length ≥ 3, capped at
  `BalanceConfig.rejectedWordsCap` (15). Purpose: find valid words the
  dictionary is missing (feeds section 8). Contains only wheel letter
  combinations — no personal data.
- Renames vs today: `words` → `words_total`, `solved`/`of` →
  `words_solved`/`words_total`. Continuity with ~1,100 old events is lost; accepted.
- `app_version`: not added as a custom property. PostHog already attaches
  `$app_version` / `$app_build` to every event (verified: 1.0.5, 1.0.6), while
  `kAppVersion` falls back to `1.0.0` when the build has no `--dart-define`.
- Every event gets `build_type: debug | profile | release` (added in
  `PostHogSink.propertiesFor`) so internal builds can be filtered.

### 4.3 Stage sessions and `exit_reason`

New pure-Dart module `lib/data/analytics/stage_session.dart` (no Flutter
imports, fully unit-tested):

- `StageSession`: ids, `source`, `attempt`, `isReplay`, `tutorial`,
  `startedAtMs`, accumulated `activeMs`, `lastResumedAtMs`, lifecycle
  (`foreground | background | detached`), `lastSeenAtMs`, solved words,
  revealed positions, `hintsUsed`, `freeHintUsed`, `wrongAttempts`,
  `rejectedWords`, `bonusFound`, `coinBalance`, `playerLevel`. Methods for
  word/wrong/hint/pause/resume, `toJson`/`fromJson`, and
  `analyticsProps({required int nowMs})`.
- `ExitReason` enum → wire values `back_button, system_back, home_button,
  app_backgrounded, app_closed, stage_changed, world_changed, unknown`.

How each reason is produced:

| Reason | Trigger |
|--------|---------|
| `back_button` | In-app back arrow in the game top bar (set before `pop`). |
| `system_back` | Android back button/gesture: `PopScope.onPopInvokedWithResult` with no reason set yet. |
| `stage_changed` / `world_changed` | A new stage session registers while another is still active and incomplete (same / different world). Rare in today's UI; implemented generically. |
| `app_backgrounded` | Recovered on the next cold start: an active session was persisted with lifecycle `background` and never ended (OS killed the app). |
| `app_closed` | Recovered on the next cold start with lifecycle `detached` or `foreground` (swiped away, force-stopped or crashed while visible). Prop `last_state`. |
| `home_button` | Reserved; no in-game Home control exists in this release. |
| `unknown` | Any other disposal (e.g. "Start over", programmatic route removal). |

Rules:

- Temporary backgrounding never logs an abandon. `AppLifecycleListener` pauses
  the active-time clock and marks the persisted session `background`; resume
  continues it.
- The active session is persisted (`ProgressStore`, key
  `active_stage_session`) on start, on every word/wrong/hint and on every
  lifecycle change.
- Recovery runs once in `main()` after `ProgressStore.create()` and before
  `runApp`: if an unended session exists, log `stage_abandon` (and
  `stage_fail` when applicable) with the persisted props plus `recovered: true`,
  `ended_at_ms` (= `lastSeenAtMs`), then clear the marker. The resume record
  (9.3) is kept.
- Fix E7: `AnalyticsService.clearStage(int stageId)` clears only if the context
  still holds that stage.

### 4.4 Ads taxonomy

Common props: `ad_type: interstitial | rewarded`, `placement`, `stage_id`
(when in a stage), `reason` where relevant. Placements: interstitial —
`next_stage`, `chapter_next`, `home`; rewarded — the `RewardedSurface` in snake
case (`level_reward, chapter_chest, coin_top_up, wheel, safety_mode, hint, other`).

Interstitial on leaving a completed stage (`GameScreen._leaveLevel`):

1. If the build/kill-switch disallows interstitials → no events at all (today's behaviour; keeps production builds without ads silent).
2. `ad_requested`.
3. `InterstitialGateNotifier.evaluate(...)` — the existing pure
   `AdPacing.decideInterstitial` without side effects.
   Blocked → `ad_skipped` with `reason` = the `AdBlockReason` in snake case
   (`too_early_in_game`, `cadence_not_reached`, `global_cooldown`,
   `cold_start`, `recent_purchase`, …). Proceed.
4. Allowed but `!isInterstitialReady` → `ad_skipped reason=not_loaded`, preload, proceed (counter untouched, as today).
5. Allowed and ready → `commit()` (reset cadence counter, set last-ad time — today's side effects), `ad_eligible`, show.
6. The ad service logs `ad_shown` on the real impression callback
   (`onAdShowedFullScreenContent`), `ad_clicked` on `onAdClicked`, and
   `ad_load_failed phase=show` on show failure.

Rewarded (`RewardedAdsNotifier`):

- `begin(surface)` → `ad_requested`; `null` → `ad_skipped` (`budget_exhausted | kill_switch | format_disabled`); otherwise `ad_eligible`.
- Ad service: `ad_shown` / `ad_clicked` from callbacks; no ad within the existing 6 s wait → `ad_skipped reason=not_loaded`; show failure → `ad_load_failed phase=show`.
- Grants → `ad_reward_granted` with `placement`, `reward_type` (`coins | double_reward | spin | hint`) and `coins`. Boot-time `flush()` grants carry `recovered: true`.
- `ad_shown` is no longer logged from providers (moves to the ad service, so it is logged exactly once and only for real impressions).

Load results: `AdMobAdService` logs `ad_loaded` (`ad_type`, `load_ms`,
`attempt`) on `onAdLoaded`, and `ad_load_failed` with `phase: load`, `ad_type`,
`error_code`, short `error_message`, `attempt` on `onAdFailedToLoad`.

Full lifecycle from the ad service (user request 2026-11-09), so every shown
ad can be verified end to end:

| Event | SDK callback | Props |
|-------|--------------|-------|
| `ad_loaded` | `onAdLoaded` | `ad_type`, `load_ms`, `attempt` |
| `ad_shown` | `onAdShowedFullScreenContent` | `ad_type`, `placement` |
| `ad_clicked` | `onAdClicked` | `ad_type`, `placement` |
| `ad_reward_earned` | `onUserEarnedReward` (player met the watch condition) | `ad_type: rewarded`, `placement` |
| `ad_dismissed` | `onAdDismissedFullScreenContent` | `ad_type`, `placement`, `shown_ms`, `reward_earned` (bool, rewarded only) |

`ad_reward_earned` (the SDK says the condition was met) and
`ad_reward_granted` (the game actually credited the reward) are deliberately
separate: a gap between them is a bug. Expected healthy rewarded sequence:
`ad_requested → ad_eligible → ad_shown → ad_reward_earned → ad_dismissed →
ad_reward_granted`. `MockAdService` (desktop/web) emits the same events so the
flow can be checked without AdMob.

Plumbing: `AdService.showInterstitial` / `showRewarded` gain an optional named
`String? placement`; `AdMobAdService`, `MockAdService` and
`PolicyGatedAdService` accept an optional `onEvent(String, Map)` hook wired to
`AnalyticsService.log` in `main.dart`. Test fakes implementing `AdService` are
updated.

### 4.5 Economy fixes

- `_payForHint` spends with `reason: 'hint'`.
- `PointsNotifier.spend` failure logs `coins_spend_failed` (not `coins_spent`).

### 4.6 PostHog setup (after the build ships; D4)

In project 298148, via the PostHog MCP, with links reported back:

1. Test-account filter: exclude `$is_emulator = true`; filter-by-default on.
2. Funnel "Critical path": `Application Installed` → `Application Opened` →
   "Play entry" → `stage_start` → `stage_complete` → `next_stage_clicked` →
   `stage_start` → `stage_complete`. Unique persons, 1-day window. "Play entry"
   is a PostHog action matching `continue_play_clicked` OR `stage_selected`
   with `source = first_launch`, because under D1 brand-new players skip Home
   and never click the CTA.
3. Dashboard "Huruf — Stages 1–10", filtered to `stage_id ≤ 10` and
   `is_replay = false`, broken down by `stage_id`: unique starters, unique
   finishers, completion rate, abandon rate (with `exit_reason` breakdown), fail
   rate, average `duration_ms`, average `hints_used`, average `wrong_attempts`,
   and a time-to-first-stage tile (`new_game_started.ms_since_first_open`).
4. Dashboard "Huruf — Ads health": rewarded funnel (`ad_requested → ad_eligible
   → ad_shown → ad_reward_earned → ad_reward_granted`) by `placement`;
   interstitial funnel (`ad_requested → ad_eligible → ad_shown → ad_dismissed`);
   `ad_skipped` by `reason`; `ad_load_failed` by `phase` and `error_code`;
   fill rate (`ad_loaded` vs `ad_load_failed`); `ad_clicked` count.
   (The brief's Priority 13 text was cut off after "average"; these averages are
   my reading of it.)

## 5. First session to gameplay (Priority 1)

### 5.1 Play entry point

New helper `openCurrentStage(context, ref, {required String source})` in
`lib/presentation/screens/map_entry.dart` (next to `openMap`): awaits
`levelsProvider.future`, picks `maxUnlocked.clamp(1, totalLevels)`, logs
`stage_selected`, pushes `GameScreen(level, allLevels, source)`. If every stage
is done it falls back to `openMap`. `GameScreen` gains a `source` parameter.

### 5.2 D1 — brand-new players start in Stage 1

`SplashScreen`: after its existing delay it does `pushReplacement(Home)`. If the
player has never completed a stage (`maxUnlocked == 1`), it then calls
`openCurrentStage(source: 'first_launch')`. Back from the stage lands on Home.
This repeats on every launch until stage 1 is completed; with resume (9.3) that
means "continue where you left off".

### 5.3 Home

- `_JourneyCard` CTA label: «ابدأ اللعب» when no stage has been completed, else
  «تابع اللعب». Tap → `continue_play_clicked` + `openCurrentStage(source: 'home_cta')`.
- A small secondary text link «خريطة المراحل» under the CTA opens `openMap`
  (the map stays one tap away).
- `_NameGate`: not shown until onboarding is complete (stage 3 completed). Then
  it asks once, on a Home view, as today.
- Nav badges (Rewards, Shop, Wheel `PulseDot`) hidden until onboarding is
  complete. Rewards themselves stay claimable.
- `home_viewed` tracker (invisible widget, `RouteAware` via a `RouteObserver`
  added to `MaterialApp.navigatorObservers`). It also triggers the deferred
  rating prompt (9.2).

### 5.4 World select

The locked-world sheet gets a primary button «تابع اللعب — المرحلة N» →
`openCurrentStage(source: 'world_locked_sheet')`. `world_viewed` on open.

## 6. Stage 1 as the tutorial (Priority 2)

No modal dialogs. The coach is active only while onboarding is incomplete
(`onboardingCompleted` flag in `ProgressStore`) and only on stages
1..`BalanceConfig.onboardingStageCount` (3). Veterans replaying stage 1 never
see it.

Pure logic: `lib/data/onboarding/tutorial_coach.dart` — a small state machine fed
with events (`stageStarted`, `touchStarted`, `singleLetterSubmitted`,
`wrongAttempt`, `wordSolved`, `bonusFound`, `idleTick`). Its outputs are
`instruction` (text or null), `showFingerDemo`, `hintButtonsVisible`,
`highlightHint`, `celebration` (text or null). Unit-tested without widgets.

UI: instruction pill in the existing 44 px preview slot (shown only while
nothing is being typed); a `FingerDemo` drawn by `LetterWheel` itself
(geometry lives there); «رائع!» as a short gold scale-in over the grid.

| Stage | Behaviour |
|-------|-----------|
| 1 | Start: «كوّن الكلمة من الحروف» + finger demo tracing ق → ل → م on the wheel (gold trail, `Icons.touch_app_rounded`, loops). Touch → demo stops. Single-letter release (tap) → «اسحب إصبعك بين الحروف» + 2 demo loops. Wrong attempt → 2 demo loops. The whole hint column (shuffle included) is hidden until 2 wrong attempts or 20 s without a solved word; it then appears with the main hint labelled «مجاني», pulsing (`hint_viewed trigger=tutorial`). Word solved → «رائع!» then the success screen. |
| 2 | No demo unless no touch within 5 s. After the first word: «رائع! كوّن كلمة أخرى من نفس الحروف». |
| 3 | First bonus word ever: «كلمة إضافية! تمنحك عملات» (once per install). |
| ≥ 4 | No coach. Progressive assistance (7.4) applies everywhere. |

`LetterWheel` additions (backwards-compatible optional params): `demoWord`
(word to trace), `demoActive`, `onTouchStart`, `onSingleLetter` (a release with
exactly one letter selected — detected inside today's pan flow, so the gesture
arena and drag feel are unchanged).

Analytics: `onboarding_started`, `onboarding_completed`, `tutorial: true` on
stage events.

## 7. Hints (Priorities 3, 7)

### 7.1 Pricing (D3) — pure `lib/data/economy/hint_pricing.dart`

`HintQuote quote({type, stageId, freeHintUsedThisAttempt, charges, balance})` →
`cost`, `paidWith (free | charge | coins)`, `requiresConfirm`, `affordable`.

- Stages 1..`BalanceConfig.earlyGameStageLimit` (10): the first hint of each
  attempt is free (`paidWith: free`). The flag lives in the session/resume
  record, so leaving and re-entering does not reset it. Further hints cost
  `coinsHintOrderedLetterEarly = 20` / `coinsHintRandomLetterEarly = 10`.
- Stage ≥ 11: today's 40 / 25.
- Order of payment: free → owned hint charges → coins.
- Button labels show «مجاني» when the next hint is free, otherwise today's
  charge/price label with the early-game price.

### 7.2 Confirmation sheet

`lib/presentation/widgets/hint_sheet.dart`, compact bottom sheet. It shows the
hint name (كشف الحرف التالي / كشف حرف عشوائي), one line on what it reveals
(«يكشف الحرف التالي في أول كلمة ناقصة»), cost, current balance and balance
after, with «استخدم التلميح» and «إلغاء». Logs `hint_viewed trigger=confirm_sheet`.

`requiresConfirm` is true for coin-paid hints when the stage ≤ 10, or when
`cost ≥ BalanceConfig.hintConfirmBalanceShare × balance` (0.25). Free and
charge-paid hints never confirm. A hint tap arriving within
`BalanceConfig.hintTapDebounce` (600 ms) of the previous *served* hint is
ignored (stops accidental double-buys; deliberate repeated use still works).

### 7.3 Not enough coins

Same sheet, insufficient variant, `hint_viewed trigger=insufficient_sheet` +
`hint_unavailable reason=insufficient_coins`:

1. If rewarded ads are available and budget remains: «شاهد إعلانا واحصل على
   التلميح» with `AdBadge` → new `RewardedSurface.hint` (short ad, shared daily
   budget) → on reward, the hint is applied directly (`paid_with: ad`,
   `ad_reward_granted reward_type=hint`).
2. Otherwise a short line: «ليس لديك عملات كافية — أكمل المراحل لتجمع العملات».
3. Only after stage 10 is there a small secondary «المتجر» text link. No pack
   offer and no store push during stages 1–10.

The existing near-miss sheet keeps serving other targets (skip, cosmetics,
retry); hints no longer use it.

### 7.4 Progressive assistance (all stages)

After `BalanceConfig.assistAfterWrongAttempts` (3) wrong attempts or
`assistAfterIdle` (30 s) without a newly solved word, the main hint button
pulses and the preview slot shows «جرّب التلميح» once per stage attempt
(`hint_viewed trigger=assist`). Never auto-reveals.

### 7.5 Board-order bonus seeding

`_bonusFound` is seeded only with saved bonus words that are still bonus words
of the current level (protects replays after the stage reorder in 8.2).

## 8. Content (Priorities 3, 4, 6)

### 8.1 Accepted words → bonus words

- New `tool/accepted_words.txt`: extra valid words (no definitions, allowed
  letters only, length ≥ 3) that the target dictionary lacks.
- New `tool/sync_bonus_words.dart` (idempotent): for every level, append to
  `bonus_words` every word from `wordlist.txt` ∪ `accepted_words.txt` that is
  formable from the level's letters (multiset), has length ≥ 3, and is not a
  core word. It never removes existing bonus words, keeps the JSON format
  (2-space indent, UTF-8), and never touches `letters`, `words` or `id`.
- Initial `accepted_words.txt` (reviewed by hand against stages 1–30 and
  52–56; each word is a standard MSA word without hamza):

  | Letters | Added |
  |---------|-------|
  | ق ل م | قمل، لقم |
  | د ر س | سدر |
  | ر ك ب | كرب |
  | ف ر س | سرف |
  | ت ح ف | حتف |
  | ح ر س | سرح، حسر |
  | ب ر ج | جرب، رجب |
  | ب ش ر | شبر |
  | ب ص ر | برص |
  | ب ع د | بدع |
  | ق م ر | مقر، رمق |
  | ق ل ب | لبق |
  | ب ش ع | شبع |
  | ا ب ل ن (52) | نبل، نال، بان، لبان |
  | ا س م ن (53) | سنام، ماس، نما، مسن، سما، سنا، سام |
  | ا ب ت ي (55) | بيات |

  Dictionary words the sync adds because today's bonus lists miss them (full
  list, computed 2026-11-07): بقر، قبر (ب ر ق), حفر (ح ر ف), حبر، رحب (ب ح ر,
  stage 23), تطويرات (stage 386), تصفيات (stage 485). Because the sync is
  global, every other level whose letters form an accepted word benefits too.
- Later additions come from the `rejected_words` data (section 4.2), not from
  guesses.

### 8.2 Onboarding order of stages 2–22

All of stages 2–22 have `difficultyScore` = 430, so reordering them cannot
break the curve tests (non-decreasing score, boss = hardest, chapter floors) or
letter-set uniqueness. New order (whole level objects move; `id` is
renumbered):

| New stage | Words |
|-----------|-------|
| 1 | قلم (unchanged) |
| 2 | حرف / فرح |
| 3 | ورد / دور |
| 4 | ركب / كبر |
| 5 | فرس / سفر |
| 6 | حار / راح |
| 7 | بعد / عبد |
| 8 | برق / قرب |
| 9 | بشر / شرب |
| 10 | بصر / صبر |
| 11 | حرس / سحر |
| 12 | جسد / سجد (boss, unchanged) |
| 13 | درس / سرد |
| 14 | بدل / بلد |
| 15 | برج / جبر |
| 16 | كرم / مكر |
| 17 | بات / تاب |
| 18 | تحف / فتح |
| 19 | بصل / صلب |
| 20 | جرد / درج |
| 21 | نهر / رهن |
| 22 | بغض / غضب |

This is done by a one-off script `tool/reorder_onboarding_stages.dart` with
this explicit mapping. `tool/rebalance_levels.dart` is stable for equal scores
(ties keep the current id order), so a later rebalance keeps this order.

### 8.3 Stage 53

Content and structure unchanged; the 7 words above become bonus words, so the
natural answers (سنام first) now succeed instead of shaking red.

### 8.4 Content tests (new)

- Every bonus word is formable from its level's letters and is not a core word.
- Sync invariant: every dictionary/accepted word formable in a level is either
  core or bonus there (forces re-running the sync after dictionary edits).
- Stages 1–10: 3 letters, ≤ 2 core words.
- Existing tests (`levels_validation_test`, `levels_difficulty_curve_test`,
  `wordlist_test`) stay green unchanged.

## 9. Stage-to-stage flow (Priorities 5, 8)

### 9.1 Success screen (`level_complete_overlay.dart`)

Same visual language (glass card, gold button, guide video, confetti), reordered:

1. Guide celebration + title «أحسنت!».
2. Earned coins (count-up), bonus-word line if any.
3. Progress line «المرحلة 4 من 12 · الفصل 1».
4. Primary, full-width, dominant: «المرحلة التالية» → `next_stage_clicked` →
   `_leaveLevel(placement: next_stage)` → next stage (`source: next_stage`).
5. Secondary, smaller: the existing `DoubleRewardButton` (AD badge), the share
   row, then a text button «الرئيسية» → pop to Home (`placement: home`).

The last level of the game keeps «خريطة المراحل».

### 9.2 Chapter finale (D2)

On the last stage of a chapter (not of a world):

- Title «أتممت الفصل!» with the chapter's line from
  `chapterCelebrationLineFor(chapterId)`.
- When this run completed the chapter (`chapterCompletedThisRun`), the chapter
  chest is claimed automatically (`claimChapterChest`) and shown as a line
  «صندوق الفصل +N»; `DoubleRewardButton` then doubles the chest (surface
  `chapterChest`, long ad, as in today's chest dialog) instead of the smaller
  stage reward. On a replay of an already-completed chapter's last stage there
  is no chest line and the button doubles the stage reward as usual.
- Primary «الفصل التالي» → first stage of the next chapter
  (`source: chapter_next`), via `pushReplacement` — the chapter list is skipped.
- The rating prompt moves: a `pending_rating_prompt` flag is set and
  `maybeAskForRating` runs on the next `home_viewed`.
- World finale (last stage of a world): unchanged (chapter list celebration →
  world-unlock ceremony).

### 9.3 Resume in-progress stages (Priority 5)

- `ProgressStore` key `stage_resume` holds a JSON map (max 3 most recent
  stages): solved words, revealed positions, wrong attempts, hints used,
  `freeHintUsed`, active ms, rejected words.
- Written on every change; cleared for a stage when it is completed.
- `GameScreen.initState` restores it when present (`resumed: true`). A toast
  «تابعت من حيث توقفت» is shown only if progress > 0.
- Applies after back, system back, or the OS killing the app.

## 10. Ads in early game (Priority 10)

No behaviour change (E15). New guard test: for every stage < 13, and for any
stage before the first play in a session, `AdPacing.decideInterstitial` blocks.

## 11. New `BalanceConfig` fields (all mutable, remote-configurable like the rest)

`onboardingStageCount = 3`, `earlyGameStageLimit = 10`,
`coinsHintOrderedLetterEarly = 20`, `coinsHintRandomLetterEarly = 10`,
`hintConfirmBalanceShare = 0.25`, `hintTapDebounce = 600 ms`,
`tutorialRevealHintAfterWrongAttempts = 2`, `tutorialRevealHintAfterIdle = 20 s`,
`tutorialDemoIfNoTouchAfter = 5 s`, `assistAfterWrongAttempts = 3`,
`assistAfterIdle = 30 s`, `rejectedWordsCap = 15`, `resumeStagesKept = 3`.

## 12. Files touched (expected)

New: `lib/data/analytics/stage_session.dart`, `lib/data/onboarding/tutorial_coach.dart`,
`lib/data/economy/hint_pricing.dart`, `lib/presentation/widgets/hint_sheet.dart`,
`lib/presentation/widgets/coach_banner.dart`, `tool/accepted_words.txt`,
`tool/sync_bonus_words.dart`, `tool/reorder_onboarding_stages.dart`, tests.

Changed: `analytics_event.dart`, `analytics_service.dart`, `posthog_sink.dart`,
`main.dart`, `progress_store.dart`, `balance_config.dart`, `providers.dart` (ads,
points, journey flags), `ad_service.dart`, `admob_ad_service.dart`,
`policy_gated_ad_service.dart`, `mock_ad_service.dart`, `rewarded_ads.dart`
(+`hint` surface), `ad_format.dart`, `game_screen.dart`, `letter_wheel.dart`,
`level_complete_overlay.dart`, `double_reward.dart`, `home_screen.dart`,
`splash_screen.dart`, `map_entry.dart`, `world_select_screen.dart`,
`stage_path_screen.dart` (source), `shop_screen.dart` (shop_viewed,
purchase_failed), `rewards_screen.dart` (rewards_viewed), `wheel_screen.dart`
(ad events), `near_miss_sheet.dart` (ad events), `assets/data/levels.json`,
and the existing tests that assert old event names (`ads_disabled_build_test`,
`ad_policy_test`, `ads_disabled_ui_test`, `home_screen_test`,
`name_dialog_test`, hint label tests).

## 13. Testing and verification

- Unit: `StageSession` (durations with background, props, JSON round-trip,
  recovery reasons); `TutorialCoach` transitions; `HintPricing` (free, early
  price, charges, confirm rule, debounce); `InterstitialGate.evaluate/commit`
  parity with today's decisions; ad event sequences with a recording analytics
  sink; content tests (8.4).
- Widget: Home CTA opens `GameScreen` directly with the right label; first
  launch auto-start; name gate and badges deferred until onboarding is complete;
  tutorial instruction/demo/hint visibility on stage 1 and its absence for
  veterans; hint confirmation and insufficient sheets (ad option only when
  available, no store link ≤ stage 10); success-screen order and actions;
  chapter-finale direct continue; resume restores solved words.
- Full suite via the SDK junction workaround (`dart analyze lib test`, then
  `flutter test`); no regressions in the existing ~800 tests.
- Manual (emulator, if available): fresh install → Stage 1 in < 20 s; tutorial
  flow; background/kill → resume and recovered `stage_abandon` in PostHog live
  events.

## 14. Success metrics (read after release, test accounts excluded)

- Install → first `stage_start`: median `new_game_started.ms_since_first_open`
  < 20 s (today ≈ 50 s).
- Stage 1 completion among starters (first attempt, non-replay) ↑; stage 1 hints
  spent within the first 10 s → ~0.
- Funnel step `stage_complete` → `next_stage_clicked` → `stage_start`
  conversion ↑.
- `stage_abandon` by `exit_reason`: share of `system_back` < 3 s tells whether
  accidental exits need a further guard (not built now).
- Next-day return (PostHog retention on `stage_start`).

## 15. Risks

- Auto-start may surprise players who expect a menu → mitigated by an obvious
  back arrow to Home and the tutorial instruction.
- Reordering changes the content behind already-completed stage ids for the few
  existing players → harmless (replay only; bonus seeding filtered, 7.5).
- `rejected_words` adds a list property to stage events → capped at 15.
- Larger `GameScreen` → new logic lives in the pure modules plus a small
  session-tracking mixin, not inline.
- Removing `ad_failed` breaks any saved PostHog insight using it — none were
  found in the event data review; dashboards are created fresh (4.6).
