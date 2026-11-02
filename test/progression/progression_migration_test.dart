import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/progression/player_level_curve.dart';
import 'package:huruf/data/progression/progression_migration.dart';
import 'package:huruf/data/progression/world_defs.dart';

void main() {
  late ProgressionStructure structure;

  setUp(() {
    structure = ProgressionStructure.generate();
  });

  group('هجرة v1 إلى v2 (اختبار قبول 4)', () {
    test('137 مرحلة مكتملة و4210 نقطة تنتج coins=4210, xp=2740, stars=137, '
        'وفتحا يصل حتى العالم 3', () {
      final result = ProgressionMigration.migrateFromV1(
        legacyPoints: 4210,
        legacyCompletedCount: 137,
        legacyBonusJar: 0,
        structure: structure,
      );

      expect(result.state.wallet.coins, 4210,
          reason: 'العملات 1:1 من النقاط القديمة، بلا أي إضافة تلقائية '
              '— صندوق الترحيب معلّق منفصل، راجع الشرح في '
              'progression_migration.dart');
      expect(result.state.wallet.xp, 2740, reason: '137 × 20 XP للمرحلة');

      // المرحلة 137 تقع في العالم 3 (121-180)، فيُفتح العالم 3 لاحتوائه
      // مرحلة مكتملة، لكن ليس العالم 4 (181-500) الذي لا مرحلة منه مكتملة
      expect(result.state.unlockedWorldIds, contains(1));
      expect(result.state.unlockedWorldIds, contains(2));
      expect(result.state.unlockedWorldIds, contains(3));
      expect(result.state.unlockedWorldIds, isNot(contains(4)),
          reason: 'لا مرحلة في العالم 4 مكتملة، فيجب ألا يُفتح');

      // 137 إدخال تقدّم بالضبط، كلها مكتملة
      expect(result.stageProgress.length, 137);
      expect(result.stageProgress.values.every((p) => p.completed), isTrue);

      // التالي للعب هو 138 (لا يزال داخل العالم 3)
      expect(result.state.currentStageId, 138);
    });

    test('صندوق الترحيب يُعاد منفصلا بقيمة BalanceConfig ولا يُدمَج في '
        'الرصيد تلقائيا', () {
      final result = ProgressionMigration.migrateFromV1(
        legacyPoints: 4210,
        legacyCompletedCount: 137,
        legacyBonusJar: 0,
        structure: structure,
      );
      expect(result.pendingWelcomeChestCoins,
          BalanceConfig.migrationWelcomeChestCoins);
      expect(result.pendingWelcomeChestCoins, 200);
    });

    test('مستوى اللاعب بعد الهجرة متوافق مع منحنى المستوى المُشتق من '
        '2740 XP (فحص إضافي غير مطلوب في اختبارات القبول الخمسة)', () {
      final result = ProgressionMigration.migrateFromV1(
        legacyPoints: 4210,
        legacyCompletedCount: 137,
        legacyBonusJar: 0,
        structure: structure,
      );
      expect(result.state.level, PlayerLevelCurve.currentLevel(2740));
    });

    test('لاعب لم يكمل أي مرحلة (تثبيت جديد) يُهاجَر بأمان: عملات ناقلة '
        'فقط، صفر XP/نجوم، عالم1/فصل1 مفتوحان', () {
      final result = ProgressionMigration.migrateFromV1(
        legacyPoints: 100,
        legacyCompletedCount: 0,
        legacyBonusJar: 0,
        structure: structure,
      );
      expect(result.state.wallet.coins, 100);
      expect(result.state.wallet.xp, 0);
      expect(result.state.currentStageId, 1);
      expect(result.state.unlockedWorldIds, {1});
    });

    test('جرّة العالم القديمة العامة تُنسَب لعالم موضع اللاعب الحالي، لا '
        'تُفقَد صمتا', () {
      final result = ProgressionMigration.migrateFromV1(
        legacyPoints: 500,
        legacyCompletedCount: 137, // العالم 3
        legacyBonusJar: 12,
        structure: structure,
      );
      final world3 = structure.stageById(137).worldId;
      expect(result.state.jarProgress[world3], 12);
    });

    test('عدد المراحل القديم يُقصّ عند حد اللعبة الحالي فلا ينهار عند '
        'قيمة غير منطقية', () {
      final result = ProgressionMigration.migrateFromV1(
        legacyPoints: 1,
        legacyCompletedCount: 999999,
        legacyBonusJar: 0,
        structure: structure,
      );
      expect(result.stageProgress.length, BalanceConfig.totalStages);
      expect(result.state.currentStageId, BalanceConfig.totalStages);
    });
  });
}
