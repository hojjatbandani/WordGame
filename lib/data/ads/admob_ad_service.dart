// تنفيذ AdMob لواجهة AdService: بيني + بيني جائزي، مع موافقة UMP.
//
// المبادئ:
//   - سياسة القوالب أولا ([AdFormatPolicy]): قالب لا تسمح به لا يُحمَّل
//     ولا يُعرض ولا يُعدّ جاهزا، ولا يعيده نداء متأخّر ولا مؤقّت إعادة
//     محاولة. وإن لم تسمح بأي قالب فلا تهيئة للحزمة ولا نموذج موافقة ولا
//     طلب شبكة إطلاقا.
//   - إعلان المكافأة بيني جائزي (RewardedInterstitialAd) لا جائزي عادي
//     (RewardedAd): AdMob لا تخدم فيه إلا إعلانات قابلة للتخطّي، فيستطيع
//     اللاعب — والطفل خصوصا — أن يغلقه في أي لحظة. هذا شرط سياسة العائلات
//     لا تفضيل (ad_policy.dart).
//   - معاملة الطفل ومحتوى G تُطبَّقان على *كل* طلب وقبل التهيئة: اللعبة
//     بلا بوّابة عمر، فكل لاعب قد يكون طفلا، وغياب العمر لا يعني بالغا.
//   - كل شيء صامت الفشل. الإعلانات طبقة دخل لا طبقة لعب: أي خطأ هنا
//     يُسجَّل ولا يصل إلى اللاعب.
//   - إعلان واحد محمَّل من كل نوع في أي لحظة، ويُعاد التحميل فور
//     الإغلاق كي يكون التالي جاهزا قبل أن يُطلب.
//   - فشل التحميل يعاد بعد مهلة متزايدة (لا حلقة طلبات فورية تستنزف
//     الحصة وتُقرأ عند Google سلوكا غير صالح).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_service.dart';
import 'ad_format.dart';
import 'ad_policy.dart';
import 'admob_ids.dart';

class AdMobAdService implements AdService {
  AdMobAdService({this.policy = AdFormatPolicy.currentBuild});

  /// AdMob متاح على الهاتف فقط
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// إعداد كل الطلبات: معاملة الطفل (تعطّل الإعلانات المخصّصة وإعادة
  /// الاستهداف، ولا تُرسل معرّف الإعلانات) وأقصى تصنيف محتوى G.
  ///
  /// `ageRestrictedTreatment` هو البديل الموثَّق للوسمين القديمين
  /// (tagForChildDirectedTreatment وtagForUnderAgeOfConsent) في
  /// google_mobile_ads 9.1.0، ولا يُضبط معهما.
  static RequestConfiguration get childSafeRequestConfiguration =>
      RequestConfiguration(
        ageRestrictedTreatment: AgeRestrictedTreatment.child,
        maxAdContentRating: MaxAdContentRating.g,
      );

  /// كل طلب إعلان غير مخصّص صراحة، فوق معاملة الطفل
  static const AdRequest adRequest = AdRequest(nonPersonalizedAds: true);

  final AdFormatPolicy policy;

  bool get _interstitialAllowed => policy.allows(AdFormat.interstitial);
  bool get _rewardedAllowed => policy.allowsRewardAds;

  bool _initialized = false;
  Future<void>? _initInFlight;

  InterstitialAd? _interstitial;
  RewardedInterstitialAd? _rewarded;
  Future<void>? _interstitialLoading;
  Future<void>? _rewardedLoading;
  int _interstitialFailures = 0;
  int _rewardedFailures = 0;
  Timer? _interstitialRetry;
  Timer? _rewardedRetry;

  @override
  bool get isInterstitialReady => _interstitialAllowed && _interstitial != null;

  @override
  bool get isRewardedReady => _rewardedAllowed && _rewarded != null;

  @override
  Future<void> init() {
    // لا قالب مسموح = لا تهيئة ولا موافقة: نموذج موافقة لإعلانات لن تُعرض
    // إزعاج بلا مقابل، والتهيئة نفسها طلب شبكة لا حاجة إليه
    if (!_interstitialAllowed && !_rewardedAllowed) return Future.value();
    if (_initialized) return Future.value();
    return _initInFlight ??= _init().whenComplete(() => _initInFlight = null);
  }

  Future<void> _init() async {
    try {
      // قبل أي شيء آخر: التهيئة وأول طلب يجب أن يحملا معاملة الطفل
      await MobileAds.instance.updateRequestConfiguration(
        childSafeRequestConfiguration,
      );
      await _gatherConsent();
      if (!await ConsentInformation.instance.canRequestAds()) {
        debugPrint('AdMob: لا يمكن طلب إعلانات (الموافقة غير مكتملة)');
        return;
      }
      await MobileAds.instance.initialize();
      _initialized = true;
      await preload();
    } catch (e) {
      debugPrint('AdMob: فشلت التهيئة — $e');
    }
  }

  /// موافقة المستخدم (GDPR في أوروبا، وأي رسالة معدّة في لوحة AdMob →
  /// Privacy & messaging). خارج تلك المناطق يعود فورا بلا نافذة.
  /// مهلة قصوى كي لا يبقى الإقلاع رهينة خادم الموافقة.
  ///
  /// الوسم «دون سنّ الموافقة» للسبب نفسه الذي تُعامل به الطلبات معاملة
  /// الطفل: لا بوّابة عمر، فلا نفترض لاعبا بالغا.
  Future<void> _gatherConsent() {
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(tagForUnderAgeOfConsent: true),
      () => ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (error != null) {
          debugPrint('AdMob/UMP: نموذج الموافقة — ${error.message}');
        }
        finish();
      }),
      (error) {
        debugPrint('AdMob/UMP: تحديث الموافقة — ${error.message}');
        finish();
      },
    );
    return done.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => debugPrint('AdMob/UMP: انتهت مهلة الموافقة'),
    );
  }

  @override
  Future<void> preload() async {
    if (!_interstitialAllowed && !_rewardedAllowed) return;
    if (!_initialized) {
      await init();
      if (!_initialized) return;
    }
    await Future.wait([
      if (_interstitialAllowed) _loadInterstitial(),
      if (_rewardedAllowed) _loadRewarded(),
    ]);
  }

  // ─────────────────────── البيني ───────────────────────

  Future<void> _loadInterstitial() {
    if (!_interstitialAllowed || _interstitial != null || !_initialized) {
      return Future.value();
    }
    return _interstitialLoading ??= _doLoadInterstitial().whenComplete(
      () => _interstitialLoading = null,
    );
  }

  Future<void> _doLoadInterstitial() async {
    final done = Completer<void>();
    await InterstitialAd.load(
      adUnitId: AdMobIds.interstitial,
      request: adRequest,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          // نداء متأخّر لا يجعل قالبا ممنوعا جاهزا
          if (!_interstitialAllowed) {
            ad.dispose();
          } else {
            _interstitial = ad;
            _interstitialFailures = 0;
          }
          if (!done.isCompleted) done.complete();
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdMob: فشل تحميل البيني — ${error.message}');
          _interstitialFailures++;
          _interstitialRetry?.cancel();
          _interstitialRetry = Timer(
            _backoff(_interstitialFailures),
            () => unawaited(_loadInterstitial()),
          );
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    return done.future;
  }

  @override
  Future<InterstitialResult> showInterstitial(
    BuildContext context, {
    VoidCallback? onOpenShop,
  }) async {
    if (!_interstitialAllowed) return InterstitialResult.unavailable;
    final ad = _interstitial;
    if (ad == null) {
      unawaited(_loadInterstitial());
      return InterstitialResult.unavailable;
    }
    _interstitial = null;

    final done = Completer<InterstitialResult>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(InterstitialResult.dismissed);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdMob: فشل عرض البيني — ${error.message}');
        ad.dispose();
        if (!done.isCompleted) done.complete(InterstitialResult.unavailable);
      },
    );
    try {
      await ad.show();
    } catch (e) {
      debugPrint('AdMob: استثناء عرض البيني — $e');
      if (!done.isCompleted) done.complete(InterstitialResult.unavailable);
    }
    final result = await done.future;
    unawaited(_loadInterstitial());
    return result;
  }

  // ─────────────────── المكافأة (بيني جائزي) ───────────────────

  Future<void> _loadRewarded() {
    if (!_rewardedAllowed || _rewarded != null || !_initialized) {
      return Future.value();
    }
    return _rewardedLoading ??= _doLoadRewarded().whenComplete(
      () => _rewardedLoading = null,
    );
  }

  Future<void> _doLoadRewarded() async {
    final done = Completer<void>();
    await RewardedInterstitialAd.load(
      adUnitId: AdMobIds.rewardedInterstitial,
      request: adRequest,
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!_rewardedAllowed) {
            ad.dispose();
          } else {
            _rewarded = ad;
            _rewardedFailures = 0;
          }
          if (!done.isCompleted) done.complete();
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdMob: فشل تحميل المكافأة — ${error.message}');
          _rewardedFailures++;
          _rewardedRetry?.cancel();
          _rewardedRetry = Timer(
            _backoff(_rewardedFailures),
            () => unawaited(_loadRewarded()),
          );
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    return done.future;
  }

  @override
  Future<bool> showRewarded(
    BuildContext context, {
    required AdLength length,
  }) async {
    // قالب ممنوع: رفض فوري — لا مهلة التحميل أدناه ولا أي انتظار
    if (!_rewardedAllowed) return false;
    // اللاعب ضغط الزر الآن: نمهله بضع ثوان إن لم يكن الإعلان جاهزا
    // بدل الرفض الفوري — لكن لا أكثر، فالانتظار الطويل أسوأ من «لا يوجد»
    if (_rewarded == null) {
      if (!_initialized) await init();
      await _loadRewarded().timeout(
        const Duration(seconds: 6),
        onTimeout: () {},
      );
    }
    final ad = _rewarded;
    if (ad == null) return false;
    _rewarded = null;

    // المنح بنداء onUserEarnedReward وحده، لا بإغلاق الإعلان
    var earned = false;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdMob: فشل عرض المكافأة — ${error.message}');
        ad.dispose();
        if (!done.isCompleted) done.complete();
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
    } catch (e) {
      debugPrint('AdMob: استثناء عرض المكافأة — $e');
      if (!done.isCompleted) done.complete();
    }
    await done.future;
    unawaited(_loadRewarded());
    return earned;
  }

  /// 15ث، 30ث، 60ث، … حتى 5 دقائق
  static Duration _backoff(int failures) => Duration(
    seconds: (15 * (1 << (failures - 1).clamp(0, 5))).clamp(15, 300),
  );
}
