// «كل قوالب الإعلان مطفأة» على طبقة المزوّدات والمنطق.
//
// رفضت Google Play النسخة 1 بموجب «متطلبات قوالب الإعلان» في سياسة
// العائلات: إعلان يقاطع اللعب ولا يُغلق بعد 5 ثوان. النسخة 3 خرجت بلا أي
// قالب، وما زال هذا المسار حيّا: نسخة إصدار بلا معرّفات AdMob حقيقية تعمل
// بـ[AdFormatPolicy.none] (main.dart). هذا الملف يثبت أن اللعبة تامّة فيه،
// حيث تُتّخذ القرارات فعلا — المزوّدات — لا في الثابت وحده:
//
//   1) مزوّدا الإتاحة يقولان «لا» مهما قالت مفاتيح الإيقاف.
//   2) إعداد عن بعد محفوظ يفتح كل شيء، وحالة تركتها نسخة كانت إعلاناتها
//      تعمل، لا يعيدان أي مدخل: لا طلب جائزي، ولا مضاعفة، ولا دورة
//      بإعلان، ولا بيني.
//   3) ما كسبه اللاعب قبل الإطفاء يُدفع مرة واحدة بالضبط، ومن اشترى إزالة
//      الإعلانات يبقى حقّه.
//   4) نزاهة المنح حين يُسمح بإعلان المكافأة: لا منح بلا مشاهدة مكتملة،
//      ولا منحتان عن نداء مكرّر.
//
// الحاوية تُبنى بـ[AdFormatPolicy.none] كما يبنيها main.dart لنسخة إصدار بلا
// معرّفات، إلا حيث يُمرَّر `policy` صراحة (مجموعة النزاهة الأخيرة).

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/ad_service.dart';
import 'package:huruf/data/ads/ad_format.dart';
import 'package:huruf/data/ads/ad_pacing.dart';
import 'package:huruf/data/ads/ad_policy.dart';
import 'package:huruf/data/ads/rewarded_ads.dart';
import 'package:huruf/data/analytics/analytics_event.dart';
import 'package:huruf/data/analytics/analytics_service.dart';
import 'package:huruf/data/config/feature_flags.dart';
import 'package:huruf/data/config/remote_config_repository.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/widgets/mock_ad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// سياسة لمجموعة النزاهة وحدها: إعلان المكافأة مسموح والبيني لا، كي تُفحص
/// آليات المنح منفصلة عن الإيقاع.
const _rewardedReEnabled = AdFormatPolicy({AdFormat.rewardedInterstitial});

/// أوسع إعداد عن بعد ممكن من زاوية الإعلانات، محفوظا من إقلاع سابق:
/// مفتاحا الإيقاف مُشغَّلان صراحة، وميزانية جائزية 10، وبيني من المرحلة
/// 1 بعد كل إتمام، ولا مهلة بين إعلانين.
final String _adsWideOpenRemoteConfig = jsonEncode({
  'ads_rewarded_enabled': true,
  'ads_interstitial_enabled': true,
  'rewardedDailyBudget': 10,
  'interstitialFirstEligibleStage': 1,
  'interstitialCadenceByStage': {'1': 1},
  'adGlobalCooldownSeconds': 0,
});

String _today() => RewardedAds.dateKey(DateTime.now());

/// ما تتركه على الجهاز نسخة كانت إعلاناتها تعمل: عدّاد إيقاع تجاوز كل
/// عتبة بكثير، ودفتر جائزي لليوم بميزانية كاملة لم يُمسّ منها شيء (بصيغة
/// الحفظ نفسها: RewardedLedger.encode).
Map<String, Object> _storedStateFromAdsEra() => {
  'completions_since_ad': 99,
  'rewarded_ledger_json': jsonEncode({
    'date': _today(),
    'viewsUsed': 0,
    'granted': ['v2_view_1', 'v2_view_2'],
    'queue': <Object>[],
  }),
};

/// الإعداد المحفوظ يُطبَّق على حقول BalanceConfig الساكنة مباشرة
/// (BalanceOverrides.applyAll)، فتُعاد الحقول الأربعة التي يلمسها بعد كل
/// اختبار — وإلا تسرّبت ميزانية 10 وإيقاع «بعد كل مرحلة» إلى ما بعده.
/// يُلتقط مرة واحدة قبل الاختبار، فلا يهمّ كم إقلاعا يجري داخله.
void _restoreAdBalanceAfterTest() {
  final budget = BalanceConfig.rewardedDailyBudget;
  final firstStage = BalanceConfig.interstitialFirstEligibleStage;
  final cadence = Map<int, int>.from(BalanceConfig.interstitialCadenceByStage);
  final cooldown = BalanceConfig.adGlobalCooldown;
  addTearDown(() {
    BalanceConfig.rewardedDailyBudget = budget;
    BalanceConfig.interstitialFirstEligibleStage = firstStage;
    BalanceConfig.interstitialCadenceByStage = cadence;
    BalanceConfig.adGlobalCooldown = cooldown;
  });
}

/// ناقل أحداث يحفظ ما يُسجَّل في الذاكرة. سبب المنع المسجَّل هو ما يجيب
/// في لوحة التحليلات عن «لماذا لا إعلانات؟»، فيجب أن يسمّي سببه الحقيقي.
class _RecordingAnalytics extends AnalyticsService {
  final List<({String name, Map<String, Object?> props})> events = [];

  @override
  void log(String name, [Map<String, Object?> properties = const {}]) =>
      events.add((name: name, props: Map.of(properties)));

  List<Map<String, Object?>> named(String name) => [
    for (final e in events)
      if (e.name == name) e.props,
  ];
}

/// سياق لا يصلح لشيء: أي لمس له (Navigator أو mounted أو ثيم) يرمي. خدمة
/// الإعلانات خلف البوّابة ترفض قبل أن تلمس الواجهة، فلا يُلمس أبدا — وإن
/// لُمس فقد وصل الطلب إلى المحاكاة التي رسمت «الإعلان» غير القابل للإغلاق
/// في النسخة 1.
class _UntouchableContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'خدمة الإعلانات لمست السياق: ${invocation.memberName}',
  );
}

class _Boot {
  _Boot(this.store, this.config, this.analytics, this.container);

  final ProgressStore store;
  final RemoteConfigResult config;
  final _RecordingAnalytics analytics;
  final ProviderContainer container;
}

Future<SharedPreferences> _seed(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// إقلاع بارد كما في main.dart: الإعداد عن بعد يُطبَّق أولا، ثم نظام
/// التقدّم، ثم الحاوية بمفاتيح الإيقاف التي جاءت منه. [prefs] نفسها في
/// إقلاعين متتاليين = إعادة تشغيل التطبيق على التخزين نفسه.
///
/// [flags] يستبدل ما جاء به الإعداد. [policy] «لا شيء» افتراضا، ولا يُمرَّر
/// غيره إلا في مجموعة النزاهة.
Future<_Boot> _boot(
  SharedPreferences prefs, {
  FeatureFlags? flags,
  AdFormatPolicy policy = AdFormatPolicy.none,
}) async {
  final store = ProgressStore(prefs);
  final config = await RemoteConfigRepository(
    prefs,
  ).loadAndApply(appVersion: '1.0.0');
  final progression = await ProgressionRepository.load(
    prefs: prefs,
    legacy: store,
  );
  final analytics = _RecordingAnalytics();
  final container = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      progressionRepositoryProvider.overrideWithValue(progression),
      analyticsProvider.overrideWithValue(analytics),
      featureFlagsProvider.overrideWithValue(flags ?? config.flags),
      adFormatPolicyProvider.overrideWithValue(policy),
    ],
  );
  addTearDown(container.dispose);
  return _Boot(store, config, analytics, container);
}

/// أسوأ حالة واقعية: جهاز حُدِّث من نسخة كانت إعلاناتها تعمل، ومعه إعداد
/// عن بعد محفوظ يفتح كل شيء.
Future<_Boot> _bootAfterAdsEra() async => _boot(
  await _seed({
    ..._storedStateFromAdsEra(),
    'remote_config_cache_v1': _adsWideOpenRemoteConfig,
  }),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(_restoreAdBalanceAfterTest);

  group('بلا قالب مسموح (none): مفاتيح الإيقاف لا تفتح ما أغلقته السياسة', () {
    test('بالمفاتيح الافتراضية (كلها مُشغَّلة): لا قالب مسموح ولا إتاحة', () async {
      final boot = await _boot(await _seed(const {}));
      final c = boot.container;

      final policy = c.read(adFormatPolicyProvider);
      for (final format in AdFormat.values) {
        expect(policy.allows(format), isFalse, reason: format.name);
      }
      expect(policy.allowsAnyFullScreen, isFalse);

      // المفتاحان مُشغَّلان افتراضيا — فالـ«لا» أدناه من السياسة لا منهما
      expect(c.read(featureFlagsProvider).rewardedAds, isTrue);
      expect(c.read(featureFlagsProvider).interstitialAds, isTrue);
      expect(c.read(rewardedAdsAvailableProvider), isFalse);
      expect(c.read(interstitialAdsAvailableProvider), isFalse);
    });

    test('مفتاحا الإعلانات مُشغَّلان صراحة عن بعد — بكل ترميز يقبله '
        'FeatureFlags — ولا إتاحة', () async {
      final prefs = await _seed(const {});
      for (final on in <Object>[true, 'true', 'TRUE', 1]) {
        final boot = await _boot(
          prefs,
          flags: FeatureFlags.fromConfig({
            'ads_rewarded_enabled': on,
            'ads_interstitial_enabled': on,
          }),
        );
        final c = boot.container;

        expect(c.read(featureFlagsProvider).rewardedAds, isTrue, reason: '$on');
        expect(
          c.read(featureFlagsProvider).interstitialAds,
          isTrue,
          reason: '$on',
        );
        expect(c.read(rewardedAdsAvailableProvider), isFalse, reason: '$on');
        expect(
          c.read(interstitialAdsAvailableProvider),
          isFalse,
          reason: '$on',
        );
      }
    });

    test('خدمة الإعلانات الافتراضية ترفض فورا: لا جاهزية ولا عرض، ولا تلمس '
        'الواجهة', () async {
      final boot = await _boot(await _seed(const {}));
      final ads = boot.container.read(adServiceProvider);

      // ضابط: المحاكاة الملفوفة تقول «جاهز» في الاختبار (ليس بناء إصدار)،
      // فالـ«لا» أدناه من بوّابة السياسة
      expect(MockAdService().isRewardedReady, isTrue);
      expect(MockAdService().isInterstitialReady, isTrue);

      expect(ads.isRewardedReady, isFalse);
      expect(ads.isInterstitialReady, isFalse);
      for (final length in AdLength.values) {
        expect(
          await ads.showRewarded(_UntouchableContext(), length: length),
          isFalse,
          reason: length.name,
        );
      }
      expect(
        await ads.showInterstitial(_UntouchableContext()),
        InterstitialResult.unavailable,
      );
    });
  });

  group('إعداد عن بعد محفوظ يفتح كل شيء + حالة من نسخة كانت إعلاناتها تعمل', () {
    test('الإعداد يُقرأ من النسخة المحفوظة ويُطبَّق فعلا، ومع ذلك لا إتاحة', () async {
      final boot = await _bootAfterAdsEra();

      // Supabase غير مضبوط في الاختبار، فالمصدر هو النسخة المحفوظة
      expect(boot.config.source, RemoteConfigSource.cache);
      expect(boot.config.flags.rewardedAds, isTrue);
      expect(boot.config.flags.interstitialAds, isTrue);
      // أرقامها الإعلانية سارية فعلا: الإعداد لم يُتجاهل، بل لا يملك ما
      // يفتحه
      expect(BalanceConfig.rewardedDailyBudget, 10);
      expect(BalanceConfig.interstitialFirstEligibleStage, 1);
      expect(BalanceConfig.interstitialCadenceForStage(1), 1);
      expect(BalanceConfig.interstitialCadenceForStage(50), 1);
      expect(BalanceConfig.adGlobalCooldown, Duration.zero);

      final c = boot.container;
      expect(c.read(featureFlagsProvider).rewardedAds, isTrue);
      expect(c.read(featureFlagsProvider).interstitialAds, isTrue);
      expect(c.read(rewardedAdsAvailableProvider), isFalse);
      expect(c.read(interstitialAdsAvailableProvider), isFalse);
    });

    test('لا طلب مشاهدة من أي سطح، والسبب المسجَّل هو السياسة لا الميزانية', () async {
      final boot = await _bootAfterAdsEra();
      final c = boot.container;
      final rewarded = c.read(rewardedAdsProvider.notifier);

      // ميزانية اليوم كاملة بالرقم المحفوظ (10) — فالمنع ليس نفادها
      expect(c.read(rewardedAdsProvider).remaining, 10);
      expect(rewarded.hasBudget, isTrue);

      for (final surface in RewardedSurface.values) {
        expect(rewarded.begin(surface), isNull, reason: surface.name);
      }

      expect(c.read(rewardedAdsProvider).viewsUsed, 0);
      final failures = boot.analytics.named(Ev.adFailed);
      expect(
        [for (final f in failures) f['surface']],
        [for (final s in RewardedSurface.values) s.name],
      );
      expect({for (final f in failures) f['reason']}, {'format_disabled'});
      expect(boot.analytics.named(Ev.adRequested), isEmpty);
    });

    test('مضاعفة الجائزة تعيد صفرا بلا استدعاء العرض أصلا، ولا عملة ولا '
        'مشاهدة', () async {
      final boot = await _bootAfterAdsEra();
      final c = boot.container;
      final pointsBefore = c.read(pointsProvider);
      final adsRequested = <AdLength>[];

      for (final surface in RewardedSurface.values) {
        final granted = await c
            .read(rewardedAdsProvider.notifier)
            .doubleReward(
              40,
              surface: surface,
              // واجهة تدّعي أن المشاهدة اكتملت: لو استُدعيت لمنحت
              playAd: (length) async {
                adsRequested.add(length);
                return true;
              },
            );
        expect(granted, 0, reason: surface.name);
      }

      expect(adsRequested, isEmpty, reason: 'لا عرض يُطلب من الواجهة');
      expect(c.read(pointsProvider), pointsBefore);
      expect(c.read(rewardedAdsProvider).viewsUsed, 0);
      expect(
        RewardedLedger.decode(boot.store.rewardedLedgerJson, _today()).viewsUsed,
        0,
        reason: 'ولا في الدفتر المحفوظ',
      );
      expect(boot.store.lastAdShownAt, isNull);
      expect(boot.analytics.named(Ev.adRewardGranted), isEmpty);
      expect(boot.analytics.named(Ev.coinsEarned), isEmpty);
    });

    test('العجلة: لا دورة بإعلان رغم ميزانية كاملة، والدورة المجانية اليومية '
        'باقية', () async {
      final boot = await _bootAfterAdsEra();
      final c = boot.container;

      // الميزانية المشتركة نفسها كاملة (10) — فصفر الدورات من السياسة
      expect(c.read(globalAdBudgetProvider).remaining, 10);
      expect(c.read(wheelProvider).adSpinsRemaining, 0);
      expect(c.read(wheelProvider).freeSpinAvailable, isTrue);

      expect(c.read(globalAdBudgetProvider.notifier).consume(), isFalse);
      final wheel = c.read(wheelProvider.notifier);
      expect(wheel.consumeSpin(viaAd: true), isFalse);
      expect(c.read(rewardedAdsProvider).viewsUsed, 0, reason: 'لا مشاهدة استُهلكت');

      expect(
        wheel.consumeSpin(viaAd: false),
        isTrue,
        reason: 'الدورة المجانية لا تحتاج إعلانا',
      );
      expect(wheel.consumeSpin(viaAd: false), isFalse, reason: 'مرة في اليوم');
      expect(c.read(wheelProvider).adSpinsRemaining, 0);
      expect(c.read(wheelProvider).canSpinNow, isFalse);
    });

    test('البيني: لا إعلان مع عدّاد تجاوز كل عتبة، ولا تصفير للعدّاد، ولا وقت '
        'إعلان يُسجَّل', () async {
      final boot = await _bootAfterAdsEra();
      final c = boot.container;
      final gate = c.read(interstitialGateProvider.notifier);

      // العدّاد المحفوظ من زمن الإعلانات قُرئ كما هو، ويتقدّم كالمعتاد
      expect(c.read(interstitialGateProvider), 99);
      for (var i = 0; i < 12; i++) {
        gate.recordStageCleared();
      }
      expect(c.read(interstitialGateProvider), 111);
      c.read(sessionGameplayProvider.notifier).markGameplayStarted();

      final now = DateTime(2026, 9, 30, 12);

      // ضابط: المدخلات نفسها التي يجمعها المزوّد، والقالب وحده مسموح —
      // القرار «اعرض». فكل قاعدة أخرى تسمح تحت هذا الإعداد، والسياسة
      // وحدها ما يمنع أدناه
      final wouldShow = AdPacing.decideInterstitial(
        InterstitialRequest(
          stageNumber: 50,
          completionsSinceLastInterstitial: c.read(interstitialGateProvider),
          formatAllowed: true,
          adsRemoved: c.read(adsRemovedProvider),
          interstitialsEnabled: c.read(featureFlagsProvider).interstitialAds,
          stageCleared: true,
          rewardSequenceComplete: true,
          protectedMomentPending: c.read(protectedMomentProvider) > 0,
          hadGameplayThisSession: c.read(sessionGameplayProvider),
          now: now,
          lastAdShownAt: boot.store.lastAdShownAt,
          lastPurchaseAt: boot.store.lastPurchaseAt,
        ),
      );
      expect(wouldShow.allowed, isTrue);

      expect(
        gate.requestInterstitial(
          stageNumber: 50,
          stageCleared: true,
          rewardSequenceComplete: true,
          nowOverride: now,
        ),
        AdCue.none,
      );
      // ولا في أي مدى آخر من الجدول
      for (final stage in [1, 13, 41, 121, 500]) {
        expect(
          gate.requestInterstitial(
            stageNumber: stage,
            stageCleared: true,
            rewardSequenceComplete: true,
            nowOverride: now,
          ),
          AdCue.none,
          reason: 'المرحلة $stage',
        );
      }

      // القرار الممنوع لا يصفّر العدّاد ولا يبدأ مهلة
      expect(c.read(interstitialGateProvider), 111);
      expect(boot.store.completionsSinceInterstitial, 111);
      expect(boot.store.lastAdShownAt, isNull);

      final blocked = [
        for (final e in boot.analytics.named(Ev.adFailed))
          if (e['kind'] == 'interstitial') e,
      ];
      expect(blocked, hasLength(6));
      expect({
        for (final e in blocked) e['reason'],
      }, {AdBlockReason.formatDisabled.name});
      expect(boot.analytics.named(Ev.adRequested), isEmpty);
      expect(boot.analytics.named(Ev.adShown), isEmpty);
    });
  });

  group('ما كسبه اللاعب أو دفع ثمنه لا يضيع بالإطفاء', () {
    test('منحة اكتملت في نسخة سابقة ولم تُضَف تُدفع مرة واحدة بالضبط، ولا '
        'تُدفع ثانية بعد إعادة التشغيل', () async {
      final yesterday = RewardedAds.dateKey(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      // دفتر بصيغة الحفظ نفسها (PendingRewardGrant.toJson): مشاهدتان
      // اكتملتا أمس وأُغلق التطبيق قبل تفريغ الطابور
      final prefs = await _seed({
        'rewarded_ledger_json': jsonEncode({
          'date': yesterday,
          'viewsUsed': 2,
          'granted': ['v2_req_a', 'v2_req_b'],
          'queue': [
            {
              'id': 'v2_req_a',
              'amount': 30,
              'surface': 'coinTopUp',
              'at': '${yesterday}T21:14:03.000',
            },
            {
              'id': 'v2_req_b',
              'amount': 40,
              'surface': 'coinTopUp',
              'at': '${yesterday}T21:16:40.000',
            },
          ],
        }),
      });

      final first = await _boot(prefs);
      final c = first.container;
      expect(c.read(rewardedAdsAvailableProvider), isFalse);
      expect(c.read(rewardedAdsProvider).queue, hasLength(2));
      final pointsBefore = c.read(pointsProvider);
      final rewarded = c.read(rewardedAdsProvider.notifier);

      expect(rewarded.flush(), 70);
      expect(c.read(pointsProvider), pointsBefore + 70);
      expect(rewarded.flush(), 0, reason: 'تفريغ ثانٍ لا يدفع شيئا');
      expect(c.read(pointsProvider), pointsBefore + 70);
      expect(c.read(rewardedAdsProvider).queue, isEmpty);

      // إقلاع تالٍ على التخزين نفسه — المصالحة تجري عند كل ظهور للرئيسية
      final second = await _boot(prefs);
      final c2 = second.container;
      expect(c2.read(rewardedAdsProvider).queue, isEmpty);
      expect(c2.read(rewardedAdsProvider.notifier).flush(), 0);
      expect(c2.read(pointsProvider), pointsBefore + 70);
    });

    test('من اشترى إزالة الإعلانات يبقى مشتريا، وحقّه نافذ يوم يعود البيني', () async {
      final boot = await _boot(await _seed(const {'ads_removed': true}));
      final c = boot.container;

      expect(c.read(adsRemovedProvider), isTrue);
      expect(c.read(purchaseStateProvider).adsRemoved, isTrue);

      // الحقّ محفوظ في الحالة التي تغذّي القرار: لو سُمح بالبيني في إصدار
      // لاحق لمنعه الشراء — لا يعود من دفع ليرى إعلانا
      final ifReEnabled = AdPacing.decideInterstitial(
        InterstitialRequest(
          stageNumber: 50,
          completionsSinceLastInterstitial: 99,
          formatAllowed: true,
          adsRemoved: c.read(adsRemovedProvider),
          stageCleared: true,
          rewardSequenceComplete: true,
          hadGameplayThisSession: true,
          now: DateTime(2026, 9, 30, 12),
        ),
      );
      expect(ifReEnabled.allowed, isFalse);
      expect(ifReEnabled.reason, AdBlockReason.adsRemoved);
    });
  });

  group('نزاهة المنح يوم يُعاد تفعيل الجائزي (سياسة متساهلة صريحة)', () {
    test('السياسة سقف: بها يصير الجائزي متاحا، ومفتاح الإيقاف يضيّقه على كل '
        'السطوح', () async {
      final open = await _boot(
        await _seed(const {}),
        policy: _rewardedReEnabled,
      );
      expect(
        open.container.read(rewardedAdsAvailableProvider),
        isTrue,
        reason: 'الـ«لا» في المجموعات السابقة من السياسة وحدها',
      );
      expect(
        open.container.read(interstitialAdsAvailableProvider),
        isFalse,
        reason: 'السياسة تسمح بالجائزي وحده',
      );
      expect(
        open.container.read(wheelProvider).adSpinsRemaining,
        WheelState.maxAdSpinsPerDay,
      );

      // المفتاح مطفأ عن بعد: كل السطوح مغلقة — المتجر والعجلة وورقة «ينقصك
      // القليل» كانت تتجاوزه بصمت حين كانت الإتاحة معاملا اختياريا
      final killed = await _boot(
        await _seed(const {}),
        policy: _rewardedReEnabled,
        flags: FeatureFlags.fromConfig(const {'ads_rewarded_enabled': false}),
      );
      final c = killed.container;
      expect(c.read(rewardedAdsAvailableProvider), isFalse);
      for (final surface in RewardedSurface.values) {
        expect(
          c.read(rewardedAdsProvider.notifier).begin(surface),
          isNull,
          reason: surface.name,
        );
      }
      expect(c.read(globalAdBudgetProvider.notifier).consume(), isFalse);
      expect(c.read(wheelProvider).adSpinsRemaining, 0);
      expect(c.read(rewardedAdsProvider).viewsUsed, 0);
    });

    test('مشاهدة لم تكتمل (playAd يعيد false): صفر، بلا استهلاك ميزانية ولا '
        'مهلة', () async {
      final boot = await _boot(
        await _seed(const {}),
        policy: _rewardedReEnabled,
      );
      final c = boot.container;
      final pointsBefore = c.read(pointsProvider);
      final adsRequested = <AdLength>[];

      final granted = await c
          .read(rewardedAdsProvider.notifier)
          .doubleReward(
            40,
            surface: RewardedSurface.levelReward,
            playAd: (length) async {
              adsRequested.add(length);
              return false;
            },
          );

      // المسار بلغ العرض فعلا (قصير لجائزة المرحلة) — فالصفر من «لم
      // تكتمل» لا من «غير متاح»
      expect(adsRequested, [AdLength.short]);
      expect(granted, 0);
      expect(c.read(pointsProvider), pointsBefore);
      expect(c.read(rewardedAdsProvider).viewsUsed, 0);
      expect(
        c.read(globalAdBudgetProvider).remaining,
        BalanceConfig.rewardedDailyBudget,
      );
      expect(boot.store.lastAdShownAt, isNull, reason: 'لا مهلة لإعلان لم يُعرض');
    });

    test('عرض رمى استثناء: لا منح ولا استهلاك', () async {
      final boot = await _boot(
        await _seed(const {}),
        policy: _rewardedReEnabled,
      );
      final c = boot.container;
      final pointsBefore = c.read(pointsProvider);

      await expectLater(
        c
            .read(rewardedAdsProvider.notifier)
            .doubleReward(
              100,
              surface: RewardedSurface.chapterChest,
              playAd: (_) async => throw StateError('SDK'),
            ),
        throwsStateError,
      );
      expect(c.read(pointsProvider), pointsBefore);
      expect(c.read(rewardedAdsProvider).viewsUsed, 0);
      expect(boot.store.lastAdShownAt, isNull);
    });

    test('نداء اكتمال مكرّر للطلب نفسه يمنح مرة واحدة ويستهلك مشاهدة واحدة، '
        'حتى بعد إعادة التشغيل', () async {
      final prefs = await _seed(const {});
      final first = await _boot(prefs, policy: _rewardedReEnabled);
      final c = first.container;
      final pointsBefore = c.read(pointsProvider);
      final rewarded = c.read(rewardedAdsProvider.notifier);

      final request = rewarded.begin(RewardedSurface.coinTopUp)!;
      expect(rewarded.complete(request), request.quotedAmount);
      expect(rewarded.complete(request), 0, reason: 'نداء SDK مكرّر');
      expect(c.read(pointsProvider), pointsBefore + request.quotedAmount);
      expect(c.read(rewardedAdsProvider).viewsUsed, 1);

      // النداءة المكرّرة تصل بعد إعادة تشغيل التطبيق: السجلّ محفوظ
      final second = await _boot(prefs, policy: _rewardedReEnabled);
      final c2 = second.container;
      expect(c2.read(rewardedAdsProvider.notifier).complete(request), 0);
      expect(c2.read(pointsProvider), pointsBefore + request.quotedAmount);
      expect(c2.read(rewardedAdsProvider).viewsUsed, 1);
    });

    test('طلب بدأ ولم تكتمل مشاهدته لا يمنح شيئا ولا يحرق ميزانية', () async {
      final prefs = await _seed(const {});
      final boot = await _boot(prefs, policy: _rewardedReEnabled);
      final c = boot.container;
      final pointsBefore = c.read(pointsProvider);
      final rewarded = c.read(rewardedAdsProvider.notifier);

      final abandoned = [
        rewarded.begin(RewardedSurface.coinTopUp),
        rewarded.begin(RewardedSurface.wheel),
      ];
      expect(abandoned, everyElement(isNotNull));

      // لا complete: لم يصل نداء المكافأة
      expect(rewarded.flush(), 0);
      expect(c.read(pointsProvider), pointsBefore);
      expect(c.read(rewardedAdsProvider).viewsUsed, 0);
      expect(c.read(rewardedAdsProvider).queue, isEmpty);
      expect(
        rewarded.nextReward,
        BalanceConfig.rewardedRewardForView(1),
        reason: 'السلّم لم يتقدّم',
      );

      // ولا شيء مستحقّ ينتظر الإقلاع التالي
      final after = await _boot(prefs, policy: _rewardedReEnabled);
      expect(after.container.read(rewardedAdsProvider.notifier).flush(), 0);
      expect(after.container.read(pointsProvider), pointsBefore);
    });

    test('سبب المنع المسجَّل يسمّي سببه الحقيقي: السياسة قبل المفتاح، '
        'والمفتاح قبل الميزانية', () async {
      const switchedOff = {'ads_rewarded_enabled': false};

      // بلا قالب ومفتاح مطفأ: السبب هو السياسة
      final policyOff = await _boot(
        await _seed(const {}),
        flags: FeatureFlags.fromConfig(switchedOff),
      );
      // سياسة متساهلة ومفتاح مطفأ: السبب هو المفتاح
      final killSwitch = await _boot(
        await _seed(const {}),
        policy: _rewardedReEnabled,
        flags: FeatureFlags.fromConfig(switchedOff),
      );
      // سياسة متساهلة ومفتاح مُشغَّل وميزانية نافدة: السبب هو الميزانية
      final exhausted = await _boot(
        await _seed(const {}),
        policy: _rewardedReEnabled,
      );
      final budget = exhausted.container.read(globalAdBudgetProvider.notifier);
      for (var i = 0; i < BalanceConfig.rewardedDailyBudget; i++) {
        expect(budget.consume(), isTrue);
      }

      Object? blockReason(_Boot boot) {
        expect(
          boot.container
              .read(rewardedAdsProvider.notifier)
              .begin(RewardedSurface.coinTopUp),
          isNull,
        );
        return boot.analytics.named(Ev.adFailed).last['reason'];
      }

      expect(blockReason(policyOff), 'format_disabled');
      expect(blockReason(killSwitch), 'kill_switch');
      expect(blockReason(exhausted), 'budget_exhausted');
    });
  });
}
