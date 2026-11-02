import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/app_language.dart';
import '../../core/theme.dart';
import 'glass_card.dart';

/// نجاح منح ألماس: انفجار جواهر + عدّ تصاعدي إلى المبلغ الممنوح.
///
/// كان خاصا بـshop_screen.dart، ورُفع إلى هنا حين صار لمسار الجوائز
/// نفس اللحظة بالضبط: نسخة ثانية من مئة سطر أنيميشن تعني احتفالين
/// يختلفان بعد أول تعديل على أحدهما.
class RewardBurstOverlay extends StatefulWidget {
  final int points;
  final AppLanguage lang;
  final VoidCallback onDismiss;

  /// سطر تحت الرقم — الافتراضي «أضيفت إلى رصيدك». يُمرَّر مخصّصا حين
  /// يكون للمناسبة اسم يستحق الذكر (جائزة الشهر مثلا).
  final String? caption;

  const RewardBurstOverlay({
    super.key,
    required this.points,
    required this.lang,
    required this.onDismiss,
    this.caption,
  });

  @override
  State<RewardBurstOverlay> createState() => _RewardBurstOverlayState();
}

class _RewardBurstOverlayState extends State<RewardBurstOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _burst;
  late final AnimationController _card;
  late final List<_Gem> _gems;

  @override
  void initState() {
    super.initState();
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
    _card = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    final rng = Random();
    _gems = List.generate(24, (_) => _Gem.random(rng));
  }

  @override
  void dispose() {
    _burst.dispose();
    _card.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _burst,
              builder: (context, _) => Stack(
                children: [
                  for (final gem in _gems)
                    _buildGem(gem, MediaQuery.sizeOf(context)),
                ],
              ),
            ),
            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(parent: _card, curve: Curves.elasticOut),
                child: GlassCard(
                  padding: const EdgeInsets.all(HurufTheme.s6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon(AppIcons.gems, size: 72),
                      const SizedBox(height: HurufTheme.s3),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: widget.points),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => Text(
                          '+$value',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: HurufTheme.gold,
                          ),
                        ),
                      ),
                      const SizedBox(height: HurufTheme.s2),
                      Text(
                        widget.caption ??
                            widget.lang.t(
                              'أضيفت إلى رصيدك',
                              'Added to your balance',
                            ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: HurufTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGem(_Gem gem, Size size) {
    final local = ((_burst.value - gem.delay) / (1 - gem.delay)).clamp(0.0, 1.0);
    if (local == 0) return const SizedBox.shrink();
    final eased = Curves.easeOutCubic.transform(local);
    final origin = Offset(size.width / 2, size.height / 2);
    final pos =
        origin +
        Offset(
          cos(gem.angle) * eased * gem.distance * size.width,
          sin(gem.angle) * eased * gem.distance * size.height +
              local * local * 120,
        );
    return Positioned(
      left: pos.dx - 10,
      top: pos.dy - 10,
      child: Opacity(
        opacity: (1 - local).clamp(0.0, 1.0),
        child: AppIcon(AppIcons.gems, size: 18 + gem.size),
      ),
    );
  }
}

class _Gem {
  final double angle;
  final double distance;
  final double size;
  final double delay;

  _Gem(this.angle, this.distance, this.size, this.delay);

  factory _Gem.random(Random rng) => _Gem(
    rng.nextDouble() * 2 * pi,
    0.15 + rng.nextDouble() * 0.3,
    rng.nextDouble() * 10,
    rng.nextDouble() * 0.2,
  );
}
