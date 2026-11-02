import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/balance_config.dart';
import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../data/audio_service.dart';
import '../../data/progression/world_defs.dart';
import '../progression_text.dart';
import '../providers.dart';
import '../widgets/pressable.dart';
import 'chapter_select_screen.dart';
import 'world_select_screen.dart' show worldSeedColor;

/// مراسم فتح عالم جديد — استحواذ كامل على الشاشة، يُعرض *مرة واحدة فقط*
/// (المستدعي يتحقّق من ProgressionRepository.worldsPendingCeremony قبل
/// الدخول هنا، وهذه الشاشة تُثبِّت "عُرضت" فعليا عند الخروج بأي طريقة).
///
/// 5 محطّات بالترتيب: ستارة/مسح إلى لوحة ألوان العالم → اسمه ووصفه →
/// دخول المرشد بتحية → 4 بطاقات تُقلَب (مرشد/ثيم/ميكانيكا/مكافآت) →
/// دعوة واحدة للبدء. 4-6 ثوان، قابلة للتخطي بعد 1.5 ثانية.
///
/// لا فنّ حقيقي بعد لهذه الهويات الجديدة (bidaya/waha/..) ولا سطر شخصية
/// مؤلَّف لكل مرشد جديد على حدة — يُستخدم تدرّج لوني مشتقّ من colorSeed
/// وإيموجي وتحية عامة بدل الانهيار على أصل غير موجود أو اختلاق محتوى
/// شخصية لم يُكتَب بعد.
class WorldUnlockCeremonyScreen extends ConsumerStatefulWidget {
  final int worldId;
  const WorldUnlockCeremonyScreen({super.key, required this.worldId});

  @override
  ConsumerState<WorldUnlockCeremonyScreen> createState() =>
      _WorldUnlockCeremonyScreenState();
}

class _WorldUnlockCeremonyScreenState
    extends ConsumerState<WorldUnlockCeremonyScreen>
    with SingleTickerProviderStateMixin {
  static const _totalDuration = Duration(milliseconds: 5200); // ضمن 4-6 ثوان
  static const _skipUnlockAt = Duration(milliseconds: 1500);

  late final AnimationController _controller;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _dismiss();
      })
      ..forward();
    ref.read(audioServiceProvider).play(Sfx.achievement);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSkip =>
      _controller.duration != null &&
      _controller.value * _controller.duration!.inMilliseconds >=
          _skipUnlockAt.inMilliseconds;

  Future<void> _dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    await ref.read(progressionProvider.notifier).markCeremonyShown(widget.worldId);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ChapterSelectScreen(worldId: widget.worldId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final structure = ref.watch(progressionStructureProvider);
    final world = structure.worldById(widget.worldId);
    final color = worldSeedColor(world.colorSeed);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: HurufTheme.bgTop,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            // onTap يُعاد تقييمه هنا عمدا داخل builder لا خارجه: هذا
            // الإغلاق يُعاد بناؤه مع كل نبضة للـcontroller (خلافا لبقية
            // الشجرة خارج AnimatedBuilder التي تُبنى مرة واحدة فقط)، فلو
            // كان GestureDetector هو الأب هنا لجمّد _canSkip على قيمته
            // عند أول بناء (false) للأبد — عطل حقيقي رُصد بهذا الاختبار
            // بالضبط قبل هذا الإصلاح
            return GestureDetector(
              onTap: _canSkip ? _dismiss : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CurtainReveal(progress: _phase(t, 0.0, 0.15), color: color),
                  if (t > 0.10)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(HurufTheme.s5),
                        child: Column(
                          children: [
                            _NameBlock(
                              world: world,
                              lang: lang,
                              progress: _phase(t, 0.15, 0.35),
                            ),
                            const SizedBox(height: HurufTheme.s4),
                            _GuideBlock(
                              world: world,
                              lang: lang,
                              progress: _phase(t, 0.35, 0.55),
                            ),
                            const SizedBox(height: HurufTheme.s4),
                            Expanded(
                              child: _RewardCardsGrid(
                                world: world,
                                lang: lang,
                                overallProgress: _phase(t, 0.55, 0.95),
                              ),
                            ),
                            _CtaButton(
                              progress: _phase(t, 0.9, 1.0),
                              lang: lang,
                              onTap: _dismiss,
                            ),
                            if (_canSkip) ...[
                              const SizedBox(height: HurufTheme.s2),
                              Text(
                                lang.t('اضغط في أي مكان للتخطي',
                                    'Tap anywhere to skip'),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: HurufTheme.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  double _phase(double t, double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0);
}

class _CurtainReveal extends StatelessWidget {
  final double progress; // 0..1
  final Color color;
  const _CurtainReveal({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.55), HurufTheme.bgBottom],
            ),
          ),
        ),
        // ستارتان تنسحبان يمينا ويسارا — "curtain/wipe" حرفيا
        Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: (0.5 - progress * 0.5).clamp(0.0, 0.5),
            heightFactor: 1,
            child: const ColoredBox(color: HurufTheme.bgTop),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: (0.5 - progress * 0.5).clamp(0.0, 0.5),
            heightFactor: 1,
            child: const ColoredBox(color: HurufTheme.bgTop),
          ),
        ),
      ],
    );
  }
}

class _NameBlock extends StatelessWidget {
  final WorldDef world;
  final AppLanguage lang;
  final double progress;
  const _NameBlock({required this.world, required this.lang, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, (1 - progress) * -16),
        child: Column(
          children: [
            Text(
              worldName(world.nameKey, lang),
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: HurufTheme.gold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              worldSubtitle(world.themeId, lang),
              style: const TextStyle(
                  fontSize: 14, color: HurufTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideBlock extends StatelessWidget {
  final WorldDef world;
  final AppLanguage lang;
  final double progress;
  const _GuideBlock({required this.world, required this.lang, required this.progress});

  @override
  Widget build(BuildContext context) {
    final color = worldSeedColor(world.colorSeed);
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset((1 - progress) * 40, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.35),
                border: Border.all(color: color, width: 2),
              ),
              child: const Text('🧑', style: TextStyle(fontSize: 30)),
            ),
            const SizedBox(width: HurufTheme.s3),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: HurufTheme.s3, vertical: HurufTheme.s2),
                decoration: BoxDecoration(
                  color: HurufTheme.surface,
                  borderRadius: BorderRadius.circular(HurufTheme.rButton),
                ),
                child: Text(
                  lang.t('أهلا بك! أنا مرشدك في هذا العالم الجديد',
                      'Welcome! I\'ll guide you through this new world'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardCardsGrid extends StatelessWidget {
  final WorldDef world;
  final AppLanguage lang;
  final double overallProgress;

  const _RewardCardsGrid({
    required this.world,
    required this.lang,
    required this.overallProgress,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      (lang.t('مرشد جديد', 'New Guide'), '🧑', worldName(world.nameKey, lang)),
      (lang.t('ثيم جديد', 'New Theme'), '🎨', worldSubtitle(world.themeId, lang)),
      (
        lang.t('ميكانيكا جديدة', 'New Mechanic'),
        '⚙️',
        mechanicName(world.mechanicId, lang)
      ),
      (
        lang.t('مكافآت جديدة', 'New Rewards'),
        '🏆',
        lang.t('+${BalanceConfig.coinsWorldComplete} عند الإتمام',
            '+${BalanceConfig.coinsWorldComplete} on completion')
      ),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: HurufTheme.s3,
        crossAxisSpacing: HurufTheme.s3,
        childAspectRatio: 1.1,
      ),
      itemCount: cards.length,
      itemBuilder: (context, i) {
        // كل بطاقة تُقلَب بالتتابع ضمن نافذة overallProgress الواحدة
        final cardStart = i / cards.length;
        final cardEnd = (i + 1) / cards.length;
        final cardProgress =
            ((overallProgress - cardStart) / (cardEnd - cardStart)).clamp(0.0, 1.0);
        return _FlipCard(
          progress: cardProgress,
          emoji: cards[i].$2,
          title: cards[i].$1,
          subtitle: cards[i].$3,
        );
      },
    );
  }
}

class _FlipCard extends StatelessWidget {
  final double progress;
  final String emoji;
  final String title;
  final String subtitle;

  const _FlipCard({
    required this.progress,
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final angle = (1 - progress) * 3.14159 / 2; // 90°→0° حول المحور Y
    return Opacity(
      opacity: progress > 0.05 ? 1 : 0,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(angle),
        child: Container(
          padding: const EdgeInsets.all(HurufTheme.s3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HurufTheme.rCard),
            border: Border.all(color: HurufTheme.gold.withValues(alpha: 0.4)),
            color: HurufTheme.surface,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10, color: HurufTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final double progress;
  final AppLanguage lang;
  final VoidCallback onTap;
  const _CtaButton({required this.progress, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: IgnorePointer(
        ignoring: progress < 0.5,
        child: Pressable(
          onTap: onTap,
          semanticLabel: lang.t('ابدأ الرحلة', 'Start the journey'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: HurufTheme.s4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: HurufTheme.goldGradient,
              borderRadius: BorderRadius.circular(HurufTheme.rButton),
            ),
            child: Text(
              lang.t('ابدأ الرحلة', 'Start the Journey'),
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: HurufTheme.bgTop),
            ),
          ),
        ),
      ),
    );
  }
}
