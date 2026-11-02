// معرّفات AdMob. المكان الوحيد الذي تُكتب فيه معرّفات وحدات الإعلان.
//
// مهم قبل النشر: أنشئ في لوحة AdMob لهذا التطبيق وحدتين — «Interstitial»
// و«Rewarded interstitial» (لا «Rewarded»: راجع ad_policy.dart) — وضع
// معرّفيهما في الثوابت `_prod*` أدناه، ومعرّف التطبيق نفسه في:
//   - android/app/src/main/AndroidManifest.xml (com.google.android.gms.ads.APPLICATION_ID)
//   - ios/Runner/Info.plist (GADApplicationIdentifier)
// test/ads/android_manifest_ads_test.dart يتحقّق أن معرّف التطبيق في البيان
// ومعرّفات الوحدات هنا من حساب الناشر نفسه.
//
// القاعدة: نسخة التطوير تستعمل معرّفات Google الاختبارية *دوما* — طلب
// إعلانات حقيقية من جهاز تطوير يوقف حساب AdMob بتهمة النقر غير الصالح.
// ونسخة الإصدار لا تستعمل الاختبارية أبدا: إن بقي معرّف حقيقي فارغا فلا
// إعلان فيها إطلاقا ([readyForThisBuild] → main.dart). النسختان 2 و3 خرجتا
// بمعرّف التطبيق الاختباري، فلم تكن لتدرّ شيئا ولو عُرض فيها إعلان.

import 'package:flutter/foundation.dart';

class AdMobIds {
  const AdMobIds._();

  // ───────── ضع معرّفاتك الحقيقية هنا (ca-app-pub-XXXX/YYYY) ─────────
  static const String _prodInterstitialAndroid =
      'ca-app-pub-3678223996715179/8834207329';
  static const String _prodRewardedInterstitialAndroid =
      'ca-app-pub-3678223996715179/8778542012';
  static const String _prodInterstitialIos = '';
  static const String _prodRewardedInterstitialIos = '';

  // ───────── معرّفات Google الاختبارية الرسمية — لا تغيّرها ─────────
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedInterstitialAndroid =
      'ca-app-pub-3940256099942544/5354046379';
  static const String _testInterstitialIos =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testRewardedInterstitialIos =
      'ca-app-pub-3940256099942544/6978759866';

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  static String get interstitial => _pick(
    prod: _ios ? _prodInterstitialIos : _prodInterstitialAndroid,
    test: _ios ? _testInterstitialIos : _testInterstitialAndroid,
  );

  static String get rewardedInterstitial => _pick(
    prod: _ios
        ? _prodRewardedInterstitialIos
        : _prodRewardedInterstitialAndroid,
    test: _ios
        ? _testRewardedInterstitialIos
        : _testRewardedInterstitialAndroid,
  );

  /// معرّفات الإنتاج لمنصّة: البيني ثم البيني الجائزي. الفارغ لم يُملأ بعد.
  @visibleForTesting
  static List<String> prodUnitIdsFor(TargetPlatform platform) =>
      platform == TargetPlatform.iOS
      ? const [_prodInterstitialIos, _prodRewardedInterstitialIos]
      : const [_prodInterstitialAndroid, _prodRewardedInterstitialAndroid];

  /// هل لهذه المنصّة معرّف حقيقي لكل وحدة؟
  static bool get hasProdIds =>
      prodUnitIdsFor(defaultTargetPlatform).every((id) => id.isNotEmpty);

  /// هل تستطيع هذه النسخة عرض إعلانات؟ التطوير دوما (بالاختبارية)،
  /// والإصدار بالمعرّفات الحقيقية وحدها.
  static bool get readyForThisBuild => !kReleaseMode || hasProdIds;

  /// الإصدار لا يسقط إلى الاختبارية: معرّف فارغ يفشل تحميله، فلا إعلان
  static String _pick({required String prod, required String test}) =>
      kReleaseMode ? prod : test;
}
