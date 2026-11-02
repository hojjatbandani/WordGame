// اختبار إضافي — غير مطلوب صراحة في اختبارات القبول الخمسة. بلا هذا
// الملف، applyStageCompletion (نقطة التحوّل الفعلية الوحيدة لتسجيل
// اللعب) تبقى غير مختبرة إطلاقا رغم أنها المنطق الأكثر عرضة للخطأ هنا:
// دوام النجوم عبر إعادة اللعب، ومنع استغلال XP بإعادة لعب مرحلة واحدة.

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/progression/player_state.dart';
import 'package:huruf/data/progression/progression_engine.dart';
import 'package:huruf/data/progression/stage_progress.dart';
import 'package:huruf/data/progression/world_defs.dart';

void main() {
  late ProgressionStructure structure;
  final now = DateTime(2026, 1, 1);

  setUp(() {
    structure = ProgressionStructure.generate();
  });

  group('applyStageCompletion', () {
    test('أول إكمال لمرحلة مع كلمة إضافية واحدة يمنح 25 XP بالضبط '
        '(20 مرحلة + 5 كلمة إضافية)', () {
      final result = ProgressionEngine.applyStageCompletion(
        state: PlayerState.initial(),
        allProgress: const {},
        structure: structure,
        stageId: 1,
        bonusWordsFoundThisRun: {'كتب'},
        hintsUsedThisRun: 0,
        timeMs: 5000,
        now: now,
      );

      expect(result.stageProgress.completed, isTrue);
      expect(result.chapterCompletedThisRun, isFalse);
      expect(result.xpGainedThisRun, 25);
      expect(result.state.wallet.xp, 25);
      expect(result.state.level, 1);
    });

    test('إعادة اللعب باستخدام تلميحات لا تُنقص ما كُسب سابقا، ولا تمنح '
        'XP مرحلة مكرّرا', () {
      final first = ProgressionEngine.applyStageCompletion(
        state: PlayerState.initial(),
        allProgress: const {},
        structure: structure,
        stageId: 1,
        bonusWordsFoundThisRun: {'كتب'},
        hintsUsedThisRun: 0,
        timeMs: 5000,
        now: now,
      );

      final replay = ProgressionEngine.applyStageCompletion(
        state: first.state,
        allProgress: {1: first.stageProgress},
        structure: structure,
        stageId: 1,
        bonusWordsFoundThisRun: const {}, // لا كلمات جديدة هذه المرة
        hintsUsedThisRun: 2, // استخدم تلميحين هذه المرة
        timeMs: 9000,
        now: now,
      );

      expect(replay.stageProgress.hintsUsedBest, 0,
          reason: 'أفضل محاولة (صفر تلميحات) تبقى محفوظة رغم تلميحي '
              'هذه المحاولة');
      expect(replay.stageProgress.bonusWordsFound, {'كتب'},
          reason: 'الكلمات الإضافية تتراكم ولا تُفرَّغ');
      expect(replay.xpGainedThisRun, 0,
          reason: 'إعادة لعب مرحلة مكتملة بلا كلمات إضافية جديدة لا تمنح XP');
      expect(replay.stageProgress.attempts, 2);
      expect(replay.state.wallet.xp, 25, reason: 'لا XP إضافية عن الإعادة');
    });

    test('إكمال مرحلة الزعيم يضيف مكافأة الزعيم + مكافأة إتمام الفصل '
        'دفعة واحدة فوق مكافأة المرحلة العادية', () {
      var state = PlayerState.initial();
      final progress = <int, StageProgress>{};

      // أكمل المراحل 1..11 من فصل1/عالم1 (لا زعيم، لا مكافأة فصل بعد)
      for (var stageId = 1; stageId <= 11; stageId++) {
        final r = ProgressionEngine.applyStageCompletion(
          state: state,
          allProgress: progress,
          structure: structure,
          stageId: stageId,
          bonusWordsFoundThisRun: const {},
          hintsUsedThisRun: 0,
          timeMs: 1000,
          now: now,
        );
        state = r.state;
        progress[stageId] = r.stageProgress;
      }
      expect(state.wallet.xp, 20 * 11); // 220: لا زعيم ولا فصل بعد

      final bossResult = ProgressionEngine.applyStageCompletion(
        state: state,
        allProgress: progress,
        structure: structure,
        stageId: 12, // زعيم الفصل الأول
        bonusWordsFoundThisRun: const {},
        hintsUsedThisRun: 0,
        timeMs: 1000,
        now: now,
      );

      expect(structure.stageById(12).isBoss, isTrue);
      expect(bossResult.xpGainedThisRun, 20 + 25 + 40,
          reason: 'مرحلة عادية (20) + إضافة الزعيم (25) + إتمام الفصل (40)');
      expect(bossResult.state.wallet.xp, 220 + 85);
      expect(bossResult.chapterCompletedThisRun, isTrue,
          reason: 'زعيم الفصل هو آخر مرحلة ناقصة فيه');
    });

    test('بلوغ عتبة جرّة العالم1 (40) دفعة واحدة يمنح مكافأة الطبقة الأولى '
        'ويسجّلها في claimedJarTierByWorld', () {
      final result = ProgressionEngine.applyStageCompletion(
        state: PlayerState.initial(),
        allProgress: const {},
        structure: structure,
        stageId: 1,
        bonusWordsFoundThisRun: {for (var i = 0; i < 40; i++) 'كلمة$i'},
        hintsUsedThisRun: 0,
        timeMs: 1000,
        now: now,
      );

      expect(result.jarRewardsGained, hasLength(1));
      expect(result.jarRewardsGained.first.tier, 1);
      expect(result.jarRewardsGained.first.coins, 150);
      expect(result.state.claimedJarTierByWorld[1], 1);
    });

    test('محاولة لاحقة بلا كلمات إضافية جديدة لا تمنح مكافأة جرّة إضافية', () {
      final first = ProgressionEngine.applyStageCompletion(
        state: PlayerState.initial(),
        allProgress: const {},
        structure: structure,
        stageId: 1,
        bonusWordsFoundThisRun: {for (var i = 0; i < 40; i++) 'كلمة$i'},
        hintsUsedThisRun: 0,
        timeMs: 1000,
        now: now,
      );

      final second = ProgressionEngine.applyStageCompletion(
        state: first.state,
        allProgress: {1: first.stageProgress},
        structure: structure,
        stageId: 2,
        bonusWordsFoundThisRun: const {},
        hintsUsedThisRun: 0,
        timeMs: 1000,
        now: now,
      );

      expect(second.jarRewardsGained, isEmpty);
      expect(second.state.claimedJarTierByWorld[1], 1);
    });
  });
}
