import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'data/ad_service.dart';
import 'data/ads/ad_policy.dart';
import 'data/ads/admob_ad_service.dart';
import 'data/ads/admob_ids.dart';
import 'data/ads/policy_gated_ad_service.dart';
import 'data/analytics/analytics_service.dart';
import 'data/analytics/posthog_sink.dart';
import 'data/config/remote_config_repository.dart';
import 'data/config/feature_flags.dart';
import 'data/deep_link_service.dart';
import 'data/games_services_sync.dart';
import 'data/iap_service.dart';
import 'data/progress_store.dart';
import 'data/progression_repository.dart';
import 'data/store/revenuecat_iap_service.dart';
import 'data/store/revenuecat_keys.dart';
import 'data/supabase_config.dart';
import 'presentation/home_widget_launch.dart';
import 'presentation/providers.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/widgets/mock_ad_service.dart';

Future<void> main() async {
  // منطقة محروسة حول التطبيق كله: عميل Supabase يعيد المحاولة في الخلفية
  // (realtime وتجديد الجلسة)، وحين تنقطع الشبكة ترمي تلك المحاولات أخطاء
  // غير متزامنة لا يملكها أي try/catch في شيفرتنا. بلا هذه المنطقة تصل
  // إلى معالج أخطاء الإطار وتظهر للاعب رغم أن اللعبة تعمل تماما بلا نت.
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // الواجهة مصممة للوضع الرأسي فقط (عجلة الحروف، الشبكة، الخريطة)
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      // الميزات السحابية (الأصدقاء، الترتيب، مزامنة التقدّم) تُعطَّل
      // بهدوء إن لم تُمرَّر مفاتيح Supabase بعد
      await SupabaseConfig.initIfConfigured();
      // تسجيل دخول صامت إلى Google Play Games كي تُحفظ الإنجازات في حساب
      // اللاعب. يفشل بهدوء إن لم يكن متاحا، واللعبة تكمل بإنجازات محلية.
      // بمهلة قصوى: خدمات Play متعثّرة كانت تُبقي شاشة البداية نحو دقيقة
      // (رُصد على محاكي بعد إقلاع بارد). بعد المهلة يكمل الدخول في الخلفية
      // ويرفع علمه حين ينجح، فلا تضيع مزامنة الإنجازات.
      await GamesServicesSync.signInSilently().timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
      final store = await ProgressStore.create();

      // الإعداد عن بعد: يُطبَّق قبل بناء الشجرة كي تقرأ الشاشات أرقاما
      // مستقرّة طوال الجلسة (تغيّر سعر تلميح تحت يد اللاعب عطل لا ميزة).
      // وقبل نظام التقدّم تحديدا: شجرة العوالم/الفصول تُولَّد مرة واحدة
      // من BalanceConfig، فأي مفتاح بنيوي يصل بعدها يفرّق بين الشجرة
      // المجمَّدة والأرقام الحيّة.
      //
      // مهلته ثانيتان *داخله*، ولا يرمي إطلاقا: تعذّر الوصول للخادم يسقط
      // إلى آخر نسخة محفوظة ثم إلى الأرقام المُصرَّفة، فيبقى زمن الإقلاع
      // بلا خادم مساويا لزمنه المعتاد + المهلة القصوى لا أكثر.
      final config = await RemoteConfigRepository(
        store.prefs,
      ).loadAndApply(appVersion: kAppVersion);
      debugPrint(
        'الإعداد عن بعد: ${config.source.name}، '
        '${config.appliedKeys} مفتاحا طُبِّق',
      );

      // نظام التقدّم الجديد (عوالم/فصول/جرّة) — يهاجر من بيانات
      // ProgressStore القديمة تلقائيا مرة واحدة إن لم يكن قد هاجر بعد
      final progressionRepo = await ProgressionRepository.load(
        prefs: store.prefs,
        legacy: store,
      );
      // روابط الدعوة: نلتقط رمزا وارد ونحفظه كي يُملأ حقل الاستبدال
      // تلقائيا. بلا await — لا يجوز أن يؤخّر رابط (أو غيابه) الإقلاع
      unawaited(DeepLinkService(store).start());

      // التحليلات: PostHog وحده (على أندرويد فقط). تهيئته في الخلفية بلا
      // await، وما يُسجَّل قبل انتهائها ينتظر دوره فلا يضيع
      final analytics = AnalyticsService(sink: PostHogSink.create()?.track);

      // الإعلانات: AdMob على الهاتف، ومحاكاة على سطح المكتب/الويب — وكلاهما
      // خلف بوّابة سياسة القوالب (data/ads/ad_policy.dart). السياسة الفعلية
      // تُحسب هنا مرة واحدة وتصل إلى الخدمة والمزوّدات معا: نسخة إصدار بلا
      // معرّفات AdMob حقيقية، أو على منصّة بلا AdMob، لا قالب فيها إطلاقا —
      // لا تهيئة ولا موافقة ولا طلب، ولا زرّ «شاهد إعلانا» يقود إلى لا شيء.
      // التهيئة تجري في الخلفية بلا await — أول إعلان بيني لا يُطلب قبل
      // المرحلة 13 على أي حال، فلا داعي لأن ينتظرها الإقلاع.
      final adPolicy = AdFormatPolicy.effective(
        adNetworkReady: AdMobAdService.isSupported
            ? AdMobIds.readyForThisBuild
            : !kReleaseMode,
      );
      final AdService adService = PolicyGatedAdService(
        AdMobAdService.isSupported
            ? AdMobAdService(policy: adPolicy)
            : MockAdService(),
        policy: adPolicy,
      );
      unawaited(adService.init());

      // الدفع: RevenueCat على الهاتف، ومحاكاة لا تبيع شيئا في الإصدار على
      // غيره (أو في إصدار بلا مفتاح RevenueCat حقيقي). يبدأ الآن بلا await:
      // شراء اكتمل والتطبيق مغلق (دفع نقدي اعتُمد، إغلاق وسط الدفع) يُسلَّم
      // في هذا الإقلاع، لا حين يفتح اللاعب المتجر.
      final rcKey = RevenueCatKeys.forThisBuild;
      final IapService iapService =
          RevenueCatIapService.isSupported && rcKey != null
          ? RevenueCatIapService(
              gateway: PluginRevenueCatGateway(apiKey: rcKey),
              prefs: store.prefs,
            )
          : MockIapService();
      unawaited(iapService.init());

      runApp(
        HurufRoot(
          store: store,
          progressionRepo: progressionRepo,
          analytics: analytics,
          flags: config.flags,
          adPolicy: adPolicy,
          adService: adService,
          iapService: iapService,
        ),
      );
    },
    (error, stack) {
      debugPrint('خطأ غير ملتقط (تُتجاهل بأمان): $error');
    },
  );
}

/// نسخة التطبيق، يُرشَّح بها الإعداد عن بعد.
///
/// تُمرَّر عند البناء (`--dart-define=APP_VERSION=1.0.0+1`) وتطابق
/// pubspec. القيمة الافتراضية موجودة كي لا يفشل تشغيل تطوير عادي.
const kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0',
);

/// جذر التطبيق. وجوده كطبقة فوق [ProviderScope] له سبب واحد: «البدء من
/// جديد» يحتاج شجرة نظيفة — كل مزوّد يقرأ حالته الأولية من التخزين مرة
/// واحدة في build()، فمسح التخزين وحده لا يُعيد شيئا إلى الصفر على
/// الشاشة. تبديل مفتاح ProviderScope يهدم الحاويات كلها ويعيد بناءها،
/// فتقرأ المزوّدات التخزين الممسوح من جديد بلا إعادة تشغيل العملية.
class HurufRoot extends StatefulWidget {
  final ProgressStore store;
  final ProgressionRepository progressionRepo;
  final AnalyticsService analytics;
  final FeatureFlags flags;

  /// السياسة الفعلية نفسها التي تحرس [adService] — راجع main()
  final AdFormatPolicy adPolicy;
  final AdService adService;
  final IapService iapService;

  const HurufRoot({
    super.key,
    required this.store,
    required this.progressionRepo,
    required this.analytics,
    required this.flags,
    required this.adPolicy,
    required this.adService,
    required this.iapService,
  });

  /// يعيد بناء شجرة التطبيق كاملة. تُستدعى بعد مسح التخزين مباشرة.
  static void restart(BuildContext context) =>
      context.findAncestorStateOfType<_HurufRootState>()?._restart();

  @override
  State<HurufRoot> createState() => _HurufRootState();
}

class _HurufRootState extends State<HurufRoot> {
  int _generation = 0;

  void _restart() => setState(() => _generation++);

  @override
  Widget build(BuildContext context) => ProviderScope(
    key: ValueKey(_generation),
    overrides: [
      progressStoreProvider.overrideWithValue(widget.store),
      progressionRepositoryProvider.overrideWithValue(widget.progressionRepo),
      analyticsProvider.overrideWithValue(widget.analytics),
      featureFlagsProvider.overrideWithValue(widget.flags),
      adFormatPolicyProvider.overrideWithValue(widget.adPolicy),
      adServiceProvider.overrideWithValue(widget.adService),
      iapServiceProvider.overrideWithValue(widget.iapService),
    ],
    child: const HurufApp(),
  );
}

class HurufApp extends ConsumerWidget {
  const HurufApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    // يبقي المتجر حيّا من الإقلاع: تسليم المشتريات موصول به، ولا يجوز أن
    // ينتظر شراءٌ مدفوع أن يفتح اللاعب شاشة المتجر. listen لا watch — تغيّر
    // الأسعار لا يعيد بناء التطبيق كله
    ref.listen(storeProvider, (_, _) {});
    return MaterialApp(
      title: lang.t('حروف', 'Huruf'),
      debugShowCheckedModeBanner: false,
      // نقرة ودجة الشاشة الرئيسية تصل خارج شجرة الودجات (بدء بارد
      // خصوصا)، فلا سياق بيدها تنطلق منه — راجع HomeWidgetLaunch
      navigatorKey: HomeWidgetLaunch.navigatorKey,
      theme: HurufTheme.build(),
      // اتجاه القوائم يتبع اللغة المختارة؛ شاشة اللعب تفرض RTL محليا دوما
      builder: (context, child) =>
          Directionality(textDirection: lang.textDirection, child: child!),
      home: const SplashScreen(),
    );
  }
}
