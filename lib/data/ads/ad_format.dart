// طول الإعلان: النموذجان، والخريطة الوحيدة من سطح العرض إلى النموذج.
//
// Dart صرف — بلا Flutter — كي تُقرأ الخريطة من الاختبار كما تُقرأ من
// الواجهة. القاعدة كلها هنا: لا شاشة تختار مدّة بنفسها، ولا `heavy:
// true` منثور في مسارات الانتقال. تغيير سطح من قصير إلى طويل تغيير سطر
// واحد في [AdFormats].

import '../../config/balance_config.dart';
import 'rewarded_ads.dart';

/// نموذجا الإعلان في اللعبة. لا ثالث لهما.
enum AdLength {
  /// إعلان قصير — يقاطع مسار اللعب، فيبقى خفيفا
  short,

  /// إعلان طويل — يقابله مكسب طلبه اللاعب بنفسه
  long,
}

extension AdLengthDuration on AdLength {
  Duration get duration => switch (this) {
    AdLength.short => BalanceConfig.shortAdDuration,
    AdLength.long => BalanceConfig.longAdDuration,
  };
}

class AdFormats {
  const AdFormats._();

  /// الإعلان البيني بين المراحل — قصير دوما.
  ///
  /// هذا هو الإعلان الوحيد الذي لم يطلبه اللاعب: يقع بين مرحلة انتهت
  /// وأخرى يريد بدأها، فطوله يُقتطع من متعة لم تُقابَل بمقابل. الطويل
  /// هنا يُقرأ عقوبة على التقدّم.
  static const AdLength betweenLevels = AdLength.short;

  /// طول إعلان المكافأة بحسب السطح الذي طُلب منه.
  ///
  /// المبدأ: قصير حين يكون الإعلان في طريق اللاعب (نهاية مرحلة)، وطويل
  /// حين يكون الإعلان هو الثمن الذي دفعه طوعا مقابل شيء ذهب إليه قاصدا
  /// (دورة عجلة، عملات من المتجر، مضاعفة صندوق فصل).
  ///
  /// `switch` شامل بلا `default`: أي سطح يُضاف لاحقا يكسر الترجمة هنا
  /// فيُختار طوله عمدا، لا يقع على قيمة افتراضية بالسهو.
  static AdLength forSurface(RewardedSurface surface) => switch (surface) {
    // ── قصير ──
    RewardedSurface.levelReward => AdLength.short,

    // ── طويل ──
    RewardedSurface.wheel => AdLength.long,
    RewardedSurface.coinTopUp => AdLength.long,
    RewardedSurface.chapterChest => AdLength.long,
    RewardedSurface.safetyMode => AdLength.long,

    // سطح بلا هوية بعد (أو محفوظ قديم فُكّ إلى `other`): الأخفّ هو
    // الافتراض الآمن
    RewardedSurface.other => AdLength.short,
  };
}
