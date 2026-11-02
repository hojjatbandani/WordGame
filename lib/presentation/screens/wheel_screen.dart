import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/balance_config.dart';
import '../../core/app_icons.dart';
import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../data/achievement_models.dart';
import '../../data/ads/ad_format.dart';
import '../../data/ads/rewarded_ads.dart';
import '../../data/audio_service.dart';
import '../../data/wheel/wheel_engine.dart';
import '../../data/wheel/wheel_models.dart';
import '../providers.dart';
import '../widgets/achievement_toast.dart';
import '../widgets/ad_unavailable_toast.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/pressable.dart';

/// عجلة الحظ: دورة مجانية يوميا + دورات إضافية بمشاهدة إعلان مكافأة
class WheelScreen extends ConsumerStatefulWidget {
  const WheelScreen({super.key});

  @override
  ConsumerState<WheelScreen> createState() => _WheelScreenState();
}

class _WheelScreenState extends ConsumerState<WheelScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  double _angle = 0; // الزاوية الحالية بالراديان
  bool _spinning = false;
  WheelSegmentDef? _lastPrize;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    // الدورة المجانية تُقرأ من التخزين حين يُبنى المزوّد فقط، وقد تُفتح
    // الشاشة بعد منتصف الليل والتطبيق لم يُغلق. دورة الإعلان كانت تعيد
    // بناءه عرضا؛ ومع إطفاء الإعلانات لا يعيده شيء غير هذا. بعد الإطار لا
    // أثناءه: الرئيسية تحت هذه الشاشة تراقب المزوّد نفسه (نقطة التبويب).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(wheelProvider);
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _startSpin({required bool viaAd}) async {
    if (_spinning) return;
    final notifier = ref.read(wheelProvider.notifier);

    if (viaAd) {
      // مشاهدة إعلان مكافأة كاملة قبل منح الدورة
      final ok = await _playAd();
      if (!ok || !mounted) return;
    }

    if (!notifier.consumeSpin(viaAd: viaAd)) return;

    // اختيار القطاع الفائز عشوائيا (موزونا) ثم تدوير العجلة لتقف عليه
    // فعلا — لا فرق بصري "شبه فوز" أبدا: الزاوية الهدف تُشتَق من نفس
    // القطاع الذي سيُمنح لاحقا مباشرة، لا اختيار عرض منفصل
    final segments = BalanceConfig.wheelSegments;
    final n = segments.length;
    final segment = WheelEngine.pickSegmentIndex(segments, Random());
    final segAngle = 2 * pi / n;
    // المؤشر في الأعلى؛ نحسب الزاوية التي تضع منتصف القطاع تحته
    final target = 2 * pi * 6 - (segment * segAngle + segAngle / 2);
    final begin = _angle % (2 * pi);

    setState(() {
      _spinning = true;
      _lastPrize = null;
    });

    final tween = Tween<double>(
      begin: begin,
      end: target,
    ).animate(CurvedAnimation(parent: _spin, curve: Curves.easeOutCubic));
    void listener() => setState(() => _angle = tween.value);
    tween.addListener(listener);
    ref.read(audioServiceProvider).play(Sfx.spin);
    HapticFeedback.mediumImpact();

    await _spin.forward(from: 0);
    tween.removeListener(listener);
    if (!mounted) return;

    final won = segments[segment];
    notifier.grantPrize(segment);
    ref.read(audioServiceProvider).play(Sfx.bonus);
    final achievements = ref.read(achievementsProvider.notifier);
    achievements.bump(StatKey.wheelSpins);
    if (won.type == WheelPrizeType.coins) {
      achievements.bump(StatKey.pointsEarned, won.value);
    }
    showAchievementUnlocked(context, achievements.takeJustUnlocked());
    HapticFeedback.heavyImpact();
    setState(() {
      _spinning = false;
      _lastPrize = won;
    });
  }

  /// إعلان الدورة الإضافية. طويل بحكم سطحه
  /// ([AdFormats.forSurface] لـ[RewardedSurface.wheel]): دورة العجلة
  /// مكسب ذهب إليه اللاعب قاصدا، لا مقاطعة وقعت عليه.
  ///
  /// نتحقّق من الميزانية *قبل* العرض لا بعده: مشاهدة كاملة ثم رفض
  /// consumeSpin تعني إعلانا شُوهد بلا مقابل.
  Future<bool> _playAd() async {
    if (!ref.read(rewardedAdsAvailableProvider)) return false;
    if (ref.read(wheelProvider).adSpinsRemaining <= 0) return false;

    setState(() => _spinning = true);
    var watched = false;
    try {
      watched = await ref
          .read(adServiceProvider)
          .showRewarded(
            context,
            length: AdFormats.forSurface(RewardedSurface.wheel),
          );
    } finally {
      // _spinning يمنع الرجوع: استثناء من طبقة الإعلان لا يحبس اللاعب هنا
      if (mounted) setState(() => _spinning = false);
    }
    if (!mounted) return false;
    if (!watched) showAdUnavailableToast(context, ref.read(languageProvider));
    return watched;
  }

  @override
  Widget build(BuildContext context) {
    final wheel = ref.watch(wheelProvider);
    final points = ref.watch(pointsProvider);
    final lang = ref.watch(languageProvider);
    final adsAvailable = ref.watch(rewardedAdsAvailableProvider);

    // لا رجوع أثناء الدوران: الدورة تُستهلك من الرصيد قبل الحركة والجائزة
    // تُمنح بعدها — مغادرة الشاشة في الوسط كانت تضيّع الدورة بلا جائزة
    return PopScope(
      canPop: !_spinning,
      child: Scaffold(
        body: AnimatedBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(points, lang),
                const Spacer(),
                _buildWheel(),
                const SizedBox(height: HurufTheme.s5),
                _buildStatusText(wheel, lang),
                const Spacer(),
                _buildActions(wheel, lang, adsAvailable: adsAvailable),
                const SizedBox(height: HurufTheme.s6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int points, AppLanguage lang) {
    return Padding(
      padding: const EdgeInsets.all(HurufTheme.s3),
      child: Row(
        children: [
          IconButton(
            tooltip: lang.t('رجوع', 'Back'),
            onPressed: _spinning ? null : () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: HurufTheme.textSecondary,
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              lang.t('عجلة الحظ', 'Wheel of Luck'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
          GlassCard(
            radius: HurufTheme.rButton,
            padding: const EdgeInsets.symmetric(
              horizontal: HurufTheme.s3,
              vertical: HurufTheme.s1,
            ),
            child: Row(
              children: [
                const AppIcon(AppIcons.gems, size: 26),
                const SizedBox(width: HurufTheme.s1),
                Text(
                  '$points',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: HurufTheme.gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth * 0.82, 340.0);
        return SizedBox(
          width: size,
          height: size + 34,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 34,
                child: Transform.rotate(
                  angle: _angle,
                  child: CustomPaint(
                    size: Size(size, size),
                    painter: _WheelPainter(
                      segments: BalanceConfig.wheelSegments,
                    ),
                  ),
                ),
              ),
              // المؤشر الثابت في الأعلى
              Positioned(
                top: 8,
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 54,
                  color: HurufTheme.gold,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              // القرص المركزي
              Positioned(
                top: 34 + size / 2 - 26,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: HurufTheme.goldGradient,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: HurufTheme.gold.withValues(alpha: 0.6),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: HurufTheme.bgTop,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusText(WheelState wheel, AppLanguage lang) {
    final prize = _lastPrize;
    if (prize != null) {
      final text = switch (prize.type) {
        WheelPrizeType.coins => lang.t(
          'ربحت ${prize.value} نقطة!',
          'You won ${prize.value} points!',
        ),
        WheelPrizeType.hintCharge => lang.t(
          'ربحت تلميحا مجانيا!',
          'You won a free hint!',
        ),
        WheelPrizeType.jarBooster => lang.t(
          'ربحت معزّز جرّة!',
          'You won a jar booster!',
        ),
      };
      return Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 32)),
          const SizedBox(height: HurufTheme.s1),
          Text(
            text,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: HurufTheme.gold,
            ),
          ),
        ],
      );
    }
    return Text(
      _spinning
          ? lang.t('العجلة تدور...', 'Spinning...')
          : lang.t('جرّب حظّك واربح نقاطا!', 'Try your luck and win points!'),
      style: const TextStyle(fontSize: 16, color: HurufTheme.textSecondary),
    );
  }

  Widget _buildActions(
    WheelState wheel,
    AppLanguage lang, {
    required bool adsAvailable,
  }) {
    final hasAdSpin = adsAvailable && wheel.adSpinsRemaining > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HurufTheme.s5),
      child: Column(
        children: [
          if (wheel.freeSpinAvailable)
            _WheelButton(
              label: lang.t('دورة مجانية', 'Free Spin'),
              icon: Icons.card_giftcard_rounded,
              enabled: !_spinning,
              primary: true,
              onTap: () => _startSpin(viaAd: false),
            )
          else
            _WheelButton(
              label: hasAdSpin
                  ? lang.t(
                      'شاهد إعلانا ودُر (${wheel.adSpinsRemaining} متبقية)',
                      'Watch an ad to spin (${wheel.adSpinsRemaining} left)',
                    )
                  : lang.t(
                      'عد غدا لدورة مجانية جديدة',
                      'Come back tomorrow for a new free spin',
                    ),
              // أيقونة الفيديو للزرّ الذي يعرض فيديو فعلا، لا لزرّ «عد غدا»
              icon: hasAdSpin
                  ? Icons.play_circle_outline_rounded
                  : Icons.schedule_rounded,
              enabled: !_spinning && hasAdSpin,
              primary: false,
              onTap: () => _startSpin(viaAd: true),
            ),
          const SizedBox(height: HurufTheme.s3),
          Text(
            // لا وعد بدورات إعلانية لا تُعرض
            adsAvailable
                ? lang.t(
                    'دورة مجانية كل يوم + حتى ${WheelState.maxAdSpinsPerDay} دورات بالإعلانات',
                    'One free spin daily + up to ${WheelState.maxAdSpinsPerDay} more via ads',
                  )
                : lang.t('دورة مجانية كل يوم', 'One free spin every day'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: HurufTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool primary;
  final VoidCallback onTap;

  const _WheelButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: enabled ? onTap : null,
      semanticLabel: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: HurufTheme.s4),
          decoration: BoxDecoration(
            gradient: primary ? HurufTheme.goldGradient : null,
            color: primary ? null : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(HurufTheme.rCard),
            border: primary
                ? null
                : Border.all(color: HurufTheme.gold.withValues(alpha: 0.6)),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: HurufTheme.gold.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: primary ? HurufTheme.bgTop : HurufTheme.gold,
                size: 22,
              ),
              const SizedBox(width: HurufTheme.s2),
              // مرن ويتقلّص: العناوين الإنجليزية («Come back tomorrow for a
              // new free spin») أعرض من الزرّ على هواتف 360 نقطة
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: primary ? HurufTheme.bgTop : Colors.white,
                    ),
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

class _WheelPainter extends CustomPainter {
  final List<WheelSegmentDef> segments;
  const _WheelPainter({required this.segments});

  static const _colors = [
    Color(0xFF4A00E0),
    Color(0xFF0F3443),
    Color(0xFFB24592),
    Color(0xFF1A1F3A),
    Color(0xFF34E89E),
    Color(0xFFC99A10),
    Color(0xFF6FB7D9),
    Color(0xFF8E2DE2),
  ];

  static String _label(WheelSegmentDef segment) => switch (segment.type) {
    WheelPrizeType.coins => '${segment.value}',
    WheelPrizeType.hintCharge => '💡',
    WheelPrizeType.jarBooster => '🏺',
  };

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final n = segments.length;
    final segAngle = 2 * pi / n;

    for (var i = 0; i < n; i++) {
      final start = -pi / 2 + i * segAngle - segAngle / 2;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = _colors[i % _colors.length].withValues(alpha: 0.92);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        segAngle,
        true,
        paint,
      );
      // خط فاصل
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        segAngle,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.25),
      );

      // نص الجائزة
      final mid = start + segAngle / 2;
      final textPos = center + Offset(cos(mid), sin(mid)) * radius * 0.66;
      final tp = TextPainter(
        text: TextSpan(
          text: _label(segments[i]),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(textPos.dx, textPos.dy);
      canvas.rotate(mid + pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // الحلقة الخارجية
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..shader = const SweepGradient(
          colors: [Color(0xFFFFE082), HurufTheme.gold, Color(0xFFFFE082)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) => false;
}
