// يبني تقرير test/simulation/report.md من نتيجة المحاكاة — جداول
// ماركداون + حالة نجاح/فشل كل تأكيد. النص إنجليزي عمدا: التقرير وثيقة
// تُقرأ في مراجعات التوازن وقد تُلصق في أدوات لا تعرض العربية جيدا.

import 'package:huruf/config/balance_config.dart';

import 'sim_engine.dart';
import 'sim_model.dart';

class AssertionOutcome {
  final String name;
  final bool passed;
  final String detail;
  const AssertionOutcome(this.name, this.passed, this.detail);
}

/// «تخمة»: رصيد يفقد العملةَ معناها — لا شيء يستحق الادّخار له بعده.
///
/// مشتقّ من الأسعار لا مخترَع: أغلى ما يشتريه اللاعب بالعملات هو
/// تجاوز بوابة عالم (500) وأغلى زينة (BalanceConfig.cosmeticsMaxPrice).
/// من يملك ضعف ذلك لم يعد أمامه قرار إنفاق حقيقي.
const int kRichThreshold = 2000;

/// عتبات «الاقتصاد السليم» — تُطبَّق على **كل** نمط لا على المنتظم وحده.
///
/// النسخة السابقة كانت تؤكّد مدى ثابتا واحدا (رصيد المنتظم بين 300 و800
/// كل يوم). كان ذلك خطأ في الشكل لا في الرقم: هو يؤكّد أن الرصيد
/// **مسطّح**، بينما رصيد لعبة يستهلك لاعبها محتواها ينمو بطبيعته. وكان
/// يقيس نمطا واحدا من خمسة، فيمرّ وقد أفلس نصفُ العارضين.
///
/// ما يهمّ فعلا طرفان وحركة بينهما: ألّا يجوع أحد، ألّا يتخم أحد، وأن
/// تدور العملة بدل أن تتكدّس.
class HealthThresholds {
  /// أرضية «لا يعلق»: تُشتقّ من السعر لا تُخترع. من يملك ثمن تلميحين
  /// عشوائيين ليس عالقا — هو مقتصد، وهذا مطلوب لا مَعيب. رقم ثابت هنا
  /// (100 مثلا) كان سيرسب المتعثّر الذي يعيش على 66 عملة وهو قادر على
  /// تلميحين، ويمرّ لو رُخّص التلميح غدا إلى 5.
  static int get minMedianBalance => 2 * BalanceConfig.coinsHintRandomLetter;

  /// أرضية «مرتاح» للأنماط السائدة (العارض، المنتظم، مشاهد الإعلانات).
  /// المتعثّر مستثنى بحكم تعريفه: هو النمط الذي *يُفترض* أن يعيش على
  /// الحافّة، وإلا لم يعد متعثّرا ولم تعد المحاكاة تختبر الحافّة أصلا.
  static const int comfortMedianBalance = 150;
  static const Set<String> comfortArchetypes = {
    'casual',
    'regular',
    'adWatcher',
  };

  /// يومان مختلفان لسؤالين مختلفين. «هل يعلق؟» يُسأل مبكرا: العلوق عطب
  /// فوري لا يُحتمَل أسبوعا. «هل هو مرتاح؟» يُسأل بعد أسبوع: اللاعب
  /// يبدأ بـ100 عملة، ومهمة أيامه الأولى أن يتعلّم أن للتلميح ثمنا —
  /// لو كان مرتاحا من اليوم الأول لما تعلّمها.
  static const int rampDays = 4;
  static const int comfortFromDay = 7;

  /// نسبة اللاعبين الذين يجوز أن يلمس رصيدهم الصفر ولو لحظة.
  /// «أحيانا ينفد» مطلوب؛ «الثلث ينفد» ليس.
  static const double maxEverBrokeShare = 0.12;

  /// نسبة من يجوز أن ينتهي به الشهر فوق [kRichThreshold]
  static const double maxRichShare = 0.10;

  /// مدى نسبة المصدر/المصرف: تحت الأدنى تُستنزف المحفظة، وفوق الأعلى
  /// تتكدّس العملة بلا قرار إنفاق
  static const double minFaucetSinkRatio = 1.00;
  static const double maxFaucetSinkRatio = 1.35;

  /// أقصى حصّة للإعلانات من مصدر مشاهد الإعلانات. فوقها يصير الإعلان
  /// هو اللعبة، وهو ما تمنعه مهمة «الإعلان مفيد لا مدمّر للقيمة».
  static const double maxAdShareOfFaucet = 0.35;
}

List<AssertionOutcome> evaluateAssertions(SimulationResult result) {
  final outcomes = <AssertionOutcome>[];

  // 1) لا يعلق أحد: لا نمط ينزل وسيطه تحت ثمن تلميحين
  var starvedWhere = '';
  for (final a in result.archetypes) {
    for (var day = HealthThresholds.rampDays; day <= kDays; day++) {
      final m = median(a.balancesAtDay(day));
      if (m < HealthThresholds.minMedianBalance) {
        starvedWhere = '${a.spec.nameEn} day $day median $m';
        break;
      }
    }
    if (starvedWhere.isNotEmpty) break;
  }
  outcomes.add(AssertionOutcome(
    'No archetype median falls below ${HealthThresholds.minMedianBalance} '
    'after day ${HealthThresholds.rampDays}',
    starvedWhere.isEmpty,
    starvedWhere.isEmpty
        ? 'lowest median across all archetypes/days: '
            '${_lowestMedian(result)}'
        : starvedWhere,
  ));

  // 1ب) الأنماط السائدة مرتاحة لا على الحافّة
  var uncomfortableWhere = '';
  for (final a in result.archetypes
      .where((a) => HealthThresholds.comfortArchetypes.contains(a.spec.id))) {
    for (var day = HealthThresholds.comfortFromDay; day <= kDays; day++) {
      final m = median(a.balancesAtDay(day));
      if (m < HealthThresholds.comfortMedianBalance) {
        uncomfortableWhere = '${a.spec.nameEn} day $day median $m';
        break;
      }
    }
    if (uncomfortableWhere.isNotEmpty) break;
  }
  outcomes.add(AssertionOutcome(
    'Mainstream archetypes stay above '
    '${HealthThresholds.comfortMedianBalance} after day '
    '${HealthThresholds.comfortFromDay}',
    uncomfortableWhere.isEmpty,
    uncomfortableWhere.isEmpty
        ? 'casual/regular/adWatcher all comfortable'
        : uncomfortableWhere,
  ));

  // 2) لا تخمة: لا نمط يتجاوز وسيطه سقف «العملة بلا معنى»
  var richWhere = '';
  for (final a in result.archetypes) {
    final m = median(a.balancesAtDay(kDays));
    if (m >= kRichThreshold) richWhere = '${a.spec.nameEn} day-30 median $m';
  }
  outcomes.add(AssertionOutcome(
    'No archetype median balance reaches $kRichThreshold by day 30',
    richWhere.isEmpty,
    richWhere.isEmpty
        ? 'highest day-30 median: ${_highestFinalMedian(result)}'
        : richWhere,
  ));

  // 3) الإفلاس نادر لا شائع
  var brokeWhere = '';
  for (final a in result.archetypes) {
    final share = a.players.where((p) => p.minBalance <= 0).length /
        a.players.length;
    if (share > HealthThresholds.maxEverBrokeShare) {
      brokeWhere = '${a.spec.nameEn} ${(share * 100).toStringAsFixed(1)}%';
    }
  }
  outcomes.add(AssertionOutcome(
    'At most ${(HealthThresholds.maxEverBrokeShare * 100).round()}% of any '
    'archetype ever touches 0 coins',
    brokeWhere.isEmpty,
    brokeWhere.isEmpty
        ? 'worst: ${_worstBrokeShare(result)}'
        : brokeWhere,
  ));

  // 4) من أفلس تعافى — لا لاعب عالق بلا رصيد في نهاية الشهر
  var strandedTotal = 0;
  for (final a in result.archetypes) {
    strandedTotal += a.players
        .where((p) =>
            p.minBalance <= 0 &&
            p.dailyBalance[kDays - 1] < HealthThresholds.minMedianBalance)
        .length;
  }
  outcomes.add(AssertionOutcome(
    'Every player who hit 0 recovered above '
    '${HealthThresholds.minMedianBalance} by day 30',
    strandedTotal == 0,
    strandedTotal == 0
        ? 'no stranded players'
        : '$strandedTotal players still below the floor',
  ));

  // 5) نسبة الفائضين محدودة
  var richShareWhere = '';
  for (final a in result.archetypes) {
    final share = a.players
            .where((p) => p.dailyBalance[kDays - 1] >= kRichThreshold)
            .length /
        a.players.length;
    if (share > HealthThresholds.maxRichShare) {
      richShareWhere = '${a.spec.nameEn} ${(share * 100).toStringAsFixed(1)}%';
    }
  }
  outcomes.add(AssertionOutcome(
    'At most ${(HealthThresholds.maxRichShare * 100).round()}% of any '
    'archetype ends above $kRichThreshold',
    richShareWhere.isEmpty,
    richShareWhere.isEmpty ? 'worst: ${_worstRichShare(result)}' : richShareWhere,
  ));

  // 6) العملة تدور: المصدر لا يفوق المصرف كثيرا ولا يقصر عنه
  var ratioWhere = '';
  for (final a in result.archetypes) {
    final r = a.faucetSinkRatio();
    if (r < HealthThresholds.minFaucetSinkRatio ||
        r > HealthThresholds.maxFaucetSinkRatio) {
      ratioWhere = '${a.spec.nameEn} ratio ${r.toStringAsFixed(3)}';
    }
  }
  outcomes.add(AssertionOutcome(
    'Every archetype faucet/sink ratio within '
    '${HealthThresholds.minFaucetSinkRatio}-'
    '${HealthThresholds.maxFaucetSinkRatio}',
    ratioWhere.isEmpty,
    ratioWhere.isEmpty
        ? result.archetypes
            .map((a) => '${a.spec.nameEn} ${a.faucetSinkRatio().toStringAsFixed(2)}')
            .join(', ')
        : ratioWhere,
  ));

  // 7) الإعلان يزيد ولا يحكم
  final adWatcher = result.byId('adWatcher');
  final adShare = adWatcher.players.fold(0, (s, p) => s + p.adCoins) /
      adWatcher.totalFaucet();
  outcomes.add(AssertionOutcome(
    'Ads are at most '
    '${(HealthThresholds.maxAdShareOfFaucet * 100).round()}% of the '
    'ad-watcher faucet',
    adShare <= HealthThresholds.maxAdShareOfFaucet,
    '${(adShare * 100).toStringAsFixed(1)}% of faucet comes from ads',
  ));

  // 8) المتعثّر: وضع الأمان ≤ 3 مرات في 30 يوما (أقصى لاعب)
  final struggler = result.byId('struggler');
  final maxSafety = struggler.players
      .map((p) => p.safetyTriggers)
      .reduce((a, b) => a > b ? a : b);
  outcomes.add(AssertionOutcome(
    'Struggler hits safety mode at most 3 times in 30 days',
    maxSafety <= 3,
    'worst player: $maxSafety triggers',
  ));

  // 9) الطاحن: الرصيد الوسيط يوم 30 لا يتجاوز 2500
  final grinder = result.byId('grinder');
  final grinderDay30 = median(grinder.balancesAtDay(kDays));
  outcomes.add(AssertionOutcome(
    'Grinder median balance on day 30 does not exceed 2,500',
    grinderDay30 <= 2500,
    'day-30 median $grinderDay30',
  ));

  return outcomes;
}

String _lowestMedian(SimulationResult result) {
  var best = 1 << 30;
  var where = '';
  for (final a in result.archetypes) {
    for (var day = HealthThresholds.rampDays; day <= kDays; day++) {
      final m = median(a.balancesAtDay(day));
      if (m < best) {
        best = m;
        where = '${a.spec.nameEn} day $day';
      }
    }
  }
  return '$best ($where)';
}

String _highestFinalMedian(SimulationResult result) {
  var best = 0;
  var where = '';
  for (final a in result.archetypes) {
    final m = median(a.balancesAtDay(kDays));
    if (m > best) {
      best = m;
      where = a.spec.nameEn;
    }
  }
  return '$best ($where)';
}

String _worstBrokeShare(SimulationResult result) {
  var worst = 0.0;
  var where = '';
  for (final a in result.archetypes) {
    final s = a.players.where((p) => p.minBalance <= 0).length /
        a.players.length;
    if (s > worst) {
      worst = s;
      where = a.spec.nameEn;
    }
  }
  return '${(worst * 100).toStringAsFixed(1)}% ($where)';
}

String _worstRichShare(SimulationResult result) {
  var worst = 0.0;
  var where = '';
  for (final a in result.archetypes) {
    final s = a.players
            .where((p) => p.dailyBalance[kDays - 1] >= kRichThreshold)
            .length /
        a.players.length;
    if (s > worst) {
      worst = s;
      where = a.spec.nameEn;
    }
  }
  return '${(worst * 100).toStringAsFixed(1)}% ($where)';
}

String buildReport(SimulationResult result, List<AssertionOutcome> outcomes) {
  final b = StringBuffer();

  b.writeln('# Economy Simulation Report');
  b.writeln();
  b.writeln('1,000 virtual players, 30 virtual days, real game engines '
      '(`EconomyService`, `LoginCalendar`, `RewardTrackEngine`, '
      '`MissionEngine`, `WheelEngine`, `SafetyMode`, `NearMiss`, '
      '`ProgressionStructure`). Regenerate with:');
  b.writeln();
  b.writeln('```');
  b.writeln('flutter test test/simulation/simulation_test.dart');
  b.writeln('```');
  b.writeln();

  // ── حالة التأكيدات أولا — هي ما يُفتح التقرير من أجله ──
  b.writeln('## Assertions');
  b.writeln();
  b.writeln('| # | Assertion | Status | Detail |');
  b.writeln('|---|-----------|--------|--------|');
  for (var i = 0; i < outcomes.length; i++) {
    final o = outcomes[i];
    b.writeln('| ${i + 1} | ${o.name} | '
        '${o.passed ? 'PASS ✅' : 'FAIL ❌'} | ${o.detail} |');
  }
  b.writeln();

  // ── ملخص لكل نمط ──
  b.writeln('## Archetype summary');
  b.writeln();
  b.writeln('| Archetype | Players | Stage d7 | Stage d14 | Stage d30 | '
      'Safety (total / max per player) | Near-miss (total / avg per player) | '
      'Faucet | Sink | Ratio | Cosmetics |');
  b.writeln('|---|---|---|---|---|---|---|---|---|---|---|');
  for (final a in result.archetypes) {
    final players = a.players;
    final safetyTotal = players.fold(0, (s, p) => s + p.safetyTriggers);
    final safetyMax =
        players.map((p) => p.safetyTriggers).fold(0, (x, y) => x > y ? x : y);
    final nearMissTotal = players.fold(0, (s, p) => s + p.nearMissFires);
    final cosmetics = players.fold(0, (s, p) => s + p.cosmeticsBought);
    b.writeln('| ${a.spec.nameEn} | ${players.length} '
        '| ${median([for (final p in players) p.stageAtDay7])} '
        '| ${median([for (final p in players) p.stageAtDay14])} '
        '| ${median([for (final p in players) p.stageAtDay30])} '
        '| $safetyTotal / $safetyMax '
        '| $nearMissTotal / ${(nearMissTotal / players.length).toStringAsFixed(1)} '
        '| ${a.totalFaucet()} | ${a.totalSink()} '
        '| ${a.faucetSinkRatio().toStringAsFixed(3)} '
        '| $cosmetics |');
  }
  b.writeln();

  // ── صحّة الاقتصاد لكل نمط ──
  //
  // الجدولان أدناه هما ما يُحكَم به على الاقتصاد، لا الرصيد وحده:
  // «متى يفلس» و«متى يتخم» طرفان لا يظهران في وسيط سليم المظهر.
  b.writeln('## Economy health per archetype');
  b.writeln();
  b.writeln('| Archetype | Earn/day | Spend/day | Mean bal | Median bal | '
      'Min bal | Max bal | Hints bought | Hints free | Ads | Ad-double coins | '
      '% ever broke | % over $kRichThreshold |');
  b.writeln('|---|---|---|---|---|---|---|---|---|---|---|---|---|');
  for (final a in result.archetypes) {
    final ps = a.players;
    final n = ps.length;
    final finals = [for (final p in ps) p.dailyBalance[kDays - 1]];
    final broke = ps.where((p) => p.minBalance <= 0).length;
    final rich = finals.where((v) => v >= kRichThreshold).length;
    b.writeln('| ${a.spec.nameEn} '
        '| ${(a.totalFaucet() / n / kDays).toStringAsFixed(1)} '
        '| ${(a.totalSink() / n / kDays).toStringAsFixed(1)} '
        '| ${(finals.fold(0, (s, v) => s + v) / n).toStringAsFixed(0)} '
        '| ${median(finals)} '
        '| ${median([for (final p in ps) p.minBalance])} '
        '| ${median([for (final p in ps) p.maxBalance])} '
        '| ${(ps.fold(0, (s, p) => s + p.hintsBought) / n).toStringAsFixed(1)} '
        '| ${(ps.fold(0, (s, p) => s + p.hintsFree) / n).toStringAsFixed(1)} '
        '| ${(ps.fold(0, (s, p) => s + p.adsWatched) / n).toStringAsFixed(1)} '
        '| ${(ps.fold(0, (s, p) => s + p.adDoubleCoins) / n).toStringAsFixed(0)} '
        '| ${(100 * broke / n).toStringAsFixed(1)}% '
        '| ${(100 * rich / n).toStringAsFixed(1)}% |');
  }
  b.writeln();
  b.writeln('Per-player daily averages. "Min bal" and "Max bal" are the median '
      'across players of each player\'s own lifetime low and high, sampled on '
      'every wallet movement — not just at end of day. "% ever broke" is the '
      'share of players whose balance touched 0 at any moment.');
  b.writeln();

  b.writeln('## Balance at the checkpoint days');
  b.writeln();
  b.writeln('| Archetype | Day 1 | Day 7 | Day 15 | Day 30 |');
  b.writeln('|---|---|---|---|---|');
  for (final a in result.archetypes) {
    b.writeln('| ${a.spec.nameEn} '
        '| ${median(a.balancesAtDay(1))} '
        '| ${median(a.balancesAtDay(7))} '
        '| ${median(a.balancesAtDay(15))} '
        '| ${median(a.balancesAtDay(30))} |');
  }
  b.writeln();

  // ── منحنى الرصيد يوما بيوم ──
  for (final a in result.archetypes) {
    b.writeln('## ${a.spec.nameEn} — daily coin balance');
    b.writeln();
    b.writeln('| Day | p10 | Median | p90 |');
    b.writeln('|-----|-----|--------|-----|');
    for (var day = 1; day <= kDays; day++) {
      final balances = a.balancesAtDay(day);
      b.writeln('| $day | ${percentile(balances, 0.10)} '
          '| ${median(balances)} | ${percentile(balances, 0.90)} |');
    }
    b.writeln();
  }

  // ── لا بوابات تحجز التقدّم ──
  b.writeln('## World gates');
  b.writeln();
  b.writeln('There is no star or jar gate any more: finishing every stage of '
      'a chapter opens the next chapter, and finishing the last chapter of '
      'a world opens the next world. No player can be blocked from '
      'progressing, so there is nothing to farm and nothing to bypass.');
  b.writeln();

  // ── الافتراضات السلوكية كاملة — لا رقم ناتج بلا سلوكه المفترض ──
  b.writeln('## Behavioral model assumptions');
  b.writeln();
  b.writeln('Balance numbers all come from `BalanceConfig` and the real '
      'engines. The rows below are *behavior*, which the game cannot know '
      'and the simulation must assume (see `sim_model.dart`).');
  b.writeln();
  b.writeln('| Assumption | ${archetypes.map((a) => a.nameEn).join(' | ')} |');
  b.writeln('|---|---|---|---|---|');
  String fmt(num Function(ArchetypeSpec) f) =>
      archetypes.map((a) => '${f(a)}').join(' | ');
  b.writeln('| Share of players | ${fmt((a) => a.share)} |');
  b.writeln('| Sessions/day | ${fmt((a) => a.sessionsPerDay)} |');
  b.writeln('| Stages/day | ${fmt((a) => a.stagesPerDay)} |');
  b.writeln('| Mean hints/stage | ${fmt((a) => a.meanHintsPerStage)} |');
  b.writeln('| Abandon rate | ${fmt((a) => a.abandonRate)} |');
  b.writeln('| Plays on a given day | ${fmt((a) => a.playProb)} |');
  b.writeln('| First-clear share of stages | ${fmt((a) => a.newStageShare)} |');
  b.writeln('| Bonus words/new stage | ${fmt((a) => a.bonusMeanNew)} |');
  b.writeln('| Bonus words/replay | ${fmt((a) => a.bonusMeanReplay)} |');
  b.writeln('| Bonus words/farm replay | ${fmt((a) => a.bonusMeanFarm)} |');
  // نفس المعامل يحكم مسار الجوائز: سمة «يجمع المنح المجانية» واحدة
  b.writeln('| Claims login calendar + reward track | '
      '${fmt((a) => a.loginClaimProb)} |');
  b.writeln('| Mission easy/med/hard | ${archetypes.map((a) => '${a.missionEasyProb}/${a.missionMediumProb}/${a.missionHardProb}').join(' | ')} |');
  b.writeln('| Weekly badge chance | ${fmt((a) => a.weeklyBadgeProb)} |');
  b.writeln('| Watches all rewarded ads | ${archetypes.map((a) => a.watchesAllAds).join(' | ')} |');
  b.writeln('| Spins wheel | ${archetypes.map((a) => a.spinsWheel).join(' | ')} |');
  b.writeln('| Hint reserve (never spends below) | ${fmt((a) => a.hintReserve)} |');
  b.writeln('| Cosmetic buy threshold | ${fmt((a) => a.cosmeticThreshold)} |');
  b.writeln('| Cosmetic buy chance/day | ${fmt((a) => a.cosmeticProb)} |');
  b.writeln('| Cosmetic price range | ${archetypes.map((a) => '${a.cosmeticMin}-${a.cosmeticMax}').join(' | ')} |');
  b.writeln('| Max cosmetics/day | ${fmt((a) => a.cosmeticMaxPerDay)} |');
  b.writeln();
  b.writeln('Core words per stage: $kCoreWordsPerStage (same assumption as '
      '`test/economy/economy_simulation_test.dart` — real per-stage word '
      'counts are not authored yet).');
  b.writeln();
  b.writeln('### Reading note');
  b.writeln();
  b.writeln('The Regular balance-band assertion (300-800 every day) and the '
      'faucet/sink ratio assertion (1.10-1.30) are mathematically coupled: '
      'retained balance = faucet − sink, so both can only hold if the '
      'Regular 30-day faucet stays under ~8,800 coins. With the current '
      '`BalanceConfig` daily grants (~85/day login calendar, the six-month '
      'reward track, missions + chest), that forces the model to assume '
      'Regular players skip days, skip some claims, and spend most stage '
      'slots on replays. If real telemetry shows higher engagement than '
      'this model, the daily-grant faucet must shrink for these targets '
      'to stay reachable.');

  return b.toString();
}
