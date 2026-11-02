import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_language.dart';
import '../../core/store_links.dart';
import '../../core/theme.dart';
import '../providers.dart';
import 'pressable.dart';

/// نافذة طلب التقييم في المتجر.
///
/// تُعرض بعد إتمام فصل — لحظة فوز لا لحظة تعثّر، وهي الفارق بين تقييم
/// خمس نجوم وتقييم غاضب. ولا تُعرض أبدا لمن ضغط «قيّم» مرة (راجع
/// appRatedProvider): طلب التقييم من لاعب قيّم فعلا إزعاج بلا مقابل.
///
/// [maybeAskForRating] هي المدخل الوحيد: تقرّر بنفسها هل تُعرض أصلا.
Future<void> maybeAskForRating(
  BuildContext context,
  WidgetRef ref,
  AppLanguage lang,
) async {
  if (ref.read(appRatedProvider)) return;
  // الويب بلا متجر تطبيقات — لا معنى للسؤال هناك
  if (kIsWeb) return;
  // iOS بلا معرّف App Store بعد: الضغط على «قيّم» كان يفتح صفحة غير
  // موجودة ثم يُعلَّم اللاعب «قيّم» فلا يُسأل ثانية أبدا
  if (defaultTargetPlatform == TargetPlatform.iOS &&
      !StoreLinks.hasIosAppId) {
    return;
  }
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _RateAppDialog(lang: lang),
  );
}

class _RateAppDialog extends ConsumerWidget {
  final AppLanguage lang;

  const _RateAppDialog({required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: lang.textDirection,
      child: AlertDialog(
        backgroundColor: HurufTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HurufTheme.rCard),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⭐', style: TextStyle(fontSize: 40)),
            const SizedBox(height: HurufTheme.s2),
            Text(
              lang.t('عجبتك اللعبة؟', 'Enjoying Huruf?'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: HurufTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          lang.t(
            'تقييمك في المتجر يوصّلها للاعبين مثلك — دقيقة واحدة تفرق معنا.',
            'A rating in the store helps players like you find Huruf. It takes a minute.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: HurufTheme.textSecondary,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Pressable(
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref.read(appRatedProvider.notifier).openStoreAndMark();
                },
                semanticLabel: lang.t('قيّم اللعبة', 'Rate the game'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: HurufTheme.s3,
                  ),
                  decoration: BoxDecoration(
                    gradient: HurufTheme.goldGradient,
                    borderRadius: BorderRadius.circular(HurufTheme.rButton),
                  ),
                  child: Text(
                    lang.t('أكيد، أقيّمها', 'Sure, rate it'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: HurufTheme.bgTop,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  lang.t('لاحقا', 'Later'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: HurufTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
