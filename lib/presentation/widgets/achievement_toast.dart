import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/achievement_models.dart';
import '../../data/audio_service.dart';
import '../providers.dart';

/// بطاقة تهنئة تنزل من أعلى الشاشة عند فتح إنجاز، ثم تختفي وحدها.
/// تُعرض عبر [showAchievementUnlocked] فوق أي شاشة.
class AchievementToast extends ConsumerStatefulWidget {
  final Achievement achievement;
  final VoidCallback onDone;

  const AchievementToast({
    super.key,
    required this.achievement,
    required this.onDone,
  });

  @override
  ConsumerState<AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends ConsumerState<AchievementToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    ref.read(audioServiceProvider).play(Sfx.achievement);
    HapticFeedback.mediumImpact();

    Future.delayed(const Duration(milliseconds: 3400), () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    final lang = ref.watch(languageProvider);
    final tierColor = Color(a.tier.color);
    final curve =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -1.4),
            end: Offset.zero,
          ).animate(curve),
          child: FadeTransition(
            opacity: _controller,
            child: Padding(
              padding: const EdgeInsets.all(HurufTheme.s4),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(HurufTheme.s3),
                  decoration: BoxDecoration(
                    color: HurufTheme.surface,
                    borderRadius: BorderRadius.circular(HurufTheme.rCard),
                    border: Border.all(color: tierColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: tierColor.withValues(alpha: 0.35),
                        blurRadius: 22,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tierColor.withValues(alpha: 0.18),
                          border: Border.all(
                              color: tierColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(a.emoji,
                            style: const TextStyle(fontSize: 26)),
                      ),
                      const SizedBox(width: HurufTheme.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              lang.t('إنجاز جديد! · ${a.tier.titleAr}',
                                  'New achievement! · ${a.tier.titleEn}'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: tierColor,
                              ),
                            ),
                            Text(
                              lang.t(a.titleAr, a.titleEn),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: HurufTheme.textPrimary,
                              ),
                            ),
                            Text(
                              lang.t(a.descriptionAr, a.descriptionEn),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: HurufTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: HurufTheme.s2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: HurufTheme.s3,
                            vertical: HurufTheme.s1),
                        decoration: BoxDecoration(
                          gradient: HurufTheme.goldGradient,
                          borderRadius:
                              BorderRadius.circular(HurufTheme.rButton),
                        ),
                        // الأسطوري بلا عملات: «+0» على أصعب إنجاز في
                        // اللعبة يقرأ عقوبة لا مكافأة
                        child: Text(
                          a.reward > 0
                              ? '+${a.reward}'
                              : lang.t('زخرفي', 'Cosmetic'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: HurufTheme.bgTop,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// يعرض بطاقات الإنجازات المفتوحة واحدة تلو الأخرى فوق الشاشة الحالية
void showAchievementUnlocked(
    BuildContext context, List<Achievement> unlocked) {
  if (unlocked.isEmpty) return;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  void showNext(int index) {
    if (index >= unlocked.length) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Consumer(
        builder: (context, ref, _) => Directionality(
          textDirection: ref.watch(languageProvider).textDirection,
          child: AchievementToast(
            achievement: unlocked[index],
            onDone: () {
              entry.remove();
              showNext(index + 1);
            },
          ),
        ),
      ),
    );
    overlay.insert(entry);
  }

  showNext(0);
}
