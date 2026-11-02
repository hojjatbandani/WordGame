// بوّابة السياسة حول أي تنفيذ لـAdService (AdMob أو المحاكاة): كل تهيئة
// وتحميل وسؤال جاهزية وعرض يمرّ من هنا قبل أن يصل إلى التنفيذ.
//
// الحجب في الواجهة وحده لا يكفي: زرّ يُنسى إخفاؤه في شاشة تُضاف بعد شهور،
// أو مسار يسأل الخدمة مباشرة، يجب أن يُرفض في طبقة الخدمة نفسها. والرفض
// فوري — لا مهلة تحميل ولا انتظار نداء — فلا ينتظر أي مسار لعب إعلانا
// لن يأتي.

import 'package:flutter/widgets.dart';

import '../ad_service.dart';
import 'ad_format.dart';
import 'ad_policy.dart';

class PolicyGatedAdService implements AdService {
  final AdService _inner;
  final AdFormatPolicy policy;

  PolicyGatedAdService(
    this._inner, {
    this.policy = AdFormatPolicy.currentBuild,
  });

  bool get _interstitialAllowed => policy.allows(AdFormat.interstitial);

  /// إعلان المكافأة بقالبه الوحيد ([AdFormatPolicy.rewardFormat])
  bool get _rewardedAllowed => policy.allowsRewardAds;

  /// القالبان اللذان تنفّذهما AdService. لا أحدهما = لا نداء للتنفيذ أصلا
  bool get _anyAllowed => _interstitialAllowed || _rewardedAllowed;

  @override
  Future<void> init() => _anyAllowed ? _inner.init() : Future.value();

  @override
  Future<void> preload() => _anyAllowed ? _inner.preload() : Future.value();

  @override
  bool get isInterstitialReady =>
      _interstitialAllowed && _inner.isInterstitialReady;

  @override
  bool get isRewardedReady => _rewardedAllowed && _inner.isRewardedReady;

  @override
  Future<InterstitialResult> showInterstitial(
    BuildContext context, {
    VoidCallback? onOpenShop,
  }) {
    if (!_interstitialAllowed) {
      return Future.value(InterstitialResult.unavailable);
    }
    return _inner.showInterstitial(context, onOpenShop: onOpenShop);
  }

  @override
  Future<bool> showRewarded(BuildContext context, {required AdLength length}) {
    // false = «لم يُشاهَد» — العقد نفسه لإعلان غير متاح: لا منح ولا
    // استهلاك من الميزانية
    if (!_rewardedAllowed) return Future.value(false);
    return _inner.showRewarded(context, length: length);
  }
}
