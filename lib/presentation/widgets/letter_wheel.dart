import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// عجلة الحروف: يسحب اللاعب إصبعه بين الحروف لتكوين كلمة
class LetterWheel extends StatefulWidget {
  final List<String> letters;
  final void Function(String word) onWordSubmitted;
  final void Function(String preview) onSelectionChanged;

  /// بدأ اللاعب لمس العجلة (يوقف عرض الإصبع)
  final VoidCallback? onTouchStart;

  /// رُفع الإصبع وحرف واحد مختار: لمسة لا سحب. كانت تُبتلع بصمت، فلا يعرف
  /// لاعب جديد اعتاد النقر حرفا حرفا لماذا لا يحدث شيء
  final VoidCallback? onSingleLetter;

  /// الكلمة التي يرسم إصبعُ العرض مسارها (المرحلة الأولى)
  final String? demoWord;
  final bool demoActive;

  const LetterWheel({
    super.key,
    required this.letters,
    required this.onWordSubmitted,
    required this.onSelectionChanged,
    this.onTouchStart,
    this.onSingleLetter,
    this.demoWord,
    this.demoActive = false,
  });

  @override
  State<LetterWheel> createState() => LetterWheelState();
}

class LetterWheelState extends State<LetterWheel>
    with TickerProviderStateMixin {
  late List<String> _letters;
  final List<int> _selected = [];
  Offset? _finger;
  late final AnimationController _shuffleController;

  /// دورة إصبع العرض: سحب على المسار ثم وقفة قصيرة
  late final AnimationController _demo;

  @override
  void initState() {
    super.initState();
    _letters = List.of(widget.letters);
    _shuffleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _demo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _syncDemo();
  }

  @override
  void didUpdateWidget(covariant LetterWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.letters != widget.letters) {
      _letters = List.of(widget.letters);
      _selected.clear();
      _finger = null;
    }
    if (oldWidget.demoActive != widget.demoActive ||
        oldWidget.demoWord != widget.demoWord) {
      _syncDemo();
    }
  }

  bool get _showDemo =>
      widget.demoActive && (widget.demoWord?.isNotEmpty ?? false);

  void _syncDemo() {
    if (_showDemo) {
      if (!_demo.isAnimating) _demo.repeat();
    } else {
      _demo.stop();
      _demo.value = 0;
    }
  }

  /// مواضع حروف [LetterWheel.demoWord] في ترتيب العجلة الحالي (بعد أي
  /// خلط)، كلّ حرف في خانة مختلفة — الحرف المكرّر يأخذ خانته الثانية
  List<int> _demoIndices() {
    final used = <int>{};
    final out = <int>[];
    for (final c in (widget.demoWord ?? '').split('')) {
      final i = Iterable<int>.generate(_letters.length).firstWhere(
        (i) => _letters[i] == c && !used.contains(i),
        orElse: () => -1,
      );
      if (i < 0) return const [];
      used.add(i);
      out.add(i);
    }
    return out;
  }

  @override
  void dispose() {
    _shuffleController.dispose();
    _demo.dispose();
    super.dispose();
  }

  /// خلط ترتيب الحروف مع دورة أنيقة (مجاني دائما)
  void shuffle() {
    setState(() {
      _letters.shuffle(Random());
      _selected.clear();
    });
    _shuffleController.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  Offset _letterCenter(int index, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - _tileRadius(size) - 6;
    final angle = -pi / 2 + (2 * pi * index) / _letters.length;
    return center + Offset(cos(angle) * radius, sin(angle) * radius);
  }

  double _tileRadius(Size size) {
    final base = size.shortestSide * 0.115;
    final n = _letters.length;
    // عجلات الكلمات الطويلة (حتى 10 حروف) تحتاج خانات أصغر كي لا تتراكب
    if (n <= 6) return base;
    return base * (6 / n).clamp(0.55, 1.0);
  }

  void _handlePointer(Offset pos, Size size) {
    final hitRadius = _tileRadius(size) * 1.25;
    for (var i = 0; i < _letters.length; i++) {
      if ((pos - _letterCenter(i, size)).distance <= hitRadius &&
          !_selected.contains(i)) {
        setState(() => _selected.add(i));
        HapticFeedback.selectionClick();
        widget.onSelectionChanged(_currentWord);
        return;
      }
    }
  }

  String get _currentWord => _selected.map((i) => _letters[i]).join();

  void _submit() {
    final word = _currentWord;
    setState(() {
      _selected.clear();
      _finger = null;
    });
    widget.onSelectionChanged('');
    if (word.length >= 2) {
      widget.onWordSubmitted(word);
    } else if (word.length == 1) {
      widget.onSingleLetter?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanStart: (d) {
            widget.onTouchStart?.call();
            _handlePointer(d.localPosition, size);
            setState(() => _finger = d.localPosition);
          },
          onPanUpdate: (d) {
            _handlePointer(d.localPosition, size);
            setState(() => _finger = d.localPosition);
          },
          onPanEnd: (_) => _submit(),
          onPanCancel: _submit,
          child: Stack(
            children: [
              Positioned.fill(child: _buildWheel(size)),
              if (_showDemo)
                Positioned.fill(child: IgnorePointer(child: _buildDemo(size))),
            ],
          ),
        );
      },
    );
  }

  /// إصبع العرض: أثر ذهبي يمتدّ من حرف إلى حرف ويد تتبعه
  Widget _buildDemo(Size size) {
    final indices = _demoIndices();
    if (indices.length < 2) return const SizedBox.shrink();
    final points = [for (final i in indices) _letterCenter(i, size)];
    return AnimatedBuilder(
      animation: _demo,
      builder: (context, _) {
        // 73% من الدورة سحب، والباقي وقفة عند آخر حرف
        final t = (_demo.value / 0.73).clamp(0.0, 1.0);
        final head = _pointAlong(points, t);
        const handSize = 40.0;
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DemoTrailPainter(
                  points: points,
                  progress: t,
                  width: _tileRadius(size) * 0.35,
                ),
              ),
            ),
            Positioned(
              left: head.dx - handSize * 0.35,
              top: head.dy - handSize * 0.1,
              child: const Icon(
                Icons.touch_app_rounded,
                size: handSize,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
              ),
            ),
          ],
        );
      },
    );
  }

  static Offset _pointAlong(List<Offset> points, double t) {
    final segments = points.length - 1;
    final scaled = t * segments;
    final i = scaled.floor().clamp(0, segments - 1);
    final local = scaled - i;
    return Offset.lerp(points[i], points[i + 1], local.clamp(0.0, 1.0))!;
  }

  Widget _buildWheel(Size size) {
    return RotationTransition(
      turns: Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _shuffleController,
          curve: Curves.easeInOutCubic,
        ),
      ),
      child: CustomPaint(
        painter: _WheelPainter(
          letters: _letters,
          selected: _selected,
          finger: _finger,
          centerOf: (i) => _letterCenter(i, size),
          tileRadius: _tileRadius(size),
        ),
        child: Stack(
          children: [
            for (var i = 0; i < _letters.length; i++) _buildLetter(i, size),
          ],
        ),
      ),
    );
  }

  Widget _buildLetter(int index, Size size) {
    final center = _letterCenter(index, size);
    final r = _tileRadius(size);
    final isSelected = _selected.contains(index);
    return Positioned(
      left: center.dx - r,
      top: center.dy - r,
      width: r * 2,
      height: r * 2,
      child: AnimatedScale(
        scale: isSelected ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isSelected ? HurufTheme.goldGradient : null,
            color: isSelected ? null : HurufTheme.tileEmpty,
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: (isSelected ? HurufTheme.gold : Colors.black).withValues(
                  alpha: isSelected ? 0.45 : 0.35,
                ),
                blurRadius: isSelected ? 18 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _letters[index],
            style: TextStyle(
              fontSize: r * 0.95,
              fontWeight: FontWeight.w800,
              height: 1,
              color: isSelected ? HurufTheme.bgTop : HurufTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<String> letters;
  final List<int> selected;
  final Offset? finger;
  final Offset Function(int) centerOf;
  final double tileRadius;

  _WheelPainter({
    required this.letters,
    required this.selected,
    required this.finger,
    required this.centerOf,
    required this.tileRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // قرص العجلة الزجاجي
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      size.shortestSide / 2,
      Paint()..color = Colors.white.withValues(alpha: 0.05),
    );
    canvas.drawCircle(
      center,
      size.shortestSide / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.12),
    );

    if (selected.isEmpty) return;

    // خط الاتصال المتدرج بين الحروف المختارة
    final points = [for (final i in selected) centerOf(i), ?finger];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final bounds = path.getBounds().inflate(1);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = tileRadius * 0.35
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFE082), HurufTheme.gold, Color(0xFFFF9F1C)],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) =>
      oldDelegate.selected.length != selected.length ||
      oldDelegate.finger != finger ||
      oldDelegate.letters != letters;
}

/// أثر إصبع العرض: نفس خطّ الاتصال الذهبي، مقطوعا عند [progress]
class _DemoTrailPainter extends CustomPainter {
  final List<Offset> points;
  final double progress;
  final double width;

  _DemoTrailPainter({
    required this.points,
    required this.progress,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || progress <= 0) return;
    final segments = points.length - 1;
    final scaled = progress * segments;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < segments; i++) {
      if (scaled <= i) break;
      final local = (scaled - i).clamp(0.0, 1.0);
      final end = Offset.lerp(points[i], points[i + 1], local)!;
      path.lineTo(end.dx, end.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width
        ..color = HurufTheme.gold.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_DemoTrailPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.points != points;
}
