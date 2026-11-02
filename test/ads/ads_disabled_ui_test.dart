// اللعبة سليمة والإعلانات مطفأة.
//
// رفضت Google Play النسخة 1 بسبب «إعلانات لا يمكن إغلاقها بعد 5 ثوان»،
// وكانت تلك محاكاة الإعلان نفسها (MockAdService + AdVideoOverlay). النسخة 3
// أطفأت كل القوالب، وما زال هذا المسار حيّا: نسخة إصدار بلا معرّفات AdMob
// حقيقية تعمل بـAdFormatPolicy.none (main.dart). هذا الملف يثبت من الواجهة
// نفسها أن اللعبة تامّة فيه: لا مدخل لإعلان في أي سطح، ولا مسار لعب ينتظر
// إعلانا، وكل ما كان يمرّ بإعلان ما زال يعمل بدونه.
//
// الخدمة المحقونة هنا مسجِّلة **بلا بوّابة السياسة**: تدّعي أن كل إعلان
// جاهز وتعيد «شوهد» دوما. فأي مسار في الواجهة ما زال يسأل طبقة الإعلان
// مباشرة — ولو سؤال جاهزية — يظهر في سجلّها ويُسقط الاختبار. بوّابة
// PolicyGatedAdService خط الدفاع الثاني؛ هذا الملف يفحص الأول.
//
// مجموعة «ضبط» في آخر الملف تعيد السيناريوهات نفسها بسياسة تسمح بالقالب،
// فتثبت أن غياب الأزرار والنداءات أعلاه ليس عمى في الأداة نفسها: الخدمة
// المسجِّلة موصولة فعلا، والإيقاع مهيّأ فعلا لعرض بيني.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// النوع Override يُصدَّر من misc وليس من نقطة الدخول الأساسية في Riverpod 3
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/app_language.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/ad_service.dart';
import 'package:huruf/data/ads/ad_format.dart';
import 'package:huruf/data/ads/ad_pacing.dart';
import 'package:huruf/data/ads/ad_policy.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/models.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/data/store/near_miss.dart';
import 'package:huruf/data/store/store_catalog.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/game_screen.dart';
import 'package:huruf/presentation/screens/home_screen.dart';
import 'package:huruf/presentation/screens/shop_screen.dart';
import 'package:huruf/presentation/screens/wheel_screen.dart';
import 'package:huruf/presentation/widgets/ad_video_overlay.dart';
import 'package:huruf/presentation/widgets/double_reward.dart';
import 'package:huruf/presentation/widgets/letter_wheel.dart';
import 'package:huruf/presentation/widgets/level_complete_overlay.dart';
import 'package:huruf/presentation/widgets/near_miss_sheet.dart';
import 'package:huruf/presentation/widgets/pressable.dart';
import 'package:huruf/presentation/widgets/word_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────── الأدوات ───────────────────────

/// خدمة إعلانات تسجّل كل نداء — حتى سؤال الجاهزية — وتدّعي الجاهزية
/// دوما. لا بوّابة سياسة حولها عمدا: ما يصلها وصل من الواجهة مباشرة.
class _RecordingAdService implements AdService {
  final calls = <String>[];

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
  }) async {
    calls.add('showInterstitial');
    return InterstitialResult.dismissed;
  }

  @override
  Future<bool> showRewarded(
    BuildContext context, {
    required AdLength length,
  }) async {
    calls.add('showRewarded(${length.name})');
    return true;
  }
}

/// كل مسار دخل مكدّس الملاح (دفعا أو استبدالا) وكل رجوع، منذ آخر [reset].
/// إعلان محاكى يُدفع مسارا (PageRouteBuilder) فلا يمرّ من هنا بلا أثر.
class _RouteLog extends NavigatorObserver {
  final entered = <Route<dynamic>>[];
  int pops = 0;

  void reset() {
    entered.clear();
    pops = 0;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      entered.add(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) entered.add(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => pops++;
}

/// يرى انتقالات دورة حياة التطبيق كما يراها أي مراقب في اللعبة — كي لا
/// يمرّ اختبار «العودة من الخلفية» لمجرد أن المحاكاة لم تصل أصلا
class _LifecycleProbe with WidgetsBindingObserver {
  final seen = <AppLifecycleState>[];

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => seen.add(state);
}

/// شاشة قاعدة بزرّ واحد يفتح السطح المختبَر: تعطيه [WidgetRef] وسياقا
/// تحت الملاح، ومسارا تحته يرجع إليه زرّ الرجوع
class _Launcher extends ConsumerWidget {
  final void Function(BuildContext context, WidgetRef ref) onOpen;

  const _Launcher({required this.onOpen});

  static const label = 'open-surface';

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => onOpen(context, ref),
        child: const Text(label),
      ),
    ),
  );
}

class _Rig {
  final ProviderContainer container;
  final ProgressStore store;
  final _RecordingAdService ads;
  final _RouteLog routes;

  const _Rig(this.container, this.store, this.ads, this.routes);
}

/// هاتف 360×800 منطقي
const _phone = Size(1080, 2400);

/// إطار أطول من قائمة المتجر كلها: ListView يبني ما في الإطار وحده، فغياب
/// قسم في آخرها لا يُثبت شيئا ما لم يكن آخرها مبنيا فعلا
const _tallPhone = Size(1080, 7200);

/// يبني التطبيق حول [home] بتخزين حقيقي، والخدمة المسجِّلة مكان طبقة
/// الإعلانات. [policy] «لا شيء» افتراضا، ولا يُمرَّر غيره إلا في مجموعة الضبط.
Future<_Rig> _pumpRig(
  WidgetTester tester, {
  required Widget home,
  AppLanguage lang = AppLanguage.ar,
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
  AdFormatPolicy policy = AdFormatPolicy.none,
  Size physicalSize = _phone,
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'player_name_asked': true,
    if (lang == AppLanguage.en) 'ui_language': 'en',
    ...prefs,
  });
  final sharedPrefs = await SharedPreferences.getInstance();
  final store = ProgressStore(sharedPrefs);
  final progression = await ProgressionRepository.load(
    prefs: sharedPrefs,
    legacy: store,
  );
  final ads = _RecordingAdService();
  final routes = _RouteLog();
  final container = ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      progressionRepositoryProvider.overrideWithValue(progression),
      adServiceProvider.overrideWithValue(ads),
      adFormatPolicyProvider.overrideWithValue(policy),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);

  // ما تقرؤه الواجهة من طبقة الإعلانات هو المسجِّل نفسه، بلا غلاف
  expect(container.read(adServiceProvider), same(ads));
  expect(container.read(languageProvider), lang);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: HurufTheme.build(),
        navigatorObservers: [routes],
        builder: (context, child) =>
            Directionality(textDirection: lang.textDirection, child: child!),
        home: home,
      ),
    ),
  );
  return _Rig(container, store, ads, routes);
}

/// يمرّر انتقال مسار كاملا (دفع أو استبدال أو رجوع)
Future<void> _settleRoute(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// يصرّف كل مؤقّت معلَّق: فقاعة المرشد (3.2 ثانية) وبطاقات الإنجاز
/// (3.8 ثانية لكلٍّ منها بالتتابع). بلا هذا يفشل الاختبار بعد نجاح كل
/// تحقّقاته بـ«A Timer is still pending».
Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// ما يرسله المحرّك فعلا عند الخروج إلى الخلفية والعودة. الإطار نفسه
/// يولّد الحالات الوسيطة (inactive ثم hidden) بين الطرفين.
Future<void> _sendLifecycle(WidgetTester tester, AppLifecycleState state) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
      (_) {},
    );

/// زرّ الرجوع في أندرويد كما يصل من المحرّك
Future<void> _pressSystemBack(WidgetTester tester) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      SystemChannels.navigation.codec.encodeMethodCall(
        const MethodCall('popRoute'),
      ),
      (_) {},
    );

/// كل نصّ مرسوم تحت [root]
List<String> _textsUnder(WidgetTester tester, Finder root) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(of: root, matching: find.byType(Text)),
  ))
    text.data ?? text.textSpan?.toPlainText() ?? '',
];

final _arabicLetters = RegExp(r'[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]');

final _englishAdWord = RegExp(r'\bads?\b', caseSensitive: false);

/// يذكر الإعلانات بأيٍّ من اللغتين (إعلان/إعلانا/بالإعلانات، ad/ads)
bool _mentionsAds(String text) =>
    text.contains('إعلان') || _englishAdWord.hasMatch(text);

/// لا وعد بإعلان في أي نصّ تحت [root]، والإنجليزية بلا حرف عربي واحد
void _expectNoAdWordingAndCleanLanguage(
  WidgetTester tester,
  Finder root,
  AppLanguage lang,
) {
  final texts = _textsUnder(tester, root);
  expect(texts, isNotEmpty, reason: 'السطح لم يُرسم أصلا');
  for (final text in texts) {
    expect(_mentionsAds(text), isFalse, reason: '«$text» يذكر الإعلانات');
    if (lang == AppLanguage.en) {
      expect(
        _arabicLetters.hasMatch(text),
        isFalse,
        reason: 'نص إنجليزي فيه حرف عربي: «$text»',
      );
    }
  }
}

String _todayKey() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ─────────────────────── المراحل ───────────────────────

/// مرحلة تُحلّ بسحبتين. المعرّف 20 عمدا: بعد أول مرحلة يجوز فيها البيني
/// (13)، وليست آخر فصلها (13-24) فزرّها «المرحلة التالية» لا «أتممت
/// الفصل». الحروف مختلفة كلها كي يكون لكلٍّ منها موضع واحد على العجلة.
const _stage20 = GameLevel(
  id: 20,
  letters: ['م', 'ل', 'ح'],
  words: [
    WordEntry(word: 'ملح', definition: 'ما يطيب به الطعام'),
    WordEntry(word: 'حلم', definition: 'ما يُرى في النوم'),
  ],
  bonusWords: [],
  difficulty: 1,
);

const _stage21 = GameLevel(
  id: 21,
  letters: ['ك', 'ت', 'ب'],
  words: [WordEntry(word: 'كتب', definition: 'خطّ الحروف')],
  bonusWords: [],
  difficulty: 1,
);

/// 22 مرحلة لا اثنتان: شاشة اللعب تعدّ المرحلة «الأخيرة» حين يبلغ رقمها
/// طول القائمة، فتعرض «خريطة المراحل» بدل «المرحلة التالية»
final _levels = <GameLevel>[
  for (var id = 1; id <= 22; id++)
    switch (id) {
      20 => _stage20,
      21 => _stage21,
      _ => GameLevel(
        id: id,
        letters: _stage21.letters,
        words: _stage21.words,
        bonusWords: const [],
        difficulty: 1,
      ),
    },
];

/// كل شرط للبيني متحقّق عند مغادرة المرحلة 20 إلا القالب: جلسة لعب
/// بدأت، ومرحلة بعد 13، وعدّاد إيقاع تجاوز الدورة بكثير
const _pacingArmedPrefs = <String, Object>{'completions_since_ad': 99};

/// يرسم [word] على عجلة الحروف بسحبة إصبع واحدة كما يفعل اللاعب
Future<void> _swipeWord(WidgetTester tester, String word) async {
  final wheel = find.byType(LetterWheel);
  Offset letterAt(String letter) =>
      tester.getCenter(find.descendant(of: wheel, matching: find.text(letter)));

  final letters = word.split('');
  final first = letterAt(letters.first);
  final gesture = await tester.startGesture(first);
  // خطوة نحو مركز العجلة الفارغ ثم عودة: السحب يُقبَل بعد تجاوز عتبة
  // الحركة، فقد يبدأ خارج الحرف الأول — العودة إليه تضمن أنه أول المختار
  await gesture.moveTo(Offset.lerp(first, tester.getCenter(wheel), 0.5)!);
  await gesture.moveTo(first);
  for (final letter in letters.skip(1)) {
    await gesture.moveTo(letterAt(letter));
  }
  await gesture.up();
  await tester.pump();
}

/// يحلّ المرحلة 20 بالسحب على العجلة، ثم ينتظر شاشة الإتمام (تظهر بعد
/// 1.1 ثانية من آخر كلمة) حتى تستقرّ بطاقتها
Future<void> _completeStage20(WidgetTester tester) async {
  for (final entry in _stage20.words) {
    await _swipeWord(tester, entry.word);
    expect(
      tester.widget<WordGrid>(find.byType(WordGrid)).solvedWords,
      contains(entry.word),
      reason: 'السحب على «${entry.word}» يجب أن يحلّها كما يحلّها اللاعب',
    );
  }
  expect(
    find.byType(LevelCompleteOverlay),
    findsNothing,
    reason: 'شاشة الإتمام تنتظر لحظة الاحتفال ولا تظهر فورا',
  );
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.pump(const Duration(milliseconds: 800));
  expect(find.byType(LevelCompleteOverlay), findsOneWidget);
}

Future<_Rig> _pumpStage20(
  WidgetTester tester, {
  AppLanguage lang = AppLanguage.ar,
  AdFormatPolicy policy = AdFormatPolicy.none,
}) async {
  final rig = await _pumpRig(
    tester,
    lang: lang,
    prefs: _pacingArmedPrefs,
    overrides: [levelsProvider.overrideWith((ref) => _levels)],
    policy: policy,
    home: GameScreen(level: _stage20, allLevels: _levels),
  );
  await tester.pump(const Duration(seconds: 4)); // فقاعة المرشد الأولى
  return rig;
}

/// قرار الإيقاع لو طُلب بيني الآن، من حالة الحاوية الحيّة نفسها
InterstitialDecision _pacingDecisionNow(
  _Rig rig, {
  required bool formatAllowed,
}) {
  final c = rig.container;
  return AdPacing.decideInterstitial(
    InterstitialRequest(
      stageNumber: _stage20.id,
      completionsSinceLastInterstitial: c.read(interstitialGateProvider),
      formatAllowed: formatAllowed,
      adsRemoved: c.read(adsRemovedProvider),
      interstitialsEnabled: c.read(featureFlagsProvider).interstitialAds,
      stageCleared: true,
      rewardSequenceComplete: true,
      protectedMomentPending: c.read(protectedMomentProvider) > 0,
      hadGameplayThisSession: c.read(sessionGameplayProvider),
      now: DateTime.now(),
      lastAdShownAt: rig.store.lastAdShownAt,
      lastPurchaseAt: rig.store.lastPurchaseAt,
    ),
  );
}

// ─────────────────────── السيناريوهات ───────────────────────

void main() {
  setUpAll(() => AudioService.disabled = true);

  group('إتمام مرحلة والانتقال إلى التالية', () {
    for (final lang in AppLanguage.values) {
      testWidgets(
        'تُحلّ المرحلة 20 بالسحب، ولا زرّ مضاعفة، و«التالي» يفتح 21 فورا '
        'بلا أي نداء لطبقة الإعلان (${lang.name})',
        (tester) async {
          final rig = await _pumpStage20(tester, lang: lang);
          expect(
            rig.container.read(sessionGameplayProvider),
            isTrue,
            reason: 'شاشة اللعب تعلن بدء اللعب في الجلسة',
          );
          rig.routes.reset();

          await _completeStage20(tester);

          // الزرّ غائب بسبب السياسة وحدها: هناك ما يُضاعَف، وميزانية
          // اليوم لم تُمسّ
          final overlay = tester.widget<LevelCompleteOverlay>(
            find.byType(LevelCompleteOverlay),
          );
          expect(overlay.reward, greaterThan(0));
          expect(rig.container.read(rewardedAdsProvider).hasRemaining, isTrue);
          expect(find.text(lang.t('أحسنت!', 'Well done!')), findsOneWidget);
          expect(
            find.text(lang.t('ضاعف جائزتك ×2', 'Double it ×2')),
            findsNothing,
          );
          expect(
            find.descendant(
              of: find.byType(DoubleRewardButton),
              matching: find.byType(Pressable),
            ),
            findsNothing,
            reason: 'لا شيء قابل للنقر مكان زرّ المضاعفة',
          );

          // الإيقاع مهيّأ لبيني: السياسة وحدها هي ما يمنعه هنا
          expect(
            _pacingDecisionNow(rig, formatAllowed: true).allowed,
            isTrue,
            reason: 'لو سُمح بالقالب لعُرض إعلان بيني عند هذه المغادرة',
          );
          expect(
            _pacingDecisionNow(rig, formatAllowed: false).reason,
            AdBlockReason.formatDisabled,
          );
          expect(rig.container.read(interstitialAdsAvailableProvider), isFalse);

          await tester.tap(find.text(lang.t('المرحلة التالية', 'Next Level')));
          await _settleRoute(tester);

          expect(find.byType(LevelCompleteOverlay), findsNothing);
          expect(find.byType(GameScreen), findsOneWidget);
          expect(
            tester.widget<GameScreen>(find.byType(GameScreen)).level.id,
            _stage21.id,
          );
          expect(find.text('المرحلة 21'), findsOneWidget);
          expect(find.text('المرحلة 20'), findsNothing);

          expect(
            rig.ads.calls,
            isEmpty,
            reason: 'لا تحميل مسبق ولا سؤال جاهزية ولا عرض — لا شيء',
          );
          expect(find.byType(AdVideoOverlay), findsNothing);
          expect(
            rig.routes.entered,
            hasLength(1),
            reason: 'المسار الوحيد الجديد هو المرحلة التالية نفسها',
          );
          expect(rig.routes.entered.single, isA<MaterialPageRoute<dynamic>>());
          // لا إعلان سُجّل على أنه عُرض، ولا إيقاع استُهلك
          expect(rig.store.lastAdShownAt, isNull);
          expect(rig.container.read(interstitialGateProvider), 100);

          await _drain(tester);
        },
      );
    }
  });

  group('المتجر', () {
    for (final lang in AppLanguage.values) {
      testWidgets(
        'لا قسم «عملات مجانية» ولا بطاقة «شاهد إعلانا»، وإزالة الإعلانات '
        'وحزم العملات باقية (${lang.name})',
        (tester) async {
          final rig = await _pumpRig(
            tester,
            lang: lang,
            physicalSize: _tallPhone,
            home: const ShopScreen(),
          );
          await tester.pump(const Duration(milliseconds: 600));
          rig.routes.reset();

          // القائمة كلها داخل الإطار: كل عنصر فيها مبني فعلا
          final list = tester.state<ScrollableState>(
            find.descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            ),
          );
          expect(list.position.maxScrollExtent, 0);

          expect(
            find.text(
              lang.t('عملات مقابل مشاهدة إعلان', 'Coins for watching ads'),
            ),
            findsNothing,
          );
          expect(find.text(lang.t('شاهد إعلانا', 'Watch an Ad')), findsNothing);
          expect(find.text(lang.t('مشاهدة', 'Watch')), findsNothing);
          expect(find.byIcon(Icons.smart_display_rounded), findsNothing);

          // حزم العملات كلها، بترتيبها
          expect(
            find.text(lang.t('حزم العملات', 'Coin Packs')),
            findsOneWidget,
          );
          for (final pack in StoreCatalog.coinPacks) {
            expect(find.text(lang.t(pack.nameAr, pack.nameEn)), findsOneWidget);
          }

          // إزالة الإعلانات معروضة وقابلة للشراء: تفتح ورقة التأكيد بسعرها
          final removeAds = find.text(lang.t('إزالة الإعلانات', 'Remove Ads'));
          expect(removeAds, findsOneWidget);
          await tester.tap(removeAds);
          await _settleRoute(tester);
          final price =
              '\$${StoreCatalog.removeAdsReferenceUsd.toStringAsFixed(2)}';
          expect(
            find.text(lang.t('شراء $price', 'Buy $price')),
            findsOneWidget,
          );
          await tester.tap(find.text(lang.t('إلغاء', 'Cancel')));
          await _settleRoute(tester);
          expect(find.text(lang.t('شراء $price', 'Buy $price')), findsNothing);
          expect(rig.container.read(adsRemovedProvider), isFalse);

          expect(rig.ads.calls, isEmpty);
          expect(rig.routes.entered, hasLength(1));
          expect(
            rig.routes.entered.single,
            isA<ModalBottomSheetRoute<dynamic>>(),
            reason: 'المسار الوحيد هو ورقة تأكيد الشراء',
          );
        },
      );
    }
  });

  group('عجلة الحظ', () {
    for (final lang in AppLanguage.values) {
      testWidgets(
        'بعد دورة اليوم المجانية: «عد غدا» معطّل بلا إعلان، والتذييل لا '
        'يعد بإعلانات، والرجوع لا يُحبس (${lang.name})',
        (tester) async {
          final rig = await _pumpRig(
            tester,
            lang: lang,
            prefs: {'wheel_date': _todayKey(), 'wheel_free_used': true},
            home: _Launcher(
              onOpen: (context, ref) => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const WheelScreen()),
              ),
            ),
          );
          await tester.tap(find.text(_Launcher.label));
          await _settleRoute(tester);
          expect(find.byType(WheelScreen), findsOneWidget);
          rig.routes.reset();

          // الميزانية المشتركة موجودة، ومع ذلك لا دورة بإعلان تُعرض
          final wheel = rig.container.read(wheelProvider);
          expect(wheel.freeSpinAvailable, isFalse);
          expect(wheel.adSpinsRemaining, 0);
          expect(
            rig.container.read(globalAdBudgetProvider).remaining,
            greaterThan(0),
          );

          final comeBack = lang.t(
            'عد غدا لدورة مجانية جديدة',
            'Come back tomorrow for a new free spin',
          );
          final footer = lang.t(
            'دورة مجانية كل يوم',
            'One free spin every day',
          );
          expect(find.text(comeBack), findsOneWidget);
          expect(find.text(footer), findsOneWidget);
          expect(
            find.textContaining(lang.t('شاهد إعلانا', 'Watch an ad')),
            findsNothing,
          );
          expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
          expect(find.byIcon(Icons.play_circle_outline_rounded), findsNothing);
          _expectNoAdWordingAndCleanLanguage(
            tester,
            find.byType(WheelScreen),
            lang,
          );

          // «عد غدا» معلومة لا زرّ: لا فعل خلفه، ولمسه لا يفعل شيئا
          final button = tester.widget<Pressable>(
            find.ancestor(
              of: find.text(comeBack),
              matching: find.byType(Pressable),
            ),
          );
          expect(button.onTap, isNull);
          final pointsBefore = rig.container.read(pointsProvider);
          await tester.tap(find.text(comeBack));
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            find.text(lang.t('العجلة تدور...', 'Spinning...')),
            findsNothing,
          );
          expect(
            find.byType(SnackBar),
            findsNothing,
            reason: 'ولا «لا إعلان متاح»',
          );
          expect(rig.container.read(pointsProvider), pointsBefore);
          expect(rig.ads.calls, isEmpty);
          expect(rig.routes.entered, isEmpty);

          // زرّ الرجوع في النظام يغلق العجلة: لا دوران عالق يحبس اللاعب
          await _pressSystemBack(tester);
          await _settleRoute(tester);
          expect(find.byType(WheelScreen), findsNothing);
          expect(find.text(_Launcher.label), findsOneWidget);
          expect(rig.routes.pops, 1);
          expect(rig.ads.calls, isEmpty);
        },
      );

      testWidgets(
        'الدورة المجانية تعمل كاملة بلا طبقة الإعلان، وبعدها «عد غدا» لا '
        'عرض إعلان (${lang.name})',
        (tester) async {
          final rig = await _pumpRig(
            tester,
            lang: lang,
            home: const WheelScreen(),
          );
          await tester.pump(const Duration(milliseconds: 500));
          rig.routes.reset();

          final footer = lang.t(
            'دورة مجانية كل يوم',
            'One free spin every day',
          );
          expect(find.text(footer), findsOneWidget);
          _expectNoAdWordingAndCleanLanguage(
            tester,
            find.byType(WheelScreen),
            lang,
          );

          final pointsBefore = rig.container.read(pointsProvider);
          final chargesBefore = rig.container.read(hintChargesProvider);
          await tester.tap(find.text(lang.t('دورة مجانية', 'Free Spin')));
          await tester.pump();
          expect(
            find.text(lang.t('العجلة تدور...', 'Spinning...')),
            findsOneWidget,
          );
          // الدوران 4.2 ثانية
          for (var i = 0; i < 25; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }

          // الجائزة أُعلنت ومُنحت فعلا — أيًّا كان القطاع الذي وقفت عليه
          expect(
            find.descendant(
              of: find.byType(WheelScreen),
              matching: find.textContaining(lang.t('ربحت', 'You won')),
            ),
            findsOneWidget,
          );
          final granted =
              rig.container.read(pointsProvider) > pointsBefore ||
              rig.container.read(hintChargesProvider) > chargesBefore ||
              rig.store.jarBoosterActiveUntil != null;
          expect(granted, isTrue, reason: 'الجائزة المعلنة دخلت المحفظة');
          expect(rig.store.wheelFreeUsed, isTrue);
          expect(rig.container.read(wheelProvider).freeSpinAvailable, isFalse);

          // الخطوة التالية للاعب «عد غدا»، لا عرض مشاهدة
          expect(
            find.text(
              lang.t(
                'عد غدا لدورة مجانية جديدة',
                'Come back tomorrow for a new free spin',
              ),
            ),
            findsOneWidget,
          );
          expect(rig.ads.calls, isEmpty);
          expect(rig.routes.entered, isEmpty);

          await _drain(tester);
        },
      );
    }
  });

  group('نافذة صندوق الفصل', () {
    for (final lang in AppLanguage.values) {
      testWidgets('بلا زرّ ×2، و«تمام» يغلقها (${lang.name})', (tester) async {
        var closed = false;
        final rig = await _pumpRig(
          tester,
          lang: lang,
          home: _Launcher(
            onOpen: (context, ref) async {
              await showChestRewardDialog(
                context,
                ref,
                ref.read(languageProvider),
                coins: 100,
              );
              closed = true;
            },
          ),
        );
        rig.routes.reset();
        final pointsBefore = rig.container.read(pointsProvider);

        await tester.tap(find.text(_Launcher.label));
        await _settleRoute(tester);

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text(lang.t('صندوق الفصل!', 'Chapter chest!')),
          findsOneWidget,
        );
        expect(find.text('+100'), findsOneWidget);
        // الميزانية موجودة: الغياب بسبب السياسة لا بسبب نفادها
        expect(rig.container.read(rewardedAdsProvider).hasRemaining, isTrue);
        expect(
          find.text(lang.t('ضاعف جائزتك ×2', 'Double it ×2')),
          findsNothing,
        );
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
        expect(
          find.descendant(
            of: find.byType(DoubleRewardButton),
            matching: find.byType(Pressable),
          ),
          findsNothing,
        );
        _expectNoAdWordingAndCleanLanguage(
          tester,
          find.byType(AlertDialog),
          lang,
        );

        await tester.tap(find.text(lang.t('تمام', 'Done')));
        await _settleRoute(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(closed, isTrue);
        expect(rig.container.read(pointsProvider), pointsBefore);
        expect(rig.ads.calls, isEmpty);
        expect(rig.routes.entered, hasLength(1));
        expect(rig.routes.entered.single, isA<DialogRoute<dynamic>>());
        expect(rig.routes.pops, 1);
      });
    }
  });

  group('ورقة «ينقصك القليل»', () {
    for (final lang in AppLanguage.values) {
      testWidgets(
        'نقص 5 من 40: لا خيار إعلان، والحزمة و«إلغاء» باقيان (${lang.name})',
        (tester) async {
          var affordableCalls = 0;
          final rig = await _pumpRig(
            tester,
            lang: lang,
            home: _Launcher(
              onOpen: (context, ref) => showNearMissSheet(
                context,
                ref,
                price: 40,
                balance: 35,
                target: NearMissTarget.hint,
                onAffordable: () => affordableCalls++,
              ),
            ),
          );
          rig.routes.reset();

          await tester.tap(find.text(_Launcher.label));
          await _settleRoute(tester);

          final deficit = lang.t('ينقصك 5 عملة', 'You need 5 more coins');
          expect(find.text(deficit), findsOneWidget);
          expect(rig.container.read(rewardedAdsProvider).hasRemaining, isTrue);
          expect(
            find.textContaining(lang.t('شاهد إعلانا', 'Watch an ad')),
            findsNothing,
          );
          expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

          final pack = StoreCatalog.smallestSufficient(
            balance: 35,
            target: 40,
          )!;
          expect(
            find.text(
              lang.t(
                '${pack.coins} عملة · ${pack.referencePriceLabel}',
                '${pack.coins} coins · ${pack.referencePriceLabel}',
              ),
            ),
            findsOneWidget,
          );
          final cancel = find.text(lang.t('إلغاء', 'Cancel'));
          expect(cancel, findsOneWidget);
          _expectNoAdWordingAndCleanLanguage(
            tester,
            find.byType(BottomSheet),
            lang,
          );

          await tester.tap(cancel);
          await _settleRoute(tester);

          expect(find.text(deficit), findsNothing);
          expect(affordableCalls, 0);
          expect(rig.ads.calls, isEmpty);
          expect(rig.routes.entered, hasLength(1));
          expect(
            rig.routes.entered.single,
            isA<ModalBottomSheetRoute<dynamic>>(),
          );
          expect(rig.routes.pops, 1);
        },
      );
    }
  });

  group('الخلفية والعودة', () {
    testWidgets(
      'الخروج من الرئيسية إلى الخلفية ثم العودة لا يطلب إعلانا ولا يفتح '
      'مسارا',
      (tester) async {
        final rig = await _pumpRig(tester, home: const HomeScreen());
        // لا pumpAndSettle: الرئيسية فيها رسوم دائمة لا تسكن أبدا
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(
          rig.ads.calls,
          isEmpty,
          reason: 'ظهور الرئيسية لا يمسّ الإعلانات',
        );
        rig.routes.reset();

        final probe = _LifecycleProbe();
        tester.binding.addObserver(probe);
        addTearDown(() => tester.binding.removeObserver(probe));

        await _sendLifecycle(tester, AppLifecycleState.paused);
        await tester.pump(const Duration(seconds: 2));
        await _sendLifecycle(tester, AppLifecycleState.resumed);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // المحاكاة وصلت فعلا: خرج التطبيق إلى الخلفية وعاد عبر الحالات
        // الوسيطة كلها، كما على الجهاز
        expect(
          probe.seen,
          containsAllInOrder([
            AppLifecycleState.paused,
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]),
        );
        expect(tester.binding.lifecycleState, AppLifecycleState.resumed);

        expect(rig.ads.calls, isEmpty);
        expect(rig.routes.entered, isEmpty);
        expect(find.byType(AdVideoOverlay), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('تابع اللعب'), findsOneWidget);
      },
    );
  });

  // دورة العجلة المجانية تُقرأ من التخزين عند بناء المزوّد فقط. قبل إطفاء
  // الإعلانات كانت دورة الإعلان تعيد بناءه عرضا فتظهر دورة اليوم الجديد؛
  // الآن لا يعيده إلا فتح العجلة أو العودة من الخلفية — وهذا ما يُثبَّت هنا.
  group('الدورة المجانية تتجدّد مع اليوم بلا إعلان', () {
    testWidgets('حالة قديمة من الأمس: فتح العجلة يقرأ التخزين من جديد فتظهر '
        'دورة اليوم', (tester) async {
      final rig = await _pumpRig(
        tester,
        prefs: {'wheel_date': _todayKey(), 'wheel_free_used': true},
        home: _Launcher(
          onOpen: (context, ref) => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const WheelScreen())),
        ),
      );
      // المزوّد بُني بدورة اليوم مستهلكة…
      expect(rig.container.read(wheelProvider).freeSpinAvailable, isFalse);
      // …ثم مرّ منتصف الليل والتطبيق مفتوح: التاريخ المحفوظ صار ماضيا
      await rig.store.setWheelDate('2000-01-01');
      expect(
        rig.container.read(wheelProvider).freeSpinAvailable,
        isFalse,
        reason: 'الحالة المخبّأة لا تتجدّد وحدها — وإلا فالاختبار لا يفحص شيئا',
      );

      await tester.tap(find.text(_Launcher.label));
      await _settleRoute(tester);

      expect(find.text('دورة مجانية'), findsOneWidget);
      expect(find.text('عد غدا لدورة مجانية جديدة'), findsNothing);
      expect(rig.container.read(wheelProvider).freeSpinAvailable, isTrue);
      expect(rig.ads.calls, isEmpty);
    });

    testWidgets('العودة من الخلفية تجدّد حالة الدورة المجانية (نقطة التبويب)', (
      tester,
    ) async {
      final rig = await _pumpRig(
        tester,
        prefs: {'wheel_date': _todayKey(), 'wheel_free_used': true},
        home: const HomeScreen(),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(rig.container.read(wheelProvider).freeSpinAvailable, isFalse);

      await rig.store.setWheelDate('2000-01-01');
      await _sendLifecycle(tester, AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 1));
      await _sendLifecycle(tester, AppLifecycleState.resumed);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(rig.container.read(wheelProvider).freeSpinAvailable, isTrue);
      expect(rig.ads.calls, isEmpty);
    });
  });

  // ─────────────────────── ضبط ───────────────────────
  //
  // السيناريوهات نفسها بسياسة تسمح بالقالب. ليست اختبارا لمسار «لا شيء»
  // (ذاك أعلاه)، بل برهان أن الأداة ترى: لو كانت الخدمة المسجِّلة غير
  // موصولة، أو الإيقاع غير مهيّأ، أو القائمة غير مبنية، لمرّت اختبارات
  // الغياب أعلاه بلا معنى — وهنا تسقط.
  group('ضبط: حين يُسمح بالقالب تظهر المداخل وتصل النداءات', () {
    const rewardedOnly = AdFormatPolicy({AdFormat.rewardedInterstitial});

    testWidgets('إتمام المرحلة 20 بسياسة البناء: زرّ ×2 يظهر، و«التالي» يسأل '
        'الخدمة ويعرض بينيا', (tester) async {
      final rig = await _pumpStage20(
        tester,
        policy: AdFormatPolicy.currentBuild,
      );
      await _completeStage20(tester);
      expect(find.text('ضاعف جائزتك ×2'), findsOneWidget);

      await tester.tap(find.text('المرحلة التالية'));
      await _settleRoute(tester);

      expect(rig.ads.calls, ['isInterstitialReady', 'showInterstitial']);
      expect(rig.store.lastAdShownAt, isNotNull);
      expect(
        tester.widget<GameScreen>(find.byType(GameScreen)).level.id,
        _stage21.id,
      );

      await _drain(tester);
    });

    testWidgets('المتجر: قسم «عملات مجانية» وبطاقة «شاهد إعلانا» يظهران', (
      tester,
    ) async {
      await _pumpRig(
        tester,
        physicalSize: _tallPhone,
        policy: rewardedOnly,
        home: const ShopScreen(),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('عملات مقابل مشاهدة إعلان'), findsOneWidget);
      expect(find.text('شاهد إعلانا'), findsOneWidget);
    });

    testWidgets('العجلة: زرّ الدورة بإعلان يظهر ولمسه يصل إلى الخدمة', (
      tester,
    ) async {
      final rig = await _pumpRig(
        tester,
        prefs: {'wheel_date': _todayKey(), 'wheel_free_used': true},
        policy: rewardedOnly,
        home: const WheelScreen(),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final adSpin = find.text('شاهد إعلانا ودُر (3 متبقية)');
      expect(adSpin, findsOneWidget);
      expect(
        find.text('دورة مجانية كل يوم + حتى 3 دورات بالإعلانات'),
        findsOneWidget,
      );

      await tester.tap(adSpin);
      await tester.pump();
      expect(rig.ads.calls, ['showRewarded(long)']);

      await _drain(tester);
    });

    testWidgets('صندوق الفصل: زرّ ×2 يظهر', (tester) async {
      await _pumpRig(
        tester,
        policy: rewardedOnly,
        home: _Launcher(
          onOpen: (context, ref) => showChestRewardDialog(
            context,
            ref,
            ref.read(languageProvider),
            coins: 100,
          ),
        ),
      );
      await tester.tap(find.text(_Launcher.label));
      await _settleRoute(tester);

      expect(find.text('ضاعف جائزتك ×2'), findsOneWidget);
    });

    testWidgets('«ينقصك القليل»: خيار «شاهد إعلانا» يظهر', (tester) async {
      await _pumpRig(
        tester,
        policy: rewardedOnly,
        home: _Launcher(
          onOpen: (context, ref) => showNearMissSheet(
            context,
            ref,
            price: 40,
            balance: 35,
            target: NearMissTarget.hint,
            onAffordable: () {},
          ),
        ),
      );
      await tester.tap(find.text(_Launcher.label));
      await _settleRoute(tester);

      expect(find.textContaining('شاهد إعلانا'), findsOneWidget);
    });
  });
}
