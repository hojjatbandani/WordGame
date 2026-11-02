import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/ad_service.dart';
import '../../data/ads/ad_format.dart';
import 'ad_video_overlay.dart';

/// إعلانات محاكاة: ترسم [AdVideoOverlay] بدل شبكة حقيقية.
///
/// تُستعمل في الاختبارات، وفي تطوير سطح المكتب/الويب حيث لا AdMob، وهي
/// ما يلفّه `adServiceProvider` افتراضيا (خلف بوّابة السياسة) كي لا تحتاج
/// أي شجرة اختبار إلى تجاوز.
///
/// **لا تُعرض للاعبين أبدا**: النسخة 1 خرجت بلا AdMob، فكانت هذه المحاكاة
/// هي ما يظهر على أنه إعلان — نافذة ملء الشاشة لا يغلقها زرّ الرجوع ولا
/// يعمل زرّ إغلاقها قبل نهاية العدّ (15 ثانية في الطويل). لذلك ترفض في
/// بناء الإصدار كل عرض ولا تدّعي جاهزية، مهما سمحت سياسة القوالب.
class MockAdService implements AdService {
  @override
  Future<void> init() async {}

  /// يحاكي زمن تحميل — يمنع أي تجمّد مرئي عند فتح الشاشة
  @override
  Future<void> preload() => kReleaseMode
      ? Future.value()
      : Future.delayed(const Duration(milliseconds: 400));

  @override
  bool get isInterstitialReady => !kReleaseMode;

  @override
  bool get isRewardedReady => !kReleaseMode;

  @override
  Future<InterstitialResult> showInterstitial(
    BuildContext context, {
    VoidCallback? onOpenShop,
  }) async {
    if (kReleaseMode) return InterstitialResult.unavailable;
    final result = await Navigator.of(context, rootNavigator: true)
        .push<InterstitialResult>(
          PageRouteBuilder<InterstitialResult>(
            opaque: false,
            barrierDismissible: false,
            barrierColor: Colors.black87,
            transitionDuration: const Duration(milliseconds: 180),
            pageBuilder: (routeContext, _, _) => PopScope(
              canPop: false,
              child: AdVideoOverlay(
                // بين المراحل: قصير دوما — إعلان لم يطلبه اللاعب
                length: AdFormats.betweenLevels,
                onDone: () => Navigator.of(
                  routeContext,
                ).pop(InterstitialResult.dismissed),
                onOpenShop: onOpenShop == null
                    ? null
                    : () {
                        Navigator.of(
                          routeContext,
                        ).pop(InterstitialResult.leftForShop);
                        onOpenShop();
                      },
              ),
            ),
          ),
        );
    return result ?? InterstitialResult.dismissed;
  }

  @override
  Future<bool> showRewarded(
    BuildContext context, {
    required AdLength length,
  }) async {
    if (kReleaseMode) return false;
    await preload();
    if (!context.mounted) return false;
    await playRewardedAdVideo(context, length: length);
    return true;
  }
}
