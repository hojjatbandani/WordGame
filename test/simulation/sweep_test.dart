// مسح حساسية: يعيد تشغيل المحاكاة كاملة تحت عدة إعدادات توازن
// ويطبع أثر كل منها جنبا إلى جنب.
//
// سببه أن أسئلة التوازن الحقيقية مقارنات لا قيما مفردة: «هل نرفع صندوق
// الفصل من 30 إلى 100؟» لا يُجاب عنه برقم واحد بل بالفرق الذي يُحدثه
// في الإفلاس والتخمة عبر الأنماط الخمسة. تشغيل واحد يعطي رقما؛ المسح
// يعطي قرارا.
//
// ليس اختبار قبول — لا تأكيدات فيه، وظيفته الطباعة. يبقى ضمن الاختبارات
// لأنه يحتاج نفس محرّكات اللعبة الحقيقية التي يحتاجها sim_engine.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';

import 'report_builder.dart';
import 'sim_engine.dart';

class _Variant {
  final String name;
  final void Function() apply;
  const _Variant(this.name, this.apply);
}

void main() {
  test('مسح حساسية الاقتصاد عبر إعدادات مرشّحة', () {
    // القيم الأصلية تُستعاد بعد كل تشغيل كي لا يتسرّب إعداد إلى غيره
    final chest = BalanceConfig.coinsChapterChest;
    final safety = BalanceConfig.safetyModeCoinThreshold;
    final freeHint = BalanceConfig.stagesPerFreeHintCharge;
    final freeGrant = BalanceConfig.safetyModeFreeGrantCoins;
    final miniChallenge = BalanceConfig.safetyModeMiniChallengeRewardCoins;
    final world = BalanceConfig.coinsWorldComplete;
    final minStage = BalanceConfig.minCoinsPerStage;
    final maxStage = BalanceConfig.maxCoinsPerStage;
    final adCap = BalanceConfig.adDoubleBonusCap;

    void restore() {
      BalanceConfig.coinsChapterChest = chest;
      BalanceConfig.coinsWorldComplete = world;
      BalanceConfig.minCoinsPerStage = minStage;
      BalanceConfig.maxCoinsPerStage = maxStage;
      BalanceConfig.adDoubleBonusCap = adCap;
      BalanceConfig.safetyModeCoinThreshold = safety;
      BalanceConfig.stagesPerFreeHintCharge = freeHint;
      BalanceConfig.safetyModeFreeGrantCoins = freeGrant;
      BalanceConfig.safetyModeMiniChallengeRewardCoins = miniChallenge;
    }

    addTearDown(restore);

    final variants = <_Variant>[
      _Variant('current', () {}),
      _Variant('safety threshold 20 -> 30', () {
        BalanceConfig.safetyModeCoinThreshold = 30;
      }),
      _Variant('free hint charge every 3 stages', () {
        BalanceConfig.stagesPerFreeHintCharge = 3;
      }),
      _Variant('safety 30 + free hint every 4', () {
        BalanceConfig.safetyModeCoinThreshold = 30;
        BalanceConfig.stagesPerFreeHintCharge = 4;
      }),
      _Variant('safety 30 + free hint every 4 + safety grants 25/20', () {
        BalanceConfig.safetyModeCoinThreshold = 30;
        BalanceConfig.stagesPerFreeHintCharge = 4;
        BalanceConfig.safetyModeFreeGrantCoins = 25;
        BalanceConfig.safetyModeMiniChallengeRewardCoins = 20;
      }),
    ];

    final rows = <String>[];
    rows.add('| Variant | Archetype | d1 | d7 | d15 | d30 | % broke '
        '| % over $kRichThreshold | earn/day | spend/day |');
    rows.add('|---|---|---|---|---|---|---|---|---|---|');

    for (final v in variants) {
      restore();
      v.apply();
      final result = runSimulation();
      for (final a in result.archetypes) {
        final ps = a.players;
        final n = ps.length;
        final finals = [for (final p in ps) p.dailyBalance[kDays - 1]];
        final broke = ps.where((p) => p.minBalance <= 0).length;
        final rich = finals.where((x) => x >= kRichThreshold).length;
        rows.add('| ${v.name} | ${a.spec.nameEn} '
            '| ${median(a.balancesAtDay(1))} '
            '| ${median(a.balancesAtDay(7))} '
            '| ${median(a.balancesAtDay(15))} '
            '| ${median(a.balancesAtDay(30))} '
            '| ${(100 * broke / n).toStringAsFixed(1)}% '
            '| ${(100 * rich / n).toStringAsFixed(1)}% '
            '| ${(a.totalFaucet() / n / kDays).toStringAsFixed(0)} '
            '| ${(a.totalSink() / n / kDays).toStringAsFixed(0)} |');
      }
    }

    debugPrint(rows.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
