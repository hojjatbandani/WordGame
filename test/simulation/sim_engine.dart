// محرّك المحاكاة: 1000 لاعب افتراضي × 30 يوما افتراضيا.
//
// كل رقم اقتصادي يمرّ عبر الشيفرة الحقيقية — لا نسخ محلية:
//   • مكافآت المراحل:        EconomyService.computeStageReward
//   • أسعار التلميحات:       BalanceConfig.coinsHintOrdered/RandomLetter (أسعار شاشة اللعب)
//   • صندوق الفصل:           ChapterChest.amountFor (عبر EconomyService)
//   • تقويم الدخول:          LoginCalendar.rewardForPosition
//   • مكافأة التحدي اليومي:  DailyChallengeScoring.computeCoinsReward
//   • المهمات وصندوقها:      MissionEngine.selectDaily / rollDailyChest
//   • سلّم الإعلانات:        BalanceConfig.rewardedRewardForView + adDoubleBonusFor
//   • عجلة الحظ:             WheelEngine.pickSegmentIndex + القطاعات الحقيقية
//   • وضع الأمان:            SafetyMode.shouldTrigger
//   • ورقة «ينقصك القليل»:   NearMiss.evaluate
//   • بنية العوالم والزعماء: ProgressionStructure.generate()
//   • مستوى اللاعب:          PlayerLevelCurve.currentLevel
//
// ما ليس من الشيفرة الحقيقية هو النموذج السلوكي في sim_model.dart فقط.

import 'dart:math';

import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/achievement_models.dart';
import 'package:huruf/data/economy/economy_service.dart';
import 'package:huruf/data/economy/safety_mode.dart';
import 'package:huruf/data/economy/stage_reward.dart';
import 'package:huruf/data/login_calendar.dart';
import 'package:huruf/data/missions/mission_engine.dart';
import 'package:huruf/data/progression/player_level_curve.dart';
import 'package:huruf/data/progression/player_state.dart';
import 'package:huruf/data/progression/world_defs.dart';
import 'package:huruf/data/rewards/reward_track.dart';
import 'package:huruf/data/store/near_miss.dart';
import 'package:huruf/data/wheel/wheel_models.dart';
import 'package:huruf/data/wheel/wheel_engine.dart';

import 'sim_model.dart';

/// كلمات أساسية لكل مرحلة — نفس افتراض test/economy/economy_simulation_test.dart
/// (المحتوى الفعلي لم يُؤلَّف بعد؛ StageDef.coreWordCount لا يزال صفرا)
const int kCoreWordsPerStage = 5;

/// سقف عيّنة الكلمات الإضافية في المرحلة الواحدة (نفس السقف السابق)
const int kMaxBonusPerStage = 3;

/// مرآة weeklyMissionsBadgeCoins في providers.dart — لا يُستورد لأن
/// providers.dart يجرّ Flutter كاملا إلى محاكاة صرفة
const int kWeeklyBadgeCoins = 300;

/// عدد الأيام واللاعبين كما نصّت المهمة
const int kDays = 30;
const int kPlayers = 1000;

/// اليوم صفر الصناعي للمحاكاة — كل «يوم» فيها يُترجَم إلى تاريخ حقيقي
/// بجمعه عليه، فيعمل `RewardTrackEngine` على تواريخ فعلية كما في اللعبة
/// بدل أن نعيد بناء منطق مواعيده هنا. تاريخ ثابت لا `DateTime.now()`:
/// المحاكاة يجب أن تعطي نفس الأرقام في كل تشغيل.
final DateTime kSimEpoch = DateTime(2026, 1, 1);

class SimPlayer {
  final ArchetypeSpec spec;
  final Random rng;

  /// الرصيد الابتدائي الحقيقي، لا صفرا.
  ///
  /// كان صفرا بينما اللاعب الحقيقي يبدأ بـ[BalanceConfig.startingCoins]
  /// (تُطبَّق في PlayerState.initial). فكانت كل أرقام الأيام الأولى في
  /// التقرير أفقر بمئة عملة من الواقع — وهي بالضبط الأيام التي يُحكَم
  /// منها على «هل يجوع اللاعب الجديد؟».
  int coins = BalanceConfig.startingCoins;
  int xp = 0;

  /// المرحلة الجديدة التالية (1..500). فوق 500 = المحتوى انتهى.
  int nextStage = 1;

  /// كلمات الجرّة المكتشفة لكل عالم
  final Map<int, int> jar = {};

  int hintCharges = 0;
  int totalCleared = 0;
  int loginPosition = 0;

  /// أيام لعب متتالية — تغذّي [StatKey.bestStreak] كما يفعل
  /// `StreakEngine` في اللعبة الحقيقية
  int playStreak = 0;

  /// حالة مسار الجوائز — المحرّك الحقيقي نفسه (`RewardTrackEngine`)،
  /// بيوم صناعي مشتقّ من رقم اليوم في المحاكاة
  RewardTrackState rewardTrack = RewardTrackState.fresh(kSimEpoch);

  /// مضاعفات الإعلان المتبقية اليوم — تُعاد كل يوم من ArchetypeSpec
  int adDoublesLeftToday = 0;

  int safetyTriggers = 0;
  int nearMissFires = 0;
  int cosmeticsBought = 0;

  int faucet = 0;
  int sink = 0;

  /// تلميحات اشتُريت بالعملات (لا تشمل ما غطّته شحنة مجانية)
  int hintsBought = 0;

  /// تلميحات غطّتها شحنة مجانية
  int hintsFree = 0;

  /// إعلانات جائزية شوهدت فعلا — بكل سطوحها (مضاعفة جائزة، شحن
  /// عملات، وضع الأمان)
  int adsWatched = 0;

  /// عملات جاءت من مضاعفة جائزة مرحلة بإعلان
  int adDoubleCoins = 0;

  /// كل ما جاء من الإعلانات الجائزية بكل سطوحها
  int adCoins = 0;

  /// أدنى وأعلى رصيد بلغه اللاعب في أي لحظة (لا نهاية يوم فقط):
  /// «هل أفلس؟» سؤال عن اللحظة لا عن الختام — من ينفد رصيده ظهرا ثم
  /// يستعيده بمنحة مسائية أفلس فعلا وإن انتهى يومه موسرا.
  int minBalance = BalanceConfig.startingCoins;
  int maxBalance = BalanceConfig.startingCoins;

  /// عدّادات الإنجازات — نفس مفاتيح ProgressStore الحقيقية
  final Map<StatKey, int> stats = {};

  /// إنجازات فُتحت بالفعل، فلا تُدفع مرتين
  final Set<String> unlockedAchievements = {};

  /// عملات جاءت من الإنجازات
  int achievementCoins = 0;

  /// الرصيد المسجّل نهاية كل يوم (30 قيمة)
  final List<int> dailyBalance = [];

  int stageAtDay7 = 0;
  int stageAtDay14 = 0;
  int stageAtDay30 = 0;

  SimPlayer(this.spec, this.rng);
}

class ArchetypeStats {
  final ArchetypeSpec spec;
  final List<SimPlayer> players;

  ArchetypeStats(this.spec, this.players);

  List<int> balancesAtDay(int day) =>
      [for (final p in players) p.dailyBalance[day - 1]];

  int totalFaucet() => players.fold(0, (s, p) => s + p.faucet);
  int totalSink() => players.fold(0, (s, p) => s + p.sink);
  double faucetSinkRatio() {
    final sinkTotal = totalSink();
    return sinkTotal == 0 ? double.infinity : totalFaucet() / sinkTotal;
  }
}

class SimulationResult {
  final List<ArchetypeStats> archetypes;
  const SimulationResult(this.archetypes);

  ArchetypeStats byId(String id) =>
      archetypes.firstWhere((a) => a.spec.id == id);
}

int median(List<int> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : ((sorted[mid - 1] + sorted[mid]) / 2).round();
}

int percentile(List<int> values, double p) {
  final sorted = [...values]..sort();
  final index = ((sorted.length - 1) * p).round();
  return sorted[index];
}

class _Engine {
  final ProgressionStructure structure;

  /// محرّك حسابات فقط — محفظته غير مستخدمة، تُستدعى منه الدوال الصرفة
  /// (quoteHintCost/computeStageReward) بلا أي حالة
  final EconomyService econ =
      EconomyService(wallet: PlayerWallet.initial());

  _Engine(this.structure);

  int get totalStages => BalanceConfig.totalStages;

  void grant(SimPlayer p, int amount) {
    if (amount <= 0) return;
    p.coins += amount;
    p.faucet += amount;
    _mark(p);
  }

  bool spend(SimPlayer p, int amount) {
    if (p.coins < amount) return false;
    p.coins -= amount;
    p.sink += amount;
    _mark(p);
    return true;
  }

  /// يسجّل القمة والقاع عند كل حركة على المحفظة — لا عند نهاية اليوم
  void _mark(SimPlayer p) {
    if (p.coins < p.minBalance) p.minBalance = p.coins;
    if (p.coins > p.maxBalance) p.maxBalance = p.coins;
  }

  /// يرفع عدّادا ويصرف ما فُتح من إنجازات.
  ///
  /// كانت المحاكاة تتجاهل الإنجازات تماما رغم أنها تدفع ~4200 عملة على
  /// مدى اللعبة — أي أنها كانت تقيس اقتصادا ينقصه أحد أكبر مصادره،
  /// وتحديدا المصدر الذي يأتي *دفعات* لا تيّارا، فيقفز به الرصيد فجأة.
  /// تُستدعى من [AchievementsNotifier] الحقيقية في اللعبة؛ هنا نستنسخ
  /// شرطها فقط (target متحقّق ومرة واحدة) على نفس قائمة الإنجازات.
  void bump(SimPlayer p, StatKey key, int by) {
    if (by <= 0) return;
    final value = (p.stats[key] ?? 0) + by;
    p.stats[key] = value;
    for (final a in visibleAchievements) {
      if (a.stat != key || a.target > value) continue;
      if (!p.unlockedAchievements.add(a.id)) continue;
      grant(p, a.reward);
      p.achievementCoins += a.reward;
    }
  }

  /// العدّاد المتزايد بلا نقصان — يُستعمل للأعلى-هو-الأفضل (أطول كلمة،
  /// أطول سلسلة) حيث الرفع ليس جمعا
  void raise(SimPlayer p, StatKey key, int to) {
    if (to <= (p.stats[key] ?? 0)) return;
    bump(p, key, to - (p.stats[key] ?? 0));
  }

  /// يوم واحد كامل للاعب واحد
  void simulateDay(SimPlayer p, int day) {
    final spec = p.spec;
    final rng = p.rng;

    final plays = rng.nextDouble() < spec.playProb;
    if (!plays) {
      // يوم فائت يقطع سلسلة النشاط (لا نمذجة لتجميد السلسلة هنا)
      p.playStreak = 0;
      return;
    }

    p.playStreak++;
    bump(p, StatKey.daysPlayed, 1);
    raise(p, StatKey.bestStreak, p.playStreak);

    var adBudgetLeft = BalanceConfig.rewardedDailyBudget;
    var safetyFreeGrantUsed = false;
    p.adDoublesLeftToday = spec.adDoublesPerDay;

    // ── المنح اليومية (تُفتح مع أول جلسة) ──
    if (rng.nextDouble() < spec.loginClaimProb) {
      p.loginPosition++;
      grant(p, LoginCalendar.rewardForPosition(p.loginPosition).coins);
    }

    // مسار الجوائز — نفس المحرّك الحقيقي على يوم صناعي. يُحكم عليه
    // بـloginClaimProb لا بمعامل مستقلّ: السمة السلوكية واحدة («هل
    // يجمع هذا اللاعب المنح المجانية؟»)، ومعاملان لها يوهمان بدقّة
    // ليست في النموذج.
    final today = RewardTrackEngine.addDays(kSimEpoch, day);
    for (final status in RewardTrackEngine.statuses(p.rewardTrack, today)) {
      if (!status.isReady) continue;
      if (rng.nextDouble() >= spec.loginClaimProb) continue;
      grant(p, status.coins);
      p.rewardTrack = RewardTrackEngine.claim(
        status.tier,
        p.rewardTrack,
        today,
      );
    }

    if (spec.missionEasyProb > 0) {
      final level = PlayerLevelCurve.currentLevel(p.xp);
      final daily = MissionEngine.selectDaily(playerLevel: level, rng: rng);
      final done = [
        rng.nextDouble() < spec.missionEasyProb,
        rng.nextDouble() < spec.missionMediumProb,
        rng.nextDouble() < spec.missionHardProb,
      ];
      for (var i = 0; i < 3; i++) {
        if (done[i]) grant(p, daily[i].coinsReward);
      }
      if (done.every((d) => d)) {
        final chest = MissionEngine.rollDailyChest(rng);
        grant(p, chest.coins);
        if (chest.hintCharge && p.hintCharges < BalanceConfig.maxHintCharges) {
          p.hintCharges++;
        }
      }
      // الشارة الأسبوعية تُحسم آخر يوم في الأسبوع
      if (day % 7 == 0 && rng.nextDouble() < spec.weeklyBadgeProb) {
        grant(p, kWeeklyBadgeCoins);
      }
    }

    // سطح «اشحن عملات»: ما تبقّى من ميزانية اليوم بعد حجز حصّة
    // المضاعفات — الميزانية واحدة مشتركة في اللعبة الحقيقية
    if (spec.watchesAllAds) {
      final reserved = spec.adDoublesPerDay;
      for (var view = 1; view <= adBudgetLeft - reserved; view++) {
        final reward = BalanceConfig.rewardedRewardForView(view);
        grant(p, reward);
        p.adCoins += reward;
        p.adsWatched++;
      }
      adBudgetLeft = reserved;
    }

    if (spec.spinsWheel) {
      final index =
          WheelEngine.pickSegmentIndex(BalanceConfig.wheelSegments, rng);
      final segment = BalanceConfig.wheelSegments[index];
      switch (segment.type) {
        case WheelPrizeType.coins:
          grant(p, segment.value);
        case WheelPrizeType.hintCharge:
          if (p.hintCharges < BalanceConfig.maxHintCharges) p.hintCharges++;
        case WheelPrizeType.jarBooster:
          break; // خارج نطاق نموذج الجرّة اليومي
      }
    }


    // ── المراحل ──
    // لا بوابة تحجز التقدّم: إتمام مراحل الفصل يفتح ما بعده مباشرة
    final stageSlots = spec.stagesPerDay;
    var newBudget = _newStageBudget(p, stageSlots);

    for (var slot = 0; slot < stageSlots; slot++) {
      if (newBudget > 0 && p.nextStage <= totalStages) {
        newBudget--;
        _playNewStage(p, adBudgetLeft, safetyFreeGrantUsed, (usedAd) {
          if (usedAd) adBudgetLeft--;
        }, () {
          safetyFreeGrantUsed = true;
        });
      } else {
        _normalReplay(p);
      }
    }

    // ── الزينة (نهاية اليوم — قرار شراء هادئ لا أثناء اللعب) ──
    var boughtToday = 0;
    while (boughtToday < spec.cosmeticMaxPerDay &&
        p.coins > spec.cosmeticThreshold &&
        rng.nextDouble() < spec.cosmeticProb) {
      final span = spec.cosmeticMax - spec.cosmeticMin + 1;
      final price = (spec.cosmeticMin + rng.nextInt(span))
          .clamp(BalanceConfig.cosmeticsMinPrice,
              BalanceConfig.cosmeticsMaxPrice);
      if (!spend(p, price)) break;
      p.cosmeticsBought++;
      boughtToday++;
    }
  }

  /// كم من مراحل اليوم إتمامات أولى — الباقي إعادة لعب
  int _newStageBudget(SimPlayer p, int slots) {
    if (p.nextStage > totalStages) return 0; // المحتوى انتهى
    final target = (slots * p.spec.newStageShare).round();
    return target.clamp(0, slots);
  }

  /// إعادة لعب عادية (نجوم/جرّة) — صفر عملات في المحرّك الحقيقي
  void _normalReplay(SimPlayer p) {
    final s = (p.nextStage - 1).clamp(1, totalStages);
    final world = structure.stageById(s).worldId;
    final found =
        min(poisson(p.rng, p.spec.bonusMeanReplay), kMaxBonusPerStage);
    p.jar[world] = (p.jar[world] ?? 0) + found;
  }

  void _playNewStage(
    SimPlayer p,
    int adBudgetLeft,
    bool safetyFreeGrantUsed,
    void Function(bool usedAd) onSafetyAd,
    void Function() onFreeGrantUsed,
  ) {
    final rng = p.rng;
    final spec = p.spec;
    final stageDef = structure.stageById(p.nextStage);
    final worldId = stageDef.worldId;

    // فشل/تخلٍّ: لا مكافأة، وقد يستدعي وضع الأمان (الشرطان الحقيقيان
    // معا: رصيد تحت العتبة + محاولتان فاشلتان على هذه المرحلة)
    if (rng.nextDouble() < spec.abandonRate) {
      if (SafetyMode.shouldTrigger(
        coins: p.coins,
        failedOrAbandonedAttemptsThisStage:
            BalanceConfig.safetyModeMinFailedAttempts,
      )) {
        p.safetyTriggers++;
        if (adBudgetLeft > 0) {
          grant(p, BalanceConfig.safetyModeAdRewardCoins);
          onSafetyAd(true);
        } else if (!safetyFreeGrantUsed) {
          grant(p, BalanceConfig.safetyModeFreeGrantCoins);
          onFreeGrantUsed();
        } else {
          grant(p, BalanceConfig.safetyModeMiniChallengeRewardCoins);
        }
      }
      return; // المرحلة لم تُحَل — سيحاولها في فتحة قادمة (نفس nextStage)
    }

    // التلميحات — بأسعار شاشة اللعب الحقيقية.
    //
    // كانت تُسعَّر بـ`econ.quoteHintCost` (السلّم 15/25/40/70 × مضاعف
    // العالم)، وذلك سعر تلميحات *شاشتي التحدي* لا شاشة اللعب: شاشة
    // اللعب تقرأ coinsHintOrderedLetter/coinsHintRandomLetter مباشرة
    // (راجع game_screen.dart). فكانت المحاكاة تحمّل اللاعب 15 عملة على
    // أول تلميح في العالم الأول بينما تأخذ منه اللعبة 25 أو 40 — أي
    // أنها كانت تقيس مصرفا أصغر من الحقيقي في أكثر التلميحات شيوعا،
    // فتخرج بأرصدة أعلى مما يعيشه اللاعب فعلا.
    final desired = min(poisson(rng, spec.meanHintsPerStage), 4);
    var hintsUsed = 0;
    for (var i = 0; i < desired; i++) {
      if (i == 0 && p.hintCharges > 0) {
        p.hintCharges--;
        hintsUsed++;
        p.hintsFree++;
        continue;
      }
      final cost = rng.nextDouble() < spec.orderedHintShare
          ? BalanceConfig.coinsHintOrderedLetter
          : BalanceConfig.coinsHintRandomLetter;
      if (p.coins < cost) {
        // هنا كانت ورقة «ينقصك القليل» ستنبثق — بقرار الشيفرة الحقيقية
        if (NearMiss.evaluate(
              price: cost,
              balance: p.coins,
              target: NearMissTarget.hint,
              canWatchAd: false,
              adReward: 0,
            ) !=
            null) {
          p.nearMissFires++;
        }
        break;
      }
      if (p.coins - cost < spec.hintReserve) break; // اكتناز دفاعي
      spend(p, cost);
      hintsUsed++;
      p.hintsBought++;
    }

    final bonusFound = min(poisson(rng, spec.bonusMeanNew), kMaxBonusPerStage);
    p.jar[worldId] = (p.jar[worldId] ?? 0) + bonusFound;

    // «مرحلة نظيفة» = بلا أي تلميح، نفس تعريف StatKey.perfectLevels
    final isPerfect = hintsUsed == 0;

    // اللعب تسلسلي 1..N: إتمام الفصل/العالم لا يقع إلا عند الزعيم —
    // نفس الاختصار الصحيح في test/economy/economy_simulation_test.dart
    final chapterJustCompleted = stageDef.isBoss;
    final worldJustCompleted = chapterJustCompleted &&
        (p.nextStage == totalStages ||
            structure.stageById(p.nextStage + 1).worldId != worldId);
    final chestRoll =
        chapterJustCompleted ? EconomyService.chapterChestCoins(stageDef.chapterId) : 0;

    // صندوق الفصل **خارج** جائزة المرحلة، تماما كاللعبة الحقيقية
    // (`chapterChestAlreadyRolled: 0` في providers.dart:_awardStageCoins):
    // الصندوق يُفتح بنقرة منفصلة وله نافذته وزرّ مضاعفته وحده. كان
    // يُمرَّر هنا داخل التفصيل، فيصير جزءا من المبلغ الذي يضاعفه إعلان
    // *المرحلة* — أي مضاعفةُ صندوقٍ بلا إعلان ثانٍ. الخلل لم يكن ظاهرا
    // حين كانت المضاعفة مقصوصة بسقف 15، وظهر لحظة صارت مضاعفة كاملة.
    final breakdown = econ.computeStageReward(StageResult(
      worldId: worldId,
      isBossStage: stageDef.isBoss,
      isReplay: false,
      coreWordsFound: kCoreWordsPerStage,
      newBonusWordsFoundThisRun: bonusFound,
      isPerfect: isPerfect,
      chapterJustCompleted: chapterJustCompleted,
      worldJustCompleted: worldJustCompleted,
      chapterChestAlreadyRolled: 0,
    ));
    grant(p, breakdown.total);
    grant(p, chestRoll);

    // مضاعفة الجائزة بإعلان — المسار الذي لم تكن المحاكاة تنمذجه أصلا
    // رغم أنه أوضح إعلان في اللعبة (زرّ يظهر على لوحة إنهاء المرحلة).
    // يستهلك من نفس الميزانية اليومية المشتركة، ويمنح المبلغ المضاعَف
    // بحسب سياسة BalanceConfig.
    if (p.adDoublesLeftToday > 0 && adBudgetLeft > 0 && breakdown.total > 0) {
      final bonus = BalanceConfig.adDoubleBonusFor(breakdown.total);
      grant(p, bonus);
      p.adDoubleCoins += bonus;
      p.adCoins += bonus;
      p.adsWatched++;
      p.adDoublesLeftToday--;
      onSafetyAd(true); // يخصم من ميزانية اليوم المشتركة
    }

    // XP بالأرقام الحقيقية — يقود مستوى اللاعب لاختيار المهمات
    p.xp += BalanceConfig.xpPerStageClear +
        BalanceConfig.xpPerBonusWord * bonusFound +
        (stageDef.isBoss ? BalanceConfig.xpBossStageExtra : 0) +
        (chapterJustCompleted ? BalanceConfig.xpPerChapterComplete : 0) +
        (worldJustCompleted ? BalanceConfig.xpPerWorldComplete : 0);

    p.totalCleared++;

    // عدّادات الإنجازات — نفس الأحداث التي ترفعها اللعبة الحقيقية
    bump(p, StatKey.levelsCompleted, 1);
    bump(p, StatKey.wordsFound, kCoreWordsPerStage);
    bump(p, StatKey.bonusWords, bonusFound);
    if (isPerfect) bump(p, StatKey.perfectLevels, 1);
    if (hintsUsed > 0) bump(p, StatKey.hintsUsed, hintsUsed);
    if (worldJustCompleted) bump(p, StatKey.worldsCompleted, 1);

    p.nextStage++;
  }
}

SimulationResult runSimulation({int seed = 20260826}) {
  final structure = ProgressionStructure.generate();
  final engine = _Engine(structure);

  final stats = <ArchetypeStats>[];
  var playerIndex = 0;

  for (final spec in archetypes) {
    final count = (kPlayers * spec.share).round();
    final players = <SimPlayer>[];

    for (var i = 0; i < count; i++) {
      players.add(SimPlayer(spec, Random(seed + playerIndex++)));
    }

    for (var day = 1; day <= kDays; day++) {
      for (final p in players) {
        engine.simulateDay(p, day);
        p.dailyBalance.add(p.coins);
        if (day == 7) p.stageAtDay7 = p.nextStage - 1;
        if (day == 14) p.stageAtDay14 = p.nextStage - 1;
        if (day == 30) p.stageAtDay30 = p.nextStage - 1;
      }
    }

    stats.add(ArchetypeStats(spec, players));
  }

  return SimulationResult(stats);
}
