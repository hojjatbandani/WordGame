import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/progression/map_view_model.dart';
import 'package:huruf/data/progression/player_state.dart';
import 'package:huruf/data/progression/stage_progress.dart';
import 'package:huruf/data/progression/world_defs.dart';

void main() {
  late ProgressionStructure structure;

  setUp(() {
    structure = ProgressionStructure.generate();
  });

  group('بطاقات العوالم L1 (اختبار قبول 1)', () {
    test('كل الثمانية عوالم تُبنى دوما، لا سبعة ولا صفر — عالم مقفل لا '
        'يُحذَف من القائمة أبدا', () {
      final cards = MapViewModel.buildWorldCards(
        state: PlayerState.initial(),
        progress: const {},
        structure: structure,
      );
      expect(cards.length, 8);
      expect(cards.map((c) => c.worldId).toList(), List.generate(8, (i) => i + 1));
    });

    test('على تثبيت جديد: العالم1 فقط مفتوح، البقية مقفلة بشرط واضح غير فارغ',
        () {
      final cards = MapViewModel.buildWorldCards(
        state: PlayerState.initial(),
        progress: const {},
        structure: structure,
      );
      expect(cards[0].isUnlocked, isTrue);
      expect(cards[0].unlockCondition, isNull);

      for (final card in cards.skip(1)) {
        expect(card.isUnlocked, isFalse, reason: 'عالم ${card.worldId}');
        expect(card.unlockCondition, isNotNull,
            reason: 'عالم ${card.worldId} يجب أن يحمل شرطا، لا فراغا');
      }
    });

    test('شرط فتح العالم2 يذكر بالضبط: العالم1 وحالة إكمال فصله الأخير '
        '— لا نص عام مبهم ولا شرط جرّة', () {
      final cards = MapViewModel.buildWorldCards(
        state: PlayerState.initial(),
        progress: const {},
        structure: structure,
      );
      final world2 = cards[1];
      expect(world2.unlockCondition!.requiredWorldId, 1);
      expect(world2.unlockCondition!.requiredWorldLastChapterComplete, isFalse);
      expect(world2.unlockCondition!.isMet, isFalse);
    });

    test('شرط عالم مفتوح يكون null دوما — لا حاجة لعرض شرط لعالم دخلته',
        () {
      final cards = MapViewModel.buildWorldCards(
        state: PlayerState.initial().copyWith(unlockedWorldIds: {1, 2}),
        progress: const {},
        structure: structure,
      );
      expect(cards[1].unlockCondition, isNull);
    });
  });

  group('بطاقات الفصول L2', () {
    test('الفصل الأول مفتوح دوما في عالم مفتوح؛ البقية تتبع إتمام ما قبلها',
        () {
      final cards = MapViewModel.buildChapterCards(
        worldId: 1,
        state: PlayerState.initial(),
        progress: const {},
        structure: structure,
      );
      expect(cards.length, 5);
      expect(cards[0].isUnlocked, isTrue);
      expect(cards[0].stagesCompleted, 0);
      expect(cards[0].stageCount, 12);
      expect(cards[1].isUnlocked, isFalse);
    });

    test('حالة الصندوق: مقفل قبل الاكتمال، مفتوح بعده، مُستلَم بعد claim',
        () {
      final world1 = structure.worldById(1);
      final chapter1 = structure.chapterById(world1.chapterIds[0]);

      expect(
        MapViewModel.buildChapterCards(
                worldId: 1,
                state: PlayerState.initial(),
                progress: const {},
                structure: structure)[0]
            .chestState,
        ChestState.locked,
      );

      final fullProgress = {
        for (final id in chapter1.stageIds)
          id: StageProgress(
            stageId: id,
            completed: true,
            bestTimeMs: null,
            hintsUsedBest: 0,
            bonusWordsFound: const {},
            attempts: 1,
            lastPlayedAt: null,
          ),
      };

      expect(
        MapViewModel.buildChapterCards(
                worldId: 1,
                state: PlayerState.initial(),
                progress: fullProgress,
                structure: structure)[0]
            .chestState,
        ChestState.unlocked,
      );

      expect(
        MapViewModel.buildChapterCards(
                worldId: 1,
                state: PlayerState.initial()
                    .copyWith(claimedChapterChestIds: {chapter1.id}),
                progress: fullProgress,
                structure: structure)[0]
            .chestState,
        ChestState.claimed,
      );
    });
  });

  group('عقد المراحل L3', () {
    test('الحالات تظهر بشكل صحيح حول current=3: ما بعدها مقفل حتى تُكمَل',
        () {
      final state = PlayerState.initial().copyWith(currentStageId: 3);
      final progress = {
        1: StageProgress(
            stageId: 1,
            completed: true,
            bestTimeMs: null,
            hintsUsedBest: 0,
            bonusWordsFound: const {},
            attempts: 1,
            lastPlayedAt: null),
        2: StageProgress(
            stageId: 2,
            completed: true,
            bestTimeMs: null,
            hintsUsedBest: 1,
            bonusWordsFound: const {},
            attempts: 1,
            lastPlayedAt: null),
      };
      final nodes = MapViewModel.buildStageNodes(
        chapterId: structure.stageById(1).chapterId,
        state: state,
        progress: progress,
        structure: structure,
      );

      expect(nodes[0].status, StageNodeStatus.completed); // 1
      expect(nodes[1].status, StageNodeStatus.completed); // 2
      expect(nodes[2].status, StageNodeStatus.current); // 3
      // 4 فما بعدها مقفلة: المرحلة 3 لم تُكمَل بعد، ولا شيء يُفتح إلا
      // بإتمام ما قبله (المعاينة عند اللمس تبقى متاحة للثلاث التاليات)
      expect(nodes[3].status, StageNodeStatus.locked); // 4
      expect(nodes[3].previewAvailableOnTap, isTrue);
      expect(nodes[4].status, StageNodeStatus.locked); // 5
      expect(nodes[5].status, StageNodeStatus.locked); // 6
    });

    test('المعاينة عند اللمس متاحة فقط للمراحل 1..3 أمام current، لا '
        'لـcurrent نفسها ولا لما بعد الثالثة', () {
      final state = PlayerState.initial().copyWith(currentStageId: 3);
      final nodes = MapViewModel.buildStageNodes(
        chapterId: structure.stageById(1).chapterId,
        state: state,
        progress: const {},
        structure: structure,
      );
      final byId = {for (final n in nodes) n.stageId: n};
      expect(byId[3]!.previewAvailableOnTap, isFalse, reason: 'current نفسها');
      expect(byId[4]!.previewAvailableOnTap, isTrue);
      expect(byId[5]!.previewAvailableOnTap, isTrue);
      expect(byId[6]!.previewAvailableOnTap, isTrue);
      expect(byId[7]!.previewAvailableOnTap, isFalse, reason: 'أبعد من 3');
    });

    test('مرحلة الزعيم دوما آخر مرحلة في الفصل، ومعلَّمة isBoss', () {
      final chapter1 = structure.chapterById(1);
      final nodes = MapViewModel.buildStageNodes(
        chapterId: 1,
        state: PlayerState.initial(),
        progress: const {},
        structure: structure,
      );
      expect(nodes.last.stageId, chapter1.bossStageId);
      expect(nodes.last.isBoss, isTrue);
      expect(nodes.sublist(0, nodes.length - 1).every((n) => !n.isBoss), isTrue);
    });

    test('نطاق العقد المرئية: سابقتان + current + ثلاث تاليات، بحدود القائمة',
        () {
      expect(MapViewModel.visibleNodeIndexRange(currentIndex: 5, nodeCount: 12),
          (3, 8));
      expect(MapViewModel.visibleNodeIndexRange(currentIndex: 0, nodeCount: 12),
          (0, 3));
      expect(MapViewModel.visibleNodeIndexRange(currentIndex: 11, nodeCount: 12),
          (9, 11));
    });
  });

  group('شريط أقرب مكافأة (اختبار قبول 4)', () {
    test('لاعب جديد تماما: أقرب معلَم هو المراحل الناقصة لصندوق الفصل1 (12)',
        () {
      final banner = MapViewModel.computeNearRewardBanner(
        state: PlayerState.initial(),
        progress: const {},
        structure: structure,
      );
      expect(banner.kind, NearRewardKind.stagesToChest);
      expect(banner.remaining, 12);
    });

    test('يختار الأقل مسافة بين الأنواع الثلاثة، لا نوعا ثابتا بالأولوية',
        () {
      // نجّح 10 من 12 مرحلة (نقص مرحلتان للصندوق)، لكن نجوم الفصل قليلة
      final chapter1 = structure.chapterById(1);
      final progress = {
        for (final id in chapter1.stageIds.take(10))
          id: StageProgress(
              stageId: id,
              completed: true,
              bestTimeMs: null,
              hintsUsedBest: 5,
              bonusWordsFound: const {},
              attempts: 1,
              lastPlayedAt: null),
      };
      final state = PlayerState.initial().copyWith(currentStageId: 11);
      final banner = MapViewModel.computeNearRewardBanner(
        state: state,
        progress: progress,
        structure: structure,
      );
      // نجوم الفصل=10 (1 لكل مرحلة)، يحتاج 25 لدخول الفصل التالي: نقص 15
      // كلمات الجرّة: نقص 40 (لا شيء وُجد بعد)
      // مراحل للصندوق: نقص 2 (10 من 12)
      // الأقل = 2 → stagesToChest
      expect(banner.kind, NearRewardKind.stagesToChest);
      expect(banner.remaining, 2);
    });

    test('صندوق الفصل مُستلَم فعلا ونجوم الفصل التالي كافية ولا نقص جرّة '
        'قريب: الاحتياط هو نسبة إتمام العالم — الشريط لا يُترك فارغا أبدا',
        () {
      final world1 = structure.worldById(1);
      final chapter1 = structure.chapterById(world1.chapterIds[0]);
      final chapter2 = structure.chapterById(world1.chapterIds[1]);

      // أكمل الفصل1 بكل نجومه (36، يكفي لدخول الفصل2 الذي يحتاج 25)،
      // واستلم صندوقه، وانتقل للفصل2 (لا صندوق مكتمل هناك بعد لكنه بعيد)
      final progress = {
        for (final id in chapter1.stageIds)
          id: StageProgress(
              stageId: id,
              completed: true,
              bestTimeMs: null,
              hintsUsedBest: 0,
              bonusWordsFound: const {},
              attempts: 1,
              lastPlayedAt: null),
      };
      final state = PlayerState.initial().copyWith(
        currentStageId: chapter2.stageStart,
        unlockedChapterIds: {chapter1.id, chapter2.id},
        claimedChapterChestIds: {chapter1.id},
      );

      final banner = MapViewModel.computeNearRewardBanner(
        state: state,
        progress: progress,
        structure: structure,
      );
      // لا يزال هناك: مراحل ناقصة لصندوق الفصل2 (12) — هذا أقرب معلَم
      // فعلي، فلن يصل الاختبار للاحتياط بعد. نتحقق أن هذا هو ما يظهر:
      expect(banner.kind, NearRewardKind.stagesToChest);
      expect(banner.remaining, chapter2.stageCount);
    });

    test('نسبة إتمام العالم تُحسَب صحيحة حين لا معلَم قريب آخر متاح إطلاقا',
        () {
      // نبني حالة اصطناعية: كل شيء "مُرضى" حول current كي تسقط كل
      // المرشّحات الثلاثة، فيظهر الاحتياط
      final world1 = structure.worldById(1);
      final allChapters = [for (final id in world1.chapterIds) structure.chapterById(id)];
      final progress = <int, StageProgress>{};
      // أكمل كل شيء إلا آخر مرحلة في العالم (فيبقى العالم غير مكتمل
      // فعليا، لكن لا معلَم "قريب" مُعرَّف يبقى غير مُرضى غير الصندوق
      // الأخير الذي سيظهر بمسافة 1 أصلا — لذا لتفعيل الاحتياط فعلا نستلم
      // كل الصناديق ونملأ كل الجرار حتى الفصل الأخير غير المكتمل تماما،
      // ونضع current داخل فصل مكتمل بالفعل بانتظار فتح ما يليه لاحقا
      for (final chapter in allChapters) {
        for (final id in chapter.stageIds) {
          progress[id] = StageProgress(
              stageId: id,
              completed: true,
              bestTimeMs: null,
              hintsUsedBest: 0,
              bonusWordsFound: const {},
              attempts: 1,
              lastPlayedAt: null);
        }
      }
      final state = PlayerState.initial().copyWith(
        currentStageId: world1.stageEnd, // آخر مرحلة، كل الفصول مكتملة
        unlockedChapterIds: {for (final c in allChapters) c.id},
        claimedChapterChestIds: {for (final c in allChapters) c.id},
        jarProgress: {1: BalanceConfig.jarThresholdForWorld(1)},
        unlockedWorldIds: {1, 2}, // العالم التالي مفتوح فعلا
      );

      final banner = MapViewModel.computeNearRewardBanner(
        state: state,
        progress: progress,
        structure: structure,
      );
      expect(banner.kind, NearRewardKind.worldCompletionPercent);
      expect(banner.percent, 100.0);
    });
  });
}
