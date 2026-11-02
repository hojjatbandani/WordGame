import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/ads/ad_format.dart';
import '../../data/ads/rewarded_ads.dart';
import '../../data/store/near_miss.dart';
import '../providers.dart';
import '../screens/shop_screen.dart';
import 'ad_unavailable_toast.dart';
import 'points_message.dart';
import 'pressable.dart';

/// ورقة «ينقصك القليل» — تُفتح حين يعجز اللاعب عن شراء شيء *قرّره هو*
/// بفارق ربع السعر أو أقل.
///
/// ثلاثة خيارات بهذا الترتيب بالضبط، والترتيب متعمَّد:
///   1) شاهد إعلانا — المجاني أولا دوما. تقديم الشراء عليه يجعل الورقة
///      إعلان بيع، وتقديم المجاني يجعلها مساعدة.
///   2) أصغر حزمة كافية — حزمة واحدة لا كتالوج.
///   3) إلغاء — مخرج واضح لا زر رمادي في الزاوية.
///
/// ولا زر «افتح المتجر» هنا: من فتح المتجر ضاع منه سياق ما كان يشتريه.
Future<void> showNearMissSheet(
  BuildContext context,
  WidgetRef ref, {
  required int price,
  required int balance,
  required NearMissTarget target,

  /// يُنفَّذ بعد أن يصبح الرصيد كافيا — إعادة محاولة الشراء نفسه
  required VoidCallback onAffordable,
}) async {
  final rewarded = ref.read(rewardedAdsProvider.notifier);
  final offer = NearMiss.evaluate(
    price: price,
    balance: balance,
    target: target,
    // الإتاحة (سياسة القوالب + مفتاح الإيقاف) قبل الميزانية: خيار إعلان
    // لن يُعرض لا يُعرض
    canWatchAd: ref.read(rewardedAdsAvailableProvider) && rewarded.hasBudget,
    adReward: rewarded.nextReward,
  );

  // نقص أكبر من الحد: لا ورقة إطلاقا. تبقى الرسالة القصيرة القائمة
  // (شريط سفلي فيه كم ينقصك ومدخل للمتجر) — إخبار بلا عرض بيع مقحم في
  // لحظة يكون فيها ما أراده اللاعب بعيدا فعلا.
  if (offer == null) {
    final (itemAr, itemEn) = switch (target) {
      NearMissTarget.hint => ('التلميح', 'The hint'),
      NearMissTarget.retry => ('إعادة المحاولة', 'The retry'),
      NearMissTarget.skip => ('تخطّي المرحلة', 'Skipping the stage'),
      NearMissTarget.cosmetic => ('هذه الزينة', 'This item'),
      NearMissTarget.other => ('هذا', 'This'),
    };
    showNotEnoughPoints(
      context,
      cost: price,
      balance: balance,
      lang: ref.read(languageProvider),
      itemAr: itemAr,
      itemEn: itemEn,
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _NearMissSheet(offer: offer, onAffordable: onAffordable),
  );
}

class _NearMissSheet extends ConsumerStatefulWidget {
  final NearMissOffer offer;
  final VoidCallback onAffordable;

  const _NearMissSheet({required this.offer, required this.onAffordable});

  @override
  ConsumerState<_NearMissSheet> createState() => _NearMissSheetState();
}

class _NearMissSheetState extends ConsumerState<_NearMissSheet> {
  bool _busy = false;

  Future<void> _watchAd() async {
    if (_busy) return;
    final rewarded = ref.read(rewardedAdsProvider.notifier);
    final request = rewarded.begin(RewardedSurface.coinTopUp);
    if (request == null) return;

    setState(() => _busy = true);
    // طويل كإعلان المتجر — السطح نفسه (شحن عملات) فالطول نفسه، والخريطة
    // هي من تقول ذلك.
    final watched = await ref
        .read(adServiceProvider)
        .showRewarded(
          context,
          length: AdFormats.forSurface(RewardedSurface.coinTopUp),
        );
    if (!mounted) return;
    if (!watched) {
      setState(() => _busy = false);
      showAdUnavailableToast(context, ref.read(languageProvider));
      return;
    }
    final granted = rewarded.complete(request);
    setState(() => _busy = false);

    if (!mounted) return;
    Navigator.of(context).pop();
    if (granted > 0 && ref.read(pointsProvider) >= widget.offer.price) {
      widget.onAffordable();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final offer = widget.offer;
    final pack = offer.pack;
    // سعر Google Play بعملة اللاعب؛ حزمة بلا سعر (لا متجر الآن) لا تُعرض
    final packPrice = pack == null
        ? null
        : ref.watch(storeProvider).priceOf(pack.id);

    return Directionality(
      textDirection: lang.textDirection,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          HurufTheme.s5,
          HurufTheme.s4,
          HurufTheme.s5,
          HurufTheme.s6,
        ),
        decoration: const BoxDecoration(
          color: HurufTheme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(HurufTheme.rCard),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: HurufTheme.s4),

            // الرقم هو الرسالة: النقص بالضبط، لا الكتالوج ولا السعر
            Text(
              lang.t(
                'ينقصك ${offer.deficit} عملة',
                'You need ${offer.deficit} more coins',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: HurufTheme.gold,
              ),
            ),
            const SizedBox(height: HurufTheme.s1),
            Text(
              lang.t(
                'السعر ${offer.price} · معك ${offer.balance}',
                'Costs ${offer.price} · you have ${offer.balance}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: HurufTheme.textSecondary,
              ),
            ),
            const SizedBox(height: HurufTheme.s5),

            // 1) المجاني أولا
            if (offer.canWatchAd)
              _SheetButton(
                icon: Icons.play_circle_fill_rounded,
                label: lang.t(
                  'شاهد إعلانا +${offer.adReward}',
                  'Watch an ad +${offer.adReward}',
                ),
                sublabel: offer.adClosesGap
                    ? lang.t('يكفي لإتمام شرائك', 'Enough to finish this')
                    : null,
                primary: true,
                busy: _busy,
                onTap: _watchAd,
              ),
            if (offer.canWatchAd) const SizedBox(height: HurufTheme.s3),

            // 2) أصغر حزمة كافية — واحدة لا كتالوج
            if (pack != null && packPrice != null)
              _SheetButton(
                icon: Icons.shopping_bag_rounded,
                label: lang.t(
                  '${pack.coins} عملة · $packPrice',
                  '${pack.coins} coins · $packPrice',
                ),
                // شراء بمال حقيقي يقول ذلك صراحة — لا يُقرأ جائزة من اللعبة
                sublabel: lang.t(
                  'شراء بمال حقيقي عبر Google Play',
                  'Real-money purchase via Google Play',
                ),
                primary: !offer.canWatchAd,
                busy: false,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ShopScreen(highlightPackId: pack.id),
                    ),
                  );
                },
              ),
            const SizedBox(height: HurufTheme.s3),

            // 3) مخرج واضح
            Pressable(
              onTap: () => Navigator.of(context).pop(),
              semanticLabel: lang.t('إلغاء', 'Cancel'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: HurufTheme.s3),
                alignment: Alignment.center,
                child: Text(
                  lang.t('إلغاء', 'Cancel'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: HurufTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final bool primary;
  final bool busy;
  final VoidCallback onTap;

  const _SheetButton({
    required this.icon,
    required this.label,
    required this.primary,
    required this.busy,
    required this.onTap,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: busy ? () {} : onTap,
      semanticLabel: label,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: HurufTheme.s3,
          horizontal: HurufTheme.s4,
        ),
        decoration: BoxDecoration(
          gradient: primary ? HurufTheme.goldGradient : null,
          color: primary ? null : HurufTheme.tileEmpty,
          borderRadius: BorderRadius.circular(HurufTheme.rButton),
          border: primary
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: HurufTheme.bgTop,
                ),
              )
            else
              Icon(
                icon,
                size: 20,
                color: primary ? HurufTheme.bgTop : HurufTheme.textPrimary,
              ),
            const SizedBox(width: HurufTheme.s3),
            // مرن: عناوين الإنجليزية أطول، ولا يفيض الزرّ على الشاشات الضيّقة
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: primary
                          ? HurufTheme.bgTop
                          : HurufTheme.textPrimary,
                    ),
                  ),
                  if (sublabel != null)
                    Text(
                      sublabel!,
                      style: TextStyle(
                        fontSize: 11,
                        color: primary
                            ? HurufTheme.bgTop.withValues(alpha: 0.75)
                            : HurufTheme.textSecondary,
                      ),
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
