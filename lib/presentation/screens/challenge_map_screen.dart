import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/balance_config.dart';
import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../data/challenge_models.dart';
import '../../data/challenge_progress.dart';
import '../providers.dart';
import '../widgets/pressable.dart';
import '../widgets/video_animation.dart';
import 'challenge_screen.dart';

/// خريطة فئة تحدٍّ واحدة — نفس لغة مسار المراحل: عقد متعرّجة، ذهبية
/// للمحلولة، وواحدة «حالية» تنبض، وما بعدها مقفل.
///
/// كانت الفئات الأربع تُفتح كقائمة تشغيل تُخلط عشوائيا بلا أثر يبقى:
/// لا يعرف اللاعب كم حلّ ولا كم بقي، ولا يُكافأ على إنهاء فئة. الخريطة
/// تعطي التقدّم شكلا مرئيا، والصندوق في نهايتها يعطي الإنهاء معنى.
class ChallengeMapScreen extends ConsumerWidget {
  final ChallengeCategory category;

  const ChallengeMapScreen({super.key, required this.category});

  static const _spacing = 104.0;
  static const _topPad = 90.0;
  static const _bottomPad = 70.0;

  Offset _nodePos(int index, double width) => Offset(
    width * (0.5 + sin(index * 0.85) * 0.19),
    _bottomPad + index * _spacing,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final progress = ref.watch(challengeProgressProvider);
    final asyncSet = ref.watch(challengesProvider);

    return Scaffold(
      backgroundColor: HurufTheme.bgTop,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // مشهد الفئة ثابت بينما تتحرّك العقد فوقه
          Image.asset(
            ChallengeProgressRules.backgroundFor(category),
            fit: BoxFit.cover,
            cacheWidth: 1080,
          ),
          // تعتيم متدرّج: أغمق عند الطرفين كي تُقرأ الترويسة وشريط
          // الصندوق، وأفتح في الوسط كي تبقى الصورة مرئية لا مجرّد لون
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  HurufTheme.bgTop.withValues(alpha: 0.88),
                  HurufTheme.bgTop.withValues(alpha: 0.35),
                  HurufTheme.bgTop.withValues(alpha: 0.30),
                  HurufTheme.bgTop.withValues(alpha: 0.85),
                ],
                stops: const [0, 0.24, 0.70, 1],
              ),
            ),
          ),
          SafeArea(
            child: asyncSet.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Text(
                  lang.t(
                    'تعذّر تحميل التحدّيات',
                    'Could not load the challenges',
                  ),
                  style: const TextStyle(color: HurufTheme.textSecondary),
                ),
              ),
              data: (set) {
                final items = set.byCategory(category);
                final nodes = ChallengeProgressRules.buildNodes(
                  category: category,
                  total: items.length,
                  solvedIds: progress.solvedIds,
                );
                final solved = ChallengeProgressRules.solvedCount(
                  category: category,
                  total: items.length,
                  solvedIds: progress.solvedIds,
                );

                return Column(
                  children: [
                    _Header(
                      category: category,
                      lang: lang,
                      solved: solved,
                      total: items.length,
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final points = [
                            for (var i = 0; i < nodes.length; i++)
                              _nodePos(i, width),
                          ];
                          final totalHeight =
                              _topPad +
                              _bottomPad +
                              (nodes.length - 1) * _spacing;

                          return SingleChildScrollView(
                            child: SizedBox(
                              width: width,
                              height: totalHeight,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _PathPainter(
                                        points: points,
                                        solvedCount: solved,
                                        accent: category.accent,
                                      ),
                                    ),
                                  ),
                                  for (var i = 0; i < nodes.length; i++)
                                    Positioned(
                                      left: points[i].dx - 45,
                                      top: points[i].dy - 45,
                                      child: _ChallengeNodeView(
                                        node: nodes[i],
                                        accent: category.accent,
                                        lang: lang,
                                        onTap: () => _play(
                                          context,
                                          ref,
                                          items: items,
                                          startIndex: nodes[i].index,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _ChestBar(
                      category: category,
                      lang: lang,
                      total: items.length,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// يفتح شاشة التحدّي من العنصر المطلوب فصاعدا، بترتيب المصفوفة لا
  /// مخلوطا: الخريطة تعد بعقدة بعينها، والخلط يكسر ذلك الوعد.
  void _play(
    BuildContext context,
    WidgetRef ref, {
    required List<ChallengeItem> items,
    required int startIndex,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChallengeScreen(
          category: category,
          items: items,
          startIndex: startIndex,
          shuffle: false,
          onSolved: (index) => ref
              .read(challengeProgressProvider.notifier)
              .markSolved(category, index),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ChallengeCategory category;
  final AppLanguage lang;
  final int solved;
  final int total;

  const _Header({
    required this.category,
    required this.lang,
    required this.solved,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HurufTheme.s3,
        HurufTheme.s3,
        HurufTheme.s3,
        HurufTheme.s2,
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
            child: Column(
              children: [
                Text(
                  lang.t(category.titleAr, category.titleEn),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lang.t('$solved من $total', '$solved of $total'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: category.accent,
                  ),
                ),
              ],
            ),
          ),
          // مرشد الفئة: أربع شخصيات مختلفة تميّز الخرائط الأربع
          CharacterPortrait(
            characterId: ChallengeProgressRules.guideFor(category),
            size: 44,
          ),
        ],
      ),
    );
  }
}

class _ChallengeNodeView extends StatelessWidget {
  final ChallengeNode node;
  final Color accent;
  final AppLanguage lang;
  final VoidCallback onTap;

  const _ChallengeNodeView({
    required this.node,
    required this.accent,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final number = node.index + 1;
    final isCurrent = node.status == ChallengeNodeStatus.current;
    final isDone = node.status == ChallengeNodeStatus.completed;
    final size = isCurrent ? 84.0 : 70.0;

    final semantic = switch (node.status) {
      ChallengeNodeStatus.locked => lang.t(
        'التحدّي $number، مقفل',
        'Challenge $number, locked',
      ),
      ChallengeNodeStatus.completed => lang.t(
        'التحدّي $number، محلول',
        'Challenge $number, solved',
      ),
      ChallengeNodeStatus.current => lang.t(
        'التحدّي $number، الحالي',
        'Challenge $number, current',
      ),
    };

    return SizedBox(
      width: 90,
      height: 90,
      child: Center(
        child: Pressable(
          // المقفل لا يُلعب: الترتيب هو ما يجعل الخريطة خريطة
          onTap: node.status == ChallengeNodeStatus.locked ? null : onTap,
          semanticLabel: semantic,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone || isCurrent
                  ? accent.withValues(alpha: isDone ? 0.9 : 0.75)
                  : HurufTheme.bgTop.withValues(alpha: 0.75),
              border: Border.all(
                color: Colors.white.withValues(alpha: isCurrent ? 0.7 : 0.35),
                width: isCurrent ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: isCurrent ? 0.5 : 0.18),
                  blurRadius: isCurrent ? 20 : 8,
                ),
              ],
            ),
            child: switch (node.status) {
              ChallengeNodeStatus.locked => const Icon(
                Icons.lock_rounded,
                color: HurufTheme.textSecondary,
                size: 22,
              ),
              ChallengeNodeStatus.completed => const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 30,
              ),
              ChallengeNodeStatus.current => Text(
                '$number',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// شريط الصندوق أسفل الخريطة: يُستلَم مرة واحدة بعد حلّ كل عناصر الفئة
class _ChestBar extends ConsumerWidget {
  final ChallengeCategory category;
  final AppLanguage lang;
  final int total;

  const _ChestBar({
    required this.category,
    required this.lang,
    required this.total,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(challengeProgressProvider);
    final complete = ChallengeProgressRules.isCategoryComplete(
      category: category,
      total: total,
      solvedIds: progress.solvedIds,
    );
    final claimable = ChallengeProgressRules.isChestClaimable(
      category: category,
      total: total,
      solvedIds: progress.solvedIds,
      claimedChestIds: progress.claimedChestIds,
    );
    final coins = BalanceConfig.challengeCategoryChestCoins;

    return Padding(
      padding: const EdgeInsets.all(HurufTheme.s4),
      child: Pressable(
        onTap: claimable
            ? () {
                final granted = ref
                    .read(challengeProgressProvider.notifier)
                    .claimChest(category, total: total);
                if (granted <= 0) return;
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: HurufTheme.surface,
                      content: Text(
                        lang.t(
                          '🎁 صندوق الفئة: +$granted عملة',
                          '🎁 Category chest: +$granted coins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
              }
            : null,
        semanticLabel: lang.t('صندوق الفئة', 'Category chest'),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HurufTheme.s4,
            vertical: HurufTheme.s3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HurufTheme.rCard),
            border: Border.all(
              color: claimable
                  ? HurufTheme.gold
                  : Colors.white.withValues(alpha: 0.12),
            ),
            color: claimable
                ? HurufTheme.gold.withValues(alpha: 0.14)
                : HurufTheme.surface.withValues(alpha: 0.6),
          ),
          child: Row(
            children: [
              Text(
                complete ? '🎁' : '🔒',
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: HurufTheme.s3),
              Expanded(
                child: Text(
                  claimable
                      ? lang.t(
                          'استلم صندوق الفئة: +$coins عملة',
                          'Claim the category chest: +$coins coins',
                        )
                      : complete
                      ? lang.t('استُلم الصندوق', 'Chest claimed')
                      : lang.t(
                          'أنهِ كل التحدّيات لتفتح صندوق +$coins عملة',
                          'Finish every challenge to open a +$coins coin chest',
                        ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: claimable
                        ? HurufTheme.gold
                        : HurufTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// خطّ المسار: مصبوغ بلون الفئة إلى آخر عقدة محلولة، باهت بعدها
class _PathPainter extends CustomPainter {
  final List<Offset> points;
  final int solvedCount;
  final Color accent;

  const _PathPainter({
    required this.points,
    required this.solvedCount,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final done = Paint()
      ..color = accent.withValues(alpha: 0.75)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final ahead = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(
        points[i],
        points[i + 1],
        i < solvedCount - 1 ? done : ahead,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) =>
      oldDelegate.solvedCount != solvedCount ||
      oldDelegate.points != points ||
      oldDelegate.accent != accent;
}
