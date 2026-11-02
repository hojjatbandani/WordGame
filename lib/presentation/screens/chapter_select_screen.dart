import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../data/economy/chapter_chest.dart';
import '../../data/progression/map_view_model.dart';
import '../../data/progression/world_defs.dart';
import '../../data/world_models.dart';
import '../progression_text.dart';
import '../providers.dart';
import '../widgets/chapter_chest_widget.dart';
import '../widgets/chapter_complete_celebration.dart';
import '../widgets/double_reward.dart';
import '../widgets/near_reward_banner.dart';
import '../widgets/rate_app_dialog.dart';
import '../widgets/pressable.dart';
import '../widgets/video_animation.dart';
import 'map_entry.dart';
import 'stage_path_screen.dart';
import 'world_select_screen.dart' show worldSeedColor;

/// L2: اختيار الفصل — 5 فصول للعالم كمقطع مسار رأسي متعرّج، كل فصل يعرض
/// مراحله المكتملة وحالة صندوقه.
class ChapterSelectScreen extends ConsumerStatefulWidget {
  final int worldId;

  /// فصل أُكمل للتوّ: تُعرض فوق القائمة تهنئة المرشد مرة واحدة. شاشة
  /// اللعب توجّه اللاعب إلى هنا بعد آخر مرحلة في الفصل بدل أن تنزلق
  /// به إلى المرحلة التالية بلا أي علامة على أنه عبر حدّ فصل.
  final int? celebrateChapterId;

  const ChapterSelectScreen({
    super.key,
    required this.worldId,
    this.celebrateChapterId,
  });

  @override
  ConsumerState<ChapterSelectScreen> createState() =>
      _ChapterSelectScreenState();
}

class _ChapterSelectScreenState extends ConsumerState<ChapterSelectScreen> {
  late int? _celebrateChapterId = widget.celebrateChapterId;

  int get worldId => widget.worldId;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final snapshot = ref.watch(progressionProvider);
    final structure = ref.watch(progressionStructureProvider);
    final world = structure.worldById(worldId);

    final chapters = MapViewModel.buildChapterCards(
      worldId: worldId,
      state: snapshot.state,
      progress: snapshot.stageProgress,
      structure: structure,
    );

    // الهوية البصرية للعالم: صورة الخلفية وشخصية المرشد
    final visuals = worldVisualsById(worldId);

    return Scaffold(
      backgroundColor: HurufTheme.bgTop,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(visuals.background, fit: BoxFit.cover, cacheWidth: 1080),
          // تعتيم أقوى هنا من شاشة المسار: بطاقات الفصول نصّية كثيفة
          // وتحتاج تباينا أعلى من عقد المسار الأيقونية
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  HurufTheme.bgTop.withValues(alpha: 0.88),
                  HurufTheme.bgTop.withValues(alpha: 0.72),
                  HurufTheme.bgTop.withValues(alpha: 0.82),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _Header(
                  worldNameKey: world.nameKey,
                  lang: lang,
                  guideId: visuals.guideId,
                ),
                const NearRewardBanner(),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(HurufTheme.s4),
                    itemCount: chapters.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: HurufTheme.s3),
                    itemBuilder: (context, i) => _ChapterCard(
                      card: chapters[i],
                      color: worldSeedColor(world.colorSeed),
                      lang: lang,
                      onClaimChest: () => _claimChest(chapters[i].chapterId),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_celebrateChapterId != null)
            _buildCelebration(
              context,
              chapterId: _celebrateChapterId!,
              guideId: visuals.guideId,
              structure: structure,
            ),
        ],
      ),
    );
  }

  /// يستلم صندوق الفصل ثم يعرض ما ربحه مع فرصة مضاعفته بمشاهدة إعلان
  Future<void> _claimChest(int chapterId) async {
    final coins = await ref
        .read(progressionProvider.notifier)
        .claimChapterChest(chapterId);
    if (!mounted || coins <= 0) return;
    await showChestRewardDialog(
      context,
      ref,
      ref.read(languageProvider),
      coins: coins,
    );
  }

  /// يغلق التهنئة، ثم يطلب التقييم إن لم يقيّم اللاعب بعد، ثم ينفّذ
  /// [then] (فتح الفصل التالي مثلا).
  ///
  /// الترتيب مقصود: طلب التقييم يقع على لحظة الفوز نفسها (فصل اكتمل
  /// للتوّ) لا على شاشة لعب جديدة، وينتهي قبل أي انتقال كي لا تُبنى
  /// شاشة ثم تُغطَّى بنافذة فورا.
  Future<void> _closeCelebration({VoidCallback? then}) async {
    setState(() => _celebrateChapterId = null);
    await maybeAskForRating(context, ref, ref.read(languageProvider));
    if (!mounted) return;
    then?.call();
  }

  Widget _buildCelebration(
    BuildContext context, {
    required int chapterId,
    required String guideId,
    required ProgressionStructure structure,
  }) {
    final chapter = structure.chapterById(chapterId);
    final next = structure.nextChapterInWorld(chapter);
    // آخر فصل في العالم: المتابعة تقود إلى الخريطة، وهي بدورها تعرض
    // مراسم فتح العالم الجديد إن كانت معلّقة (راجع map_entry.dart)
    final isWorldFinale = next == null;
    return ChapterCompleteCelebration(
      chapterId: chapterId,
      chapterIndex: chapter.index,
      guideId: guideId,
      nextIsNewWorld: isWorldFinale,
      onNextChapter: () => _closeCelebration(
        then: () {
          if (isWorldFinale) {
            openMap(context, ref);
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StagePathScreen(chapterId: next.id),
            ),
          );
        },
      ),
      onDismiss: _closeCelebration,
    );
  }
}

class _Header extends StatelessWidget {
  final String worldNameKey;
  final AppLanguage lang;

  /// شخصية مرشد العالم — تحتلّ مكان الفراغ الذي كان يوازن زرّ الرجوع
  final String guideId;

  const _Header({
    required this.worldNameKey,
    required this.lang,
    required this.guideId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HurufTheme.s3,
        HurufTheme.s3,
        HurufTheme.s3,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: lang.t('رجوع', 'Back'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: HurufTheme.textSecondary,
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              worldName(worldNameKey, lang),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                // ظلّ يضمن قراءة العنوان فوق أي صورة خلفية
                shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
          ),
          CharacterPortrait(characterId: guideId, size: 44),
        ],
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final ChapterCardViewData card;
  final Color color;
  final AppLanguage lang;
  final VoidCallback onClaimChest;

  const _ChapterCard({
    required this.card,
    required this.color,
    required this.lang,
    required this.onClaimChest,
  });

  @override
  Widget build(BuildContext context) {
    final title = lang.t('الفصل ${card.index}', 'Chapter ${card.index}');
    return Opacity(
      opacity: card.isUnlocked ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(HurufTheme.s4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HurufTheme.rCard),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          color: HurufTheme.surface,
        ),
        child: Row(
          children: [
            Expanded(
              child: Pressable(
                onTap: card.isUnlocked
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              StagePathScreen(chapterId: card.chapterId),
                        ),
                      )
                    : null,
                semanticLabel: card.isUnlocked
                    ? title
                    : lang.t(
                        '$title، مقفل حتى إتمام الفصل السابق',
                        '$title, locked until the previous chapter is complete',
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (!card.isUnlocked) ...[
                          const Icon(
                            Icons.lock_rounded,
                            size: 16,
                            color: HurufTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('🚩', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          lang.t(
                            '${card.stagesCompleted}/${card.stageCount} مرحلة',
                            '${card.stagesCompleted}/${card.stageCount} stages',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: HurufTheme.gold,
                          ),
                        ),
                      ],
                    ),
                    if (!card.isUnlocked) ...[
                      const SizedBox(height: 2),
                      Text(
                        lang.t(
                          'أكمل كل مراحل الفصل السابق لفتحه',
                          'Complete every stage of the previous chapter',
                        ),
                        style: const TextStyle(
                          fontSize: 10,
                          color: HurufTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ChapterChestWidget(
              state: card.chestState,
              lang: lang,
              rewardCoins: ChapterChest.amountFor(card.chapterId),
              onClaimed: onClaimChest,
            ),
          ],
        ),
      ),
    );
  }
}
