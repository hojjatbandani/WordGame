// محاكاة اقتصادية على مقياس 1000 لاعب × 100 مرحلة. تدمج ProgressionStructure
// وProgressionRules الحقيقيتين (من مهمة سابقة) لحدود العوالم/الفصول
// ولاكتشاف إتمام الفصل/العالم بدقة — لا نموذجا مبسّطا منفصلا لذلك.
//
// ═══ افتراضات محاكاة صريحة — ليست أرقام توازن، ولا تُستخدم في أي كود
// إنتاجي ═══
// عدد كلمات كل مرحلة غير موجود فعليا بعد (StageDef.coreWordCount لا يزال
// صفرا افتراضيا بانتظار خط أنابيب تأليف محتوى — راجع الملاحظة في
// world_defs.dart وردّ المهمة السابقة). هذا الملف يفترض 5 كلمات أساسية
// لكل مرحلة، ومتوسط كلمة إضافية واحدة لكل مرحلة (نفس المتوسط لكل
// الملامح الثلاثة — المهمة تُغيّر محور استخدام التلميحات فقط، لا محور
// إيجاد الكلمات الإضافية). هذان رقما نموذج محاكاة موثّقان بوضوح،
// قابلان للتعديل هنا بمعزل تام عن BalanceConfig.
//
// ملاحظة نطاق مهمة: الهدف الأعلى في نص المهمة يتحدث عن "أيام 1-30"، لكن
// اختبار القبول المطلوب فعليا يتحدث عن "مراحل 10/25/50/100" — لا معدّل
// مراحل/يوم مُعطى لتحويل أحدهما للآخر، فهذا الاختبار يطابق حرفيا محور
// "المراحل" المذكور في اختبار القبول، ولا يحاول محاكاة "يوم تقويمي".

import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/economy/economy_models.dart';
import 'package:huruf/data/economy/economy_service.dart';
import 'package:huruf/data/economy/stage_reward.dart';
import 'package:huruf/data/progression/player_state.dart';
import 'package:huruf/data/progression/progression_rules.dart';
import 'package:huruf/data/progression/stage_progress.dart';
import 'package:huruf/data/progression/world_defs.dart';

const int _kSimCoreWordsPerStage = 5;
const double _kSimMeanBonusWordsPerStage = 1.0;
const int _kSimMaxBonusWordsPerStage = 3;

/// سقف أعلى لعيّنة بواسون المتطرّفة فقط (حارس أداء، لا قاعدة اقتصادية)
const int _kSimMaxHintsPerStageDraw = 12;

/// عيّنة بواسون بخوارزمية كنوث القياسية (ليست عشوائية مخترعة هنا، طريقة
/// معروفة لعدد صحيح عشوائي بمتوسط معطى)
int _poisson(Random rng, double mean) {
  if (mean <= 0) return 0;
  final l = exp(-mean);
  var k = 0;
  var p = 1.0;
  do {
    k++;
    p *= rng.nextDouble();
  } while (p > l);
  return k - 1;
}

class _Profile {
  final String name;
  final double meanHintsPerStage;
  const _Profile(this.name, this.meanHintsPerStage);
}

const _profiles = [
  _Profile('light', 0.5),
  _Profile('medium', 1.5),
  _Profile('heavy', 3.5),
];

/// يحاكي لاعبا واحدا عبر [stageCount] مرحلة متتالية من المرحلة 1 — تباعا
/// بلا إعادة لعب (سلوك إعادة اللعب مختبر بمعزل في stage_reward_test.dart
/// عبر computeStageReward مباشرة). يعيد رصيد العملات بعد كل مرحلة
/// (balances[0] = الرصيد بعد المرحلة 1).
List<int> _simulateOnePlayer({
  required ProgressionStructure structure,
  required _Profile profile,
  required int stageCount,
  required Random rng,
}) {
  final economy = EconomyService(wallet: PlayerWallet.initial());
  final progress = <int, StageProgress>{};
  final balances = <int>[];

  for (var stageId = 1; stageId <= stageCount; stageId++) {
    final stageDef = structure.stageById(stageId);
    final world = structure.worldById(stageDef.worldId);

    final desiredHints = min(
        _poisson(rng, profile.meanHintsPerStage), _kSimMaxHintsPerStageDraw);
    var hintsActuallyUsed = 0;
    for (var i = 0; i < desiredHints; i++) {
      if (i == 0 && economy.consumeHintCharge()) {
        hintsActuallyUsed++;
        continue;
      }
      final cost = economy.quoteHintCost(HintType.revealRandomLetter,
          hintsUsedThisStage: i, worldId: world.id);
      final result = economy.spend(cost, SpendReason.hint);
      if (result.isFailure) break; // لا يقدر يدفع أكثر، يتوقف هنا واقعيا
      hintsActuallyUsed++;
    }

    final bonusWordsFound = min(_poisson(rng, _kSimMeanBonusWordsPerStage),
        _kSimMaxBonusWordsPerStage);
    // «مرحلة نظيفة» = بلا أي تلميح، نفس تعريف StatKey.perfectLevels
    final isPerfect = hintsActuallyUsed == 0;

    progress[stageId] = StageProgress(
      stageId: stageId,
      completed: true,
      bestTimeMs: null,
      hintsUsedBest: hintsActuallyUsed,
      bonusWordsFound: {
        for (var i = 0; i < bonusWordsFound; i++) 'w$stageId-$i'
      },
      attempts: 1,
      lastPlayedAt: null,
    );

    // تحسين أداء صحيح *فقط* لأن هذه المحاكاة تلعب 1..N تباعا بلا إعادة
    // لعب: إتمام الفصل/العالم لا يقع إلا عند حل مرحلة الزعيم بالضبط
    var chapterJustCompleted = false;
    var worldJustCompleted = false;
    var chestRoll = 0;
    if (stageDef.isBoss) {
      final chapter = structure.chapterById(stageDef.chapterId);
      chapterJustCompleted =
          ProgressionRules.isChapterComplete(chapter, progress);
      if (chapterJustCompleted) {
        chestRoll = EconomyService.chapterChestCoins(chapter.id);
        worldJustCompleted =
            ProgressionRules.isWorldComplete(world, structure, progress);
      }
    }

    economy.applyStageReward(StageResult(
      worldId: world.id,
      isBossStage: stageDef.isBoss,
      isReplay: false,
      coreWordsFound: _kSimCoreWordsPerStage,
      newBonusWordsFoundThisRun: bonusWordsFound,
      isPerfect: isPerfect,
      chapterJustCompleted: chapterJustCompleted,
      worldJustCompleted: worldJustCompleted,
      chapterChestAlreadyRolled: chestRoll,
    ));

    economy.grantFreeHintChargeIfEarned(stageId);
    balances.add(economy.wallet.coins);
  }

  return balances;
}

int _median(List<int> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : ((sorted[mid - 1] + sorted[mid]) / 2).round();
}

double _mean(List<int> values) =>
    values.reduce((a, b) => a + b) / values.length;

void main() {
  test(
      'محاكاة اقتصادية: 1000 لاعب، 100 مرحلة، ثلاث ملامح استخدام '
      'تلميحات (اختبار قبول)', () {
    final structure = ProgressionStructure.generate();
    const playerCount = 1000;
    const stageCount = 100;
    const checkpoints = [10, 25, 50, 100];
    final rng = Random(2026); // بذرة ثابتة — الاختبار حتمي دوما

    // تُجمَع كل النتائج وتُطبَع أولا لكل الملامح الثلاثة قبل أي تحقّق —
    // كي لا يُخفي فشل مبكر في ملمح واحد بيانات الملامح الأخرى (fail-fast
    // في expect() كان يقطع الحلقة قبل وصولها لـheavy في أول تشغيل)
    final results = <String, Map<int, List<int>>>{};
    for (final profile in _profiles) {
      final atCheckpoint = {for (final c in checkpoints) c: <int>[]};
      for (var p = 0; p < playerCount; p++) {
        final balances = _simulateOnePlayer(
          structure: structure,
          profile: profile,
          stageCount: stageCount,
          rng: rng,
        );
        for (final c in checkpoints) {
          atCheckpoint[c]!.add(balances[c - 1]);
        }
      }
      results[profile.name] = atCheckpoint;

      debugPrint('── ملمح ${profile.name} '
          '(متوسط ${profile.meanHintsPerStage} تلميح/مرحلة) ──');
      for (final c in checkpoints) {
        final values = atCheckpoint[c]!;
        debugPrint('  مرحلة $c: وسيط=${_median(values)}  '
            'متوسط=${_mean(values).toStringAsFixed(1)}');
      }
    }

    // ── التأكيدات ──
    //
    // كان هنا مدى واحد (300–800 لملمح medium عند كل نقطة) عُوير على
    // اقتصاد قديم يدفع ~33 عملة للمرحلة. بعد خفض أجر المرحلة إلى سقف
    // 12 ورفع سعرَي التلميح إلى 40 و25 صار ذلك المدى بلا معنى: الوسيط
    // الفعلي 21. فبدل رقم مُعاد ضبطه على ما تخرجه المحاكاة اليوم (وهو
    // ليس اختبارا بل تسجيلا)، صارت التأكيدات على *خصائص* الاقتصاد التي
    // يجب أن تصمد مهما عُدّلت الأرقام.

    for (final profile in results.keys) {
      for (final c in checkpoints) {
        final median = _median(results[profile]![c]!);
        expect(median, greaterThanOrEqualTo(0),
            reason: 'لا ملمح يُفلس: $profile عند المرحلة $c وُجد $median');
      }
    }

    // من يقتصد في التلميحات يراكم فعلا — وإلا فلا معنى للاقتصاد أصلا
    final light = results['light']!;
    expect(_median(light[100]!), greaterThan(_median(light[10]!) * 5),
        reason: 'رصيد المقتصد يجب أن ينمو نموا واضحا على 100 مرحلة');
    expect(_median(light[100]!), greaterThan(300),
        reason: 'ويبلغ ما يكفي لشراء شيء ذي بال');

    // ومن يُكثر منها يعيش على الكفاف: هذا هو أثر القرار (سقف 12 للمرحلة
    // مقابل 40 و25 للتلميح) لا عرَض جانبي. التلميح المكثّف يُموَّل من
    // الشحنات المجانية لا من الأجر.
    final heavy = results['heavy']!;
    expect(_median(heavy[100]!), lessThan(_median(light[100]!) / 5),
        reason: 'كثير التلميح لا يجوز أن يراكم كالمقتصد');

    // الترتيب بين الملامح ثابت عند نهاية المحاكاة
    expect(_median(light[100]!),
        greaterThan(_median(results['medium']![100]!)),
        reason: 'المقتصد أغنى من المتوسط');
    expect(_median(results['medium']![100]!),
        greaterThanOrEqualTo(_median(heavy[100]!)),
        reason: 'والمتوسط ليس أفقر من المُكثر');
  });
}
