import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../screens/shop_screen.dart';

/// رسالة موحّدة عند عدم كفاية النقاط.
///
/// كانت بعض الشاشات ترفض التلميح بصمت تماما (شاشة التحدي اليومي) فيظن
/// اللاعب أن الزر معطّل، وبعضها يعرض نصا بلا أي مخرج. هنا رسالة واحدة
/// تقول كم يحتاج وكم معه، وتفتح المتجر مباشرة.
///
/// [itemAr]/[itemEn]: ما حاول شراءه (الافتراضي: التلميح). الرسالة تُستدعى
/// أيضا لإعادة محاولة التحدي اليومي، وكانت تقول «التلميح بـ…» هناك.
void showNotEnoughPoints(
  BuildContext context, {
  required int cost,
  required int balance,
  required AppLanguage lang,
  String itemAr = 'التلميح',
  String itemEn = 'The hint',
}) {
  final missing = cost - balance;
  // يُلتقط الآن لا عند الضغط: الشريط يعيش على ScaffoldMessenger التطبيق
  // ويبقى أربع ثوان بعد مغادرة الشاشة، وسياقها حينها ميّت
  final navigator = Navigator.of(context);
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      backgroundColor: HurufTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HurufTheme.rButton),
      ),
      content: Directionality(
        textDirection: lang.textDirection,
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: HurufTheme.error, size: HurufTheme.iconMd),
            const SizedBox(width: HurufTheme.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lang.t('نقاطك ما تكفي', 'Not enough points'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: HurufTheme.textPrimary,
                    ),
                  ),
                  Text(
                    lang.t('$itemAr بـ $cost ومعك $balance — ينقصك $missing',
                        '$itemEn costs $cost, you have $balance — $missing short'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: HurufTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      action: SnackBarAction(
        label: lang.t('المتجر', 'Shop'),
        textColor: HurufTheme.gold,
        onPressed: () => navigator.push(
          MaterialPageRoute(builder: (_) => const ShopScreen()),
        ),
      ),
    ));
}
