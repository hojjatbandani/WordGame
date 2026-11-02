import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../data/audio_service.dart';
import '../../data/progression/chapter_celebration.dart';
import '../../data/world_models.dart';
import '../providers.dart';
import 'chapter_chest_widget.dart' show kChestAnimationAsset, kChestFullAsset;
import 'glass_card.dart';
import 'pressable.dart';
import 'video_animation.dart';

/// احتفال إتمام فصل: يُعرض فوق شاشة قائمة الفصول بعد آخر مرحلة في الفصل.
///
/// لماذا هنا لا في شاشة اللعب: إتمام الفصل حدث *على الخريطة* — اللاعب
/// يجب أن يرى الفصل الذي أغلقه والفصل الذي انفتح له، لا أن ينزلق من
/// المرحلة 12 إلى 13 بلا أي علامة على أنه عبر حدّا.
///
/// وسط الشاشة صندوق الجائزة الكبير (رسم فتح الصندوق من assets/gold)،
/// وأسفله مرشد العالم بجملة خليجية عامية وصوت الشخصية.
class ChapterCompleteCelebration extends ConsumerStatefulWidget {
  /// معرّف الفصل المكتمل — يحدّد الجملة (ثابتة لكل فصل)
  final int chapterId;

  /// ترتيب الفصل داخل عالمه (1..5) — للعنوان
  final int chapterIndex;

  /// شخصية مرشد العالم
  final String guideId;

  /// المتابعة: الفصل التالي داخل نفس العالم، أو العالم التالي إن كان
  /// هذا آخر فصل في العالم
  final VoidCallback? onNextChapter;

  /// يغيّر عنوان زرّ المتابعة: آخر فصل في العالم يقود إلى العالم التالي
  final bool nextIsNewWorld;

  final VoidCallback onDismiss;

  const ChapterCompleteCelebration({
    super.key,
    required this.chapterId,
    required this.chapterIndex,
    required this.guideId,
    required this.onNextChapter,
    this.nextIsNewWorld = false,
    required this.onDismiss,
  });

  @override
  ConsumerState<ChapterCompleteCelebration> createState() =>
      _ChapterCompleteCelebrationState();
}

class _ChapterCompleteCelebrationState
    extends ConsumerState<ChapterCompleteCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    // صوتان متتاليان لا متزامنان: نغمة الإنجاز أولا (مؤثّر قصير)، ثم
    // بصمة صوت المرشد مع دخوله — تراكبهما يطمس كليهما
    final audio = ref.read(audioServiceProvider);
    audio.play(Sfx.achievement);
    Future.delayed(const Duration(milliseconds: 520), () {
      if (mounted) audio.playCharacter(widget.guideId);
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final line = chapterCelebrationLineFor(widget.chapterId);

    return Semantics(
      container: true,
      label: lang.t(
        'أكملت الفصل ${widget.chapterIndex}',
        'Chapter ${widget.chapterIndex} complete',
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // خلفية معتّمة تُغلق بالنقر — لا تحبس اللاعب خلف زرّ واحد
          Pressable(
            haptic: false,
            onTap: widget.onDismiss,
            semanticLabel: lang.t('إغلاق التهنئة', 'Dismiss'),
            pressedScale: 1,
            // أسود صلب لا شفاف: مقطع الصندوق مصوَّر على خلفية سوداء
            // (mp4 بلا قناة شفافية)، فأي لون آخر خلفه يُظهر مربّعه
            child: const ColoredBox(
              color: Colors.black,
              child: SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                HurufTheme.s4,
                HurufTheme.s4,
                HurufTheme.s4,
                HurufTheme.s5,
              ),
              child: Column(
                children: [
                  // الجائزة أولا وأكبر شيء على الشاشة: هذه اللحظة كلها
                  // عنها، والنصّ تحتها تعليق عليها لا العكس
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _enter,
                        builder: (context, child) {
                          final t = Curves.easeOutBack.transform(
                            _enter.value.clamp(0.0, 1.0),
                          );
                          return Transform.scale(
                            scale: 0.72 + 0.28 * t,
                            child: Opacity(
                              opacity: _enter.value.clamp(0.0, 1.0),
                              child: child,
                            ),
                          );
                        },
                        child: const _TreasureReveal(),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _enter,
                    builder: (context, child) {
                      final t = Curves.easeOutBack.transform(
                        _enter.value.clamp(0.0, 1.0),
                      );
                      return Transform.translate(
                        offset: Offset(0, (1 - t) * 90),
                        child: Opacity(
                          opacity: _enter.value.clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: _Panel(
                      lang: lang,
                      line: line,
                      chapterIndex: widget.chapterIndex,
                      guideId: widget.guideId,
                      onNextChapter: widget.onNextChapter,
                      nextIsNewWorld: widget.nextIsNewWorld,
                      onDismiss: widget.onDismiss,
                    ),
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

/// صندوق الجائزة الكبير وسط الشاشة.
///
/// المقطع مصوَّر على خلفية سوداء صلبة (لا شفافية في mp4)، وخلفية
/// التهنئة كلها سوداء لهذا السبب: هكذا يذوب مربّع المقطع تماما بدل أن
/// يُرى. والهالة الذهبية تحته تجعل الصندوق يبدو مضيئا لا ملصقا.
class _TreasureReveal extends StatelessWidget {
  const _TreasureReveal();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // أكبر مربّع يتّسع فعلا: العرض يقيّده على الهواتف الضيّقة
        // والارتفاع على الشاشات القصيرة
        final side = (constraints.maxWidth * 0.86)
            .clamp(0.0, constraints.maxHeight)
            .toDouble();
        return SizedBox(
          width: side,
          height: side,
          child: Stack(
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      HurufTheme.gold.withValues(alpha: 0.22),
                      HurufTheme.gold.withValues(alpha: 0.0),
                    ],
                    stops: const [0.35, 1],
                  ),
                ),
                child: SizedBox(width: side, height: side),
              ),
              SizedBox(
                width: side * 0.9,
                height: side * 0.9,
                child: const VideoAnimationWidget(
                  assetPath: kChestAnimationAsset,
                  loop: false,
                  fit: BoxFit.contain,
                  // حتى يجهز المقطع (وإن تعذّر تشغيله أصلا) تبقى صورة
                  // الصندوق الممتلئ مكانه — لا فراغ في لحظة الجائزة
                  placeholderImage: kChestFullAsset,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  final AppLanguage lang;
  final ChapterCelebrationLine line;
  final int chapterIndex;
  final String guideId;
  final VoidCallback? onNextChapter;
  final bool nextIsNewWorld;
  final VoidCallback onDismiss;

  const _Panel({
    required this.lang,
    required this.line,
    required this.chapterIndex,
    required this.guideId,
    required this.onNextChapter,
    required this.nextIsNewWorld,
    required this.onDismiss,
  });

  String get _nextLabel => nextIsNewWorld
      ? lang.t('العالم التالي', 'Next world')
      : lang.t('الفصل التالي', 'Next chapter');

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // المرشد في زاوية الشاشة لا وسطها — البطاقات خلفه تبقى مقروءة
            CharacterAnimation(
              characterId: guideId,
              emotion: CharacterEmotion.celebrating,
              size: 96,
            ),
            const SizedBox(width: HurufTheme.s3),
            Expanded(
              child: GlassCard(
                radius: HurufTheme.rButton,
                padding: const EdgeInsets.symmetric(
                  horizontal: HurufTheme.s4,
                  vertical: HurufTheme.s3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lang.t(
                        'خلّصت الفصل $chapterIndex 🎉',
                        'Chapter $chapterIndex complete 🎉',
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: HurufTheme.gold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lang.t(line.ar, line.en),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: HurufTheme.s4),
        if (onNextChapter != null)
          Pressable(
            onTap: onNextChapter,
            semanticLabel: _nextLabel,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: HurufTheme.s3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(HurufTheme.rButton),
                color: HurufTheme.gold,
              ),
              child: Text(
                _nextLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: HurufTheme.bgTop,
                ),
              ),
            ),
          ),
        const SizedBox(height: HurufTheme.s2),
        Pressable(
          onTap: onDismiss,
          semanticLabel: lang.t('البقاء في قائمة الفصول', 'Stay on the map'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: HurufTheme.s2),
            child: Text(
              lang.t('أشوف الخريطة', 'Stay on the map'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: HurufTheme.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
