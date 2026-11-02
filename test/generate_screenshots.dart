// مولّد لقطات المتاجر — ليس اختبارا للتحقق، بل أداة إخراج صور.
//
// يرسم كل شاشة فعليا عبر خط الـ golden في Flutter بأبعاد بكسل دقيقة،
// فينتج صورا جاهزة لجوجل بلاي وآب ستور دون الحاجة إلى محاكي أو جهاز.
//
// اسم الملف بلا لاحقة _test عمدا: لو حمل اللاحقة لالتقطه `flutter test`
// مع بقية الاختبارات وفشلت الحزمة كلها عند أي تغيير بصري مقصود، لأن
// مقارنة الـ golden تعتبر أي بكسل مختلف فشلا. هنا نشغّله يدويا فقط.
//
// التشغيل (لاحظ update-goldens ومفاتيح Supabase كي تظهر الميزات السحابية):
//
//   flutter test test/generate_screenshots.dart --update-goldens \
//     --dart-define=SUPABASE_URL=https://dgzaigukluaxjflzpnda.supabase.co \
//     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
//
// الخرج: مجلد Screenshot/ في جذر المشروع.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// النوع Override يُصدَّر من misc وليس من نقطة الدخول الأساسية في Riverpod 3
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:huruf/core/theme.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/challenge_models.dart';
import 'package:huruf/data/models.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/data/rewards/reward_track.dart';
import 'package:huruf/data/social_models.dart';
import 'package:huruf/data/streak/streak_models.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/data/achievement_models.dart';
import 'package:huruf/presentation/screens/achievements_screen.dart';
import 'package:huruf/presentation/screens/challenge_screen.dart';
import 'package:huruf/presentation/screens/friends_screen.dart';
import 'package:huruf/presentation/screens/game_screen.dart';
import 'package:huruf/presentation/screens/home_screen.dart';
import 'package:huruf/presentation/screens/leaderboard_screen.dart';
import 'package:huruf/presentation/screens/rewards_screen.dart';
import 'package:huruf/presentation/screens/world_select_screen.dart';
import 'package:huruf/presentation/screens/shop_screen.dart';
import 'package:huruf/presentation/screens/wheel_screen.dart';
import 'package:huruf/presentation/widgets/letter_wheel.dart';
import 'package:huruf/presentation/widgets/word_grid.dart';

/// مقاسات المتاجر الرسمية.
/// - جوجل بلاي: نسبة 9:16، و1080×1920 هي المقاس الموصى به للهاتف.
/// - آب ستور: 1290×2796 هو مقاس شاشة 6.7 بوصة المطلوب حاليا.
class StoreSize {
  final String folder;
  final Size pixels;
  final double dpr;

  /// مجلد الخرج نسبة إلى مجلد test/. الافتراضي لقطات المتاجر الخام،
  /// و«لقطات goldie» توضع مباشرة حيث يتوقّعها أمر frame.
  final String outPrefix;

  /// هل يُسمّى الملف بمعرّف المشهد فقط (goldie) أم بالاسم المرقّم؟
  final bool sceneIdOnly;

  /// حشو علوي بالبكسل الفيزيائي يحاكي شريط الحالة. لقطات goldie تُركَّب
  /// داخل هيكل هاتف فيه ثقب كاميرا في أعلى الشاشة؛ بلا هذا الحشو يبدأ
  /// محتوى التطبيق من الحافة تماما فيختفي عنوانه تحت الثقب.
  final double topInsetPx;

  const StoreSize(
    this.folder,
    this.pixels,
    this.dpr, {
    this.outPrefix = '../Screenshot',
    this.sceneIdOnly = false,
    this.topInsetPx = 0,
  });

  Size get logical => Size(pixels.width / dpr, pixels.height / dpr);

  String pathFor(String name, String sceneId) =>
      '$outPrefix/$folder/${sceneIdOnly ? sceneId : name}.png';
}

const _stores = [
  StoreSize('google-play', Size(1080, 1920), 3.0), // منطقي 360×640
  StoreSize('app-store', Size(1290, 2796), 3.0), // منطقي 430×932

  // لقطات خام لـ goldie: مقاس شاشة هيكل Pixel 10 Pro بالضبط (1280×2856)
  // كي تركّب داخل الإطار بلا تمديد ولا أشرطة سوداء — نسبة الشاشة أطول
  // من 1080×1920 فلو استعملنا تلك لظهر المحتوى مشوّها داخل الهيكل.
  StoreSize('pixel-10-pro', Size(1280, 2856), 3.0,
      outPrefix: '../goldie/out/raw',
      sceneIdOnly: true,
      // ثقب الكاميرا في هيكل Pixel يقع أعلى الشاشة، فنترك له مساحة
      topInsetPx: 210),
];

late final List<GameLevel> _levels;
late final ChallengeSet _challenges;


/// مرحلة العرض في اللقطات: 6 حروف و5 كلمات كي تُظهر الشبكة تنوّع
/// الأطوال بدل ثلاث خانات فقط.
///
/// تُختار بالشكل لا بالمعرّف: ترتيب levels.json يتغيّر مع كل ضبط لمنحنى
/// الصعوبة (tool/rebalance_levels.dart)، فرقمٌ مثبّت هنا كان يصير مرحلة
/// أخرى بصمت — واللقطة تخرج بشبكة لا تشبه ما قصدناه.
GameLevel get _showcaseLevel => _levels.firstWhere(
      (l) => l.letters.length == 6 && l.words.length == 5,
      orElse: () => _levels[40],
    );

/// سلسلة ثابتة للقطات — راجع lib/data/streak/streak_engine.dart
class _DemoStreakNotifier extends StreakNotifier {
  @override
  StreakState build() => const StreakState(
        currentStreak: 7,
        longestStreak: 12,
        freezesHeld: 1,
        freezeMilestonesGranted: 1,
        securedThroughDateKey: null,
        pendingFreezeNoticeCount: 0,
      );
}

/// مسار جوائز «في منتصف الطريق» — اليومية انتهت (7/7)، والأسبوعية
/// جاهزة الآن، والشهرية تنتظر أياما. الحالات الثلاث في لقطة واحدة.
class _DemoRewardTrackNotifier extends RewardTrackNotifier {
  @override
  RewardTrackState build() {
    final today = DateTime.now();
    final start = RewardTrackEngine.addDays(
      RewardTrackEngine.dayOf(today),
      -21,
    );
    return RewardTrackState(
      startDay: start,
      tiers: {
        RewardTier.daily: RewardTierProgress(
          claimed: RewardTier.daily.totalClaims,
          lastClaimDay: RewardTrackEngine.addDays(start, 6),
        ),
        RewardTier.weekly: RewardTierProgress(
          claimed: 2,
          // آخر مطالبة قبل أسبوع بالضبط ⇒ الثالثة جاهزة اليوم
          lastClaimDay: RewardTrackEngine.addDays(
            RewardTrackEngine.dayOf(today),
            -7,
          ),
        ),
      },
    );
  }
}

/// حالة إنجازات «لاعب في منتصف الطريق» — كي تُظهر اللقطة شارات مفتوحة
/// وأشرطة تقدّم جزئية معا بدل شاشة فارغة بالكامل
class _DemoAchievementsNotifier extends AchievementsNotifier {
  @override
  AchievementsState build() {
    const stats = {
      StatKey.levelsCompleted: 137,
      StatKey.wordsFound: 640,
      StatKey.bonusWords: 128,
      StatKey.perfectLevels: 31,
      StatKey.hintsUsed: 84,
      StatKey.worldsCompleted: 2,
      StatKey.longestWord: 8,
      StatKey.daysPlayed: 12,
      StatKey.bestStreak: 7,
      StatKey.challengesSolved: 24,
      StatKey.friendsAdded: 3,
      StatKey.wheelSpins: 41,
      StatKey.pointsEarned: 5400,
    };
    return AchievementsState(
      stats: stats,
      unlocked: {
        for (final a in achievements)
          if (a.isEarnedAt(stats[a.stat] ?? 0)) a.id,
      },
    );
  }
}

const _leaderboard = [
  LeaderboardEntry(
      playerId: 'a',
      displayName: 'أبو خالد',
      friendCode: 'K7MQ2X',
      value: 14,
      position: 1,
      isMe: false),
  LeaderboardEntry(
      playerId: 'me',
      displayName: 'أنت',
      friendCode: 'L3KZTD',
      value: 11,
      position: 2,
      isMe: true),
  LeaderboardEntry(
      playerId: 'c',
      displayName: 'سارة',
      friendCode: 'B9PWRT',
      value: 8,
      position: 3,
      isMe: false),
  LeaderboardEntry(
      playerId: 'd',
      displayName: 'فهد',
      friendCode: 'Z24QXU',
      value: 5,
      position: 4,
      isMe: false),
];

/// بيئة الاختبار لا تحمّل أي خط تلقائيا، فتظهر الأيقونات والإيموجي
/// مربعات فارغة (tofu). نحمّل هنا: خط التطبيق، وخط أيقونات ماتيريال،
/// وخط الإيموجي من نظام ويندوز.
Future<void> _loadFonts() async {
  final app = FontLoader('IRANSans')
    ..addFont(rootBundle.load('assets/fonts/IRANSans.ttf'))
    ..addFont(rootBundle.load('assets/fonts/IRANSans_Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/IRANSans_Bold.ttf'));
  await app.load();

  // خطا الرئيسية الجديدة (تصميم 1c)
  final cairo = FontLoader('Cairo')
    ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
  await cairo.load();
  final baloo = FontLoader('BalooBhaijaan2')
    ..addFont(rootBundle.load('assets/fonts/BalooBhaijaan2.ttf'));
  await baloo.load();

  // أيقونات ماتيريال (Icons.*) — مضمّنة داخل حزمة flutter نفسها
  try {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  } catch (e) {
    // ignore: avoid_print
    print('تعذّر تحميل خط أيقونات ماتيريال: $e');
  }

  // الإيموجي: نسجّله تحت اسم عائلة مستقل ونمرّره عبر fontFamilyFallback
  for (final path in const [
    r'C:\Windows\Fonts\seguiemj.ttf',
    '/System/Library/Fonts/Apple Color Emoji.ttc',
    '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
  ]) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    final emoji = FontLoader(_emojiFamily)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await emoji.load();
    _emojiAvailable = true;
    break;
  }
  if (!_emojiAvailable) {
    // ignore: avoid_print
    print('تحذير: لم يُعثر على خط إيموجي — ستظهر الرموز مربعات فارغة');
  }
}

const _emojiFamily = 'ScreenshotEmoji';
bool _emojiAvailable = false;

ThemeData _withEmojiFallback(ThemeData base) {
  if (!_emojiAvailable) return base;
  const fallback = [_emojiFamily];
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamilyFallback: fallback),
  );
}

/// يبني التطبيق بنفس إعدادات main.dart (تيمة + RTL) حول شاشة واحدة
Widget _app(Widget home, ProgressStore store,
    {List<Override> extra = const []}) {
  return ProviderScope(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      levelsProvider.overrideWith((ref) => _levels),
      challengesProvider.overrideWith((ref) => _challenges),
      streakProvider.overrideWith(() => _DemoStreakNotifier()),
      myProfileProvider.overrideWith((ref) => const PlayerProfile(
            userId: 'me',
            friendCode: 'L3KZTDQ7',
            displayName: 'أنت',
            totalScore: 4280,
          )),
      pendingRequestsProvider.overrideWith((ref) => const [
            FriendRequest(
                id: 1,
                fromId: 'fahad',
                fromName: 'فهد',
                fromCode: 'Z24QXUM8',
                fromLevel: 7),
          ]),
      leaderboardProvider.overrideWith((ref) => _leaderboard),
      ...extra,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      // نفس تيمة التطبيق، مع إضافة خط الإيموجي كخط احتياطي فقط داخل
      // بيئة اللقطات (على الجهاز الحقيقي يوفّره النظام تلقائيا)
      theme: _withEmojiFallback(HurufTheme.build()),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: home,
    ),
  );
}

/// يضخّ إطارات كافية لاستقرار المشهد، ويحمّل الصور فعليا.
/// لا نستخدم pumpAndSettle لأن الخلفية والهالات فيها حركات لا نهائية
/// فينتهي الأمر بمهلة فاشلة.
Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 3; round++) {
    await tester.pump();
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element);
      }
    });
    await tester.pump(const Duration(milliseconds: 400));
  }
  // إطار أخير بعد انتهاء حركات الدخول
  await tester.pump(const Duration(milliseconds: 900));
}

/// يلعب كلمة فعليا بالسحب على عجلة الحروف — نكرّر حساب مواقع الحروف
/// كما في LetterWheel كي تصيب الإيماءة مركز كل حرف
Future<void> _playWord(
    WidgetTester tester, List<String> wheel, String word) async {
  final rect = tester.getRect(find.byType(LetterWheel));
  final n = wheel.length;
  final base = rect.size.shortestSide * 0.115;
  final tileRadius = n <= 6 ? base : base * (6 / n).clamp(0.55, 1.0);
  final radius = rect.size.shortestSide / 2 - tileRadius - 6;

  Offset centerOf(int i) {
    final angle = -math.pi / 2 + (2 * math.pi * i) / n;
    return rect.center +
        Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }

  final used = <int>{};
  final path = <Offset>[];
  for (final ch in word.split('')) {
    final index = List.generate(n, (i) => i)
        .firstWhere((i) => wheel[i] == ch && !used.contains(i), orElse: () => -1);
    if (index < 0) return; // الكلمة غير قابلة للتكوين — نتجاهل بهدوء
    used.add(index);
    path.add(centerOf(index));
  }

  // نبدأ الإيماءة بعيدا قليلا عن الحرف الأول ثم نتحرك إليه: السحب لا
  // يُتعرَّف عليه إلا بعد تجاوز عتبة اللمس، فلو بدأنا فوق الحرف مباشرة
  // قد يُفوَّت أول حرف من الكلمة
  final gesture = await tester.startGesture(path.first - const Offset(0, 26));
  await tester.pump();
  for (final point in path) {
    await gesture.moveTo(point);
    await tester.pump(const Duration(milliseconds: 40));
  }
  await gesture.up();
  // خانات الكلمة تنقلب بتأخير متدرّج (i*90ms) ثم رسم 420ms. ضخّة واحدة
  // كبيرة تُطلق المؤقّت لكنها تترك الرسم عند الإطار صفر، فنضخّ إطارات
  // متتابعة كي يكتمل الانقلاب وتظهر الخانات ذهبية بحروفها
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _shoot(
  WidgetTester tester,
  StoreSize store,
  String name,
  Widget Function(ProgressStore store) build, {
  List<Override> extra = const [],
  Future<void> Function(WidgetTester tester)? interact,
}) async {
  SharedPreferences.setMockInitialValues({
    'player_name_asked': true,
    'points': 1250,
    'max_unlocked': 137,
    'bonus_jar': 23,
    'levels_completed_count': 136,
  });
  final progress = ProgressStore(await SharedPreferences.getInstance());
  // نظام التقدّم الجديد يهاجر تلقائيا من نفس بيانات ProgressStore أعلاه
  // (137 مرحلة مكتملة) فيُنتج خريطة عوالم/فصول واقعية للقطة بلا تكرار
  // الإعداد يدويا
  final progressionRepo =
      await ProgressionRepository.load(prefs: progress.prefs, legacy: progress);

  tester.view.physicalSize = store.pixels;
  tester.view.devicePixelRatio = store.dpr;
  // SafeArea في التطبيق يقرأ هذا الحشو، فيبدأ المحتوى تحت ثقب الكاميرا
  tester.view.padding =
      FakeViewPadding(top: store.topInsetPx);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app(build(progress), progress,
      extra: [
        progressionRepositoryProvider.overrideWithValue(progressionRepo),
        ...extra,
      ],
  ));
  await _settle(tester);

  if (interact != null) await interact(tester);

  // معرّف المشهد لـ goldie = الاسم بلا بادئة الترقيم ("01_home" → "home")
  final sceneId = name.replaceFirst(RegExp(r'^\d+_'), '');
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(store.pathFor(name, sceneId)),
  );

  // بعد التقاط الصورة نصرّف المؤقتات المؤجّلة (فقاعة المرشد تبقى 3.2 ثانية)
  // وإلا فشل الاختبار بـ "A Timer is still pending". نفعل ذلك بعد اللقطة
  // عمدا كي تظهر الفقاعة في الصورة بدل أن تختفي قبلها.
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    AudioService.disabled = true; // لا إضافة صوت في بيئة الاختبار

    // إضافات المنصّة غير موجودة في بيئة الاختبار، وبعضها يشترك في قناة
    // أحداث فور بناء الشاشة فترمي MissingPluginException من داخلها —
    // خارج أي try/catch عندنا. نردّ عليها بمعالج صامت بدل تعطّل اللقطة.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in const [
      'home_widget/updates',
      'home_widget',
      'com.llfbandit.app_links/events',
      'com.llfbandit.app_links/messages',
      'dexterous.com/flutter/local_notifications',
    ]) {
      messenger.setMockMethodCallHandler(
          MethodChannel(channel), (call) async => null);
    }
    await _loadFonts();

    final rawLevels = await rootBundle.loadString('assets/data/levels.json');
    _levels = ((jsonDecode(rawLevels) as Map)['levels'] as List)
        .map((l) => GameLevel.fromJson(l as Map<String, dynamic>))
        .toList();

    final rawChallenges =
        await rootBundle.loadString('assets/data/challenges.json');
    _challenges =
        ChallengeSet.fromJson(jsonDecode(rawChallenges) as Map<String, dynamic>);

  });

  for (final store in _stores) {
    group(store.folder, () {
      testWidgets('01 home', (t) async {
        await _shoot(t, store, '01_home', (_) => const HomeScreen());
      });

      testWidgets('02 level map', (t) async {
        await _shoot(t, store, '02_level_map', (_) => const WorldSelectScreen());
      });

      testWidgets('03 gameplay', (t) async {
        final level = _showcaseLevel;
        await _shoot(
          t,
          store,
          '03_gameplay',
          (_) => GameScreen(level: level, allLevels: _levels),
          interact: (tester) async {
            // ننتظر انتهاء فقاعة المرشد (3.2 ثانية) كي لا تغطي الشبكة
            await tester.pump(const Duration(milliseconds: 3400));
            // نحل أقصر كلمتين في المرحلة نفسها — لا كلمتين مكتوبتين
            // بالاسم: المرحلة تُختار بالشكل فمحتواها ليس مضمونا
            final toPlay = wordsInBoardOrder(level.words).take(2);
            for (final entry in toPlay) {
              await _playWord(tester, level.letters, entry.word);
            }
            for (var frame = 0; frame < 8; frame++) {
              await tester.pump(const Duration(milliseconds: 120));
            }
          },
        );
      });

      // حالة «منتصف المسار»: جائزة جاهزة الآن، وأخرى انقضت، وثالثة
      // تنتظر أياما — الثلاث معا هي ما يشرح المسار في لقطة واحدة
      testWidgets('04 reward track', (t) async {
        await _shoot(
          t,
          store,
          '04_reward_track',
          (_) => const RewardsScreen(),
          extra: [
            rewardTrackProvider.overrideWith(_DemoRewardTrackNotifier.new),
          ],
        );
      });

      testWidgets('05 challenge proverbs', (t) async {
        await _shoot(t, store, '05_challenge', (_) {
          const category = ChallengeCategory.proverb;
          return ChallengeScreen(
            category: category,
            items: _challenges.byCategory(category),
          );
        });
      });

      testWidgets('06 leaderboard', (t) async {
        await _shoot(t, store, '06_leaderboard', (_) => const LeaderboardScreen());
      });

      testWidgets('07 friends', (t) async {
        await _shoot(t, store, '07_friends', (_) => const FriendsScreen());
      });

      testWidgets('10 achievements', (t) async {
        await _shoot(
          t,
          store,
          '10_achievements',
          (_) => const AchievementsScreen(),
          // لاعب في منتصف الطريق: بعض الإنجازات مفتوحة وبعضها بشريط تقدّم
          extra: [
            achievementsProvider.overrideWith(
                () => _DemoAchievementsNotifier()),
          ],
        );
      });

      testWidgets('11 shop', (t) async {
        await _shoot(t, store, '11_shop', (_) => const ShopScreen());
      });

      testWidgets('12 wheel', (t) async {
        await _shoot(t, store, '12_wheel', (_) => const WheelScreen());
      });
    });
  }
}
