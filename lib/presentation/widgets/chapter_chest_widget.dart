import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../data/progression/map_view_model.dart';
import 'pressable.dart';

/// أصول صندوق الفصل — صورتان فقط: ممتلئ (الجائزة لم تُستلَم بعد) وفارغ
/// (استُلمت). المقفل هو نفسه الممتلئ لكن مطفأ اللون: الجائزة داخله فعلا،
/// وما ينقص هو إكمال الفصل لا محتوى الصندوق.
const kChestFullAsset = 'assets/gold/full.png';
const kChestEmptyAsset = 'assets/gold/empty.png';

/// رسم فتح الصندوق الكبير — يُعرض وسط الشاشة في تهنئة إتمام الفصل
/// (راجع chapter_complete_celebration.dart)
const kChestAnimationAsset = 'assets/gold/animation.mp4';

/// صندوق الفصل: مقفل (ممتلئ مطفأ مع قفل)، مفتوح (ممتلئ لامع، قابل
/// للّمس)، مُستلَم (الصندوق الفارغ). فتحه فعليا يشغّل كشفا من 3 مراحل:
/// اهتزاز → وميض ذهبي → تكبّر، ثم [onClaimed] — وعندها تحلّ صورة
/// الصندوق الفارغ محلّ الممتلئ.
class ChapterChestWidget extends StatefulWidget {
  final ChestState state;
  final AppLanguage lang;

  /// مكافأة هذا الصندوق بالضبط — نفس الرقم الذي سيقبضه اللاعب عند
  /// الفتح، لا تقديرا ولا مدى.
  ///
  /// كان يُعرض `coinsChapterChestMode` (45) بينما الاستلام يقرع رقما
  /// عشوائيا بين 20 و100، فيَعِد بـ45 ويدفع 38 أو 75. المصدر الآن واحد:
  /// [ChapterChest.amountFor] يحسبه هنا وفي الاستلام معا.
  final int rewardCoins;
  final VoidCallback onClaimed;

  const ChapterChestWidget({
    super.key,
    required this.state,
    required this.lang,
    required this.rewardCoins,
    required this.onClaimed,
  });

  @override
  State<ChapterChestWidget> createState() => _ChapterChestWidgetState();
}

class _ChapterChestWidgetState extends State<ChapterChestWidget>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  bool _revealing = false;

  /// كشف من 3 مراحل: 0..0.35 اهتزاز، 0.35..0.7 وميض، 0.7..1 تكبّر وظهور
  static const _shakePhaseEnd = 0.35;
  static const _flashPhaseEnd = 0.7;

  static const _chestSize = 68.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (widget.state != ChestState.unlocked || _revealing) return;
    setState(() => _revealing = true);
    await _controller.forward(from: 0);
    widget.onClaimed();
    if (mounted) setState(() => _revealing = false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final label = switch (widget.state) {
      ChestState.locked => lang.t('صندوق مقفل', 'Locked chest'),
      ChestState.unlocked => lang.t(
        'اضغط لفتح الصندوق!',
        'Tap to open the chest!',
      ),
      ChestState.claimed => lang.t('صندوق مُستلَم', 'Chest claimed'),
    };

    return Pressable(
      onTap: widget.state == ChestState.unlocked ? _open : null,
      semanticLabel: label,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          double dx = 0;
          double glow = 0;
          double scale = 1;
          if (_revealing) {
            if (t < _shakePhaseEnd) {
              final shakeT = t / _shakePhaseEnd;
              dx = (1 - shakeT) * 6 * (((t * 40).floor() % 2 == 0) ? 1 : -1);
            } else if (t < _flashPhaseEnd) {
              glow = (t - _shakePhaseEnd) / (_flashPhaseEnd - _shakePhaseEnd);
            } else {
              glow = 1;
              scale = 1 + ((t - _flashPhaseEnd) / (1 - _flashPhaseEnd)) * 0.25;
            }
          }

          final isOpenable = widget.state == ChestState.unlocked;
          final isClaimed = widget.state == ChestState.claimed;
          final labelColor = isClaimed
              ? HurufTheme.textSecondary
              : isOpenable
              ? HurufTheme.gold
              : HurufTheme.textSecondary;

          return Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(
              scale: scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: _chestSize,
                    height: _chestSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // هالة ذهبية خلف الصندوق القابل للفتح وحده —
                        // تميّزه عن المقفل بلا نصّ إضافي
                        if (isOpenable || glow > 0)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: HurufTheme.gold.withValues(
                                    alpha: 0.35 + glow * 0.45,
                                  ),
                                  blurRadius: 18 + 24 * glow,
                                  spreadRadius: 1 + 4 * glow,
                                ),
                              ],
                            ),
                            child: const SizedBox(width: 34, height: 34),
                          ),
                        _ChestImage(state: widget.state, size: _chestSize),
                        if (widget.state == ChestState.locked)
                          const Positioned(
                            right: 0,
                            bottom: 2,
                            child: _LockBadge(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: HurufTheme.s2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
                  ),
                  if (widget.state != ChestState.claimed) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '+${widget.rewardCoins}',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: HurufTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const AppIcon(AppIcons.gems, size: 12),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// صورة الصندوق بحسب حالته. المقفل يمرّ بمصفوفة رمادية: نفس الصندوق
/// الممتلئ لكن بلا بريق، فيبقى واضحا أن الجائزة موجودة وأنها غير متاحة
/// بعد — بديل الرمز الرمادي المجرّد.
class _ChestImage extends StatelessWidget {
  final ChestState state;
  final double size;

  const _ChestImage({required this.state, required this.size});

  /// مصفوفة تحويل ألوان قياسية إلى تدرّج رمادي (أوزان الإضاءة المعتادة)
  static const _grayscale = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      state == ChestState.claimed ? kChestEmptyAsset : kChestFullAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );

    return switch (state) {
      ChestState.locked => Opacity(
        opacity: 0.55,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(_grayscale),
          child: image,
        ),
      ),
      ChestState.claimed => Opacity(opacity: 0.7, child: image),
      ChestState.unlocked => image,
    };
  }
}

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: HurufTheme.bgTop.withValues(alpha: 0.85),
    ),
    child: const Icon(
      Icons.lock_rounded,
      size: 13,
      color: HurufTheme.textSecondary,
    ),
  );
}
