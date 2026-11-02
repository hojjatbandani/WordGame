import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../data/ads/rewarded_ads.dart';
import '../providers.dart';
import 'ad_unavailable_toast.dart';
import 'pressable.dart';

/// «شاهد فيديو وضاعف الجائزة» — عرض واحد يُستعمل في مكانين: بعد إتمام
/// مرحلة (إعلان قصير)، وعند فتح صندوق الفصل (إعلان طويل). الطول ليس
/// معاملا هنا: يُشتقّ من [surface] وحده عبر خريطة AdFormats.
///
/// المكافأة هنا ليست سلّم الإعلانات المعتاد بل *ضعف ما ربحه اللاعب
/// للتوّ*، فتُستهلك المشاهدة من الميزانية اليومية بلا عملاتها
/// (consumeViewWithoutCoins) ثم يُمنح المبلغ المضاعف صراحة. بلا ذلك
/// يأخذ اللاعب مكافأتين عن مشاهدة واحدة، وتخرج ميزانية اليوم عن حدّها.

/// هل يمكن عرض زرّ المضاعفة أصلا؟ (سياسة القوالب + مفتاح الإطفاء +
/// ميزانية اليوم)
bool canDoubleReward(WidgetRef ref) {
  if (!ref.watch(rewardedAdsAvailableProvider)) return false;
  return ref.watch(rewardedAdsProvider).hasRemaining;
}

/// زرّ المضاعفة. يختفي من تلقائه حين لا ميزانية أو حين تمّت المضاعفة.
class DoubleRewardButton extends ConsumerStatefulWidget {
  /// المبلغ الذي سيُضاف (= الجائزة الأصلية، فيصير المجموع ضعفها)
  final int amount;

  final AppLanguage lang;

  /// السطح — وهو أيضا ما يحدّد طول الإعلان المعروض
  /// ([AdFormats.forSurface]): [RewardedSurface.levelReward] قصير،
  /// [RewardedSurface.chapterChest] طويل.
  final RewardedSurface surface;

  /// تُستدعى بعد نجاح المضاعفة بالمبلغ الممنوح
  final ValueChanged<int> onDoubled;

  const DoubleRewardButton({
    super.key,
    required this.amount,
    required this.lang,
    required this.onDoubled,
    this.surface = RewardedSurface.other,
  });

  @override
  ConsumerState<DoubleRewardButton> createState() => _DoubleRewardButtonState();
}

class _DoubleRewardButtonState extends ConsumerState<DoubleRewardButton> {
  bool _busy = false;
  bool _done = false;

  Future<void> _watch() async {
    if (_busy || _done) return;
    setState(() => _busy = true);
    var granted = 0;
    try {
      granted = await ref
          .read(rewardedAdsProvider.notifier)
          .doubleReward(
            widget.amount,
            surface: widget.surface,
            // الفيديو يُعرض فعلا قبل المنح — الطول يأتي من الخريطة.
            // الزرّ الذي غادرت شاشته قبل بدء العرض (ضغط «التالي» أثناء
            // التحميل) يعيد false فلا تُضاعَف جائزة بلا إعلان
            playAd: (length) async {
              if (!mounted) return false;
              final watched = await ref
                  .read(adServiceProvider)
                  .showRewarded(context, length: length);
              if (!watched && mounted) {
                showAdUnavailableToast(context, widget.lang);
              }
              return watched;
            },
          );
    } finally {
      // استثناء من طبقة الإعلان لا يترك الزرّ دوّارا إلى الأبد
      if (mounted) {
        setState(() {
          _busy = false;
          _done = granted > 0;
        });
      }
    }
    if (!mounted) return;
    if (granted > 0) widget.onDoubled(granted);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    // المبلغ صفر (إعادة لعب مرحلة) = لا شيء يُضاعَف: زرّ كهذا ميّت
    if (_done || widget.amount <= 0 || !canDoubleReward(ref)) {
      return const SizedBox.shrink();
    }

    // سياسة العائلات (رفض النسخة 9: «Unclear ads/offers»): زرّ يعرض
    // إعلانا يجب أن يُقرأ إعلانا لا جائزة من اللعبة. لذلك لا ذهبيّ ولا نبض
    // ولا لمعة كزرّ «المرحلة التالية»، وكلمة «إعلان» مكتوبة صراحة مرتين:
    // شارة ونصّ — لا «فيديو» يحسبه الطفل جزءا من اللعبة.
    return Pressable(
      onTap: _busy ? null : _watch,
      semanticLabel: lang.t(
        'إعلان: شاهد إعلانا واحصل على ${widget.amount} عملة إضافية',
        'Ad: watch an ad for ${widget.amount} more coins',
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          HurufTheme.s3,
          HurufTheme.s2,
          HurufTheme.s4,
          HurufTheme.s2,
        ),
        decoration: BoxDecoration(
          color: HurufTheme.tileEmpty,
          borderRadius: BorderRadius.circular(HurufTheme.rButton),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: HurufTheme.textPrimary,
                    ),
                  )
                : const AdBadge(),
            const SizedBox(width: HurufTheme.s3),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _busy
                        ? lang.t('جاري عرض الإعلان…', 'Showing ad…')
                        : lang.t('ضاعف جائزتك ×2', 'Double it ×2'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: HurufTheme.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  // الربح الملموس لا الوعد المجرّد: كم يدخل الجيب بالضبط
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          lang.t(
                            'شاهد إعلانا  +${widget.amount}',
                            'Watch an ad  +${widget.amount}',
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: HurufTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const AppIcon(AppIcons.gems, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شارة «إعلان» الصغيرة أمام كل زرّ يعرض إعلانا — ما يفصل الإعلان عن
/// محتوى اللعبة بلمحة، كما تشترط سياسة العائلات.
class AdBadge extends ConsumerWidget {
  const AdBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        lang.t('إعلان', 'AD'),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.black,
          height: 1.2,
        ),
      ),
    );
  }
}

/// نافذة صندوق الفصل: كم ربح، وفرصة مضاعفته بمشاهدة.
///
/// تُعرض بعد الاستلام لا قبله: العملات في جيبه فعلا، والمضاعفة إضافة
/// اختيارية — لا مقامرة على ما ربحه.
Future<void> showChestRewardDialog(
  BuildContext context,
  WidgetRef ref,
  AppLanguage lang, {
  required int coins,
}) async {
  if (coins <= 0 || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _ChestRewardDialog(lang: lang, coins: coins),
  );
}

class _ChestRewardDialog extends ConsumerStatefulWidget {
  final AppLanguage lang;
  final int coins;

  const _ChestRewardDialog({required this.lang, required this.coins});

  @override
  ConsumerState<_ChestRewardDialog> createState() => _ChestRewardDialogState();
}

class _ChestRewardDialogState extends ConsumerState<_ChestRewardDialog> {
  late int _total = widget.coins;
  bool _doubled = false;

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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/gold/full.png',
              width: 96,
              height: 96,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: HurufTheme.s2),
            Text(
              lang.t('صندوق الفصل!', 'Chapter chest!'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: HurufTheme.textSecondary,
              ),
            ),
            const SizedBox(height: HurufTheme.s1),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+$_total',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: HurufTheme.gold,
                  ),
                ),
                const SizedBox(width: HurufTheme.s2),
                const AppIcon(AppIcons.gems, size: 26),
              ],
            ),
            if (_doubled) ...[
              const SizedBox(height: 2),
              Text(
                lang.t('تضاعفت!', 'Doubled!'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: HurufTheme.success,
                ),
              ),
            ],
            const SizedBox(height: HurufTheme.s4),
            DoubleRewardButton(
              amount: widget.coins,
              lang: lang,
              // صندوق نهاية الفصل — إعلان طويل
              surface: RewardedSurface.chapterChest,
              onDoubled: (granted) => setState(() {
                _total += granted;
                _doubled = true;
              }),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              lang.t('تمام', 'Done'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: HurufTheme.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
