// متى يطلب التطبيق إعلانا من الشبكة. Dart صرف بلا Flutter.
//
// تقرير AdMob (أسبوع 2-8 نوفمبر 2026): 142 طلبا مقابل 7 مرات ظهور فقط، ونسبة
// امتلاء 24%. سببان من الشيفرة يضخّمان الطلبات بلا أي دخل:
//  1) الإعلان البيني يُحمَّل من أول إقلاع، بينما لا يُعرض قبل المرحلة 13 —
//     فلاعب جديد يطلب إعلانات لن يراها أبدا (تنتهي صلاحيتها بعد ساعة).
//  2) حين لا تملأ الشبكة (بلد بلا طلب إعلاني)، كانت إعادة المحاولة بلا
//     نهاية كل بضع دقائق طوال الجلسة.
// الطلب الصريح (مغادرة مرحلة، أو لمس زرّ إعلان) يبقى يحاول دوما.

import '../../config/balance_config.dart';

class AdLoadPolicy {
  const AdLoadPolicy._();

  /// يستحق تحميل الإعلان البيني الآن؟ قبل المرحلة السابقة لأول مرحلة
  /// يُسمح فيها لا فائدة منه.
  static bool wantsInterstitial({required int maxUnlocked}) =>
      maxUnlocked >= BalanceConfig.interstitialFirstEligibleStage - 1;

  /// مهلة إعادة المحاولة التلقائية بعد [consecutiveFailures] إخفاقا
  /// متتاليا: 15ث ثم 30ث ثم 60ث، ثم null = توقّف حتى طلب صريح
  static Duration? retryDelay(int consecutiveFailures) {
    if (consecutiveFailures < 1 ||
        consecutiveFailures > BalanceConfig.adLoadMaxAutoRetries) {
      return null;
    }
    return Duration(seconds: 15 * (1 << (consecutiveFailures - 1)));
  }
}
