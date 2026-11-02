import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// عجلة الحروف: يسحب اللاعب إصبعه بين الحروف لتكوين كلمة
class LetterWheel extends StatefulWidget {
  final List<String> letters;
  final void Function(String word) onWordSubmitted;
  final void Function(String preview) onSelectionChanged;

  const LetterWheel({
    super.key,
    required this.letters,
    required this.onWordSubmitted,
    required this.onSelectionChanged,
  });

  @override
  State<LetterWheel> createState() => LetterWheelState();
}

class LetterWheelState extends State<LetterWheel>
    with SingleTickerProviderStateMixin {
  late List<String> _letters;
  final List<int> _selected = [];
  Offset? _finger;
  late final AnimationController _shuffleController;

  @override
  void initState() {
    super.initState();
    _letters = List.of(widget.letters);
    _shuffleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void didUpdateWidget(covariant LetterWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.letters != widget.letters) {
      _letters = List.of(widget.letters);
      _selected.clear();
      _finger = null;
    }
  }

  @override
  void dispose() {
    _shuffleController.dispose();
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
    if (word.length >= 2) widget.onWordSubmitted(word);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        onPanStart: (d) {
          _handlePointer(d.localPosition, size);
          setState(() => _finger = d.localPosition);
        },
        onPanUpdate: (d) {
          _handlePointer(d.localPosition, size);
          setState(() => _finger = d.localPosition);
        },
        onPanEnd: (_) => _submit(),
        onPanCancel: _submit,
        child: RotationTransition(
          turns: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
            parent: _shuffleController,
            curve: Curves.easeInOutCubic,
          )),
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
                for (var i = 0; i < _letters.length; i++)
                  _buildLetter(i, size),
              ],
            ),
          ),
        ),
      );
    });
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
                color: (isSelected ? HurufTheme.gold : Colors.black)
                    .withValues(alpha: isSelected ? 0.45 : 0.35),
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
    final points = [
      for (final i in selected) centerOf(i),
      ?finger,
    ];
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
