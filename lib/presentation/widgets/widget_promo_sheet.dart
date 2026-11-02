import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../config/balance_config.dart';
import '../../core/app_icons.dart';
import '../../core/app_language.dart';
import '../../core/theme.dart';
import 'pressable.dart';

/// عرض «أضف الودجة» — يظهر **مرة واحدة**، وبعد أن يُثبت اللاعب اهتمامه
/// بإتمام عدة مراحل، لا عند أول تشغيل.
///
/// نبرة العرض دعوة لا إلحاح: زرّ «لاحقا» بنفس بروز زرّ «فهمت»، ولا
/// يُعاد السؤال أبدا بعد إغلاقه (راجع `ProgressStore.widgetPromoShown`
/// وهو محفوظ حتى عبر «البدء من جديد»).
class WidgetPromoSheet extends StatelessWidget {
  final AppLanguage lang;

  const WidgetPromoSheet({super.key, required this.lang});

  /// تعليمات الإضافة تختلف بين المنصّتين اختلافا كاملا، ونصّ واحد عام
  /// («أضفها من شاشتك») لا يساعد أحدا
  static String _instructions(AppLanguage lang) {
    if (kIsWeb) {
      return lang.t(
        'افتح اللعبة من هاتفك لإضافة الودجة',
        'Open the game on your phone to add the widget',
      );
    }
    if (Platform.isIOS) {
      return lang.t(
        'اضغط مطوّلا على شاشتك الرئيسية، ثم زرّ + في الأعلى، '
            'ابحث عن «حروف» واختر حجم الودجة.',
        'Touch and hold your Home Screen, tap + at the top, '
            'search for "Huruf" and pick a widget size.',
      );
    }
    if (Platform.isAndroid) {
      return lang.t(
        'اضغط مطوّلا على مساحة فارغة في شاشتك الرئيسية، اختر '
            '«الأدوات» (Widgets)، ثم ابحث عن «حروف» واسحبها إلى الشاشة.',
        'Touch and hold an empty area on your Home screen, tap '
            '"Widgets", then find "Huruf" and drag it onto the screen.',
      );
    }
    return lang.t(
      'الودجة متاحة على الهواتف فقط',
      'The widget is available on phones only',
    );
  }

  static Future<void> show(BuildContext context, AppLanguage lang) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => WidgetPromoSheet(lang: lang),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101C33), Color(0xFF0A1222)],
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lang.t('أضف الودجة', 'Add the widget'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: HurufTheme.textPrimary,
              ),
            ),
            const SizedBox(height: HurufTheme.s2),
            Text(
              lang.t('واحصل على', 'and get'),
              style: const TextStyle(color: HurufTheme.textSecondary),
            ),
            const SizedBox(height: HurufTheme.s2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppIcon(AppIcons.gems, size: 40),
                const SizedBox(width: HurufTheme.s2),
                Text(
                  '${BalanceConfig.widgetActivationRewardCoins}',
                  // رقم لاتيني في سياق عربي — يبقى بترتيبه هو
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: HurufTheme.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: HurufTheme.s3),
            Text(
              lang.t(
                'لا تفوّت جائزتك اليومية — تظهر على شاشتك مباشرة.',
                "Don't miss your daily reward — it shows right on your screen.",
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: HurufTheme.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: HurufTheme.s4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(HurufTheme.s3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(HurufTheme.rButton),
                color: HurufTheme.tileEmpty.withValues(alpha: .55),
              ),
              child: Text(
                _instructions(lang),
                textAlign: TextAlign.start,
                style: const TextStyle(
                  color: HurufTheme.textSecondary,
                  fontSize: 12.5,
                  height: 1.8,
                ),
              ),
            ),
            const SizedBox(height: HurufTheme.s4),
            Row(
              children: [
                Expanded(
                  child: Pressable(
                    onTap: () => Navigator.of(context).pop(),
                    semanticLabel: lang.t('لاحقا', 'Later'),
                    child: Container(
                      height: HurufTheme.minTouch,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          HurufTheme.rButton,
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .16),
                        ),
                      ),
                      child: Text(
                        lang.t('لاحقا', 'Later'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: HurufTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: HurufTheme.s3),
                Expanded(
                  child: Pressable(
                    onTap: () => Navigator.of(context).pop(),
                    semanticLabel: lang.t('فهمت', 'Got it'),
                    child: Container(
                      height: HurufTheme.minTouch,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          HurufTheme.rButton,
                        ),
                        color: HurufTheme.gold,
                      ),
                      child: Text(
                        lang.t('فهمت', 'Got it'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: HurufTheme.bgTop,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
