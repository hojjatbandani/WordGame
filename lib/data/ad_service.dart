/// طبقة الإعلانات: واجهة واحدة لكل ما يعرض إعلانا في اللعبة.
///
/// تنفيذان: [AdMobAdService] (data/ads/admob_ad_service.dart) للشبكة
/// الحقيقية على أندرويد وiOS، و`MockAdService` (presentation/widgets/
/// mock_ad_service.dart) يرسم فيديو محاكى — للاختبارات، ولسطح المكتب
/// والويب حيث لا AdMob.
///
/// العقد الذي تعتمد عليه الشاشات:
///   - [showRewarded] يعيد true **فقط** إن أتمّ اللاعب المشاهدة واستحقّ
///     المكافأة. false = لا إعلان متاح أو أُغلق مبكرا — فلا منح ولا
///     استهلاك من الميزانية اليومية.
///   - [showInterstitial] لا يعود قبل إغلاق الإعلان، ويقول إن لم يُعرض
///     أصلا كي لا يظنّ المستدعي أن اللاعب رأى شيئا.
///   - [isInterstitialReady] يُسأل *قبل* استشارة وحدة الإيقاع: قرارها
///     يصفّر العدّاد ويسجّل وقت الإعلان، وإعلان لم يُحمَّل يجب ألّا
///     يستهلك دورة من الإيقاع.
library;

import 'package:flutter/widgets.dart';

import 'ads/ad_format.dart';

/// ما آل إليه طلب إعلان بيني
enum InterstitialResult {
  /// لم يُعرض شيء (لا إعلان محمَّل، أو فشل العرض) — المستدعي يمضي فورا
  unavailable,

  /// عُرض وأغلقه اللاعب — المستدعي يمضي
  dismissed,

  /// غادر اللاعب الإعلان إلى المتجر — المستدعي **لا** يمضي
  leftForShop,
}

abstract class AdService {
  /// تهيئة الشبكة وجمع الموافقة (UMP) وتحميل أول إعلانين. لا يرمي
  /// إطلاقا ولا يؤخّر الإقلاع — يُنادى بلا await.
  Future<void> init();

  /// يحمّل ما لم يُحمَّل بعد. آمن للنداء المتكرّر.
  Future<void> preload();

  bool get isInterstitialReady;
  bool get isRewardedReady;

  /// يعرض إعلانا بينيا ويعود بعد إغلاقه. [onOpenShop] يُستعمل في
  /// النسخة المحاكاة وحدها (زر «أزل الإعلانات»).
  Future<InterstitialResult> showInterstitial(
    BuildContext context, {
    VoidCallback? onOpenShop,
  });

  /// يعرض إعلان مكافأة. [length] تعنيه النسخة المحاكاة فقط — الإعلان
  /// الحقيقي طوله من الشبكة.
  Future<bool> showRewarded(BuildContext context, {required AdLength length});
}
