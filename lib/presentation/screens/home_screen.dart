import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/balance_config.dart';
import '../../config/debug_config.dart';
import '../../core/app_icons.dart';
import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../data/achievement_models.dart';
import '../../data/challenge_models.dart';
import '../../data/progression/challenge_unlocks.dart';
import '../../data/supabase_config.dart';
import '../../data/world_models.dart';
import '../home_widget_launch.dart';
import '../providers.dart';
import '../widgets/achievement_toast.dart';
import '../widgets/pressable.dart';
import '../widgets/video_animation.dart';
import '../widgets/widget_promo_sheet.dart';
import 'achievements_screen.dart';
import 'challenge_map_screen.dart';
import 'map_entry.dart';
import 'rewards_screen.dart';
import 'shop_screen.dart';
import 'wheel_screen.dart';

// ─────────────────────── رموز تصميم «1c Hub» ───────────────────────
// منقولة حرفيا من مستند التصميم: Huroof Home.dc.html → الخيار 1c

const _ink = Color(0xFFF2ECE2);
const _sand = Color(0xFFF3E8D6); // rgba(243,232,214,*) للنصوص الثانوية
const _gold = Color(0xFFF3C459);
const _goldLogo = Color(0xFFF5CD6A);
const _btnTop = Color(0xFFFBDA7F);
const _btnMid = Color(0xFFEAB340);
const _btnBot = Color(0xFFD89A2A);
const _chipTop = Color(0xFFF8D779);
const _chipBot = Color(0xFFDFA338);
const _onGold = Color(0xFF2A1A05);
const _panel = Color(0xFF091020); // rgba(9,16,32,*)
const _navPanel = Color(0xFF070C1A); // rgba(7,12,26,*)
const _ringHole = Color(0xFF0C1729);
const _avatarHole = Color(0xFF10203A);
const _red = Color(0xFFE7574A);
const _redDot = Color(0xFFFF6B5A);
const _redSoft = Color(0xFFFF9A8C);

/// ارتفاع كل عنصر في صفّ الترويسة الأيمن
const _headerControl = 40.0;

/// خط الواجهة الموحّد (IRANSans). أوزانه ملفات ثابتة لا محور wght
/// متغيّر، فالوزن يُطبَّق عبر fontWeight وحده وFlutter يقرّب إلى أقرب
/// ملف متاح: 200/300/400/500/700
TextStyle _c(
  double size,
  double wght, {
  Color color = _ink,
  double? height,
  double spacing = 0,
}) => TextStyle(
  fontFamily: HurufTheme.fontFamily,
  fontSize: size,
  height: height,
  letterSpacing: spacing,
  color: color,
  fontWeight: FontWeight.values[(wght ~/ 100).clamp(1, 9) - 1],
);

Color _white(double a) => Colors.white.withValues(alpha: a);

/// الرئيسية بتصميم «Hub cards»: لوحة معلومات — التقدّم والسلسلة في
/// البطاقة البطلة، وكل الأنماط على بعد لمسة واحدة كبطاقات شبكية.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final social = SupabaseConfig.isConfigured;

    // بدء الموسيقى مع أول ظهور للرئيسية
    ref.read(audioServiceProvider).startMusic();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SkyBackground(),
          // فيديو خلفية الرئيسية فوق التدرّج
          const _HomeVideoBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(lang: lang, social: social),
                          const SizedBox(height: 20),
                          _LogoRow(lang: lang, social: social),
                          // فاصلان متساويان يحيطان الكتلة الوسطى (الزرّ
                          // الرئيسي وأيقونات التحدّيات) فتتوسّط رأسيا
                          // مهما اختلف ارتفاع الشاشة
                          const Spacer(),
                          _JourneyCard(lang: lang),
                          const SizedBox(height: 14),
                          _ChallengeIconsRow(lang: lang),
                          const Spacer(),
                          const SizedBox(height: 10),
                          _StatsRow(lang: lang, social: social),
                          const SizedBox(height: 10),
                          _NavBar(lang: lang),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (social) const _PendingRewardsClaimer(),
          const _NotificationSync(),
          const _HomeWidgetSync(),
          const _WidgetPromoGate(),
          const _NameGate(),
        ],
      ),
    );
  }
}

// ─────────────────────── فيديو خلفية الرئيسية ───────────────────────

/// فيديو القائمة الرئيسية يعمل تكرارا خلف المحتوى.
///
/// يُرسَم فوق [_SkyBackground] لا بدلا منه: المشغّل يعيد شيئا شفافا حتى
/// يجهز (وإن فشل — متصفح يمنع التشغيل التلقائي مثلا — يبقى شفافا)، فيبقى
/// التدرّج والنجوم خلفه خلفية كاملة في كل الحالات.
///
/// طبقة التعتيم فوقه ليست زينة: إطارات الفيديو الفاتحة تبتلع نصوص
/// البطاقات وحدودها الرفيعة بلا هذا التدرّج.
class _HomeVideoBackground extends StatelessWidget {
  const _HomeVideoBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const VideoAnimationWidget(
          assetPath: 'assets/video/mainmenu.mp4',
          loop: true,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF060B1A).withValues(alpha: .80),
                const Color(0xFF0A1428).withValues(alpha: .62),
                const Color(0xFF0F1D34).withValues(alpha: .90),
              ],
              stops: const [0, .45, 1],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────── الخلفية: سماء ونجوم وكثيب ───────────────────────

class _SkyBackground extends StatelessWidget {
  const _SkyBackground();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return Stack(
          children: [
            // linear-gradient(180deg,#060B1A 0%,#0A1428 40%,#0F1D34 100%)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF060B1A),
                    Color(0xFF0A1428),
                    Color(0xFF0F1D34),
                  ],
                  stops: [0, .4, 1],
                ),
              ),
              child: SizedBox.expand(),
            ),
            // النجوم الثلاث
            const Positioned.fill(child: CustomPaint(painter: _StarsPainter())),
            // توهّج ذهبي أعلى الشاشة
            Positioned(
              left: w * -.15,
              top: 0,
              width: w * 1.3,
              height: h * .52,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -.6),
                      radius: .75,
                      colors: [
                        _gold.withValues(alpha: .13),
                        _gold.withValues(alpha: 0),
                      ],
                      stops: const [0, .7],
                    ),
                  ),
                ),
              ),
            ),
            // الكثيب: تلة عريضة بحافة علوية ذهبية خافتة
            Positioned(
              left: w * -.30,
              top: h * .56,
              width: w * 1.6,
              height: h * .56,
              child: Container(
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: .16),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.elliptical(w * .8, h * .56 * .56),
                  ),
                ),
                padding: const EdgeInsets.only(top: 2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1B2C48), Color(0xFF0A1220)],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.elliptical(w * .8, h * .56 * .56),
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            // تعتيم سفلي يضمن قراءة الشريط والبطاقات
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: h * .40,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00060A16), Color(0xE0060A16)],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    void star(double fx, double fy, double r, double a) {
      paint.color = Colors.white.withValues(alpha: a);
      canvas.drawCircle(Offset(size.width * fx, size.height * fy), r, paint);
    }

    star(.18, .06, 2, .6);
    star(.72, .04, 1.5, .45);
    star(.90, .10, 1.5, .35);
  }

  @override
  bool shouldRepaint(_StarsPainter oldDelegate) => false;
}

/// حلقة تقدّم دائرية تبدأ من الأعلى (مكافئ conic-gradient في التصميم)
class _RingPainter extends CustomPainter {
  final double progress;
  final double thickness;

  const _RingPainter({required this.progress, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - thickness) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = _white(.13);
    canvas.drawCircle(center, radius, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = _gold;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.thickness != thickness;
}

// ─────────────────────── الترويسة ───────────────────────

class _Header extends ConsumerWidget {
  final AppLanguage lang;
  final bool social;

  const _Header({required this.lang, required this.social});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(pointsProvider);
    final maxUnlocked = ref.watch(maxUnlockedProvider);
    final world = worldForLevel(maxUnlocked.clamp(1, totalLevels));
    final worldProgress = (maxUnlocked - world.firstLevelId) / world.levelCount;
    // الاسم المحلّي (الذي أدخله بنفسه عند أول تشغيل) هو الأصل، والملف
    // الاجتماعي احتياط: التحية يجب أن تعمل بلا حساب ولا شبكة
    final name =
        ref.watch(playerNameProvider) ??
        (social
            ? ref
                  .watch(myProfileProvider)
                  .maybeWhen(data: (p) => p?.displayName, orElse: () => null)
            : null);
    final chaptersDone = ref.watch(chaptersCompletedProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // الصورة الرمزية بحلقة تقدّم وشارة العالم
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: const Size(46, 46),
                      painter: _RingPainter(
                        progress: worldProgress,
                        thickness: 2,
                      ),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: _avatarHole,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '🙂',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [_chipTop, _chipBot],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$chaptersDone',
                            style: _c(9.5, 800, color: _onGold, height: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // لمس الاسم يفتح تغييره — من أدخل اسما بالخطأ أو تخطّى
              // السؤال يحتاج طريقا إليه بلا إعادة تثبيت.
              //
              // SizedBox+Align مقصودان: Pressable يفرض 48 كأدنى مساحة
              // لمس ويرسم طفله في أعلى ذلك الصندوق، فنصّ بلا محاذاة
              // يعلو مركز الصورة الرمزية بنحو 15 بكسل. نفس علاج كبسولة
              // الرصيد أدناه، لكن بمحاذاة البداية لا الوسط الأفقي.
              Flexible(
                child: Pressable(
                  onTap: () => askPlayerName(context, ref, lang),
                  semanticLabel: lang.t('تغيير اسمك', 'Change your name'),
                  pressedScale: 0.98,
                  child: SizedBox(
                    height: HurufTheme.minTouch,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        name == null
                            ? lang.t('أهلاً بك', 'Welcome')
                            : lang.t('أهلاً، $name', 'Hi, $name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _c(15, 700, height: 1.2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // كبسولة الرصيد: تعرض ما يملكه اللاعب، ولمسها تفتح المتجر
            Pressable(
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ShopScreen())),
              semanticLabel: lang.t(
                'رصيدك $points عملة، افتح المتجر',
                'Your balance is $points coins, open the shop',
              ),
              // Center مقصود: Pressable يفرض 48 كأدنى مساحة لمس، وبلا
              // هذا الغلاف يتمدّد الصندوق المرسوم إلى 48 بينما يبقى زرّ
              // المتجر (داخل Stack) عند 40 — فتختلف ارتفاعات الترويسة
              child: Center(
                child: Container(
                  height: _headerControl,
                  padding: const EdgeInsetsDirectional.only(start: 8, end: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: _white(.14)),
                    borderRadius: BorderRadius.circular(999),
                    color: _panel.withValues(alpha: .62),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // نفس أيقونة الرصيد في المتجر والعجلة وشاشة اللعب
                      // (AppIcons.gems)، لا رمز تعبيري مختلف: الرصيد شيء
                      // واحد فلا يجوز أن يكون له شكلان في التطبيق نفسه.
                      // المقاس 22 لا 26 لأن الكبسولة بارتفاع ثابت،
                      // وAppIcon يرسم الألماسة بمعامل 1.38 من المقاس.
                      const AppIcon(AppIcons.gems, size: 22),
                      const SizedBox(width: 5),
                      Text('$points', style: _c(14, 700, height: 1)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Pressable(
              onTap: () => _openSettingsSheet(context, ref),
              semanticLabel: lang.t('الإعدادات', 'Settings'),
              child: Center(
                child: Container(
                  width: _headerControl,
                  height: _headerControl,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _white(.14)),
                    color: _panel.withValues(alpha: .62),
                  ),
                  child: const Text('⚙️', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────── الشعار وشارة السلسلة ───────────────────────

class _LogoRow extends ConsumerWidget {
  final AppLanguage lang;
  final bool social;

  const _LogoRow({required this.lang, required this.social});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // محلية بالكامل الآن (لا تعتمد على Supabase) — تُعرض دوما بصرف
    // النظر عن حالة الاتصال، راجع lib/data/streak/streak_engine.dart
    final streak = ref.watch(streakProvider).currentStreak;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          // أداة اختبار: نقرتان على الشعار تمنحان عملات كي تُجرَّب
          // المراحل بلا طحن. kCheatsEnabled ثابت وقت الترجمة ومطفأ في
          // إصدار المتجر، فهذا الفرع لا يصل اللاعبين أصلا.
          onDoubleTap: kCheatsEnabled
              ? () => _grantCheatCoins(context, ref)
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                clipBehavior: Clip.antiAlias,
                // الحلقة فوق الصورة لا تحتها: decoration تُرسم قبل
                // الطفل، والصورة تملأ الدائرة حتى حافة القصّ فتخفيها
                foregroundDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _gold, width: 2),
                ),
                child: Image.asset(
                  AppIcons.logo,
                  fit: BoxFit.cover,
                  // فكّ الترميز بحجم العرض لا 640px كاملة
                  cacheHeight: 160,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                lang.t('حروف', 'Huruf'),
                style: TextStyle(
                  fontFamily: HurufTheme.fontFamily,
                  fontWeight: FontWeight.w800,
                  fontSize: 38,
                  height: 1,
                  color: _goldLogo,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: .5),
                      offset: const Offset(0, 8),
                      blurRadius: 22,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (streak >= 2)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _gold.withValues(alpha: .35)),
              color: _gold.withValues(alpha: .1),
            ),
            child: Text(
              lang.t('🔥 $streak أيام', '🔥 $streak days'),
              style: _c(13, 700, color: _gold, height: 1),
            ),
          ),
      ],
    );
  }
}

/// منح عملات الاختبار — لا يُستدعى إطلاقا حين تكون [kCheatsEnabled]
/// مطفأة (راجع lib/config/debug_config.dart).
void _grantCheatCoins(BuildContext context, WidgetRef ref) {
  ref.read(pointsProvider.notifier).add(kCheatCoinGrant, reason: 'debug_cheat');
  final lang = ref.read(languageProvider);
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          lang.t(
            '🧪 أداة اختبار: +$kCheatCoinGrant عملة',
            '🧪 Test tool: +$kCheatCoinGrant coins',
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: HurufTheme.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
}

// ─────────────────────── البطاقة البطلة: الرحلة ───────────────────────

class _JourneyCard extends ConsumerWidget {
  final AppLanguage lang;

  const _JourneyCard({required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxUnlocked = ref.watch(maxUnlockedProvider);
    final done = maxUnlocked > totalLevels;
    final level = maxUnlocked.clamp(1, totalLevels);
    final world = worldForLevel(level);
    final progress = done
        ? 1.0
        : (maxUnlocked - world.firstLevelId) / world.levelCount;
    final remaining = world.lastLevelId - level + 1;
    final nextWorld = world.id < worlds.length ? worlds[world.id] : null;

    // عدد كلمات المرحلة الحالية من بيانات المراحل إن كانت محمّلة
    final wordCount = ref
        .watch(levelsProvider)
        .maybeWhen(
          data: (levels) =>
              level <= levels.length ? levels[level - 1].words.length : null,
          orElse: () => null,
        );

    final target = nextWorld == null
        ? lang.t('نهاية الرحلة', 'the journey\'s end')
        : lang.t('«${nextWorld.nameAr}»', '"${nextWorld.nameEn}"');
    final subtitle = done
        ? lang.t('أنهيت كل المراحل! 🎉', 'You finished every level! 🎉')
        : [
            if (wordCount != null)
              lang.t(
                '$wordCount كلمات في هذه المرحلة',
                '$wordCount words in this level',
              ),
            lang.t(
              '$remaining مرحلة حتى $target',
              '$remaining levels to $target',
            ),
          ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold.withValues(alpha: .3)),
        gradient: LinearGradient(
          begin: const Alignment(-.6, -1),
          end: const Alignment(.6, 1),
          colors: [_gold.withValues(alpha: .16), _panel.withValues(alpha: .72)],
          stops: const [0, .58],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .9),
            offset: const Offset(0, 22),
            blurRadius: 46,
            spreadRadius: -24,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CustomPaint(
                size: const Size(86, 86),
                painter: _RingPainter(progress: progress, thickness: 8),
                child: SizedBox(
                  width: 86,
                  height: 86,
                  child: Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        color: _ringHole,
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$level', style: _c(22, 900, height: 1)),
                          Text(
                            lang.t('مرحلة', 'level'),
                            style: _c(
                              9,
                              600,
                              color: _sand.withValues(alpha: .5),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.t('أكمل رحلتك', 'Continue your journey'),
                      style: _c(20, 800, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: _c(
                        12,
                        500,
                        color: _sand.withValues(alpha: .6),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Pressable(
            onTap: () => openMap(context, ref),
            semanticLabel: lang.t(
              'تابع اللعب، المرحلة $level',
              'Continue playing, level $level',
            ),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_btnTop, _btnMid, _btnBot],
                  stops: [0, .52, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE9B23F).withValues(alpha: .7),
                    offset: const Offset(0, 14),
                    blurRadius: 28,
                    spreadRadius: -14,
                  ),
                  const BoxShadow(
                    color: Color(0x8CFFFFFF),
                    offset: Offset(0, 1),
                    blurRadius: 0,
                    spreadRadius: -1,
                    blurStyle: BlurStyle.inner,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        lang.t('تابع اللعب', 'Continue Playing'),
                        maxLines: 1,
                        style: _c(21, 800, color: _onGold, height: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    lang.t('←', '→'),
                    style: const TextStyle(fontSize: 19, color: _onGold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ─────────────────────── التحدّيات: أربع أيقونات ───────────────────────

/// الفئات الأربع كصفّ أيقونات تحت الزرّ الرئيسي — كل واحدة تفتح فئتها
/// مباشرة بلا ورقة وسيطة. وهي **المدخل الوحيد** إليها بعد رفع صفّها من
/// ورقة الإعدادات: مدخلان لنفس الشيء يعلّمان اللاعب تجاهل أحدهما.
///
/// ليست كلها مفتوحة من البداية — راجع [ChallengeUnlocks]: النمط الأول
/// بعد فصلين، ثم واحد كلما أتمّ عالمين. المقفل يبقى ظاهرا لا مخفيّا:
/// وعدٌ مرئي بما ينتظره أقوى من مفاجأة لا يعرف اللاعب أنها قادمة.
class _ChallengeIconsRow extends ConsumerWidget {
  final AppLanguage lang;

  const _ChallengeIconsRow({required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // الملف يُحمَّل من الأصول: قبل جاهزيته تُعرض الأيقونات باهتة لا
    // مكانها فارغا — قفزة تخطيط بعد جزء من الثانية أسوأ من انتظار ساكن
    final set = ref
        .watch(challengesProvider)
        .maybeWhen(data: (s) => s, orElse: () => null);
    final chapters = ref.watch(chaptersCompletedProvider);
    final worlds = ref.watch(worldsCompletedProvider);
    final categories = ChallengeUnlocks.order;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < categories.length; i++) ...[
          if (i > 0) const SizedBox(width: 9),
          Expanded(
            child: _ChallengeIcon(
              category: categories[i],
              lang: lang,
              items: set?.byCategory(categories[i]) ?? const [],
              unlocked: ChallengeUnlocks.isUnlocked(
                categories[i],
                chaptersCompleted: chapters,
                worldsCompleted: worlds,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// شرط فتح النمط بصيغة سطر واحد للاعب.
///
/// العربية تُصرَّف لا تُركَّب من رقم وجمع: «أتمم عالمين» لا «أتمم 2
/// عوالم» — والمثنّى هو الحالة الشائعة هنا فعلا (خطوة العوالم اثنان).
String _gateLabel(ChallengeGate gate, AppLanguage lang) {
  String ar(int n, String one, String two, String many) => switch (n) {
    1 => 'أتمم $one',
    2 => 'أتمم $two',
    _ => 'أتمم $n $many',
  };

  if (gate.worlds > 0) {
    return lang.t(
      ar(gate.worlds, 'عالما', 'عالمين', 'عوالم'),
      'Finish ${gate.worlds} world${gate.worlds == 1 ? '' : 's'}',
    );
  }
  return lang.t(
    ar(gate.chapters, 'فصلا', 'فصلين', 'فصول'),
    'Finish ${gate.chapters} chapter${gate.chapters == 1 ? '' : 's'}',
  );
}

class _ChallengeIcon extends StatelessWidget {
  final ChallengeCategory category;
  final AppLanguage lang;
  final List<ChallengeItem> items;

  /// بلغ اللاعب بوّابة هذا النمط
  final bool unlocked;

  const _ChallengeIcon({
    required this.category,
    required this.lang,
    required this.items,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    final accent = category.accent;
    final title = lang.t(category.titleAr, category.titleEn);
    // «جاهز» تعني الملف حُمِّل، و«مفتوح» تعني اللاعب بلغ بوّابته —
    // حالتان مختلفتان: الأولى انتظار لحظي والثانية قفل حقيقي بشرط
    final ready = items.isNotEmpty;
    final gate = ChallengeUnlocks.gateFor(category);
    final requirement = _gateLabel(gate, lang);

    return Pressable(
      onTap: !unlocked
          // القفل يشرح نفسه عند النقر: أيقونة مقفلة لا تقول شيئا تُقرأ
          // عطلا، والشرط في سطر واحد يحوّلها إلى هدف
          ? () => ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    lang.t(
                      '🔒 $title — $requirement لفتحه',
                      '🔒 $title — $requirement to unlock',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  backgroundColor: HurufTheme.surface,
                  behavior: SnackBarBehavior.floating,
                ),
              )
          : ready
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChallengeMapScreen(category: category),
              ),
            )
          : null,
      semanticLabel: unlocked ? title : '$title. $requirement',
      child: Opacity(
        opacity: unlocked && !ready ? .45 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // المقفل ظاهر لا شبح، والبطاقة نفسها معتمة لا شفّافة:
            // كانت تُرسم بشفافية .1 فوق خلفية اللعبة المتحرّكة فتذوب
            // فيها تماما حتى صار الصفّ كلّه يُقرأ فراغا. الآن الخلفية
            // معتمة بلون الفئة، والأيقونة بكامل وضوحها في الحالتين،
            // والقفلُ فوق طبقة سوداء خفيفة تغطّي البطاقة كلها. الفارق
            // بين مفتوح ومقفل يحمله القفل والنصّ، لا إخفاءُ ما يُفترض
            // أن يُغري.
            Container(
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: accent.withValues(alpha: unlocked ? .55 : .48),
                ),
                // معتمة تماما: [Color.alphaBlend] فوق [_panel] لا لون
                // شفّاف فوق ما خلفها — البطاقة تبقى مقروءة أيّا كانت
                // الخلفية المتحرّكة تحتها
                color: Color.alphaBlend(
                  accent.withValues(alpha: unlocked ? .26 : .22),
                  _panel,
                ),
              ),
              child: unlocked
                  ? AppIcon(category.iconAsset, size: 32)
                  : SizedBox.expand(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // بكامل وضوحها: اللاعب يرى *ماذا* ينتظره، لا
                          // شبحا خلف قفل
                          AppIcon(category.iconAsset, size: 32),
                          // طبقة سوداء خفيفة على البطاقة كلها بدل إخفات
                          // الأيقونة وحدها: تكفي لتقول «مقفل» وتُبرز
                          // القفل، ولا تمحو ما تحتها
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.black.withValues(alpha: .28),
                              ),
                            ),
                          ),
                          // ظلّ تحت القفل بدل القرص الداكن السابق:
                          // يفصله عن تفاصيل الأيقونة بلا أن يحجب منها شيئا
                          Icon(
                            Icons.lock_rounded,
                            size: 19,
                            color: _sand,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 7),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            // ارتفاع ثابت لسطرين: بلاه تختلف ارتفاعات الأعمدة الأربعة
            // بحسب طول الاسم فلا تستوي حوافها السفلية
            SizedBox(
              height: 26,
              child: Text(
                // المقفل يعرض شرطه بدل اسمه: الاسم بلا طريق إليه لا
                // يفيد، والشرط يحوّل القفل إلى هدف قابل للقياس
                unlocked ? title : requirement,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _c(
                  9.5,
                  600,
                  // شرط المقفل أهمّ ما في الخانة — لا يُكتب بلون أخفت
                  color: _sand.withValues(alpha: unlocked ? .72 : .92),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────── صف الإحصاءات ───────────────────────

class _StatsRow extends ConsumerWidget {
  final AppLanguage lang;
  final bool social;

  const _StatsRow({required this.lang, required this.social});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(achievementsProvider);
    final words = stats.valueOf(StatKey.wordsFound);
    final levels = stats.valueOf(StatKey.levelsCompleted);
    final streak = ref.watch(streakProvider).currentStreak;

    Widget cell(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(value, style: _c(16, 800, height: 1.1)),
          Text(
            label,
            style: _c(10, 500, color: _sand.withValues(alpha: .5), height: 1.4),
          ),
        ],
      ),
    );

    Widget divider() => Container(width: 1, height: 26, color: _white(.1));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _white(.1)),
        color: _panel.withValues(alpha: .5),
      ),
      child: Row(
        children: [
          cell('$words', lang.t('كلمة محلولة', 'words solved')),
          divider(),
          cell('$levels', lang.t('مرحلة مكتملة', 'levels done')),
          divider(),
          cell('$streak', lang.t('أيام متواصلة', 'day streak')),
        ],
      ),
    );
  }
}

// ─────────────────────── شريط التنقّل السفلي ───────────────────────

class _NavBar extends ConsumerWidget {
  final AppLanguage lang;

  /// لا شرط اتصال في هذا الشريط بعد الآن: كل تبويب فيه (اليومي، المتجر،
  /// العجلة، الإنجازات) يعمل محليا بالكامل
  const _NavBar({required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _white(.12)),
        color: _navPanel.withValues(alpha: .76),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // الرئيسية — التبويب النشط. نفس الودجة كالبقية كي يتطابق
          // الارتفاع والتوسيط بدلا من نسخة يدوية تنحرف عنها
          _NavItem(
            emoji: '🏠',
            label: lang.t('الرئيسية', 'Home'),
            active: true,
          ),
          // مسار الجوائز — حلّ محلّ التحدي اليومي في نفس الموضع، وإشعارات
          // «جائزة اليوم/الأسبوع/الشهر جاهزة» تفتح اللعبة عليه
          if (flags.rewardTrack)
            _NavItem(
              emoji: '🎁',
              label: lang.t('الجوائز', 'Rewards'),
              // النقطة الحمراء = جائزة جاهزة للاستلام، وتختفي فور
              // استلامها — نفس عقد نقطة العجلة تماما
              badge: ref.watch(rewardTrackPendingProvider),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RewardsScreen()),
                );
                // بعد العودة: اليوم قد يكون تغيّر أثناء بقاء التطبيق
                // مفتوحا، فتصير جائزة الغد جاهزة بلا حدث يوقظ النقطة
                ref.read(rewardTrackPendingProvider.notifier).refresh();
              },
            ),
          // المتجر والعجلة: يعملان بلا حساب ولا شبكة، بخلاف ما كان
          // هنا قبلهما (النزال والدوري) — لا تبويب يقود إلى رسالة
          // «تحتاج إنترنت» بعد اليوم
          // مفتاح المتجر المطفأ يُخفي التبويب — صار هذا مدخل المتجر
          // الوحيد بعد رفع زرّ الترويسة، فالعقد كله عليه
          if (flags.store)
            _NavItem(
              emoji: '🛒',
              label: lang.t('المتجر', 'Shop'),
              // النقطة هنا تعني «استلام بانتظارك» لا «عرض للبيع»:
              // جائزة الدخول اليومية أو قسط حزمة بداية مدفوعة — راجع
              // shopPendingProvider. نقطةٌ تعلن بيعا لا تختفي أبدا،
              // فتُعلّم اللاعب تجاهل النقاط كلها
              badge: ref.watch(shopPendingProvider),
              onTap: () async {
                await Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ShopScreen()));
                // الجائزة اليومية تُستلم داخل المتجر، فتتقادم النقطة
                // بمجرّد العودة منه
                ref.invalidate(dailyRewardProvider);
              },
            ),
          _NavItem(
            emoji: '🎡',
            label: lang.t('العجلة', 'Wheel'),
            // النقطة الحمراء = دورة مجانية جاهزة، وتختفي فور استهلاكها.
            // انتقلت إلى هنا من زرّ الزاوية العائم الذي كان يكرّر نفس
            // المدخل فوق لوح اللعب
            badge: ref.watch(wheelProvider).freeSpinAvailable,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const WheelScreen())),
          ),
          _NavItem(
            emoji: '🎖️',
            label: lang.t('إنجازات', 'Awards'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AchievementsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// ارتفاع خانة التبويب الواحدة. ثابت مشترك كي يتطابق التبويب النشط مع
/// غيره تماما — اختلاف بضعة بكسلات بينها يُقرأ «شريط مائل».
const double _navItemHeight = 56;

/// خانة تبويب واحدة في الشريط السفلي.
///
/// الرمز والنص كلاهما داخل صندوق ثابت الارتفاع ثم يُتوسَّط فيه: ارتفاع
/// السطر يختلف بين العربية واللاتينية وبين الرموز التعبيرية والحروف،
/// فبلا صندوق ثابت يهبط نص ويعلو آخر ولا يستوي الشريط أبدا.
class _NavItem extends StatelessWidget {
  final String emoji;
  final String label;

  /// التبويب الحالي: خلفية ذهبية ولا نقر (نحن فيه أصلا)
  final bool active;

  /// نقطة حمراء فوق الرمز: شيء بانتظار اللاعب داخل هذا التبويب
  /// (دورة عجلة مجانية مثلا) — الإشارة الوحيدة التي تستحق مقاطعة نظره
  final bool badge;

  final VoidCallback? onTap;

  const _NavItem({
    required this.emoji,
    required this.label,
    this.active = false,
    this.badge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: _navItemHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: active ? _gold.withValues(alpha: .14) : Colors.transparent,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 24,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 19, height: 1)),
                  if (badge)
                    const PositionedDirectional(
                      top: -6,
                      end: -8,
                      child: PulseDot(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 13,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _c(
                10.5,
                active ? 700 : 600,
                color: active ? _gold : _sand.withValues(alpha: .7),
                height: 1.24,
              ),
            ),
          ),
        ],
      ),
    );

    return Expanded(
      child: Padding(
        // فراغ بين الخانات: بلا هذا تلتصق خلفية التبويب النشط بجاره
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Pressable(onTap: onTap, semanticLabel: label, child: content),
      ),
    );
  }
}

/// النقطة الحمراء فوق رمز التبويب: «هنا شيء بانتظارك».
///
/// كانت قرصا ساكنا بقطر 9 نقاط فوق رمز تعبيري ملوّن — تُرى إن بُحث
/// عنها، وتضيع وسط ألوان الشريط إن لم يُبحث. ثلاث زيادات تصحّح ذلك بلا
/// أن تصير الشارة صراخا:
///   • قرص أكبر قليلا (11) بحافة أعرض تفصله عن الرمز خلفه
///   • هالة حمراء ثابتة حوله ترفع تباينه على أي خلفية
///   • نبضة بطيئة (1.6 ثانية) — حلقة تتوسّع وتتلاشى، والقرص نفسه يكبر
///     4٪ فقط. الحركة هي ما تلتقطه العين الطرفية، وهي وحدها كافية:
///     نبضة أعنف على شريط دائم الظهور تتحوّل إلى إزعاج يُطفأ بالتجاهل.
///
/// تتجمّد كليا عند طلب تقليل الحركة — نفس عقد [AnimatedBackground].
class PulseDot extends StatefulWidget {
  const PulseDot({super.key});

  @override
  State<PulseDot> createState() => PulseDotState();
}

class PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  static const _size = 11.0;

  /// أقصى اتّساع للحلقة حول القرص — يحدّد المساحة المحجوزة للودجة كلها
  static const _ringMax = 9.0;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    if (reduce && _c.isAnimating) _c.stop();
    if (!reduce && !_c.isAnimating) _c.repeat();

    // مربّع ثابت يتّسع لأقصى حلقة: بلاه تتغيّر مساحة الودجة مع النبضة
    // فتُعاد تخطيط الخانة ستين مرة في الثانية
    const box = _size + _ringMax;

    return IgnorePointer(
      child: SizedBox(
        width: box,
        height: box,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            // نصف الدورة اتّساع ونصفها سكون: نبضة متقطّعة تُلاحَظ أكثر
            // من نبض متّصل يذوب في الخلفية
            final t = (_c.value * 2).clamp(0.0, 1.0);
            final eased = Curves.easeOutCubic.transform(t);
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: _size + _ringMax * eased,
                  height: _size + _ringMax * eased,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _redDot.withValues(alpha: (1 - eased) * .7),
                      width: 1.4,
                    ),
                  ),
                ),
                Transform.scale(scale: 1 + (1 - eased) * .04, child: child),
              ],
            );
          },
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: _redDot,
              shape: BoxShape.circle,
              border: Border.all(color: _navPanel, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: _redDot.withValues(alpha: .55),
                  blurRadius: 7,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── ورقة الإعدادات ───────────────────────

void _openSettingsSheet(BuildContext context, WidgetRef outerRef) {
  // سياق الرئيسية نفسها. Consumer بالداخل يظلّل اسم context بسياق يعيش
  // *داخل* الورقة، وأي فتح/حوار بعد إغلاقها يجب أن ينطلق من سياق يبقى
  // حيّا بعده — لا من عنصر يُنتزع من الشجرة في اللحظة ذاتها.
  final rootContext = context;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final lang = ref.watch(languageProvider);
        final audio = ref.watch(audioServiceProvider);
        final notifSettings = ref.watch(notificationSettingsProvider);
        final notifNotifier = ref.read(notificationSettingsProvider.notifier);
        return Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _white(.14)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF101C33), Color(0xFF0A1222)],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.t('الإعدادات', 'Settings'),
                      style: _c(19, 800, height: 1),
                    ),
                    Pressable(
                      onTap: () => Navigator.of(sheetContext).pop(),
                      semanticLabel: lang.t('إغلاق', 'Close'),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _white(.14)),
                        ),
                        child: Text('✕', style: _c(15, 600, height: 1)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // الصوت — مفتاح واحد للموسيقى والمؤثّرات معا. كان اسمه
                // «الموسيقى» وهو لا يوقف إلا الموسيقى، فيبقى كل صوت
                // قصير في اللعب يعمل بلا مفتاح يُسكته
                _SettingsRow(
                  emoji: '🔊',
                  title: lang.t('الصوت', 'Sound'),
                  trailing: StatefulBuilder(
                    builder: (context, setState) => Switch(
                      value: audio.soundEnabled,
                      activeThumbColor: _gold,
                      onChanged: (v) async {
                        await audio.setSoundEnabled(v);
                        // الورقة قد تُغلق أثناء الكتابة/تشغيل الموسيقى
                        if (context.mounted) setState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                // اللغة
                _SettingsRow(
                  emoji: '🌐',
                  title: lang.t('اللغة', 'Language'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LangChoice(
                        label: 'العربية',
                        selected: lang == AppLanguage.ar,
                        onTap: () => ref
                            .read(languageProvider.notifier)
                            .select(AppLanguage.ar),
                      ),
                      const SizedBox(width: 6),
                      _LangChoice(
                        label: 'English',
                        selected: lang == AppLanguage.en,
                        onTap: () => ref
                            .read(languageProvider.notifier)
                            .select(AppLanguage.en),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                _SettingsRow(
                  emoji: '🎁',
                  title: lang.t('تنبيه المكافأة اليومية', 'Daily reward alert'),
                  trailing: Switch(
                    value: notifSettings.dailyRewardEnabled,
                    activeThumbColor: _gold,
                    onChanged: notifNotifier.setDailyRewardEnabled,
                  ),
                ),
                const SizedBox(height: 9),
                // مفتاح واحد للطبقات الثلاث (اليومية والأسبوعية
                // والشهرية): شاشة واحدة وميزة واحدة، وثلاثة مفاتيح لها
                // إغراق للإعدادات بلا مقابل
                _SettingsRow(
                  emoji: '💎',
                  title: lang.t('تنبيه مسار الجوائز', 'Reward track alert'),
                  trailing: Switch(
                    value: notifSettings.rewardTrackEnabled,
                    activeThumbColor: _gold,
                    onChanged: notifNotifier.setRewardTrackEnabled,
                  ),
                ),
                const SizedBox(height: 9),
                _SettingsRow(
                  emoji: '🔥',
                  title: lang.t('تنبيه السلسلة', 'Streak alert'),
                  trailing: Switch(
                    value: notifSettings.streakEnabled,
                    activeThumbColor: _gold,
                    onChanged: notifNotifier.setStreakEnabled,
                  ),
                ),
                const SizedBox(height: 9),
                _SettingsRow(
                  emoji: '🧭',
                  title: lang.t('مرشد الخريطة', 'Map guide'),
                  trailing: Switch(
                    value: ref.watch(assistantEnabledProvider),
                    activeThumbColor: _gold,
                    onChanged: ref.read(assistantEnabledProvider.notifier).set,
                  ),
                ),
                const SizedBox(height: 9),
                // لا صفّ للتحدّيات اللغوية هنا: أيقوناتها الأربع في
                // الرئيسية نفسها، ومدخلان لنفس الشيء يعلّمان اللاعب
                // تجاهل أحدهما.
                // البدء من جديد — مسح التقدّم المحلي كله
                Pressable(
                  onTap: () =>
                      _confirmResetProgress(rootContext, sheetContext, ref),
                  semanticLabel: lang.t('البدء من جديد', 'Start over'),
                  child: _SettingsRow(
                    emoji: '🔄',
                    title: lang.t('البدء من جديد', 'Start over'),
                    trailing: Text(
                      lang.t('مسح التقدّم', 'Erase progress'),
                      style: _c(12.5, 700, color: _redSoft, height: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// تأكيد ثم مسح. خطوتان لأن العملية لا رجعة فيها: لا نسخة احتياطية
/// سحابية للتقدّم المحلي بعد.
Future<void> _confirmResetProgress(
  BuildContext rootContext,
  BuildContext sheetContext,
  WidgetRef ref,
) async {
  final lang = ref.read(languageProvider);
  final confirmed = await showDialog<bool>(
    context: rootContext,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: HurufTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        lang.t('البدء من جديد؟', 'Start over?'),
        style: _c(17, 800, height: 1.3),
      ),
      content: Text(
        lang.t(
          'سيُمسح تقدّمك كله: المراحل والعملات والسلسلة والإنجازات '
              'والمهام. لا يمكن التراجع.',
          'All your progress will be erased: levels, coins, streak, '
              'achievements and missions. This cannot be undone.',
        ),
        style: _c(14, 500, color: HurufTheme.textSecondary, height: 1.6),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(lang.t('إلغاء', 'Cancel'), style: _c(14, 700)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            lang.t('امسح وابدأ', 'Erase'),
            style: _c(14, 800, color: _red),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  // القراءة قبل إغلاق الورقة: ref هنا يتبع Consumer داخلها
  final store = ref.read(progressStoreProvider);
  final progression = ref.read(progressionRepositoryProvider);
  await store.resetProgress();
  await progression.resetToInitial();

  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
  // إعادة بناء الشجرة كي تقرأ كل المزوّدات التخزين الممسوح من جديد
  if (rootContext.mounted) HurufRoot.restart(rootContext);
}

class _SettingsRow extends StatelessWidget {
  final String emoji;
  final String title;
  final Widget trailing;

  const _SettingsRow({
    required this.emoji,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _white(.12)),
        color: _white(.04),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _white(.07),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _c(14.5, 700, height: 1.3),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 168),
            child: FittedBox(fit: BoxFit.scaleDown, child: trailing),
          ),
        ],
      ),
    );
  }
}

class _LangChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        // ارتفاع ثابت وتوسيط صريح: «العربية» و«English» لهما ارتفاع
        // سطر مختلف في نفس الخط، فحشوة رأسية وحدها تعطي كبسولتين
        // بارتفاعين مختلفين ونصا غير مستقر رأسيا
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? _gold.withValues(alpha: .55) : _white(.14),
          ),
          color: selected ? _gold.withValues(alpha: .14) : Colors.transparent,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: _c(
            12.5,
            700,
            color: selected ? _gold : _sand.withValues(alpha: .7),
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

// ─────────────────── استلام مكافآت الدعوات المعلّقة ───────────────────

/// ودجة غير مرئية: تستلم مكافآت الدعوات المعلّقة عند فتح التطبيق وتعرض
/// بشارة للاعب. تُنفَّذ مرة واحدة لأن السيرفر يعلّم المكافآت مستلمة.
class _PendingRewardsClaimer extends ConsumerStatefulWidget {
  const _PendingRewardsClaimer();

  @override
  ConsumerState<_PendingRewardsClaimer> createState() =>
      _PendingRewardsClaimerState();
}

class _PendingRewardsClaimerState
    extends ConsumerState<_PendingRewardsClaimer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _claim());
  }

  Future<void> _claim() async {
    // أولا نرفع XP: هذه هي الرفعة التي تؤهّل دعوتي أنا في الخادم إن
    // كنت مدعوّا وبلغت مستوى التأهيل، فيُدفع لمن دعاني. بلا هذا السطر
    // يبقى الداعي بلا مكافأة حتى أفتح شاشة الدوري صدفة.
    await syncReferralQualification(ref);
    if (!mounted) return;

    final claimed = await claimPendingReferralRewards(ref);
    if (!mounted || claimed.isEmpty) return;

    final achievements = ref.read(achievementsProvider.notifier);
    showAchievementUnlocked(context, achievements.takeJustUnlocked());

    final lang = ref.read(languageProvider);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            // المكافأة تصل حين *يتقدّم* المدعوّ لا حين ينضم، فالنصّ
            // يقول ذلك: بشارة تنسب المكافأة لسبب غير سببها تجعل اللاعب
            // يظنّ النظام معطّلا حين لا تصله بعد انضمام مباشر
            lang.t(
              claimed.count == 1
                  ? 'صديق دعوته وصل المستوى ${BalanceConfig.referralQualifyLevel}! +${claimed.total} عملة 🎉'
                  : '${claimed.count} من مدعوّيك وصلوا المستوى ${BalanceConfig.referralQualifyLevel}! +${claimed.total} عملة 🎉',
              claimed.count == 1
                  ? 'A friend you invited reached level ${BalanceConfig.referralQualifyLevel}! +${claimed.total} coins 🎉'
                  : '${claimed.count} of your invites reached level ${BalanceConfig.referralQualifyLevel}! +${claimed.total} coins 🎉',
            ),
            textAlign: TextAlign.center,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: HurufTheme.surface,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─────────────────────── اسم اللاعب ───────────────────────

/// ودجة غير مرئية: تسأل اللاعب عن اسمه مرة واحدة عند أول دخول للعبة.
///
/// لماذا هنا لا في شاشة البدء: شاشة البدء تختفي من تلقائها بعد ثانيتين،
/// وحوار فوقها يُقطع في منتصفه. وأول ظهور للرئيسية هو أول لحظة يرى فيها
/// اللاعب اللعبة فعلا مستقرّة.
class _NameGate extends ConsumerStatefulWidget {
  const _NameGate();

  @override
  ConsumerState<_NameGate> createState() => _NameGateState();
}

class _NameGateState extends ConsumerState<_NameGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = ref.read(progressStoreProvider);
      // سُئل مرة = لا يُسأل ثانية، حتى لو تخطّى السؤال بلا اسم
      if (store.playerNameAsked || store.playerName != null) return;
      askPlayerName(context, ref, ref.read(languageProvider), firstTime: true);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// حوار إدخال/تغيير اسم اللاعب. [firstTime] يغيّر النبرة فقط: أول مرة
/// ترحيب، وما بعدها تعديل.
Future<void> askPlayerName(
  BuildContext context,
  WidgetRef ref,
  AppLanguage lang, {
  bool firstTime = false,
}) async {
  final name = await showDialog<String>(
    context: context,
    barrierDismissible: !firstTime,
    builder: (dialogContext) => _NameDialog(
      lang: lang,
      firstTime: firstTime,
      initialName: ref.read(playerNameProvider) ?? '',
    ),
  );

  final notifier = ref.read(playerNameProvider.notifier);
  if (name == null || name.trim().isEmpty) {
    // تخطّى السؤال: لا يُسأل ثانية تلقائيا، ويبقى مدخل التغيير في
    // الترويسة متاحا متى شاء
    await notifier.skip();
    return;
  }
  await notifier.set(name);
}

/// جسد حوار الاسم.
///
/// ودجة حالة لا دالة بناء داخل showDialog: المتحكّم يجب أن يعيش ما دام
/// الحقل حيّا ويُتخلَّص منه في dispose الخاصة به. التخلّص منه بعد
/// `await showDialog` مباشرة كان يقع *قبل* انتهاء حركة إغلاق الحوار —
/// والحقل ما يزال مبنيّا — فينفجر التأكيد `_dependents.isEmpty`. يظهر
/// ذلك تحديدا عند الضغط على Enter لأن الإغلاق يقع داخل نداء الإدخال.
class _NameDialog extends StatefulWidget {
  final AppLanguage lang;
  final bool firstTime;
  final String initialName;

  const _NameDialog({
    required this.lang,
    required this.firstTime,
    required this.initialName,
  });

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? value]) =>
      Navigator.of(context).pop(value ?? _controller.text);

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return Directionality(
      textDirection: lang.textDirection,
      child: AlertDialog(
        backgroundColor: HurufTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HurufTheme.rCard),
        ),
        title: Text(
          widget.firstTime
              ? lang.t('وش اسمك؟', 'What should we call you?')
              : lang.t('غيّر اسمك', 'Change your name'),
          style: _c(17, 800, height: 1.3),
        ),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 18,
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
          style: _c(15, 600),
          decoration: InputDecoration(
            hintText: lang.t('اسمك هنا', 'Your name'),
            hintStyle: _c(14, 500, color: HurufTheme.textSecondary),
            counterText: '',
            filled: true,
            fillColor: HurufTheme.bgTop.withValues(alpha: 0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HurufTheme.rButton),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              widget.firstTime
                  ? lang.t('لاحقا', 'Later')
                  : lang.t('إلغاء', 'Cancel'),
              style: _c(14, 700, color: HurufTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => _submit(),
            child: Text(
              lang.t('يلا نبدأ', 'Let\'s go'),
              style: _c(14, 800, color: HurufTheme.gold),
            ),
          ),
        ],
      ),
    );
  }
}

/// ودجة غير مرئية: تسجّل جلسة/وقت الفتح وتعيد جدولة إشعارات اليوم مرة
/// واحدة عند كل ظهور للرئيسية — راجع syncNotifications في providers.dart
class _NotificationSync extends ConsumerStatefulWidget {
  const _NotificationSync();

  @override
  ConsumerState<_NotificationSync> createState() => _NotificationSyncState();
}

class _NotificationSyncState extends ConsumerState<_NotificationSync> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      syncNotifications(ref);
      // مصالحة الإعلانات الجائزية: مشاهدة اكتملت ولم تصل نداءة مكافأتها
      // قبل إغلاق التطبيق تُضاف هنا. بلا هذا يخسر اللاعب مكافأة شاهد
      // إعلانها كاملا لمجرد أن الشبكة تأخّرت ثانيتين.
      final reconciled = ref.read(rewardedAdsProvider.notifier).flush();
      if (reconciled > 0 && mounted) {
        final lang = ref.read(languageProvider);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: HurufTheme.surface,
              content: Text(
                lang.t(
                  'مكافأة إعلان متأخّرة: +$reconciled عملة',
                  'Delayed ad reward: +$reconciled coins',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // نصّ الإشعار يُثبَّت في نظام التشغيل لحظة الجدولة، فتبديل لغة
    // الواجهة بعدها يترك تذكير المساء باللغة المتروكة. هنا نعيد صياغة
    // ما هو مجدول فعلا بلا إعادة تقييم أهليته (راجع الشرح في
    // relocalizeScheduledNotifications).
    ref.listen<AppLanguage>(languageProvider, (previous, next) {
      if (previous == next) return;
      relocalizeScheduledNotifications(ref);
    });
    return const SizedBox.shrink();
  }
}

/// ودجة غير مرئية: تُبقي ودجة الشاشة الرئيسية مطابقة لحالة اللاعب،
/// وتمنح مكافأة تفعيلها مرة واحدة، وتستقبل نقراتها.
///
/// لماذا هنا لا في main.dart: الرئيسية هي أول شاشة تملك شجرة مزوّدات
/// كاملة ومُلاحا جاهزا — نفس موضع [_NotificationSync] تماما.
class _HomeWidgetSync extends ConsumerStatefulWidget {
  const _HomeWidgetSync();

  @override
  ConsumerState<_HomeWidgetSync> createState() => _HomeWidgetSyncState();
}

class _HomeWidgetSyncState extends ConsumerState<_HomeWidgetSync>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _clicks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refresh());
      final service = ref.read(homeWidgetServiceProvider);
      _clicks = HomeWidgetLaunch.listen(
        clicks: service.clicks,
        initialUri: service.initialLaunchUri,
      );
    });
  }

  @override
  void dispose() {
    _clicks?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // العودة من الخلفية: قد يكون اليوم تغيّر، أو أُضيفت الودجة والتطبيق
    // مغلق. لا مؤقّتات ولا عمل خلفي — هذه اللحظة وحدها تكفي.
    if (state == AppLifecycleState.resumed) {
      // دورة العجلة المجانية تتجدّد مع اليوم؛ حالتها تُقرأ عند البناء فقط
      ref.invalidate(wheelProvider);
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    await syncHomeWidget(ref);
    final granted = await grantWidgetActivationRewardIfDue(ref);
    if (granted == null || !mounted) return;

    // الرصيد تغيّر بالمنح، فالودجة نفسها صارت متقادمة
    await syncHomeWidget(ref);
    if (!mounted) return;
    final lang = ref.read(languageProvider);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: HurufTheme.surface,
          content: Text(
            lang.t(
              'شكرا لإضافة الودجة! +$granted ألماسة',
              'Thanks for adding the widget! +$granted gems',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // الودجة تعرض الرصيد والسلسلة والتقدّم — أي تغيّر فيها يجعلها
    // متقادمة على الشاشة الرئيسية للهاتف. المراقبة هنا أرخص من نداء
    // يدوي في كل موضع يغيّر أحد هذه الأرقام.
    ref.listen<int>(pointsProvider, (previous, next) {
      if (previous != next) unawaited(syncHomeWidget(ref));
    });
    // السلسلة تتغيّر بإتمام مرحلة، وتلك تغيّر الرصيد أيضا — لكن الربط
    // بها صراحة يبقيها صحيحة لو تغيّرت يوما بلا حركة عملات (تجميد
    // مستهلَك، أو انكسار يُكتشف عند أول قراءة بعد منتصف الليل)
    ref.listen<int>(streakProvider.select((s) => s.currentStreak), (
      previous,
      next,
    ) {
      if (previous != next) unawaited(syncHomeWidget(ref));
    });
    ref.listen<AppLanguage>(languageProvider, (previous, next) {
      if (previous != next) unawaited(syncHomeWidget(ref));
    });
    return const SizedBox.shrink();
  }
}

/// بوّابة عرض «أضف الودجة»: تعرضه مرة واحدة فقط، وبعد أن يُتمّ اللاعب
/// [BalanceConfig.widgetPromoAfterStages] مرحلة — لا عند أول تشغيل.
///
/// تُستثنى الحالة التي أُضيفت فيها الودجة فعلا (المكافأة مُنحت): دعوة
/// لإضافة شيء مُضاف أصلا إزعاج بلا معنى.
class _WidgetPromoGate extends ConsumerStatefulWidget {
  const _WidgetPromoGate();

  @override
  ConsumerState<_WidgetPromoGate> createState() => _WidgetPromoGateState();
}

class _WidgetPromoGateState extends ConsumerState<_WidgetPromoGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_maybeShow()));
  }

  Future<void> _maybeShow() async {
    final store = ref.read(progressStoreProvider);
    if (store.widgetPromoShown || store.widgetActivationRewarded) return;

    final stages = ref
        .read(achievementsProvider)
        .valueOf(StatKey.levelsCompleted);
    if (stages < BalanceConfig.widgetPromoAfterStages) return;

    // الودجة مضافة سلفا (لاعب أضافها قبل أن يبلغ العتبة) — لا دعوة
    if (await ref.read(homeWidgetServiceProvider).isInstalled()) return;
    if (!mounted) return;

    // لا تُكدَّس فوق حوار قائم: الرئيسية تعرض عند العودة إليها حوار
    // الاسم، وتسلسل مكافآت معلَّقة، وتنبيه إعلان متأخّر. ورقة تقفز فوق
    // أحدها تُغلق ما تحتها أو تُقرأ كأنها جزء منه.
    if (ModalRoute.of(context)?.isCurrent != true) return;

    await store.setWidgetPromoShown(true);
    if (!mounted) return;
    await WidgetPromoSheet.show(context, ref.read(languageProvider));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
