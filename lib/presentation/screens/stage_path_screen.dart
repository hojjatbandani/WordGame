import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/assistant_tips.dart';
import '../../data/world_models.dart';
import '../../data/progression/map_view_model.dart';
import '../providers.dart';
import '../widgets/near_reward_banner.dart';
import '../widgets/pressable.dart';
import '../widgets/video_animation.dart';
import 'game_screen.dart';
import 'world_select_screen.dart' show worldSeedColor;

/// L3: مسار المراحل — آخر مستوى تكبير، 12 أو 13 عقدة مرحلة لفصل واحد
/// كمسار متعرّج. يفتح الشاشة بتمرير تلقائي إلى العقدة الحالية مع ظهور
/// العقدتين السابقتين والثلاث التاليتين معا (اختبار قبول 2).
///
/// جسر مؤقت: اللعب الفعلي لا يزال على شاشة اللعب القديمة
/// (GameLevel/levels.json) لأن هذه المهمة تخصّ الخريطة والانتقال، لا
/// إعادة بناء اللعب — راجع الشرح الكامل في
/// progression_repository.dart:recordBasicCompletionFromLegacyBridge.
/// المطابقة بين مرحلة النظام الجديد ومرحلة levels.json القديمة هي معرّف
/// رقمي مباشر (كلا النظامين 500 مرحلة إجمالا)، لا أكثر.
class StagePathScreen extends ConsumerStatefulWidget {
  final int chapterId;
  const StagePathScreen({super.key, required this.chapterId});

  @override
  ConsumerState<StagePathScreen> createState() => _StagePathScreenState();
}

class _StagePathScreenState extends ConsumerState<StagePathScreen> {
  static const _spacing = 108.0;
  static const _topPad = 120.0;
  static const _bottomPad = 80.0;

  ScrollController? _scroll;
  bool _scheduledInitialScroll = false;

  Offset _nodePos(int index, double width) {
    final y = _bottomPad + index * _spacing;
    final x = width * (0.5 + sin(index * 0.85) * 0.18);
    return Offset(x, y);
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final snapshot = ref.watch(progressionProvider);
    final structure = ref.watch(progressionStructureProvider);
    final chapter = structure.chapterById(widget.chapterId);
    final world = structure.worldById(chapter.worldId);

    final nodes = MapViewModel.buildStageNodes(
      chapterId: widget.chapterId,
      state: snapshot.state,
      progress: snapshot.stageProgress,
      structure: structure,
    );

    final currentIndex = nodes.indexWhere(
      (n) => n.status == StageNodeStatus.current,
    );
    final anchorIndex = currentIndex >= 0
        ? currentIndex
        : nodes.lastIndexWhere((n) => n.status == StageNodeStatus.completed);
    final effectiveAnchor = anchorIndex >= 0 ? anchorIndex : 0;

    final assistantOn = ref.watch(assistantEnabledProvider);

    // الهوية البصرية للعالم: صورة الخلفية وشخصية المرشد
    final visuals = worldVisualsById(world.id);

    return Scaffold(
      backgroundColor: HurufTheme.bgTop,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // الخلفية ثابتة بينما يتحرك المسار فوقها (إحساس البارالاكس)
          Image.asset(visuals.background, fit: BoxFit.cover, cacheWidth: 1080),
          // تعتيم متدرّج: أغمق عند الطرفين كي تُقرأ الترويسة والعقد،
          // وأفتح في الوسط كي تبقى الصورة مرئية فعلا لا مجرد لون
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  HurufTheme.bgTop.withValues(alpha: 0.85),
                  HurufTheme.bgTop.withValues(alpha: 0.28),
                  HurufTheme.bgTop.withValues(alpha: 0.20),
                  HurufTheme.bgTop.withValues(alpha: 0.65),
                ],
                stops: const [0, 0.28, 0.72, 1],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _Header(
                  index: chapter.index,
                  lang: lang,
                  guideId: visuals.guideId,
                ),
                const NearRewardBanner(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final totalHeight =
                          _topPad + _bottomPad + (nodes.length - 1) * _spacing;
                      final points = [
                        for (var i = 0; i < nodes.length; i++)
                          _nodePos(i, width),
                      ];

                      _scroll ??= ScrollController(
                        initialScrollOffset: _initialOffset(
                          anchorY: points[effectiveAnchor].dy,
                          totalHeight: totalHeight,
                          viewportHeight: constraints.maxHeight,
                        ),
                      );

                      // ضمان إضافي: أول إطار بعد أول تخطيط فعلي (constraints قد
                      // لا تكون نهائية عند initState) — يعيد ضبط الموضع مرة
                      // واحدة فقط كي تبقى العقد الخمس (2 سابقة + الحالية +
                      // 3 تالية) ظاهرة فعلا كما يشترط اختبار القبول
                      if (!_scheduledInitialScroll) {
                        _scheduledInitialScroll = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted || !_scroll!.hasClients) return;
                          _scroll!.jumpTo(
                            _initialOffset(
                              anchorY: points[effectiveAnchor].dy,
                              totalHeight: totalHeight,
                              viewportHeight: constraints.maxHeight,
                            ),
                          );
                        });
                      }

                      return SingleChildScrollView(
                        controller: _scroll,
                        child: SizedBox(
                          width: width,
                          height: totalHeight,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _PathPainter(
                                    points: points,
                                    completedCount: nodes
                                        .where(
                                          (n) =>
                                              n.status ==
                                              StageNodeStatus.completed,
                                        )
                                        .length,
                                    accent: worldSeedColor(world.colorSeed),
                                  ),
                                ),
                              ),
                              for (var i = 0; i < nodes.length; i++)
                                Positioned(
                                  left: points[i].dx - 45,
                                  top: points[i].dy - 45,
                                  child: _StageNode(
                                    key: ValueKey(
                                      'stage_node_${nodes[i].stageId}',
                                    ),
                                    data: nodes[i],
                                    lang: lang,
                                    onTap: () =>
                                        _handleTap(context, nodes[i], lang),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (assistantOn)
            PositionedDirectional(
              start: HurufTheme.s3,
              end: HurufTheme.s3,
              bottom: HurufTheme.s3,
              child: SafeArea(
                top: false,
                child: _MapAssistant(guideId: visuals.guideId, lang: lang),
              ),
            ),
        ],
      ),
    );
  }

  double _initialOffset({
    required double anchorY,
    required double totalHeight,
    required double viewportHeight,
  }) {
    // نضع العقدة الحالية في الثلث العلوي من الشاشة كي تتّسع تحتها
    // العقدتان السابقتان والثلاث التاليتان معا بصريا
    final target = anchorY - viewportHeight * 0.32;
    return target.clamp(0.0, max(0.0, totalHeight - viewportHeight));
  }

  void _handleTap(
    BuildContext context,
    StageNodeViewData node,
    AppLanguage lang,
  ) {
    switch (node.status) {
      case StageNodeStatus.current:
      case StageNodeStatus.completed:
        _playStage(context, node.stageId);
      case StageNodeStatus.next:
      case StageNodeStatus.upcoming:
        if (node.previewAvailableOnTap) {
          _showPreviewSheet(context, node, lang);
        }
      case StageNodeStatus.locked:
        // مقفلة لكنها ضمن الثلاث التاليات: المعاينة تبقى متاحة كي يعرف
        // اللاعب أن المحتوى موجود قبل أن يصله
        if (node.previewAvailableOnTap) {
          _showPreviewSheet(context, node, lang);
        }
    }
  }

  Future<void> _playStage(BuildContext context, int stageId) async {
    final levelsAsync = ref.read(levelsProvider);
    final levels = levelsAsync.asData?.value;
    if (levels == null) return; // لا تزال تُحمَّل — لا شيء يُلعب بعد

    final legacyLevel = levels
        .where((l) => l.id == stageId)
        .cast<GameLevel?>()
        .firstOrNull;
    if (legacyLevel == null) return; // خارج مدى المحتوى القديم المتاح حاليا

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(level: legacyLevel, allLevels: levels),
      ),
    );
    // التسجيل في نظام التقدّم (v2) يقع داخل شاشة اللعب نفسها لا هنا:
    // زرّ «التالي» يستبدل مسارها، فلا تعود هذه الدالة إلا بعد أول
    // مرحلة ولا ترى ما بعدها — راجع GameScreen._recordProgressionCompletion
  }

  void _showPreviewSheet(
    BuildContext context,
    StageNodeViewData node,
    AppLanguage lang,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HurufTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(HurufTheme.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang.t(
                  'معاينة المرحلة ${node.stageId}',
                  'Stage ${node.stageId} preview',
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: HurufTheme.s2),
              if (node.isBoss)
                Container(
                  margin: const EdgeInsets.only(bottom: HurufTheme.s3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: HurufTheme.s3,
                    vertical: HurufTheme.s1,
                  ),
                  decoration: BoxDecoration(
                    color: HurufTheme.error.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    lang.t('👑 مرحلة زعيم', '👑 Boss stage'),
                    style: const TextStyle(
                      color: HurufTheme.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              // محتوى المرحلة (عدد الحروف/الكلمات) لم يُؤلَّف بعد لهذا
              // النظام الجديد — راجع StageDef في world_defs.dart. عرض
              // "صفر" هنا كان سيبدو كخلل، فنعرض رسالة صريحة بدلا منه.
              Text(
                lang.t(
                  'تفاصيل المحتوى (عدد الحروف والكلمات) قيد الإعداد',
                  'Content details (letters and words) are still being authored',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: HurufTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int index;
  final AppLanguage lang;
  final String guideId;

  const _Header({
    required this.index,
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
              lang.t('الفصل $index', 'Chapter $index'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          CharacterPortrait(characterId: guideId, size: 44),
        ],
      ),
    );
  }
}

class _StageNode extends StatefulWidget {
  final StageNodeViewData data;
  final AppLanguage lang;
  final VoidCallback onTap;

  const _StageNode({
    super.key,
    required this.data,
    required this.lang,
    required this.onTap,
  });

  @override
  State<_StageNode> createState() => _StageNodeState();
}

class _StageNodeState extends State<_StageNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _syncPulse();
  }

  /// العقدة تحتفظ بحالتها عبر تغيّر الوضع (مفتاحها رقم المرحلة)، فبدء
  /// النبض في initState وحده يترك العقدة الحالية الجديدة ساكنة والسابقة
  /// تنبض إلى الأبد بعد إتمامها
  @override
  void didUpdateWidget(covariant _StageNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.status != widget.data.status) _syncPulse();
  }

  void _syncPulse() {
    if (widget.data.status == StageNodeStatus.current) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final lang = widget.lang;
    final isCurrent = data.status == StageNodeStatus.current;
    final size = isCurrent ? 88.0 : 74.0;

    final semantic = switch (data.status) {
      StageNodeStatus.locked => lang.t(
        'المرحلة ${data.stageId}، مقفلة',
        'Stage ${data.stageId}, locked',
      ),
      StageNodeStatus.completed => lang.t(
        'المرحلة ${data.stageId}، مكتملة',
        'Stage ${data.stageId}, completed',
      ),
      StageNodeStatus.current => lang.t(
        'المرحلة ${data.stageId}، الحالية',
        'Stage ${data.stageId}, current',
      ),
      StageNodeStatus.next || StageNodeStatus.upcoming => lang.t(
        'المرحلة ${data.stageId}، معاينة',
        'Stage ${data.stageId}, preview',
      ),
    };

    final node = SizedBox(
      width: 90,
      height: 90,
      child: Center(
        child: Pressable(
          onTap: widget.onTap,
          semanticLabel: semantic,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final glow = isCurrent ? 10 + _pulse.value * 14 : 6.0;
              return Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _fillGradient(data.status),
                  color: _fillGradient(data.status) == null
                      ? _flatColor(data.status)
                      : null,
                  border: Border.all(
                    color: data.isBoss
                        ? HurufTheme.error
                        : Colors.white.withValues(alpha: 0.5),
                    width: data.isBoss ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (data.isBoss ? HurufTheme.error : HurufTheme.gold)
                          .withValues(
                            alpha: isCurrent || data.isBoss ? 0.5 : 0.2,
                          ),
                      blurRadius: glow,
                    ),
                  ],
                ),
                child: _buildContent(data, lang),
              );
            },
          ),
        ),
      ),
    );

    // المقفلة وحدها بلا شخصية: عقدة لم يبلغها اللاعب بعد لا مرشد لها
    if (data.status == StageNodeStatus.locked) return node;

    return node;
  }

  Widget _buildContent(StageNodeViewData data, AppLanguage lang) {
    if (data.status == StageNodeStatus.locked) {
      return const Icon(
        Icons.lock_rounded,
        color: HurufTheme.textSecondary,
        size: 22,
      );
    }
    if (data.status == StageNodeStatus.completed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(data.isBoss ? '👑' : '✓',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: HurufTheme.bgTop,
              )),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (data.isBoss) const Text('👑', style: TextStyle(fontSize: 16)),
        Text(
          '${data.stageId}',
          style: TextStyle(
            fontSize: data.status == StageNodeStatus.current ? 24 : 18,
            fontWeight: FontWeight.w900,
            color: data.status == StageNodeStatus.current
                ? HurufTheme.bgTop
                : HurufTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Gradient? _fillGradient(StageNodeStatus status) => switch (status) {
    StageNodeStatus.completed ||
    StageNodeStatus.current => HurufTheme.goldGradient,
    _ => null,
  };

  Color _flatColor(StageNodeStatus status) => switch (status) {
    StageNodeStatus.locked => HurufTheme.bgTop.withValues(alpha: 0.75),
    _ => HurufTheme.tileEmpty,
  };
}

// ─────────────────────── مرشد الخريطة ───────────────────────

/// مرشد واحد مثبّت على الشاشة يمرّ المسار خلفه — لا شخصية عند كل عقدة.
///
/// نسخة واحدة لسببين: ثلاثة عشر مشغّل فيديو على شاشة واحدة يخنق الجهاز،
/// وتكرار الوجه نفسه ثلاث عشرة مرة يجعله زخرفة تُرى ولا تُقرأ. واحد
/// ثابت في الزاوية يبقى «شخصا» يُنظر إليه ويُنقر.
///
/// النقر يبدّل الجملة، ويمكن إطفاؤه كليا من الإعدادات (مرشد الخريطة).
class _MapAssistant extends ConsumerStatefulWidget {
  final String guideId;
  final AppLanguage lang;

  const _MapAssistant({required this.guideId, required this.lang});

  @override
  ConsumerState<_MapAssistant> createState() => _MapAssistantState();
}

class _MapAssistantState extends ConsumerState<_MapAssistant> {
  final _rng = Random();
  late AssistantTip _tip = randomAssistantTip(_rng);

  /// جملة جديدة غير الحالية — تكرار الجملة نفسها عند النقر يُقرأ عطلا
  void _nextTip() => setState(() {
    _tip = randomAssistantTip(_rng, except: _tip);
  });

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;

    return Pressable(
      onTap: _nextTip,
      haptic: false,
      semanticLabel: lang.t(
        'المرشد: ${_tip.ar}. المس لنصيحة أخرى',
        'Guide: ${_tip.en}. Tap for another tip',
      ),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CharacterAnimation(characterId: widget.guideId, size: 64),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: HurufTheme.s3,
                  vertical: HurufTheme.s2 + 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(HurufTheme.rCard),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  color: HurufTheme.surface.withValues(alpha: 0.92),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      offset: const Offset(0, 8),
                      blurRadius: 18,
                      spreadRadius: -6,
                    ),
                  ],
                ),
                child: Text(
                  lang.t(_tip.ar, _tip.en),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: HurufTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  final List<Offset> points;
  final int completedCount;
  final Color accent;

  _PathPainter({
    required this.points,
    required this.completedCount,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final donePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = accent;
    final aheadPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.25);

    for (var i = 0; i < points.length - 1; i++) {
      final paint = i < completedCount - 1 ? donePaint : aheadPaint;
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(_PathPainter oldDelegate) =>
      oldDelegate.completedCount != completedCount ||
      oldDelegate.points.length != points.length;
}
