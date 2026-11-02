import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// خلفية «ليل الصحراء»: تدرج عميق + حقل جسيمات ذهبية هادئ
class AnimatedBackground extends StatefulWidget {
  final Widget child;

  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    // التشغيل/الإيقاف يُدار في build حسب إعداد تقليل الحركة
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 40));
    final rng = Random(7);
    _particles = List.generate(40, (_) => _Particle.random(rng));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // حقل الجسيمات زخرفي بحت: يتجمّد عند طلب تقليل الحركة
    final reduce = context.reduceMotion;
    if (reduce && _controller.isAnimating) _controller.stop();
    if (!reduce && !_controller.isAnimating) _controller.repeat();

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: HurufTheme.bgGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _ParticlePainter(_particles, _controller.value),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Particle {
  final double x; // 0..1
  final double startY; // 0..1
  final double size;
  final double speed;
  final double phase;
  final double opacity;

  _Particle(this.x, this.startY, this.size, this.speed, this.phase, this.opacity);

  factory _Particle.random(Random rng) => _Particle(
        rng.nextDouble(),
        rng.nextDouble(),
        0.8 + rng.nextDouble() * 2.2,
        0.3 + rng.nextDouble() * 0.7,
        rng.nextDouble() * 2 * pi,
        0.12 + rng.nextDouble() * 0.35,
      );
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final y = (p.startY - t * p.speed) % 1.0;
      final drift = sin(t * 2 * pi * p.speed + p.phase) * 0.015;
      final twinkle = 0.6 + 0.4 * sin(t * 6 * pi + p.phase);
      paint.color =
          HurufTheme.gold.withValues(alpha: p.opacity * twinkle);
      canvas.drawCircle(
        Offset((p.x + drift) * size.width, y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}
