import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/world_models.dart';
import 'character_bubble.dart';
import 'glass_card.dart';
import 'video_animation.dart';

/// شاشة إتمام المرحلة: احتفال المرشد بالفيديو + جسيمات + عد تصاعدي
class LevelCompleteOverlay extends StatefulWidget {
  final int reward;
  final int bonusFound;
  final bool isLastLevel;
  final VoidCallback onNext;
  final VoidCallback onMap;
  final String? characterId;
  final int worldBonus;
  final String? worldName;

  const LevelCompleteOverlay({
    super.key,
    required this.reward,
    required this.bonusFound,
    required this.isLastLevel,
    required this.onNext,
    required this.onMap,
    this.characterId,
    this.worldBonus = 0,
    this.worldName,
  });

  @override
  State<LevelCompleteOverlay> createState() => _LevelCompleteOverlayState();
}

class _LevelCompleteOverlayState extends State<LevelCompleteOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _confetti;
  late final AnimationController _card;
  late final List<_Burst> _bursts;

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();
    _card = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    final rng = Random();
    _bursts = List.generate(60, (_) => _Burst.random(rng));
  }

  @override
  void dispose() {
    _confetti.dispose();
    _card.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black.withValues(alpha: 0.6)),
        AnimatedBuilder(
          animation: _confetti,
          builder: (context, _) =>
              CustomPaint(painter: _ConfettiPainter(_bursts, _confetti.value)),
        ),
        Center(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _card, curve: Curves.elasticOut),
            child: Padding(
              padding: const EdgeInsets.all(HurufTheme.s6),
              child: GlassCard(
                padding: const EdgeInsets.all(HurufTheme.s6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // احتفال المرشد بمقطع MP4، أو الكأس إن لم تحدد شخصية
                    if (widget.characterId != null)
                      CharacterAnimation(
                        characterId: widget.characterId!,
                        emotion: CharacterEmotion.celebrating,
                        size: 110,
                      )
                    else
                      const Text('🏆', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: HurufTheme.s3),
                    Text(
                      widget.worldBonus > 0 ? 'أتممت العالم!' : 'أحسنت!',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: HurufTheme.gold,
                      ),
                    ),
                    if (widget.characterId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: HurufTheme.s1),
                        child: Text(
                          randomMessage(CharacterEmotion.celebrating),
                          style: const TextStyle(
                            fontSize: 14,
                            color: HurufTheme.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: HurufTheme.s4),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: widget.reward),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        '+$value نقطة',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (widget.worldBonus > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: HurufTheme.s2),
                        child: Text(
                          '🏆 مكافأة «${widget.worldName}»: +${widget.worldBonus}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: HurufTheme.success,
                          ),
                        ),
                      ),
                    if (widget.bonusFound > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: HurufTheme.s2),
                        child: Text(
                          '🫙 ${widget.bonusFound} كلمة إضافية',
                          style: const TextStyle(
                            color: HurufTheme.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: HurufTheme.s5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GoldButton(
                          label: widget.isLastLevel
                              ? 'خريطة المراحل'
                              : 'المرحلة التالية',
                          onTap: widget.isLastLevel
                              ? widget.onMap
                              : widget.onNext,
                        ),
                        const SizedBox(width: HurufTheme.s3),
                        if (!widget.isLastLevel)
                          IconButton(
                            onPressed: widget.onMap,
                            icon: const Icon(Icons.map_outlined,
                                color: HurufTheme.textSecondary),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GoldButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HurufTheme.s6,
          vertical: HurufTheme.s3,
        ),
        decoration: BoxDecoration(
          gradient: HurufTheme.goldGradient,
          borderRadius: BorderRadius.circular(HurufTheme.rButton),
          boxShadow: [
            BoxShadow(
              color: HurufTheme.gold.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: HurufTheme.bgTop,
          ),
        ),
      ),
    );
  }
}

class _Burst {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double delay;

  _Burst(this.angle, this.speed, this.size, this.color, this.delay);

  factory _Burst.random(Random rng) {
    const colors = [
      HurufTheme.gold,
      Color(0xFFFFE082),
      Color(0xFFFF9F1C),
      HurufTheme.success,
      Colors.white,
    ];
    return _Burst(
      rng.nextDouble() * 2 * pi,
      0.25 + rng.nextDouble() * 0.55,
      3 + rng.nextDouble() * 5,
      colors[rng.nextInt(colors.length)],
      rng.nextDouble() * 0.25,
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Burst> bursts;
  final double t;

  _ConfettiPainter(this.bursts, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.35);
    final paint = Paint();
    for (final b in bursts) {
      final local = ((t - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (local == 0) continue;
      final eased = Curves.easeOutCubic.transform(local);
      final dist = eased * b.speed * size.shortestSide;
      final gravity = local * local * size.height * 0.35;
      final pos = origin +
          Offset(cos(b.angle) * dist, sin(b.angle) * dist * 0.7 + gravity);
      paint.color = b.color.withValues(alpha: (1 - local).clamp(0.0, 1.0));
      canvas.drawCircle(pos, b.size * (1 - local * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => true;
}
