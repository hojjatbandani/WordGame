import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/theme.dart';

/// احتفال بلوغ كل خمس كلمات إضافية جديدة.
///
/// لماذا لافتة وسط الشاشة لا مجرّد رقم يتغيّر في الأعلى: مكافأة الخمس
/// كلمات تُمنح بعد سلسلة طويلة من الاكتشافات المتفرّقة، وعدّاد يزحف في
/// الزاوية لا يُرى وسط لوح الحروف — فلا يعرف اللاعب أصلا أن هناك ما
/// يُكافأ عليه، فيتوقّف عن البحث عن الكلمات الإضافية.
///
/// لا تلتقط أي لمسة (IgnorePointer): اللعب يستمرّ تحتها بلا انتظار.
class BonusMilestoneBurst extends StatefulWidget {
  /// العملات الممنوحة الآن
  final int coins;

  /// مجموع الكلمات الإضافية الجديدة التي بلغها اللاعب (5، 10، 15..)
  final int totalBonusWords;

  final AppLanguage lang;

  /// تُستدعى بعد انتهاء الحركة كي تزيلها الشاشة من شجرتها
  final VoidCallback onFinished;

  const BonusMilestoneBurst({
    super.key,
    required this.coins,
    required this.totalBonusWords,
    required this.lang,
    required this.onFinished,
  });

  @override
  State<BonusMilestoneBurst> createState() => _BonusMilestoneBurstState();
}

class _BonusMilestoneBurstState extends State<BonusMilestoneBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
    final rng = Random();
    _sparks = List.generate(18, (_) => _Spark.random(rng));
    _c.forward().whenComplete(() {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0..0.18 دخول، 0.18..0.78 ثبات، 0.78..1 خروج للأعلى
  double _cardOpacity(double t) {
    if (t < 0.18) return t / 0.18;
    if (t < 0.78) return 1;
    return 1 - (t - 0.78) / 0.22;
  }

  double _cardScale(double t) {
    if (t < 0.18) {
      return 0.6 + 0.4 * Curves.easeOutBack.transform(t / 0.18);
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final opacity = _cardOpacity(t).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(220),
                  painter: _SparkPainter(sparks: _sparks, t: t),
                ),
                Transform.translate(
                  offset: Offset(0, -34 * (t < 0.78 ? 0 : (t - 0.78) / 0.22)),
                  child: Transform.scale(
                    scale: _cardScale(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: HurufTheme.s6,
                        vertical: HurufTheme.s4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(HurufTheme.rCard),
                        color: HurufTheme.surface.withValues(alpha: 0.96),
                        border: Border.all(
                          color: HurufTheme.gold.withValues(alpha: 0.75),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: HurufTheme.gold.withValues(alpha: 0.45),
                            blurRadius: 34,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🫙', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: HurufTheme.s2),
                          Text(
                            lang.t(
                              '${widget.totalBonusWords} كلمات إضافية!',
                              '${widget.totalBonusWords} bonus words!',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: HurufTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+${widget.coins}',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: HurufTheme.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Spark {
  final double angle;
  final double distance;
  final double size;
  final double delay;

  const _Spark(this.angle, this.distance, this.size, this.delay);

  factory _Spark.random(Random rng) => _Spark(
    rng.nextDouble() * 2 * pi,
    60 + rng.nextDouble() * 55,
    3 + rng.nextDouble() * 4,
    rng.nextDouble() * 0.18,
  );
}

class _SparkPainter extends CustomPainter {
  final List<_Spark> sparks;
  final double t;

  const _SparkPainter({required this.sparks, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (final spark in sparks) {
      // كل شرارة تنطلق مرة واحدة في أول 45% من الحركة ثم تتلاشى
      final local = ((t - spark.delay) / 0.45).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final eased = Curves.easeOutCubic.transform(local);
      final offset =
          center +
          Offset(cos(spark.angle), sin(spark.angle)) * spark.distance * eased;
      final paint = Paint()
        ..color = HurufTheme.gold.withValues(alpha: (1 - local) * 0.9);
      canvas.drawCircle(offset, spark.size * (1 - local * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter oldDelegate) => oldDelegate.t != t;
}
