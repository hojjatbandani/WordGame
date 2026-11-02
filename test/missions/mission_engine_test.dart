import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/missions/mission_engine.dart';
import 'package:huruf/data/missions/mission_models.dart';

void main() {
  group('مجمعات المهمات المعطاة حرفيا', () {
    test('اليومية السهلة: 5 كلمات / مرحلة واحدة / كلمة إضافية، كلها +15', () {
      expect(dailyEasyPool.map((m) => m.coinsReward).toSet(), {15});
      expect(dailyEasyPool.firstWhere((m) => m.type == MissionObjectiveType.findWords).target, 5);
      expect(dailyEasyPool.firstWhere((m) => m.type == MissionObjectiveType.completeStages).target, 1);
      expect(dailyEasyPool.firstWhere((m) => m.type == MissionObjectiveType.findBonusWords).target, 1);
    });

    test('اليومية المتوسطة: 3 كلمات إضافية / مرحلتان / 10 كلمات، كلها +25', () {
      expect(dailyMediumPool.map((m) => m.coinsReward).toSet(), {25});
      expect(dailyMediumPool.firstWhere((m) => m.type == MissionObjectiveType.findBonusWords).target, 3);
      expect(dailyMediumPool.firstWhere((m) => m.type == MissionObjectiveType.completeStages).target, 2);
      expect(dailyMediumPool.firstWhere((m) => m.type == MissionObjectiveType.findWords).target, 10);
    });

    test('اليومية الصعبة: مرحلة بلا تلميحات / 8 كلمات إضافية / 15 كلمة، كلها +40', () {
      expect(dailyHardPool.map((m) => m.coinsReward).toSet(), {40});
      expect(dailyHardPool.firstWhere((m) => m.type == MissionObjectiveType.findBonusWords).target, 8);
      expect(dailyHardPool.firstWhere((m) => m.type == MissionObjectiveType.findWords).target, 15);
      expect(dailyHardPool.every((m) => m.minPlayerLevel == null), isTrue,
          reason: 'لا مهمة يومية مشروطة بمستوى بعد إزالة النزال');
    });

    test('الأسبوعية: 100 كلمة / 25 إضافية / 5 أيام مختلفة / 20 مرحلة', () {
      expect(weeklyPool.firstWhere((m) => m.type == MissionObjectiveType.findWords).target, 100);
      expect(weeklyPool.firstWhere((m) => m.type == MissionObjectiveType.findBonusWords).target, 25);
      expect(weeklyPool.firstWhere((m) => m.type == MissionObjectiveType.playDifferentDays).target, 5);
      expect(weeklyPool.firstWhere((m) => m.type == MissionObjectiveType.completeStages).target, 20);
    });
  });

  group('اختبار قبول: كل مهمات اليوم قابلة للإسناد بأي مستوى', () {
    test('بمستوى 1 تُسنَد ثلاث مهمات كاملة — لا مهمة مقفلة بمستوى', () {
      final rng = Random(7);
      for (var i = 0; i < 500; i++) {
        final picks = MissionEngine.selectDaily(playerLevel: 1, rng: rng);
        expect(picks, hasLength(3));
      }
    });

    test('كل اختيار يومي يعيد بالضبط مهمة واحدة من كل مستوى صعوبة', () {
      final rng = Random(1);
      final picks = MissionEngine.selectDaily(playerLevel: 20, rng: rng);
      expect(dailyEasyPool.map((m) => m.id), contains(picks[0].id));
      expect(dailyMediumPool.map((m) => m.id), contains(picks[1].id));
      expect(dailyHardPool.map((m) => m.id), contains(picks[2].id));
    });
  });

  group('MissionEngine.selectWeekly', () {
    test('يعيد 3 مهمات مختلفة (بلا تكرار) من المجمّع الأسبوعي', () {
      final rng = Random(3);
      final picks = MissionEngine.selectWeekly(rng: rng);
      expect(picks.length, 3);
      expect(picks.map((m) => m.id).toSet().length, 3);
      for (final p in picks) {
        expect(weeklyPool.map((m) => m.id), contains(p.id));
      }
    });
  });

  group('MissionEngine.rollDailyChest', () {
    test('العملات دوما بين 50 و120 ضمنا عبر 1000 محاولة', () {
      final rng = Random(11);
      for (var i = 0; i < 1000; i++) {
        final reward = MissionEngine.rollDailyChest(rng);
        expect(reward.coins, greaterThanOrEqualTo(50));
        expect(reward.coins, lessThanOrEqualTo(120));
      }
    });

    test('شحنة التلميح تظهر بنسبة معقولة (ليست دوما true أو دوما false)', () {
      final rng = Random(11);
      var withCharge = 0;
      const trials = 2000;
      for (var i = 0; i < trials; i++) {
        if (MissionEngine.rollDailyChest(rng).hintCharge) withCharge++;
      }
      final fraction = withCharge / trials;
      expect(fraction, closeTo(0.5, 0.05));
    });
  });

  group('MissionEngine.mostRecentMonday', () {
    test('الاثنين نفسه يعيد نفسه', () {
      final monday = DateTime(2026, 1, 5); // اثنين فعلي
      expect(MissionEngine.mostRecentMonday(monday), monday);
    });

    test('الأحد يعيد اثنين الأسبوع نفسه (قبله بـ6 أيام)', () {
      final sunday = DateTime(2026, 1, 11);
      expect(MissionEngine.mostRecentMonday(sunday), DateTime(2026, 1, 5));
    });

    test('الأربعاء يعيد اثنين نفس الأسبوع', () {
      final wednesday = DateTime(2026, 1, 7);
      expect(MissionEngine.mostRecentMonday(wednesday), DateTime(2026, 1, 5));
    });
  });

  group('MissionInstance.reportEvent', () {
    test('حدث مطابق للنوع يزيد التقدّم', () {
      const def = MissionDef(
          id: 't', type: MissionObjectiveType.findWords, target: 5, coinsReward: 15);
      final m = MissionInstance.fresh(def).reportEvent(MissionObjectiveType.findWords, 3);
      expect(m.progress, 3);
      expect(m.isComplete, isFalse);
    });

    test('حدث من نوع مختلف لا يغيّر شيئا', () {
      const def = MissionDef(
          id: 't', type: MissionObjectiveType.findWords, target: 5, coinsReward: 15);
      final m = MissionInstance.fresh(def)
          .reportEvent(MissionObjectiveType.completeStages, 3);
      expect(m.progress, 0);
    });

    test('التقدّم لا يتجاوز الهدف حتى مع أحداث زائدة', () {
      const def = MissionDef(
          id: 't', type: MissionObjectiveType.findWords, target: 5, coinsReward: 15);
      final m = MissionInstance.fresh(def).reportEvent(MissionObjectiveType.findWords, 50);
      expect(m.progress, 5);
      expect(m.isComplete, isTrue);
    });
  });
}
