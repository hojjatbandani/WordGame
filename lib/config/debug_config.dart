/// أدوات الاختبار الداخلية — ليست ميزة لعب.
///
/// مطفأة في إصدار المتجر ومشتعلة أثناء التطوير. لتشغيلها في بناء
/// release على جهاز اختبار:
///
///   flutter run --release --dart-define=CHEATS=true
///
/// القيمة ثابتة وقت الترجمة، فالفروع المحمية بها تُحذف كليا من ثنائي
/// الإصدار — لا شيفرة غش تُشحن للاعبين أصلا.
library;

import 'package:flutter/foundation.dart';

/// هل أدوات الاختبار مفعّلة؟
const bool kCheatsEnabled = bool.fromEnvironment(
  'CHEATS',
  defaultValue: kDebugMode,
);

/// كم عملة يمنحها نقر الشعار المزدوج
const int kCheatCoinGrant = 1000;
