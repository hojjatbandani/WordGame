import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/theme.dart';

/// رسالة واحدة لكل السطوح حين لا يتوفّر إعلان مكافأة الآن.
///
/// «لا يوجد» لا «فشل»: من وجهة اللاعب الشبكة لم تجد إعلانا يناسبه في
/// هذه اللحظة، وهذا يحدث كثيرا في الأسواق الصغيرة — ليس عطلا في اللعبة.
void showAdUnavailableToast(BuildContext context, AppLanguage lang) {
  ScaffoldMessenger.maybeOf(context)
    ?..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          lang.t(
            'لا يوجد إعلان متاح الآن، حاول بعد قليل',
            'No ad available right now, try again shortly',
          ),
          textAlign: TextAlign.center,
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: HurufTheme.surface,
      ),
    );
}
