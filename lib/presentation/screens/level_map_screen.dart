import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/world_models.dart';
import '../providers.dart';
import '../widgets/glass_card.dart';
import '../widgets/video_animation.dart';
import 'game_screen.dart';

/// خريطة العوالم: صفحة لكل عالم بخلفيته الخاصة ومساره ذي 12 مرحلة
class LevelMapScreen extends ConsumerStatefulWidget {
  const LevelMapScreen({super.key});

  @override
  ConsumerState<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends ConsumerState<LevelMapScreen> {
  PageController? _pager;
  int _page = 0;

  @override
  void dispose() {
    _pager?.dispose();
    super.dispose();
  }

  void _precacheNeighbors(int page) {
    for (final i in [page - 1, page + 1]) {
      if (i >= 0 && i < worlds.length) {
        precacheImage(AssetImage(worlds[i].background), context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelsAsync = ref.watch(levelsProvider);
    final maxUnlocked = ref.watch(maxUnlockedProvider);

    return Scaffold(
      body: levelsAsync.when(
        loading: () => const ColoredBox(
          color: HurufTheme.bgTop,
          child: Center(
              child: CircularProgressIndicator(color: HurufTheme.gold)),
        ),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (levels) {
          final currentWorld = worldForLevel(maxUnlocked.clamp(1, levels.length));
          _pager ??= PageController(initialPage: currentWorld.id - 1)
            ..addListener(() {
              final p = _pager!.page?.round() ?? 0;
              if (p != _page) {
                setState(() => _page = p);
                _precacheNeighbors(p);
              }
            });
          if (_page == 0 && currentWorld.id != 1) _page = currentWorld.id - 1;

          return PageView.builder(
            controller: _pager,
            itemCount: worlds.length,
            itemBuilder: (context, index) => _WorldPage(
              world: worlds[index],
              levels: levels
                  .where((l) => l.worldId == worlds[index].id)
                  .toList(),
              maxUnlocked: maxUnlocked,
              isFirstWorld: index == 0,
              isLastWorld: index == worlds.length - 1,
              onPrev: () => _pager!.previousPage(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeInOutCubic,
              ),
              onNext: () => _pager!.nextPage(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeInOutCubic,
              ),
              onOpenLevel: (level) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      GameScreen(level: level, allLevels: levels),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WorldPage extends StatefulWidget {
  final WorldModel world;
  final List<GameLevel> levels;
  final int maxUnlocked;
  final bool isFirstWorld;
  final bool isLastWorld;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final void Function(GameLevel) onOpenLevel;

  const _WorldPage({
    required this.world,
    required this.levels,
    required this.maxUnlocked,
    required this.isFirstWorld,
    required this.isLastWorld,
    required this.onPrev,
    required this.onNext,
    required this.onOpenLevel,
  });

  @override
  State<_WorldPage> createState() => _WorldPageState();
}

class _WorldPageState extends State<_WorldPage> {
  static const double _spacing = 108;
  static const double _bottomPad = 100;
  static const double _topPad = 150;

  ScrollController? _scroll;

  WorldModel get world => widget.world;
  List<GameLevel> get levels => widget.levels;
  int get maxUnlocked => widget.maxUnlocked;

  bool get _worldUnlocked => maxUnlocked >= world.firstLevelId;
  int get _completedInWorld => levels
      .where((l) => l.id < maxUnlocked)
      .length
      .clamp(0, world.levelCount);

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  Offset _nodePos(int index, double width, double totalHeight) {
    // مسار متعرج يتسلق من أسفل الخريطة إلى أعلاها
    final y = totalHeight - _bottomPad - index * _spacing;
    final x = width * (0.5 + sin(index * 0.85) * 0.28);
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final totalHeight =
          _topPad + _bottomPad + (levels.length - 1) * _spacing;
      final points = [
        for (var i = 0; i < levels.length; i++)
          _nodePos(i, width, totalHeight),
      ];
      final currentIndex = levels.indexWhere((l) => l.id == maxUnlocked);

      if (_worldUnlocked && _scroll == null) {
        final focus = currentIndex < 0 ? levels.length - 1 : currentIndex;
        _scroll = ScrollController(
          initialScrollOffset: (_bottomPad +
                  focus * _spacing -
                  constraints.maxHeight / 2)
              .clamp(0.0, max(0.0, totalHeight - constraints.maxHeight)),
        );
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          // الخلفية ثابتة بينما يتحرك المسار فوقها (إحساس البارالاكس)
          Image.asset(world.background, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  HurufTheme.bgTop.withValues(alpha: 0.85),
                  HurufTheme.bgTop.withValues(alpha: 0.18),
                  HurufTheme.bgTop.withValues(alpha: 0.10),
                  HurufTheme.bgTop.withValues(alpha: 0.55),
                ],
                stops: const [0, 0.28, 0.72, 1],
              ),
            ),
          ),
          if (_worldUnlocked)
            SingleChildScrollView(
              controller: _scroll,
              reverse: true,
              child: SizedBox(
                width: width,
                height: totalHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TrailPainter(
                          points: points,
                          completedSegments: currentIndex < 0
                              ? levels.length - 1
                              : currentIndex,
                          accent: world.accent,
                        ),
                      ),
                    ),
                    for (var i = 0; i < levels.length; i++)
                      Positioned(
                        left: points[i].dx - 30,
                        top: points[i].dy - 30,
                        child: _LevelNode(
                          level: levels[i],
                          unlocked: levels[i].id <= maxUnlocked,
                          completed: levels[i].id < maxUnlocked,
                          accent: world.accent,
                          onTap: () => widget.onOpenLevel(levels[i]),
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            _buildLockedOverlay(),
          SafeArea(child: _buildHeader(context)),
          SafeArea(child: _buildPagerArrows()),
        ],
      );
    });
  }

  Widget _buildLockedOverlay() {
    return Container(
      color: HurufTheme.bgTop.withValues(alpha: 0.6),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_rounded,
              size: 64, color: HurufTheme.textSecondary),
          const SizedBox(height: HurufTheme.s3),
          Text(
            'أكمل عالم «${worlds[world.id - 2].nameAr}» لفتح هذا العالم',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: HurufTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(HurufTheme.s3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_forward_ios_rounded,
                      color: HurufTheme.textPrimary, size: 20),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        world.nameAr,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 8),
                          ],
                        ),
                      ),
                      Text(
                        world.taglineAr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: HurufTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                CharacterPortrait(characterId: world.guideId, size: 52),
              ],
            ),
            const SizedBox(height: HurufTheme.s2),
            // مؤشر تقدم العالم
            GlassCard(
              radius: HurufTheme.rButton,
              padding: const EdgeInsets.symmetric(
                horizontal: HurufTheme.s3,
                vertical: HurufTheme.s2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_completedInWorld / ${world.levelCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: HurufTheme.gold,
                    ),
                  ),
                  const SizedBox(width: HurufTheme.s2),
                  SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _completedInWorld / world.levelCount,
                        minHeight: 6,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.15),
                        valueColor:
                            AlwaysStoppedAnimation(world.accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: HurufTheme.s2),
                  Text(
                    '🏆 +${world.completionReward}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagerArrows() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: HurufTheme.s3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ArrowButton(
              icon: Icons.chevron_right_rounded,
              visible: !widget.isFirstWorld,
              onTap: widget.onPrev,
            ),
            Text(
              '${world.id} / ${worlds.length}',
              style: const TextStyle(
                fontSize: 12,
                color: HurufTheme.textSecondary,
                shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
              ),
            ),
            _ArrowButton(
              icon: Icons.chevron_left_rounded,
              visible: !widget.isLastWorld,
              onTap: widget.onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final bool visible;
  final VoidCallback onTap;

  const _ArrowButton({
    required this.icon,
    required this.visible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: HurufTheme.s3),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: HurufTheme.bgTop.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: HurufTheme.gold, size: 30),
          ),
        ),
      ),
    );
  }
}

/// المسار بين المراحل: متوهج بلون العالم للمقطع المكتمل، نقاط لما بعده
class _TrailPainter extends CustomPainter {
  final List<Offset> points;
  final int completedSegments;
  final Color accent;

  _TrailPainter({
    required this.points,
    required this.completedSegments,
    required this.accent,
  });

  Path _segment(int i) {
    final p0 = points[max(0, i - 1)];
    final p1 = points[i];
    final p2 = points[i + 1];
    final p3 = points[min(points.length - 1, i + 2)];
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    return Path()
      ..moveTo(p1.dx, p1.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }

  Path _dashed(Path src, double dash, double gap) {
    final out = Path();
    for (final metric in src.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        out.addPath(
          metric.extractPath(d, min(d + dash, metric.length)),
          Offset.zero,
        );
        d += dash + gap;
      }
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final done = Path();
    final ahead = Path();
    for (var i = 0; i < points.length - 1; i++) {
      (i < completedSegments ? done : ahead).addPath(_segment(i), Offset.zero);
    }

    canvas.drawPath(
      _dashed(ahead, 1, 14),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.55),
    );

    if (completedSegments > 0) {
      canvas.drawPath(
        done,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawPath(
        done,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [accent, HurufTheme.gold],
          ).createShader(done.getBounds()),
      );
      canvas.drawPath(
        done,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) =>
      oldDelegate.completedSegments != completedSegments ||
      oldDelegate.points.length != points.length ||
      oldDelegate.accent != accent;
}

class _LevelNode extends StatefulWidget {
  final GameLevel level;
  final bool unlocked;
  final bool completed;
  final Color accent;
  final VoidCallback onTap;

  const _LevelNode({
    required this.level,
    required this.unlocked,
    required this.completed,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<_LevelNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  bool get _isCurrent => widget.unlocked && !widget.completed;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (_isCurrent) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.unlocked ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final glow = _isCurrent ? 14 + _pulse.value * 16 : 8.0;
          return Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.unlocked ? HurufTheme.goldGradient : null,
              color: widget.unlocked
                  ? null
                  : HurufTheme.bgTop.withValues(alpha: 0.75),
              border: Border.all(
                color: Colors.white
                    .withValues(alpha: widget.unlocked ? 0.5 : 0.2),
                width: 2,
              ),
              boxShadow: [
                if (widget.unlocked)
                  BoxShadow(
                    color: (_isCurrent ? widget.accent : HurufTheme.gold)
                        .withValues(alpha: _isCurrent ? 0.7 : 0.35),
                    blurRadius: glow,
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: widget.unlocked
                ? (widget.completed
                    ? const Icon(Icons.star_rounded,
                        color: HurufTheme.bgTop, size: 30)
                    : Text(
                        '${widget.level.indexInWorld}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: HurufTheme.bgTop,
                        ),
                      ))
                : const Icon(Icons.lock_rounded,
                    color: HurufTheme.textSecondary, size: 22),
          );
        },
      ),
    );
  }
}
