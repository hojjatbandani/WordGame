import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/progression/player_state.dart';
import 'package:huruf/data/progression/progression_merge.dart';
import 'package:huruf/data/progression/stage_progress.dart';
import 'package:huruf/data/progression/world_defs.dart';

StageProgress _progress(
  int stageId, {
  bool completed = true,
  Set<String> bonus = const {},
  int? hints,
  int? timeMs,
  int attempts = 1,
}) =>
    StageProgress(
      stageId: stageId,
      completed: completed,
      bestTimeMs: timeMs,
      hintsUsedBest: hints,
      bonusWordsFound: bonus,
      attempts: attempts,
      lastPlayedAt: null,
    );

void main() {
  late ProgressionStructure structure;

  setUp(() {
    structure = ProgressionStructure.generate();
  });

  group('دمج التقدّم المحلي مع البعيد (اختبار قبول 5)', () {
    test('دمج حالة محلية مع حالة بعيدة قديمة لا يخفّض أي عدّاد أبدا', () {
      final local = PlayerState(
        wallet: const PlayerWallet(
            coins: 500, xp: 1200, hintCharges: 3),
        level: 5,
        currentStageId: 90,
        unlockedWorldIds: {1, 2},
        unlockedChapterIds: {1, 2, 3, 4, 5, 6},
        jarProgress: {1: 40, 2: 15},
        schemaVersion: 2,
      );
      final localProgress = {
        1: _progress(1, bonus: {'كتب', 'قلم'}, hints: 0),
        90: _progress(90),
      };

      // بعيد "قديم": أرقام أقل من كل النواحي — محاكاة جهاز لم يُزامن منذ فترة
      final remote = PlayerState(
        wallet: const PlayerWallet(
            coins: 300, xp: 900, hintCharges: 5),
        level: 4,
        currentStageId: 70,
        unlockedWorldIds: {1},
        unlockedChapterIds: {1, 2, 3},
        jarProgress: {1: 25},
        schemaVersion: 2,
      );
      final remoteProgress = {
        1: _progress(1, bonus: {'كتب'}, hints: 1),
        70: _progress(70),
      };

      final merged = ProgressionMerge.merge(
        local: local,
        localProgress: localProgress,
        remote: remote,
        remoteProgress: remoteProgress,
        structure: structure,
      );

      // لا عدّاد محفظة يتراجع تحت أي من الطرفين
      expect(merged.state.wallet.coins,
          greaterThanOrEqualTo(local.wallet.coins));
      expect(
          merged.state.wallet.coins, greaterThanOrEqualTo(remote.wallet.coins));
      expect(merged.state.wallet.xp, greaterThanOrEqualTo(local.wallet.xp));
      expect(merged.state.wallet.xp, greaterThanOrEqualTo(remote.wallet.xp));
      expect(merged.state.wallet.hintCharges,
          greaterThanOrEqualTo(local.wallet.hintCharges));
      expect(merged.state.wallet.hintCharges,
          greaterThanOrEqualTo(remote.wallet.hintCharges));

      // القيم الفعلية: max حرفيا لكل عدّاد
      expect(merged.state.wallet.coins, 500);
      expect(merged.state.wallet.xp, 1200);

      // المؤشر الحالي لا يتراجع
      expect(merged.state.currentStageId,
          greaterThanOrEqualTo(local.currentStageId));
      expect(merged.state.currentStageId,
          greaterThanOrEqualTo(remote.currentStageId));

      // الجرّة: أكبر قيمة لكل عالم على حدة، لا مجموع ولا تراجع
      expect(merged.state.jarProgress[1], 40);
      expect(merged.state.jarProgress[2], 15);

      // الفتح: اتحاد، لا إزالة لما فتحه أي طرف
      expect(merged.state.unlockedWorldIds, containsAll(local.unlockedWorldIds));
      expect(
          merged.state.unlockedWorldIds, containsAll(remote.unlockedWorldIds));
      expect(merged.state.unlockedChapterIds,
          containsAll(local.unlockedChapterIds));
      expect(merged.state.unlockedChapterIds,
          containsAll(remote.unlockedChapterIds));

      // تقدّم كل مرحلة: اتحاد الكلمات الإضافية، لا فقدان لأي كلمة وُجدت
      // في أي طرف
      final mergedStage1 = merged.stageProgress[1]!;
      expect(mergedStage1.bonusWordsFound, containsAll({'كتب', 'قلم'}));
      expect(mergedStage1.completed, isTrue);
      expect(mergedStage1.hintsUsedBest, 0,
          reason: 'أقل عدد تلميحات بين الطرفين (0 محليا) يبقى الأصغر');

      // المرحلتان اللتان لعبهما طرف واحد فقط تبقيان في الناتج كاملتين
      expect(merged.stageProgress[90]!.completed, isTrue);
      expect(merged.stageProgress[70]!.completed, isTrue);
    });

    test('دمج حالتين متطابقتين تماما لا يغيّر شيئا (خاصية idempotent)', () {
      final state = PlayerState(
        wallet: const PlayerWallet(
            coins: 100, xp: 200, hintCharges: 1),
        level: 2,
        currentStageId: 15,
        unlockedWorldIds: {1},
        unlockedChapterIds: {1, 2},
        jarProgress: {1: 5},
        schemaVersion: 2,
      );
      final progress = {5: _progress(5, bonus: {'كلمة'})};

      final merged = ProgressionMerge.merge(
        local: state,
        localProgress: progress,
        remote: state,
        remoteProgress: progress,
        structure: structure,
      );

      expect(merged.state.wallet.coins, 100);
      expect(merged.state.wallet.xp, 200);
      expect(merged.stageProgress[5]!.bonusWordsFound, {'كلمة'});
    });

    test('دمج مرحلة موجودة في طرف واحد فقط يُبقيها كما هي كاملة', () {
      final base = PlayerState(
        wallet: const PlayerWallet(coins: 0, xp: 0, hintCharges: 0),
        level: 1,
        currentStageId: 1,
        unlockedWorldIds: {1},
        unlockedChapterIds: {1},
        jarProgress: const {},
        schemaVersion: 2,
      );
      final merged = ProgressionMerge.merge(
        local: base,
        localProgress: {3: _progress(3, bonus: {'أ', 'ب'})},
        remote: base,
        remoteProgress: const {},
        structure: structure,
      );
      expect(merged.stageProgress[3]!.completed, isTrue);
      expect(merged.stageProgress[3]!.bonusWordsFound, {'أ', 'ب'});
    });
  });
}
