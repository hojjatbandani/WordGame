// ورقتا التلميح (المواصفة §7.2-7.3): قبل الدفع يرى اللاعب ما سيأخذه وكم
// يكلّف وكم معه، وحين لا تكفي العملات يُعرض الإعلان أولا — لا المتجر.
//
// شاشة اللعب عربية دوما، فالنصوص هنا عربية فقط.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/theme.dart';
import '../../data/economy/hint_pricing.dart';
import '../providers.dart';
import '../screens/shop_screen.dart';
import 'ad_unavailable_toast.dart';
import 'double_reward.dart';
import 'pressable.dart';

enum HintSheetOutcome { cancelled, adRewarded }

String hintName(HintType type) => switch (type) {
  HintType.orderedLetter => 'كشف الحرف التالي',
  HintType.randomLetter => 'كشف حرف عشوائي',
};

String hintDescription(HintType type) => switch (type) {
  HintType.orderedLetter => 'يكشف الحرف التالي في أول كلمة ناقصة',
  HintType.randomLetter => 'يكشف حرفا عشوائيا في أول كلمة ناقصة',
};

/// يعيد true إن وافق اللاعب على الدفع
Future<bool> showHintConfirmSheet(
  BuildContext context, {
  required HintQuote quote,
  required int balance,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    // ارتفاع المحتوى لا 9/16 الشاشة: على الشاشات القصيرة كان الزرّ يُقصّ
    isScrollControlled: true,
    builder: (sheetContext) => _SheetFrame(
      children: [
        _Title(hintName(quote.type)),
        const SizedBox(height: HurufTheme.s1),
        _Sub(hintDescription(quote.type)),
        const SizedBox(height: HurufTheme.s4),
        _PriceRow(cost: quote.cost, balance: balance),
        const SizedBox(height: HurufTheme.s5),
        _SheetButton(
          label: 'استخدم التلميح',
          primary: true,
          onTap: () => Navigator.of(sheetContext).pop(true),
        ),
        const SizedBox(height: HurufTheme.s2),
        _CancelButton(onTap: () => Navigator.of(sheetContext).pop(false)),
      ],
    ),
  );
  return ok ?? false;
}

/// الرصيد لا يكفي: الإعلان (إن توفّر) يمنح التلميح نفسه
Future<HintSheetOutcome> showHintInsufficientSheet(
  BuildContext context,
  WidgetRef ref, {
  required HintQuote quote,
  required int balance,
  required bool showShopLink,
}) async {
  final canWatchAd =
      ref.read(rewardedAdsAvailableProvider) &&
      ref.read(rewardedAdsProvider.notifier).hasBudget;
  final outcome = await showModalBottomSheet<HintSheetOutcome>(
    context: context,
    backgroundColor: Colors.transparent,
    // لا إغلاق بالحاجز أو السحب: إعلان يبدأ ثم تُغلق الورقة يعني مشاهدة
    // بلا تلميح. للخروج زرّ «إلغاء» صريح
    isDismissible: false,
    enableDrag: false,
    // ارتفاع المحتوى لا 9/16 الشاشة: على الشاشات القصيرة كان الزرّ يُقصّ
    isScrollControlled: true,
    builder: (sheetContext) => _InsufficientBody(
      quote: quote,
      balance: balance,
      canWatchAd: canWatchAd,
      showShopLink: showShopLink,
    ),
  );
  return outcome ?? HintSheetOutcome.cancelled;
}

class _InsufficientBody extends ConsumerStatefulWidget {
  final HintQuote quote;
  final int balance;
  final bool canWatchAd;
  final bool showShopLink;

  const _InsufficientBody({
    required this.quote,
    required this.balance,
    required this.canWatchAd,
    required this.showShopLink,
  });

  @override
  ConsumerState<_InsufficientBody> createState() => _InsufficientBodyState();
}

class _InsufficientBodyState extends ConsumerState<_InsufficientBody> {
  bool _busy = false;

  Future<void> _watch() async {
    if (_busy) return;
    setState(() => _busy = true);
    final watched = await ref
        .read(rewardedAdsProvider.notifier)
        .watchForHint(context);
    if (!mounted) return;
    setState(() => _busy = false);
    if (watched) {
      Navigator.of(context).pop(HintSheetOutcome.adRewarded);
    } else {
      showAdUnavailableToast(context, ref.read(languageProvider));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quote;
    return PopScope(
      // رجوع النظام لا يغلقها والإعلان يُحمَّل أو يُعرض
      canPop: !_busy,
      child: _body(q),
    );
  }

  Widget _body(HintQuote q) {
    return _SheetFrame(
      children: [
        _Title('ينقصك ${q.cost - widget.balance} عملة'),
        const SizedBox(height: HurufTheme.s1),
        _Sub('${hintName(q.type)} · السعر ${q.cost} · معك ${widget.balance}'),
        const SizedBox(height: HurufTheme.s5),
        if (widget.canWatchAd)
          _SheetButton(
            key: const ValueKey('hint_ad_button'),
            label: 'شاهد إعلانا واحصل على التلميح',
            icon: Icons.play_circle_fill_rounded,
            // محايد لا ذهبي: سياسة العائلات — إعلان لا يشبه جائزة اللعبة
            // (راجع double_reward.dart، سبب رفض النسخة 9)
            primary: false,
            busy: _busy,
            // سياسة العائلات: كل مدخل إعلان يقول إنه إعلان
            trailing: const AdBadge(),
            onTap: _watch,
          )
        else
          const _Sub('ليس لديك عملات كافية — أكمل المراحل لتجمع العملات'),
        const SizedBox(height: HurufTheme.s2),
        if (widget.showShopLink)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(HintSheetOutcome.cancelled);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ShopScreen(source: 'hint_sheet'),
                ),
              );
            },
            child: const Text(
              'المتجر',
              style: TextStyle(color: HurufTheme.textSecondary),
            ),
          ),
        _CancelButton(
          onTap: () => Navigator.of(context).pop(HintSheetOutcome.cancelled),
        ),
      ],
    );
  }
}

class _SheetFrame extends StatelessWidget {
  final List<Widget> children;
  const _SheetFrame({required this.children});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
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
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ),
  );
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: HurufTheme.gold,
    ),
  );
}

class _Sub extends StatelessWidget {
  final String text;
  const _Sub(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 13, color: HurufTheme.textSecondary),
  );
}

class _PriceRow extends StatelessWidget {
  final int cost;
  final int balance;
  const _PriceRow({required this.cost, required this.balance});

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    runSpacing: HurufTheme.s1,
    children: [
      const AppIcon(AppIcons.gems, size: 22),
      const SizedBox(width: HurufTheme.s1),
      Text('السعر $cost', style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(width: HurufTheme.s4),
      Text(
        'رصيدك $balance ← ${balance - cost}',
        style: const TextStyle(color: HurufTheme.textSecondary),
      ),
    ],
  );
}

class _SheetButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool primary;
  final bool busy;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SheetButton({
    super.key,
    required this.label,
    required this.primary,
    required this.onTap,
    this.icon,
    this.busy = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Pressable(
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
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primary ? HurufTheme.bgTop : HurufTheme.textPrimary,
              ),
            )
          else if (icon != null)
            Icon(
              icon,
              size: 20,
              color: primary ? HurufTheme.bgTop : HurufTheme.textPrimary,
            ),
          if (busy || icon != null) const SizedBox(width: HurufTheme.s2),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: primary ? HurufTheme.bgTop : HurufTheme.textPrimary,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: HurufTheme.s2),
            Flexible(flex: 0, child: trailing!),
          ],
        ],
      ),
    ),
  );
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: 'إلغاء',
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: HurufTheme.s3),
      alignment: Alignment.center,
      child: const Text(
        'إلغاء',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: HurufTheme.textSecondary,
        ),
      ),
    ),
  );
}
