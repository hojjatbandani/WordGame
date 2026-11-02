// سياسة قوالب الإعلان وطبقة الخدمة.
//
// رفضت Google Play النسخة 1 بموجب سياسة العائلات («إعلانات تقاطع اللعب ولا
// يمكن إغلاقها بعد 5 ثوان»)، ولم يكن فيها AdMob أصلا: «إعلانها» الوحيد كان
// نافذة المحاكاة (MockAdService + AdVideoOverlay) التي لا يغلقها زرّ الرجوع
// ولا يعمل زرّ إغلاقها قبل نهاية العدّ. النسخة 3 أطفأت كل القوالب، وهذا
// البناء يعيد قالبين تضمن AdMob إغلاقهما خلال 5 ثوان (ad_policy.dart).
// هذا الملف يثبّت:
//   ١) السياسة: البيني والبيني الجائزي وحدهما — لا الجائزي العادي ولا
//      إعلان الفتح — و«لا شيء» لنسخة إصدار بلا معرّفات، ومفتاح الإيقاف عن
//      بعد يضيّق ولا يوسّع.
//   ٢) البوّابة (PolicyGatedAdService): ما تمنعه لا يصل منه نداء إلى
//      التنفيذ والرفض فوري — وليست إطفاء أعمى: ما تسمح به يمرّ كما هو.
//   ٣) AdMobAdService الحقيقية: بلا قالب لا رسالة واحدة إلى قنوات
//      google_mobile_ads، وبسياسة البناء تحمّل بينيا وبينيا جائزيا — لا
//      جائزيا عاديا ولا إعلان فتح أبدا.
//   ٤) إعداد الطلبات: معاملة الطفل ومحتوى G، وطلبات غير مخصّصة، وموافقة
//      موسومة «دون السنّ».
//   ٥) adServiceProvider: بلا قالب لا نافذة محاكاة ولا مسار جديد.
//
// كل «لا» هنا يقابلها ضابط يرى «نعم» حين يُسمح بالقالب، كي لا يمرّ اختبار
// لأن المعترض أعمى أو لأن الباحث لا يرى شيئا أصلا.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// مرمّز الحزمة نفسه: معاملات التحميل فيها أنواع خاصة (AdRequest) لا يفكّها
// المرمّز القياسي، ومعرّف الوحدة بينها
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart'
    show instanceManager;
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/ad_service.dart';
import 'package:huruf/data/ads/ad_format.dart';
import 'package:huruf/data/ads/ad_policy.dart';
import 'package:huruf/data/ads/admob_ad_service.dart';
import 'package:huruf/data/ads/policy_gated_ad_service.dart';
import 'package:huruf/data/config/feature_flags.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/widgets/ad_video_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────── قنوات google_mobile_ads 9.1.0 ───────────────────────

/// SDK الإعلانات: التهيئة وإعداد الطلبات والتحميل والعرض
const _adsChannel = 'plugins.flutter.io/google_mobile_ads';

/// UMP: تحديث معلومات الموافقة ونموذجها
const _umpChannel = 'plugins.flutter.io/google_mobile_ads/ump';

/// الواجهة/الخلفية — ما يستمع إليه إعلان فتح التطبيق
const _appStateMethodChannel =
    'plugins.flutter.io/google_mobile_ads/app_state_method';
const _appStateEventChannel =
    'plugins.flutter.io/google_mobile_ads/app_state_event';

const _sdkChannels = [
  _adsChannel,
  _umpChannel,
  _appStateMethodChannel,
  _appStateEventChannel,
];

/// رسالة واحدة التقطها المعترض في طريقها إلى المنصّة
class _SdkCall {
  _SdkCall(this.channel, this.method, this.arguments, [this.raw]);

  final String channel;
  final String method;

  /// null إن لم تُفكّ بالمرمّز القياسي (أنواع خاصة بالحزمة)
  final Object? arguments;

  /// الرسالة كما وصلت — لفكّها بمرمّز الحزمة حين لا يكفي القياسي
  final ByteData? raw;

  /// معاملات طلب تحميل بمرمّز الحزمة نفسه (فيها AdRequest)
  Map<Object?, Object?> get loadArguments =>
      instanceManager.channel.codec.decodeMethodCall(raw).arguments
          as Map<Object?, Object?>;

  @override
  String toString() => '$method @ $channel';
}

_SdkCall _decode(String channel, ByteData? message) {
  if (message == null) return _SdkCall(channel, '(empty message)', null);
  // اسم الطريقة أول قيمة في الرسالة، ونوعه نصّ قياسي دوما — يُقرأ وحده
  // كي لا يتوقّف على فكّ المعاملات
  final method = const StandardMessageCodec().readValue(ReadBuffer(message));
  return _SdkCall(channel, '$method', _tryDecodeArguments(message), message);
}

Object? _tryDecodeArguments(ByteData message) {
  try {
    return const StandardMethodCodec().decodeMethodCall(message).arguments;
  } on FormatException {
    // معاملات بأنواع خاصة بالحزمة (AdRequest، ConsentRequestParameters):
    // يكفي اسم الطريقة
    return null;
  }
}

/// يعترض قنوات الحزمة كلها ويسجّل كل رسالة بترتيبها، ويُزال الاعتراض في
/// نهاية الاختبار. [respond] يقرّر ردّ «المنصّة»؛ null = نجاح بلا قيمة.
List<_SdkCall> _interceptSdkChannels({
  ByteData? Function(_SdkCall call)? respond,
}) {
  final calls = <_SdkCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in _sdkChannels) {
    messenger.setMockMessageHandler(channel, (message) async {
      final call = _decode(channel, message);
      calls.add(call);
      return respond?.call(call) ??
          const StandardMethodCodec().encodeSuccessEnvelope(null);
    });
    addTearDown(() => messenger.setMockMessageHandler(channel, null));
  }
  return calls;
}

// ─────────────────────────────── بدائل الاختبار ───────────────────────────────

/// تنفيذ مسجِّل يدّعي إعلانين محمّلين سلفا: لو مرّرت البوّابة إليه أي شيء
/// — ولو سؤال جاهزية — لظهر في [calls]. العرض يبقى «على الشاشة» حتى يُكمله
/// الاختبار، كما يبقى إعلان حقيقي حتى يُغلق.
class _RecordingAdService implements AdService {
  final calls = <String>[];
  final interstitialClosed = Completer<InterstitialResult>();
  final rewardedClosed = Completer<bool>();
  VoidCallback? onOpenShopReceived;

  @override
  Future<void> init() async => calls.add('init');

  @override
  Future<void> preload() async => calls.add('preload');

  @override
  bool get isInterstitialReady {
    calls.add('isInterstitialReady');
    return true;
  }

  @override
  bool get isRewardedReady {
    calls.add('isRewardedReady');
    return true;
  }

  @override
  Future<InterstitialResult> showInterstitial(
    BuildContext context, {
    VoidCallback? onOpenShop,
  }) {
    calls.add('showInterstitial');
    onOpenShopReceived = onOpenShop;
    return interstitialClosed.future;
  }

  @override
  Future<bool> showRewarded(BuildContext context, {required AdLength length}) {
    calls.add('showRewarded:${length.name}');
    return rewardedClosed.future;
  }
}

/// بديل [ConsentInformation] (الحقل الساكن العام في الحزمة): يسجّل معاملات
/// طلب الموافقة، ثم يجيب «لا يمكن طلب إعلانات» فتقف الخدمة قبل التهيئة.
class _RecordingConsentInformation implements ConsentInformation {
  final requests = <ConsentRequestParameters>[];

  @override
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    OnConsentInfoUpdateSuccessListener successListener,
    OnConsentInfoUpdateFailureListener failureListener,
  ) {
    requests.add(params);
    successListener();
  }

  @override
  Future<bool> canRequestAds() async => false;

  @override
  Future<bool> isConsentFormAvailable() async => false;

  @override
  Future<ConsentStatus> getConsentStatus() async => ConsentStatus.notRequired;

  @override
  Future<void> reset() async {}

  @override
  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async =>
      PrivacyOptionsRequirementStatus.notRequired;
}

/// نداء بدأ ولم يُنتظر: بماذا اكتمل، ومتى على ساعة الاختبار المزيّفة. لا
/// يُنتظر بـawait عمدا: نداء ينتظر مؤقّتا كان سيعلّق الاختبار بدل أن يُسقطه.
class _Pending<T> {
  _Pending(WidgetTester tester, Future<T> future) {
    unawaited(
      future.then((value) {
        result = value;
        completedAt = tester.binding.clock.now();
      }),
    );
  }

  T? result;
  DateTime? completedAt;
}

// ─────────────────────────────── الحاضنة ───────────────────────────────

const _anchor = Key('ad-policy-anchor');

/// شاشة واحدة تحت Navigator حقيقي — منها يُؤخذ سياق مداخل العرض
Future<void> _pumpHost(
  WidgetTester tester, {
  ProviderContainer? container,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final app = MaterialApp(
    theme: HurufTheme.build(),
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: const Scaffold(key: _anchor, body: SizedBox.expand()),
  );
  await tester.pumpWidget(
    container == null
        ? app
        : UncontrolledProviderScope(container: container, child: app),
  );
}

BuildContext _hostContext(WidgetTester tester) =>
    tester.element(find.byKey(_anchor));

Future<ProviderContainer> _container({AdFormatPolicy? policy}) async {
  SharedPreferences.setMockInitialValues({});
  final store = await ProgressStore.create();
  final container = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      if (policy != null) adFormatPolicyProvider.overrideWithValue(policy),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// يستدعي كل مداخل [service] — وأكثر من مرة، كما تستدعيها الشاشات
/// ومؤقّتات إعادة المحاولة وعودة التطبيق من الخلفية — ثم يثبت أن لا جاهزية،
/// وأن كل نداء اكتمل بالرفض في اللحظة نفسها على الساعة المزيّفة.
Future<void> _expectImmediateRefusal(
  WidgetTester tester,
  AdService service,
  BuildContext context,
) async {
  final t0 = tester.binding.clock.now();
  final setup = <_Pending<Object?>>[
    for (var i = 0; i < 2; i++) _Pending(tester, service.init()),
    for (var i = 0; i < 3; i++) _Pending(tester, service.preload()),
  ];
  final interstitials = [
    for (var i = 0; i < 2; i++)
      _Pending(tester, service.showInterstitial(context, onOpenShop: () {})),
  ];
  final rewarded = {
    for (final length in AdLength.values)
      length: _Pending(tester, service.showRewarded(context, length: length)),
  };

  // إطار واحد بلا أي زمن: ما لم يكتمل الآن فهو ينتظر مؤقّتا أو ردّا
  await tester.pump();

  expect(service.isInterstitialReady, isFalse);
  expect(service.isRewardedReady, isFalse);
  for (final call in interstitials) {
    expect(call.result, InterstitialResult.unavailable);
  }
  for (final MapEntry(key: length, value: call) in rewarded.entries) {
    expect(
      call.result,
      isFalse,
      reason: 'جائزي ${length.name}: false = «لم يُشاهَد»، فلا منح ولا استهلاك',
    );
  }
  for (final call in [...setup, ...interstitials, ...rewarded.values]) {
    expect(
      call.completedAt,
      t0,
      reason: 'كل نداء يكتمل في اللحظة نفسها: لا مهلة تحميل ولا انتظار نداء',
    );
  }
}

/// ينتظر نهاية العدّ في نافذة المحاكاة ثم يغلقها بزرّها
Future<void> _sitThroughAndClose(WidgetTester tester, AdLength length) async {
  await tester.pump(length.duration);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.byIcon(Icons.close_rounded));
  await tester.pump();
  // انتقال الخروج
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('سياسة القوالب (AdFormatPolicy)', () {
    test('هذا البناء: البيني والبيني الجائزي وحدهما', () {
      // ثابت وقت الترجمة: لو صار يُقرأ من إعداد عن بعد أو تخزين لما تُرجم
      // هذا السطر
      const policy = AdFormatPolicy.currentBuild;
      expect(
        {
          for (final format in AdFormat.values)
            if (policy.allows(format)) format,
        },
        {AdFormat.interstitial, AdFormat.rewardedInterstitial},
      );
      expect(
        policy.allows(AdFormat.rewarded),
        isFalse,
        reason: 'الجائزي العادي: مهلة مكافأته تبلغ 30 ثانية',
      );
      expect(
        policy.allows(AdFormat.appOpen),
        isFalse,
        reason: 'بيني عند فتح التطبيق ممنوع نصّا في سياسة العائلات',
      );
      expect(policy.allowsRewardAds, isTrue);
    });

    test('مكافأة الإعلان يخدمها البيني الجائزي وحده — الجائزي العادي لا '
        'يفتحها', () {
      expect(AdFormatPolicy.rewardFormat, AdFormat.rewardedInterstitial);
      for (final format in AdFormat.values) {
        expect(
          AdFormatPolicy({format}).allowsRewardAds,
          format == AdFormat.rewardedInterstitial,
          reason: format.name,
        );
      }
    });

    test('none: لا قالب ولا ملء شاشة ولا مكافأة', () {
      for (final format in AdFormat.values) {
        expect(
          AdFormatPolicy.none.allows(format),
          isFalse,
          reason: format.name,
        );
      }
      expect(AdFormatPolicy.none.allowsAnyFullScreen, isFalse);
      expect(AdFormatPolicy.none.allowsRewardAds, isFalse);
    });

    test('السياسة الفعلية: سياسة البناء بشبكة جاهزة، ولا شيء بدونها', () {
      expect(
        AdFormatPolicy.effective(adNetworkReady: true),
        same(AdFormatPolicy.currentBuild),
      );
      expect(
        AdFormatPolicy.effective(adNetworkReady: false),
        same(AdFormatPolicy.none),
      );
    });

    test('السياسة تسمح بما سُمّي فيها وحده: لا قالب يجرّ قالبا آخر', () {
      for (final enabled in AdFormat.values) {
        final policy = AdFormatPolicy({enabled});
        for (final format in AdFormat.values) {
          expect(
            policy.allows(format),
            format == enabled,
            reason: 'سياسة {${enabled.name}} تُسأل عن ${format.name}',
          );
        }
      }
    });

    test('ملء الشاشة: البيني والجائزي والبيني الجائزي وإعلان الفتح — '
        'لا البانر ولا الأصلي', () {
      const fullScreen = {
        AdFormat.interstitial,
        AdFormat.rewarded,
        AdFormat.rewardedInterstitial,
        AdFormat.appOpen,
      };
      for (final format in AdFormat.values) {
        expect(
          AdFormatPolicy({format}).allowsAnyFullScreen,
          fullScreen.contains(format),
          reason: format.name,
        );
      }
      expect(
        const AdFormatPolicy({
          AdFormat.banner,
          AdFormat.native,
        }).allowsAnyFullScreen,
        isFalse,
      );
    });

    test('مفتاح الإيقاف عن بعد يضيّق السياسة ولا يوسّعها', () {
      ProviderContainer containerWith({
        AdFormatPolicy? policy,
        required bool flagsOn,
      }) {
        final container = ProviderContainer(
          overrides: [
            if (policy != null)
              adFormatPolicyProvider.overrideWithValue(policy),
            featureFlagsProvider.overrideWithValue(
              FeatureFlags({
                FeatureFlags.kInterstitialAds: flagsOn,
                FeatureFlags.kRewardedAds: flagsOn,
              }),
            ),
          ],
        );
        addTearDown(container.dispose);
        return container;
      }

      // الخادم يقول «شغّل» صراحة والسياسة تقول لا: لا
      final serverSaysOn = containerWith(
        policy: AdFormatPolicy.none,
        flagsOn: true,
      );
      expect(serverSaysOn.read(rewardedAdsAvailableProvider), isFalse);
      expect(serverSaysOn.read(interstitialAdsAvailableProvider), isFalse);

      // ولا الجائزي العادي يفتح «شاهد إعلانا»: ليس قالب المكافأة
      final rewardedVideoOnly = containerWith(
        policy: const AdFormatPolicy({AdFormat.rewarded}),
        flagsOn: true,
      );
      expect(rewardedVideoOnly.read(rewardedAdsAvailableProvider), isFalse);

      // البناء يسمح والخادم يطفئ: لا
      final serverSaysOff = containerWith(
        policy: AdFormatPolicy.currentBuild,
        flagsOn: false,
      );
      expect(serverSaysOff.read(rewardedAdsAvailableProvider), isFalse);
      expect(serverSaysOff.read(interstitialAdsAvailableProvider), isFalse);

      // ضابط: كلاهما يسمح — نعم، وهو حال المزوّد بلا تجاوز (سياسة البناء)
      for (final bothAllow in [
        containerWith(policy: AdFormatPolicy.currentBuild, flagsOn: true),
        containerWith(flagsOn: true),
      ]) {
        expect(bothAllow.read(rewardedAdsAvailableProvider), isTrue);
        expect(bothAllow.read(interstitialAdsAvailableProvider), isTrue);
      }
    });
  });

  group('بوّابة السياسة (PolicyGatedAdService)', () {
    testWidgets('بلا قالب (none): لا يصل إلى التنفيذ نداء واحد ولو ادّعى '
        'إعلانين محمّلين، والرفض فوري', (tester) async {
      await _pumpHost(tester);
      final inner = _RecordingAdService();

      await _expectImmediateRefusal(
        tester,
        PolicyGatedAdService(inner, policy: AdFormatPolicy.none),
        _hostContext(tester),
      );

      expect(
        inner.calls,
        isEmpty,
        reason: 'لا تهيئة ولا تحميل ولا سؤال جاهزية ولا عرض',
      );
    });

    testWidgets('قوالب بلا تنفيذ (بانر، أصلي، فتح، جائزي عادي) لا تفتح '
        'البوّابة لشيء', (tester) async {
      await _pumpHost(tester);
      final inner = _RecordingAdService();
      final gate = PolicyGatedAdService(
        inner,
        policy: const AdFormatPolicy({
          AdFormat.banner,
          AdFormat.native,
          AdFormat.appOpen,
          AdFormat.rewarded,
        }),
      );

      await _expectImmediateRefusal(tester, gate, _hostContext(tester));

      expect(inner.calls, isEmpty);
    });

    testWidgets('بسياسة هذا البناء (الافتراضية): القالبان يمرّان إلى التنفيذ', (
      tester,
    ) async {
      await _pumpHost(tester);
      final inner = _RecordingAdService();
      final gate = PolicyGatedAdService(inner);

      await gate.init();
      await gate.preload();
      expect(gate.isInterstitialReady, isTrue);
      expect(gate.isRewardedReady, isTrue);

      final context = _hostContext(tester);
      final interstitial = _Pending(tester, gate.showInterstitial(context));
      final rewarded = _Pending(
        tester,
        gate.showRewarded(context, length: AdLength.long),
      );
      await tester.pump();
      expect(inner.calls, [
        'init',
        'preload',
        'isInterstitialReady',
        'isRewardedReady',
        'showInterstitial',
        'showRewarded:long',
      ]);

      inner.interstitialClosed.complete(InterstitialResult.dismissed);
      inner.rewardedClosed.complete(true);
      await tester.pump();
      expect(interstitial.result, InterstitialResult.dismissed);
      expect(rewarded.result, isTrue);
    });

    testWidgets('تسمح بالبيني الجائزي وحده: يمرّ كما هو وتنتظر إغلاقه، ويبقى '
        'البيني مرفوضا دون أن يُسأل التنفيذ', (tester) async {
      await _pumpHost(tester);
      final inner = _RecordingAdService();
      final gate = PolicyGatedAdService(
        inner,
        policy: const AdFormatPolicy({AdFormat.rewardedInterstitial}),
      );

      await gate.init();
      await gate.preload();
      expect(inner.calls, ['init', 'preload']);
      expect(gate.isRewardedReady, isTrue);
      expect(gate.isInterstitialReady, isFalse);

      final context = _hostContext(tester);
      final interstitial = _Pending(tester, gate.showInterstitial(context));
      final rewarded = _Pending(
        tester,
        gate.showRewarded(context, length: AdLength.long),
      );
      await tester.pump();

      expect(interstitial.result, InterstitialResult.unavailable);
      expect(inner.calls, contains('showRewarded:long'));
      expect(
        rewarded.completedAt,
        isNull,
        reason: 'البوّابة تنتظر الإعلان الحقيقي حتى يُغلق ولا تجيب عنه',
      );

      inner.rewardedClosed.complete(true);
      await tester.pump();
      expect(rewarded.result, isTrue);

      expect(
        inner.calls.where((call) => call.contains('Interstitial')),
        isEmpty,
        reason: 'البيني الممنوع لم يصل إلى التنفيذ ولا بسؤال جاهزية',
      );
    });

    testWidgets('تسمح بالبيني وحده: يمرّ كما هو مع مدخل المتجر، ويبقى '
        'الجائزي مرفوضا دون أن يُسأل التنفيذ', (tester) async {
      await _pumpHost(tester);
      final inner = _RecordingAdService();
      final gate = PolicyGatedAdService(
        inner,
        policy: const AdFormatPolicy({AdFormat.interstitial}),
      );

      await gate.init();
      await gate.preload();
      expect(inner.calls, ['init', 'preload']);
      expect(gate.isInterstitialReady, isTrue);
      expect(gate.isRewardedReady, isFalse);

      var shopOpened = false;
      final context = _hostContext(tester);
      final interstitial = _Pending(
        tester,
        gate.showInterstitial(context, onOpenShop: () => shopOpened = true),
      );
      final rewarded = _Pending(
        tester,
        gate.showRewarded(context, length: AdLength.short),
      );
      await tester.pump();

      expect(rewarded.result, isFalse);
      expect(inner.calls, contains('showInterstitial'));
      expect(interstitial.completedAt, isNull);

      // اللاعب ضغط «أزل الإعلانات» داخل الإعلان: المدخل وصل كما هو
      inner.onOpenShopReceived?.call();
      inner.interstitialClosed.complete(InterstitialResult.leftForShop);
      await tester.pump();
      expect(shopOpened, isTrue);
      expect(interstitial.result, InterstitialResult.leftForShop);

      expect(
        inner.calls.where((call) => call.contains('Rewarded')),
        isEmpty,
        reason: 'الجائزي الممنوع لم يصل إلى التنفيذ ولا بسؤال جاهزية',
      );
    });
  });

  group('AdMobAdService الحقيقية وقنوات google_mobile_ads', () {
    final variants = <String, AdService Function()>{
      'AdMobAdService(policy: none) وحدها': () =>
          AdMobAdService(policy: AdFormatPolicy.none),
      'كما يركّبها main.dart لنسخة إصدار بلا معرّفات': () =>
          PolicyGatedAdService(
            AdMobAdService(policy: AdFormatPolicy.none),
            policy: AdFormatPolicy.none,
          ),
    };
    for (final MapEntry(key: label, value: build) in variants.entries) {
      testWidgets('$label: لا رسالة واحدة إلى الحزمة، ولا جاهزية، والرفض '
          'بلا مهلة الست ثوان', (tester) async {
        final sdk = _interceptSdkChannels();
        await _pumpHost(tester);

        await _expectImmediateRefusal(tester, build(), _hostContext(tester));

        expect(
          sdk,
          isEmpty,
          reason: 'لا تهيئة للحزمة ولا نموذج موافقة ولا تحميل ولا عرض',
        );
      });
    }

    testWidgets('ضابط: حين يُسمح بقالب تصل الرسائل فعلا، وأولها معاملة '
        'الطفل ومحتوى G قبل الموافقة والتهيئة', (tester) async {
      final sdk = _interceptSdkChannels(
        respond: (call) => switch (call.method) {
          'ConsentInformation#canRequestAds' =>
            const StandardMethodCodec().encodeSuccessEnvelope(true),
          // لا SDK تحت flutter test: تفشل التهيئة فتقف الخدمة قبل أي تحميل
          'MobileAds#initialize' =>
            const StandardMethodCodec().encodeErrorEnvelope(
              code: 'no-sdk',
              message: 'flutter test',
            ),
          _ => null,
        },
      );
      final admob = AdMobAdService();

      final init = _Pending(tester, admob.init());
      await tester.pump();
      expect(init.completedAt, isNotNull);

      // المعترض يرى القناتين فعلا — فصفر الرسائل أعلاه صفر حقيقي
      expect(
        sdk.map((call) => call.channel),
        containsAll([_adsChannel, _umpChannel]),
      );

      // _init: تنظيف إعادة التشغيل الساخن، ترسله الحزمة نفسها عند أول لمس
      // لـMobileAds.instance في العملية — لا إعداد فيه ولا طلب إعلان
      final methods = [
        for (final call in sdk)
          if (call.method != '_init') call.method,
      ];
      expect(methods.first, 'MobileAds#updateRequestConfiguration');
      expect(
        methods,
        containsAllInOrder([
          'MobileAds#updateRequestConfiguration',
          'ConsentInformation#requestConsentInfoUpdate',
          'MobileAds#initialize',
        ]),
      );

      final config = sdk
          .firstWhere(
            (call) => call.method == 'MobileAds#updateRequestConfiguration',
          )
          .arguments;
      expect(config, isA<Map<Object?, Object?>>());
      config as Map<Object?, Object?>;
      expect(
        config['ageRestrictedTreatment'],
        AgeRestrictedTreatment.child.index,
      );
      expect(config['maxAdContentRating'], MaxAdContentRating.g);
      expect(config['tagForChildDirectedTreatment'], isNull);
      expect(config['tagForUnderAgeOfConsent'], isNull);
    });

    testWidgets('بسياسة البناء تحمّل بينيا وبينيا جائزيا بالمعرّفين '
        'الاختباريين — لا جائزيا عاديا ولا إعلان فتح أبدا', (tester) async {
      final sdk = _interceptSdkChannels(
        respond: (call) => switch (call.method) {
          'ConsentInformation#canRequestAds' =>
            const StandardMethodCodec().encodeSuccessEnvelope(true),
          'MobileAds#initialize' =>
            instanceManager.channel.codec.encodeSuccessEnvelope(
              InitializationStatus({}),
            ),
          _ => null,
        },
      );
      final admob = AdMobAdService();

      // التحميل ينتظر نداء «حُمِّل» من المنصّة، ولا منصّة هنا — فلا يُنتظر
      _Pending(tester, admob.init());
      await tester.pump();

      final loads = {
        for (final call in sdk)
          if (call.method.startsWith('load'))
            call.method: call.loadArguments['adUnitId'],
      };
      // نسخة تطوير: معرّفا Google الاختباريان دوما
      expect(loads, {
        'loadInterstitialAd': 'ca-app-pub-3940256099942544/1033173712',
        'loadRewardedInterstitialAd': 'ca-app-pub-3940256099942544/5354046379',
      });
      // لا جاهزية قبل نداء «حُمِّل»: الزرّ لا يعد بإعلان لم يصل
      expect(admob.isInterstitialReady, isFalse);
      expect(admob.isRewardedReady, isFalse);
    });

    testWidgets('طلب الموافقة (UMP) موسوم «دون سنّ الموافقة»', (tester) async {
      _interceptSdkChannels();
      final consent = _RecordingConsentInformation();
      final original = ConsentInformation.instance;
      ConsentInformation.instance = consent;
      addTearDown(() => ConsentInformation.instance = original);
      final admob = AdMobAdService();

      final init = _Pending(tester, admob.init());
      await tester.pump();
      expect(init.completedAt, isNotNull);

      expect(consent.requests, hasLength(1));
      expect(consent.requests.single.tagForUnderAgeOfConsent, isTrue);
    });
  });

  group('إعداد الطلبات: كل لاعب مجهول العمر يُعامل معاملة الطفل', () {
    test('معاملة الطفل وأقصى تصنيف G، بلا الوسمين المهجورين', () {
      final config = AdMobAdService.childSafeRequestConfiguration;
      expect(config.ageRestrictedTreatment, AgeRestrictedTreatment.child);
      expect(config.maxAdContentRating, MaxAdContentRating.g);
      // البديل الموثّق يُضبط وحده، لا مع الوسمين القديمين
      // ignore: deprecated_member_use
      expect(config.tagForChildDirectedTreatment, isNull);
      // ignore: deprecated_member_use
      expect(config.tagForUnderAgeOfConsent, isNull);
    });

    test('كل طلب إعلان غير مخصّص', () {
      expect(AdMobAdService.adRequest.nonPersonalizedAds, isTrue);
    });
  });

  group('adServiceProvider الافتراضي', () {
    testWidgets('بلا قالب (none): يرفض فورا ولا يدفع نافذة المحاكاة ولا أي '
        'مسار', (tester) async {
      final container = await _container(policy: AdFormatPolicy.none);
      await _pumpHost(tester, container: container);
      final ads = container.read(adServiceProvider);

      await _expectImmediateRefusal(tester, ads, _hostContext(tester));

      // المحاكاة تدفع نافذتها بعد «تحميل» 400ms — نمنحها أكثر من ذلك،
      // ونبحث خارج المسرح أيضا: أول إطار لمسار مدفوع يُبنى خارجه
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(AdVideoOverlay, skipOffstage: false), findsNothing);
      expect(
        Navigator.of(_hostContext(tester), rootNavigator: true).canPop(),
        isFalse,
        reason: 'لا مسار فوق الشاشة الأولى',
      );
    });

    testWidgets('ضابط: بسياسة البناء (بلا تجاوز) يدفع المزوّد نفسه نافذة '
        'المحاكاة فعلا', (tester) async {
      final container = await _container();
      await _pumpHost(tester, container: container);
      final ads = container.read(adServiceProvider);
      expect(ads.isInterstitialReady, isTrue);
      expect(ads.isRewardedReady, isTrue);

      final interstitial = _Pending(
        tester,
        ads.showInterstitial(_hostContext(tester)),
      );
      // أول إطار للمسار المدفوع يُبنى خارج المسرح (لقياس Hero)، والثاني عليه
      await tester.pump();
      await tester.pump();
      expect(find.byType(AdVideoOverlay), findsOneWidget);
      await _sitThroughAndClose(tester, AdFormats.betweenLevels);
      expect(interstitial.result, InterstitialResult.dismissed);
      expect(find.byType(AdVideoOverlay), findsNothing);

      final rewarded = _Pending(
        tester,
        ads.showRewarded(_hostContext(tester), length: AdLength.short),
      );
      // «تحميل» المحاكاة 400ms قبل دفع النافذة
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(AdVideoOverlay), findsOneWidget);
      await _sitThroughAndClose(tester, AdLength.short);
      expect(rewarded.result, isTrue);
      expect(find.byType(AdVideoOverlay), findsNothing);
    });
  });
}
