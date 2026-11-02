import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/balance_config.dart';
import '../../core/app_icons.dart';
import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../data/analytics/analytics_event.dart';
import '../../data/ads/ad_format.dart';
import '../../data/ads/rewarded_ads.dart';
import '../../data/iap_service.dart';
import '../../data/login_calendar.dart';
import '../../data/store/starter_pack.dart';
import '../../data/store/store_catalog.dart';
import '../providers.dart';
import '../widgets/ad_unavailable_toast.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/pressable.dart';
import '../widgets/reward_burst_overlay.dart';

/// المتجر: حزم العملات، حزمة البداية، إزالة الإعلانات، المكافأة اليومية،
/// والإعلان الجائزي.
///
/// **لا يُفتح تلقائيا أبدا.** لا عند إتمام مرحلة، ولا عند نفاد العملات،
/// ولا بمؤقّت. يُفتح بفعل من اللاعب وحده: تبويب المتجر في الشريط
/// السفلي، أو لمس رصيده في الترويسة، أو ورقة «ينقصك القليل» التي فتحها
/// هو أصلا بمحاولة شراء.
class ShopScreen extends ConsumerStatefulWidget {
  /// حزمة تُبرَز عند الفتح — تصل من ورقة «ينقصك القليل» كي لا يضيع
  /// السياق: اللاعب جاء لشيء بعينه لا ليتصفّح
  final String? highlightPackId;

  const ShopScreen({super.key, this.highlightPackId});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  bool _purchasing = false;
  int? _successPoints;

  @override
  void initState() {
    super.initState();
    // Google Play لم يُجب عند الإقلاع (بلا اتصال، أو لم يجهز بعد): يُسأل
    // ثانية الآن، فتظهر الأسعار بلا إعادة تشغيل التطبيق
    unawaited(ref.read(storeProvider.notifier).refresh());
  }

  static const _packGradients = <String, List<Color>>{
    SkuIds.coins500: [Color(0xFF0F3443), Color(0xFF34E89E)],
    SkuIds.coins1650: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
    SkuIds.coins4800: [Color(0xFFB24592), Color(0xFFFF9F1C)],
    SkuIds.coins16000: [Color(0xFF1A1F3A), Color(0xFFC99A10)],
  };

  AppLanguage get _lang => ref.read(languageProvider);

  /// يشتري [sku] ويعرض ما آل إليه.
  ///
  /// التسليم ليس هنا: خدمة الدفع تسلّم كل شراء موثَّق عبر StoreNotifier
  /// (providers.dart) حتى لو أُغلقت هذه الشاشة وسط الدفع أو اعتُمد الدفع
  /// بعد ساعات. الشاشة تعرض النتيجة فقط.
  Future<void> _purchase(String sku) async {
    final lang = _lang;
    final store = ref.read(storeProvider.notifier);
    setState(() => _purchasing = true);
    final result = await store.buy(sku);
    if (!mounted) return;
    setState(() => _purchasing = false);

    switch (result.status) {
      case PurchaseStatus.success:
        HapticFeedback.mediumImpact();
        if (result.delivery.coins > 0) {
          setState(() => _successPoints = result.delivery.coins);
        }
        if (result.delivery.firstPurchase) _showFirstPurchaseBonus();
      case PurchaseStatus.pending:
        _toast(
          lang.t(
            'الدفع قيد المعالجة — تصلك مشترياتك تلقائيا فور اعتماده',
            'Payment is processing — your items arrive as soon as it clears',
          ),
        );
      case PurchaseStatus.alreadyOwned:
        _toast(
          lang.t(
            'تملك هذا المنتج بالفعل — استُعيد إلى حسابك',
            'You already own this — it has been restored',
          ),
        );
      case PurchaseStatus.cancelled:
        break;
      case PurchaseStatus.unavailable:
      case PurchaseStatus.failed:
        _toast(
          lang.t(
            'تعذر إتمام الشراء، حاول مجددا',
            'Purchase failed, please try again',
          ),
        );
    }
  }

  /// مكافأة الشراء الأول تُعلَن صراحة: «أخذت أكثر مما دفعت» لا يعمل إن
  /// لم يره اللاعب
  void _showFirstPurchaseBonus() {
    final lang = _lang;
    final percent = ((BalanceConfig.firstPurchaseCoinMultiplier - 1) * 100)
        .round();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          backgroundColor: HurufTheme.surface,
          content: Text(
            lang.t(
              'هدية أول شراء: +$percent٪ عملات لمدة 24 ساعة 🎁',
              'First purchase gift: +$percent% coins for 24 hours 🎁',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
  }

  Future<void> _buyCoins(CoinPack pack) async {
    final price = ref.read(storeProvider).priceOf(pack.id);
    if (price == null) return;
    final lang = _lang;
    ref.logEvent(Ev.purchaseStarted, {'sku': pack.id, 'coins': pack.coins});
    final confirmed = await _showConfirmSheet(
      title: lang.t(pack.nameAr, pack.nameEn),
      body: lang.t('${pack.coins} عملة', '${pack.coins} coins'),
      priceLabel: price,
    );
    if (confirmed != true || !mounted) return;
    await _purchase(pack.id);
  }

  /// حزمة البداية: مرة واحدة لكل حساب. [fromOffer] = جاءت من عرض الشراء
  /// الأول (للتحليلات وحدها: السعر هو سعر Google Play نفسه).
  Future<void> _buyStarterPack({bool fromOffer = false}) async {
    if (ref.read(purchaseStateProvider).starterPackOwned) return;
    final price = ref.read(storeProvider).priceOf(SkuIds.starterPack);
    if (price == null) return;
    final lang = _lang;
    ref.logEvent(Ev.purchaseStarted, {
      'sku': SkuIds.starterPack,
      'from_offer': fromOffer,
    });

    // نصّ التأكيد يذكر التقسيط صراحة: من ظنّ أنه يشتري 600 دفعة واحدة
    // ثم وجد 300 يقرأها خصما لا جدولا، مهما كان الجدول في صالحه
    final confirmed = await _showConfirmSheet(
      title: lang.t('حزمة البداية', 'Starter Pack'),
      body: lang.t(
        '${StoreCatalog.starterPackCoins} عملة على '
            '${StoreCatalog.starterPackDays} أيام + '
            '${StoreCatalog.starterPackHintCharges} تلميحات',
        '${StoreCatalog.starterPackCoins} coins over '
            '${StoreCatalog.starterPackDays} days + '
            '${StoreCatalog.starterPackHintCharges} hints',
      ),
      priceLabel: price,
    );
    if (confirmed != true || !mounted) return;
    // الزيّ والإطار والقسط الأول يُمنحون عند التسليم (StoreNotifier). لا
    // يُوعَد بالزينة في نصّ الشراء ما دامت لا تظهر للاعب بعد
    await _purchase(SkuIds.starterPack);
  }

  /// يقبض قسط اليوم من حزمة البداية
  Future<void> _claimStarterInstallment() async {
    final installment = await ref.read(starterPackProvider.notifier).claim();
    if (installment == null || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _successPoints = installment.coins);
  }

  Future<bool?> _showConfirmSheet({
    required String title,
    required String body,
    required String priceLabel,
  }) {
    final lang = _lang;
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Directionality(
        textDirection: lang.textDirection,
        child: Container(
          margin: const EdgeInsets.all(HurufTheme.s4),
          padding: const EdgeInsets.all(HurufTheme.s5),
          decoration: BoxDecoration(
            color: HurufTheme.surface,
            borderRadius: BorderRadius.circular(HurufTheme.rCard),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: HurufTheme.s2),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: HurufTheme.textSecondary,
                ),
              ),
              const SizedBox(height: HurufTheme.s5),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: HurufTheme.gold,
                        foregroundColor: HurufTheme.bgTop,
                        padding: const EdgeInsets.symmetric(
                          vertical: HurufTheme.s3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            HurufTheme.rButton,
                          ),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(
                        lang.t('شراء $priceLabel', 'Buy $priceLabel'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: HurufTheme.s3),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      lang.t('إلغاء', 'Cancel'),
                      style: const TextStyle(color: HurufTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              // السعر أعلاه هو ما يُدفع بعملة اللاعب، وورقة Google هي من
              // تأخذ الدفع — الفرق بين عملات اللعبة والمال الحقيقي صريح
              if (Theme.of(context).platform == TargetPlatform.android) ...[
                const SizedBox(height: HurufTheme.s2),
                Text(
                  lang.t(
                    'الدفع بمال حقيقي عبر Google Play',
                    'Paid with real money via Google Play',
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    color: HurufTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _buyRemoveAds() async {
    if (ref.read(adsRemovedProvider)) return;
    final price = ref.read(storeProvider).priceOf(SkuIds.removeAds);
    if (price == null) return;
    final lang = _lang;
    ref.logEvent(Ev.purchaseStarted, {'sku': SkuIds.removeAds});
    // «بين المراحل» لا «كل الإعلانات»: فيديو المكافأة يبقى خيارا يطلبه
    // اللاعب بنفسه، ووعد أوسع مما يُسلَّم يعني طلبات استرداد
    final confirmed = await _showConfirmSheet(
      title: lang.t('إزالة الإعلانات', 'Remove Ads'),
      body: lang.t(
        'بدون إعلانات بين المراحل أبدا + هدية ${StoreCatalog.removeAdsGiftCoins} عملة\n'
            'فيديوهات المكافأة الاختيارية تبقى متاحة لمن يريدها',
        'No ads between levels ever + a ${StoreCatalog.removeAdsGiftCoins} coin gift\n'
            'Optional reward videos stay available if you want them',
      ),
      priceLabel: price,
    );
    if (confirmed != true || !mounted) return;
    await _purchase(SkuIds.removeAds);
  }

  void _claimDaily() {
    final reward = ref.read(dailyRewardProvider.notifier).claim();
    if (reward != null) {
      HapticFeedback.mediumImpact();
      setState(() => _successPoints = reward.coins);
    }
  }

  /// إعلان جائزي من المتجر. يستهلك من *الميزانية المشتركة* نفسها التي
  /// تستهلكها العجلة ووضع الأمان وورقة «ينقصك القليل» — أربع مشاهدات في
  /// اليوم لكل التطبيق لا لكل شاشة.
  ///
  /// طويل بحكم سطحه ([AdFormats.forSurface] لـ[RewardedSurface.coinTopUp]):
  /// اللاعب جاء إلى المتجر يريد عملات، فالمشاهدة ثمن دفعه قاصدا.
  Future<void> _watchAd() async {
    // البطاقة لا تُرسم حين لا يُتاح القالب؛ هذا حارس لأي مسار آخر يصل هنا
    if (!ref.read(rewardedAdsAvailableProvider)) return;
    final rewarded = ref.read(rewardedAdsProvider.notifier);
    final request = rewarded.begin(
      RewardedSurface.coinTopUp,
      amount: BalanceConfig.shopAdRewardCoins,
    );
    if (request == null) {
      _toast(
        _lang.t(
          'استنفدت إعلانات اليوم، عد غدا!',
          'You\'ve used today\'s ads, come back tomorrow!',
        ),
      );
      return;
    }

    setState(() => _purchasing = true);
    var watched = false;
    try {
      watched = await ref
          .read(adServiceProvider)
          .showRewarded(
            context,
            length: AdFormats.forSurface(RewardedSurface.coinTopUp),
          );
    } finally {
      // الطبقة التي تحجب الشاشة وزرّ الرجوع لا تبقى بعد استثناء
      if (mounted) setState(() => _purchasing = false);
    }
    if (!mounted) return;
    // لا إعلان أو أُغلق مبكرا: لا منح ولا استهلاك — الطلب لم يُكمَل
    if (!watched) {
      showAdUnavailableToast(context, _lang);
      return;
    }

    // المبلغ المُضاف هو المبلغ المعروض على الزر قبل المشاهدة
    final granted = rewarded.complete(request);
    if (granted > 0) {
      HapticFeedback.mediumImpact();
      setState(() => _successPoints = granted);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
          backgroundColor: HurufTheme.surface,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final points = ref.watch(pointsProvider);
    final daily = ref.watch(dailyRewardProvider);
    final adsRemoved = ref.watch(adsRemovedProvider);
    final purchase = ref.watch(purchaseStateProvider);
    final lang = ref.watch(languageProvider);
    final offer = purchase.activeOffer(DateTime.now());
    final starterPack = ref.watch(starterPackProvider);
    // ما لا سعر له من Google Play لا يُعرض للبيع: الرقم المعروض هو الرقم
    // المدفوع بعملة اللاعب، أو لا شيء
    final shop = ref.watch(storeProvider);
    final starterPrice = purchase.starterPackOwned
        ? null
        : shop.priceOf(SkuIds.starterPack);
    final removeAdsPrice = shop.priceOf(SkuIds.removeAds);
    final packs = [
      for (final p in StoreCatalog.coinPacks)
        if (shop.priceOf(p.id) case final price?) (pack: p, price: price),
    ];

    // لا رجوع أثناء معاملة شراء جارية: التسليم لا يتوقّف على الشاشة (راجع
    // _purchase)، لكن إغلاق المتجر وسط الدفع تجربة مربكة بلا فائدة
    return PopScope(
      canPop: !_purchasing,
      child: Scaffold(
        body: AnimatedBackground(
          child: SafeArea(
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(HurufTheme.s4),
                  children: [
                    _buildHeader(points, lang),
                    const SizedBox(height: HurufTheme.s4),

                    // عرض الشراء الأول أولا حين يكون ساريا — هو السبب
                    // الوحيد الذي جاء اللاعب من أجله في تلك اللحظة
                    if (offer != null && starterPrice != null) ...[
                      _StarterPackCard(
                        lang: lang,
                        price: starterPrice,
                        featured: true,
                        onTap: () => _buyStarterPack(fromOffer: true),
                      ),
                      const SizedBox(height: HurufTheme.s4),
                    ],

                    // أقساط حزمة البداية — فوق كل شيء بعد العرض: ما دُفع
                    // ثمنه ولم يُسلَّم بعد يسبق ما يُعرض للبيع
                    if (purchase.starterPackOwned &&
                        !starterPack.isFullyDelivered) ...[
                      _StarterInstallmentsCard(
                        lang: lang,
                        status: starterPack,
                        onClaim: _claimStarterInstallment,
                      ),
                      const SizedBox(height: HurufTheme.s4),
                    ],

                    _buildDailyCard(daily, lang),
                    const SizedBox(height: HurufTheme.s4),

                    if (offer == null && starterPrice != null) ...[
                      _StarterPackCard(
                        lang: lang,
                        price: starterPrice,
                        onTap: () => _buyStarterPack(),
                      ),
                      const SizedBox(height: HurufTheme.s4),
                    ],

                    // المفعَّلة تُعرض دوما (حالة يملكها اللاعب)؛ غير المفعَّلة
                    // بسعرها فقط
                    if (adsRemoved || removeAdsPrice != null) ...[
                      _buildRemoveAdsCard(adsRemoved, lang, removeAdsPrice),
                      const SizedBox(height: HurufTheme.s4),
                    ],
                    if (packs.isNotEmpty) ...[
                      _SectionTitle(lang.t('حزم العملات', 'Coin Packs')),
                      const SizedBox(height: HurufTheme.s3),
                    ],
                    for (final (:pack, :price) in packs) ...[
                      _CoinPackCard(
                        pack: pack,
                        price: price,
                        gradient: _packGradients[pack.id]!,
                        lang: lang,
                        highlighted: pack.id == widget.highlightPackId,
                        onTap: () => _buyCoins(pack),
                      ),
                      const SizedBox(height: HurufTheme.s3),
                    ],
                    // لا متجر الآن (لا Google Play، أو لم تصل الأسعار بلا
                    // اتصال): سطر يشرح بدل قسم يختفي بصمت
                    if (!shop.anyForSale && !adsRemoved) ...[
                      Text(
                        lang.t(
                          'الشراء غير متاح الآن — تحقّق من اتصالك ومن Google Play',
                          'Purchases are unavailable right now — check your connection and Google Play',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: HurufTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: HurufTheme.s4),
                    ],
                    // «عملات مجانية» قسم إعلان جائزي وحده: يختفي كلّه حين
                    // لا يُتاح القالب، لا عنوانا فوق زرّ ميّت
                    if (ref.watch(rewardedAdsAvailableProvider)) ...[
                      _SectionTitle(
                        lang.t(
                          'عملات مقابل مشاهدة إعلان',
                          'Coins for watching ads',
                        ),
                      ),
                      const SizedBox(height: HurufTheme.s3),
                      _buildAdCard(lang),
                    ],
                    const SizedBox(height: HurufTheme.s6),
                  ],
                ),
                if (_purchasing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    child: const Center(
                      child: CircularProgressIndicator(color: HurufTheme.gold),
                    ),
                  ),
                if (_successPoints != null)
                  RewardBurstOverlay(
                    points: _successPoints!,
                    lang: lang,
                    onDismiss: () => setState(() => _successPoints = null),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int points, AppLanguage lang) {
    return Row(
      children: [
        IconButton(
          tooltip: lang.t('رجوع', 'Back'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: HurufTheme.textSecondary,
            size: 20,
          ),
        ),
        Expanded(
          child: Text(
            lang.t('المتجر', 'Shop'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
        GlassCard(
          radius: HurufTheme.rButton,
          padding: const EdgeInsets.symmetric(
            horizontal: HurufTheme.s3,
            vertical: HurufTheme.s1,
          ),
          child: Row(
            children: [
              const AppIcon(AppIcons.gems, size: 26),
              const SizedBox(width: HurufTheme.s1),
              Text(
                '$points',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: HurufTheme.gold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyCard(DailyRewardState daily, AppLanguage lang) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.card_giftcard_rounded,
                size: HurufTheme.iconMd,
                color: HurufTheme.gold,
              ),
              const SizedBox(width: HurufTheme.s2),
              Expanded(
                child: Text(
                  lang.t('المكافأة اليومية', 'Daily Reward'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: daily.canClaim
                      ? HurufTheme.gold
                      : HurufTheme.tileEmpty,
                  foregroundColor: daily.canClaim
                      ? HurufTheme.bgTop
                      : HurufTheme.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HurufTheme.rButton),
                  ),
                ),
                onPressed: daily.canClaim ? _claimDaily : null,
                child: Text(
                  daily.canClaim
                      ? '+${daily.nextReward.coins}'
                      : lang.t('غدا', 'Tomorrow'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: HurufTheme.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // يعرض الأسبوع الحالي فقط من تقويم متصاعد لا ينتهي (لا
              // يتصفّر أبدا بفوات يوم) — راجع lib/data/login_calendar.dart.
              // موضع "اليوم" داخل هذا الأسبوع:
              // مرنة: سبع رقاقات بعرض ثابت كانت تفيض على هواتف 320 نقطة
              for (var day = 1; day <= 7; day++)
                Flexible(child: _dayChipFor(day, daily.todayPosition)),
            ],
          ),
        ],
      ),
    );
  }

  /// رقاقة اليوم [day] (1..7) ضمن الأسبوع المعروض حاليا — الأسبوع الذي
  /// يقع فيه [todayPosition] (الموضع المطلَق في التقويم المتصاعد).
  Widget _dayChipFor(int day, int todayPosition) {
    final dayInWeek = (todayPosition - 1) % 7 + 1; // 1..7
    final chipPosition = todayPosition - dayInWeek + day;
    final state = chipPosition < todayPosition
        ? _DayState.claimed
        : chipPosition == todayPosition
        ? _DayState.today
        : _DayState.future;
    return _DayChip(
      day: day,
      reward: LoginCalendar.rewardForPosition(chipPosition).coins,
      state: state,
    );
  }

  /// [price] null حين تكون مفعّلة (لا شيء يُباع) — البطاقة تعرض الحالة
  Widget _buildRemoveAdsCard(bool adsRemoved, AppLanguage lang, String? price) {
    return Pressable(
      onTap: adsRemoved ? null : _buyRemoveAds,
      semanticLabel: adsRemoved
          ? lang.t('إزالة الإعلانات مفعّلة', 'Ads removed is active')
          : lang.t(
              'إزالة الإعلانات بين المراحل مقابل $price',
              'Remove ads between levels for $price',
            ),
      child: Container(
        padding: const EdgeInsets.all(HurufTheme.s4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: adsRemoved
                ? [
                    HurufTheme.success.withValues(alpha: 0.25),
                    HurufTheme.success.withValues(alpha: 0.1),
                  ]
                : [
                    const Color(0xFF232A4D).withValues(alpha: 0.7),
                    const Color(0xFF0F3443).withValues(alpha: 0.5),
                  ],
          ),
          borderRadius: BorderRadius.circular(HurufTheme.rCard),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Text(adsRemoved ? '✅' : '🚫', style: const TextStyle(fontSize: 26)),
            const SizedBox(width: HurufTheme.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.t('إزالة الإعلانات', 'Remove Ads'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    adsRemoved
                        ? lang.t(
                            'مفعّلة — استمتع بلعب بلا مقاطعات',
                            'Active — enjoy playing without interruptions',
                          )
                        : lang.t(
                            'بدون إعلانات بين المراحل + هدية ${StoreCatalog.removeAdsGiftCoins} عملة',
                            'No ads between levels + a ${StoreCatalog.removeAdsGiftCoins} coin gift',
                          ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: HurufTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!adsRemoved && price != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: HurufTheme.s3,
                  vertical: HurufTheme.s2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(HurufTheme.rButton),
                ),
                child: Text(
                  price,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// المبلغ يُعرض *قبل* المشاهدة دوما — ثابت للمتجر
  /// ([BalanceConfig.shopAdRewardCoins]) لا سلّم بقية السطوح.
  Widget _buildAdCard(AppLanguage lang) {
    final ledger = ref.watch(rewardedAdsProvider);
    final remaining = ledger.remaining;
    final reward = BalanceConfig.shopAdRewardCoins;
    return GlassCard(
      child: Row(
        children: [
          const Icon(
            Icons.smart_display_rounded,
            size: HurufTheme.iconMd,
            color: HurufTheme.success,
          ),
          const SizedBox(width: HurufTheme.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.t('شاهد إعلانا', 'Watch an Ad'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  remaining > 0
                      ? lang.t(
                          '+$reward عملة — متبق $remaining اليوم',
                          '+$reward coins — $remaining left today',
                        )
                      : lang.t('انتهت مشاهدات اليوم', 'No views left today'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: HurufTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: remaining > 0
                  ? HurufTheme.success
                  : HurufTheme.tileEmpty,
              foregroundColor: HurufTheme.bgTop,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(HurufTheme.rButton),
              ),
            ),
            onPressed: remaining > 0 ? _watchAd : null,
            child: Text(
              lang.t('مشاهدة', 'Watch'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

enum _DayState { claimed, today, future }

class _DayChip extends StatelessWidget {
  final int day;
  final int reward;
  final _DayState state;

  const _DayChip({
    required this.day,
    required this.reward,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = state == _DayState.today;
    final claimed = state == _DayState.claimed;
    return Column(
      children: [
        Container(
          width: 38,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isToday ? HurufTheme.goldGradient : null,
            color: isToday
                ? null
                : claimed
                ? HurufTheme.gold.withValues(alpha: 0.18)
                : HurufTheme.tileEmpty,
            borderRadius: BorderRadius.circular(HurufTheme.rTile),
            border: Border.all(
              color: isToday
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: claimed
              ? const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: HurufTheme.gold,
                )
              : Text(
                  '$reward',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isToday
                        ? HurufTheme.bgTop
                        : HurufTheme.textSecondary,
                  ),
                ),
        ),
        const SizedBox(height: 2),
        Text(
          '$day',
          style: const TextStyle(fontSize: 10, color: HurufTheme.textSecondary),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: HurufTheme.textSecondary,
      ),
    );
  }
}

/// سطر جدول الأقساط: «اليوم ١: ٣٠٠ · اليوم ٢: ٢٠٠ · اليوم ٣: ١٠٠».
///
/// مولَّد من [StoreCatalog.starterPackDailyCoins] لا مكتوب يدويا: نصّ
/// ثابت يعد بأرقام لا يمنحها الكود هو الوعد الكاذب الوحيد الذي لا يسقط
/// منه اختبار.
String starterPackScheduleLine(AppLanguage lang) {
  final days = StoreCatalog.starterPackDailyCoins;
  return [
    for (var i = 0; i < days.length; i++)
      lang.t('اليوم ${i + 1}: ${days[i]}', 'Day ${i + 1}: ${days[i]}'),
  ].join(' · ');
}

/// حزمة البداية — مرة واحدة لكل حساب.
///
/// [price] هو سعر Google Play بعملة اللاعب، ولا سعر سواه: لا سعر مشطوب ولا
/// شارة خصم ولا عدّاد. خصم حقيقي يحتاج منتجا بسعره في Play Console، ورقم
/// لا يُدفع فعلا لا يُعرض. [featured] = عرض الشراء الأول قائم: إطار أوضح
/// وموضع أعلى في المتجر، بالسعر نفسه.
class _StarterPackCard extends StatelessWidget {
  final AppLanguage lang;
  final String price;
  final bool featured;
  final VoidCallback onTap;

  const _StarterPackCard({
    required this.lang,
    required this.price,
    required this.onTap,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: lang.t(
        'حزمة البداية مقابل $price',
        'Starter Pack for $price',
      ),
      child: Container(
        padding: const EdgeInsets.all(HurufTheme.s4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              HurufTheme.gold.withValues(alpha: 0.30),
              const Color(0xFF4A00E0).withValues(alpha: 0.35),
            ],
          ),
          borderRadius: BorderRadius.circular(HurufTheme.rCard),
          border: Border.all(
            color: HurufTheme.gold.withValues(alpha: featured ? 0.7 : 0.3),
          ),
        ),
        child: Row(
          children: [
            const Text('🎁', style: TextStyle(fontSize: 34)),
            const SizedBox(width: HurufTheme.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.t('حزمة البداية', 'Starter Pack'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    lang.t(
                      '${StoreCatalog.starterPackCoins} عملة + '
                          '${StoreCatalog.starterPackHintCharges} تلميحات',
                      '${StoreCatalog.starterPackCoins} coins + '
                          '${StoreCatalog.starterPackHintCharges} hints',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: HurufTheme.textSecondary,
                    ),
                  ),
                  // الجدول تحت السعر مباشرة: التقسيط شرط في الصفقة
                  // لا مفاجأة تُكتشف بعد الدفع
                  const SizedBox(height: 3),
                  Text(
                    starterPackScheduleLine(lang),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: HurufTheme.gold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang.t(
                      'مرة واحدة لكل حساب · الأقساط لا تسقط',
                      'Once per account · installments never expire',
                    ),
                    style: TextStyle(
                      fontSize: 10,
                      color: HurufTheme.textSecondary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: HurufTheme.s3,
                vertical: HurufTheme.s2,
              ),
              decoration: BoxDecoration(
                gradient: HurufTheme.goldGradient,
                borderRadius: BorderRadius.circular(HurufTheme.rButton),
              ),
              child: Text(
                price,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: HurufTheme.bgTop,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// أقساط حزمة البداية بعد شرائها: ما قُبض، وما بقي، وقسط اليوم إن حان.
///
/// تختفي البطاقة من تلقائها حين تُسلَّم الأقساط كلها — لا تبقى مساحة
/// ميتة في المتجر تذكّر بشراء انتهى.
class _StarterInstallmentsCard extends StatelessWidget {
  final AppLanguage lang;
  final StarterPackStatus status;
  final VoidCallback onClaim;

  const _StarterInstallmentsCard({
    required this.lang,
    required this.status,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final claimable = status.claimable;
    final total = StarterPackDelivery.totalInstallments;
    final claimed = total - status.remaining;

    return Container(
      padding: const EdgeInsets.all(HurufTheme.s4),
      decoration: BoxDecoration(
        color: HurufTheme.surface,
        borderRadius: BorderRadius.circular(HurufTheme.rCard),
        border: Border.all(
          color: HurufTheme.gold.withValues(
            alpha: claimable != null ? 0.7 : 0.2,
          ),
        ),
      ),
      child: Row(
        children: [
          const Text('🎁', style: TextStyle(fontSize: 30)),
          const SizedBox(width: HurufTheme.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.t('أقساط حزمة البداية', 'Starter Pack installments'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lang.t(
                    '$claimed من $total مستلَمة',
                    '$claimed of $total claimed',
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    color: HurufTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                // «لا يسقط» مكتوبة هنا أيضا لا في بطاقة البيع وحدها:
                // من فاته يوم يقرؤها في اللحظة التي يقلق فيها
                Text(
                  claimable != null
                      ? lang.t(
                          'قسط اليوم جاهز: ${claimable.coins} عملة',
                          'Today\'s installment: ${claimable.coins} coins',
                        )
                      : lang.t(
                          'القسط التالي غدا — لا يسقط بفوات يوم',
                          'Next one tomorrow — it never expires',
                        ),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: claimable != null
                        ? HurufTheme.gold
                        : HurufTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (claimable != null)
            Pressable(
              onTap: onClaim,
              semanticLabel: lang.t(
                'استلم ${claimable.coins} عملة',
                'Claim ${claimable.coins} coins',
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: HurufTheme.s4,
                  vertical: HurufTheme.s2,
                ),
                decoration: BoxDecoration(
                  gradient: HurufTheme.goldGradient,
                  borderRadius: BorderRadius.circular(HurufTheme.rButton),
                ),
                child: Text(
                  lang.t('استلم', 'Claim'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: HurufTheme.bgTop,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoinPackCard extends StatelessWidget {
  final CoinPack pack;

  /// سعر Google Play بعملة اللاعب
  final String price;
  final List<Color> gradient;
  final AppLanguage lang;
  final bool highlighted;
  final VoidCallback onTap;

  const _CoinPackCard({
    required this.pack,
    required this.price,
    required this.gradient,
    required this.lang,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = lang.t(pack.nameAr, pack.nameEn);
    return Pressable(
      onTap: onTap,
      semanticLabel: lang.t(
        '$name: ${pack.coins} عملة بسعر $price',
        '$name: ${pack.coins} coins for $price',
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(HurufTheme.s4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  gradient[0].withValues(alpha: 0.55),
                  gradient[1].withValues(alpha: 0.35),
                ],
              ),
              borderRadius: BorderRadius.circular(HurufTheme.rCard),
              border: Border.all(
                color: highlighted
                    ? HurufTheme.gold
                    : Colors.white.withValues(alpha: 0.18),
                width: highlighted ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (highlighted ? HurufTheme.gold : gradient[1])
                      .withValues(alpha: highlighted ? 0.45 : 0.25),
                  blurRadius: highlighted ? 22 : 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                AppIcon(
                  pack.id == SkuIds.coins16000
                      ? AppIcons.shopChest
                      : AppIcons.coin,
                  size: 52,
                ),
                const SizedBox(width: HurufTheme.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        pack.advertisedBonusPercent > 0
                            ? lang.t(
                                '${pack.coins} عملة · قيمة أعلى بـ${pack.advertisedBonusPercent}٪',
                                '${pack.coins} coins · ${pack.advertisedBonusPercent}% better value',
                              )
                            : lang.t(
                                '${pack.coins} عملة',
                                '${pack.coins} coins',
                              ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: HurufTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HurufTheme.s3,
                    vertical: HurufTheme.s2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(HurufTheme.rButton),
                  ),
                  child: Text(
                    price,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (pack.badgeAr != null)
            Positioned(
              top: -9,
              right: HurufTheme.s4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: HurufTheme.s3,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  gradient: HurufTheme.goldGradient,
                  borderRadius: BorderRadius.circular(HurufTheme.rButton),
                  boxShadow: [
                    BoxShadow(
                      color: HurufTheme.gold.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  lang.t(pack.badgeAr!, pack.badgeEn ?? pack.badgeAr!),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: HurufTheme.bgTop,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
