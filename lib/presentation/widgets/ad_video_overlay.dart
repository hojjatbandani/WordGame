import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/ads/ad_format.dart';
import '../providers.dart';
import 'glass_card.dart';
import 'pressable.dart';

/// إعلان فيديو محاكى (بديل لشبكة إعلانات حقيقية). سطح عرض واحد لكل
/// إعلانات اللعبة: البيني بين المراحل، وإعلانات المكافأة الأربعة.
///
/// الطول ليس خيار هذه الواجهة بل يأتيها من [AdFormats] — الخريطة الوحيدة
/// من سطح إلى نموذج. هنا تُرسم المدّة فقط، لا تُقرَّر.
class AdVideoOverlay extends ConsumerStatefulWidget {
  final AdLength length;

  /// إعلان مكافأة (اللاعب طلبه مقابل شيء) لا إعلانا بينيا. يغيّر
  /// الشارة، ويمنع عرض «أزل الإعلانات»: شراء إزالة الإعلانات لا يلغي
  /// إعلانات المكافأة، وعرضه هنا وعد كاذب.
  final bool rewarded;

  final VoidCallback onDone;

  /// مدخل المتجر — يُعرض في البيني وحده. null يخفيه.
  final VoidCallback? onOpenShop;

  const AdVideoOverlay({
    super.key,
    required this.length,
    required this.onDone,
    this.rewarded = false,
    this.onOpenShop,
  });

  @override
  ConsumerState<AdVideoOverlay> createState() => _AdVideoOverlayState();
}

class _AdVideoOverlayState extends ConsumerState<AdVideoOverlay>
    with SingleTickerProviderStateMixin {
  late final Duration _duration;
  late final AnimationController _countdown;

  @override
  void initState() {
    super.initState();
    _duration = widget.length.duration;
    _countdown = AnimationController(vsync: this, duration: _duration)
      ..forward();
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isLong = widget.length == AdLength.long;
    return Material(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(HurufTheme.s5),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: HurufTheme.s2, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.rewarded
                          ? lang.t('إعلان مكافأة', 'Rewarded ad')
                          : lang.t('إعلان', 'Ad'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: HurufTheme.textSecondary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _countdown,
                    builder: (context, _) {
                      final done = _countdown.isCompleted;
                      final secondsLeft =
                          (_duration.inSeconds * (1 - _countdown.value))
                              .ceil();
                      return Pressable(
                        onTap: done ? widget.onDone : null,
                        semanticLabel: done
                            ? lang.t('إغلاق الإعلان', 'Close the ad')
                            : lang.t('يمكن الإغلاق بعد $secondsLeft ثانية',
                                'You can close in $secondsLeft seconds'),
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: done
                              ? const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 20)
                              : Text(
                                  '$secondsLeft',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const Spacer(),
              // محتوى الإعلان المحاكى
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: HurufTheme.s6,
                  vertical: isLong ? HurufTheme.s8 : HurufTheme.s6,
                ),
                decoration: BoxDecoration(
                  gradient: HurufTheme.bgGradient,
                  borderRadius: BorderRadius.circular(HurufTheme.rCard),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // مؤشّر التشغيل في النموذجين معا: كلاهما فيديو،
                    // والفرق بينهما مدّة لا نوع. الطويل وحده يكبر.
                    Container(
                      width: isLong ? 68 : 52,
                      height: isLong ? 68 : 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: isLong ? 40 : 30),
                    ),
                    const SizedBox(height: HurufTheme.s4),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          HurufTheme.goldGradient.createShader(bounds),
                      child: Text(
                        lang.t('حُروف', 'Huruf'),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: HurufTheme.s3),
                    Text(
                      lang.t('تابع رحلتك في عالم الكلمات العربية',
                          'Continue your journey through Arabic words'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: HurufTheme.textSecondary,
                      ),
                    ),
                    // شريط التقدّم: انتظار بلا ما يقاس به أطول مما هو
                    const SizedBox(height: HurufTheme.s5),
                    AnimatedBuilder(
                      animation: _countdown,
                      builder: (context, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _countdown.value,
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          valueColor:
                              const AlwaysStoppedAnimation(HurufTheme.gold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (widget.onOpenShop != null)
                Pressable(
                  onTap: widget.onOpenShop,
                  semanticLabel: lang.t('أزل الإعلانات نهائيا من المتجر',
                      'Remove ads permanently from the shop'),
                  child: GlassCard(
                    radius: HurufTheme.rButton,
                    padding: const EdgeInsets.symmetric(
                      horizontal: HurufTheme.s4,
                      vertical: HurufTheme.s3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.block_rounded,
                            color: HurufTheme.gold, size: 18),
                        const SizedBox(width: HurufTheme.s2),
                        Text(
                          lang.t('أزل الإعلانات نهائيا من المتجر',
                              'Remove ads permanently from the shop'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
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

/// يعرض إعلان مكافأة بالطول الذي تقرّره [AdFormats.forSurface]، ولا
/// يعود إلا بعد أن تكتمل المشاهدة ويغلقها اللاعب.
///
/// المسار مانع للرجوع (PopScope + barrierDismissible: false): إعلان
/// المكافأة عقد — مشاهدة كاملة مقابل جائزة — وزرّ الرجوع في منتصفه كان
/// سيمنح الجائزة بلا مشاهدة. لا يُنتظر منه ردّ: نداؤه يعني «شُوهد».
Future<void> playRewardedAdVideo(
  BuildContext context, {
  required AdLength length,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (routeContext, _, _) => PopScope(
        canPop: false,
        child: AdVideoOverlay(
          length: length,
          rewarded: true,
          onDone: () => Navigator.of(routeContext).pop(),
        ),
      ),
    ),
  );
}
