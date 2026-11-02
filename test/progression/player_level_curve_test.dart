// اختبار إضافي — غير مطلوب صراحة في اختبارات القبول الخمسة، لكنه يثبّت
// منحنى XP يدويا بحساب مستقل قبل أن يعتمد عليه engine/migration.

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/progression/player_level_curve.dart';

void main() {
  group('منحنى مستوى اللاعب (تحقّق إضافي)', () {
    test('حدود المستوى الأول: صفر XP وحتى 149 يبقيان عند المستوى 1', () {
      expect(PlayerLevelCurve.currentLevel(0), 1);
      expect(PlayerLevelCurve.currentLevel(149), 1);
    });

    test('150 XP بالضبط ترفع اللاعب إلى المستوى 2', () {
      expect(PlayerLevelCurve.currentLevel(150), 2);
      expect(PlayerLevelCurve.currentLevel(349), 2);
      expect(PlayerLevelCurve.currentLevel(350), 3);
    });

    test('2740 XP (نتيجة هجرة 137 مرحلة) تساوي مستوى 9 بدخول 140 XP', () {
      expect(PlayerLevelCurve.currentLevel(2740), 9);
      expect(PlayerLevelCurve.xpIntoCurrentLevel(2740), 140);
      expect(PlayerLevelCurve.xpNeededForNextLevel(2740), 550);
      expect(
        PlayerLevelCurve.levelProgress01(2740),
        closeTo(140 / 550, 0.0001),
      );
    });

    test('التكلفة التراكمية للوصول لمستوى معيّن مطابقة لمجموع يدوي مستقل', () {
      // 150 + 200 + 250 + 300 = 900 للوصول للمستوى 5
      expect(PlayerLevelCurve.cumulativeXpToReach(5), 900);
      // 150+200+250+300+350+400+450+500 = 2600 للوصول للمستوى 9
      expect(PlayerLevelCurve.cumulativeXpToReach(9), 2600);
    });

    test('التقدّم داخل المستوى صفر عند بداية المستوى بالضبط', () {
      expect(PlayerLevelCurve.levelProgress01(900), 0);
      expect(PlayerLevelCurve.currentLevel(900), 5);
    });
  });
}
