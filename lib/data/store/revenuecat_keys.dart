// مفاتيح RevenueCat العامة (Public SDK keys). المكان الوحيد الذي تُكتب فيه.
//
// المفتاح العام ليس سرّا — يُشحن داخل التطبيق بطبيعته — لكن نوعه يهمّ:
//
//   - مفتاح Test Store (`test_…`): متجر RevenueCat التجريبي، بلا Google
//     Play ولا دفع حقيقي. لنسخة التطوير وحدها.
//   - مفتاح Google Play (`goog_…`) ومفتاح App Store (`appl_…`): الدفع
//     الحقيقي. من لوحة RevenueCat ← Project settings ← API keys.
//
// القاعدة كما في AdMobIds: نسخة التطوير تستعمل مفتاح الاختبار دوما،
// ونسخة الإصدار لا تستعمله أبدا. إن بقي مفتاح الإصدار فارغا فلا متجر في
// الإصدار إطلاقا (لا سعر يُعرض ولا شراء) بدل بيعٍ وهمي.
import 'package:flutter/foundation.dart';

class RevenueCatKeys {
  const RevenueCatKeys._();

  static const String _test = 'test_ujtmOlEdojcWboySIxzoZfHccxT';

  // ───────── ضع مفاتيح الإصدار هنا ─────────
  static const String _prodAndroid = 'goog_aiFpRLcWatYbModbfwLPJkUOGjL';
  static const String _prodIos = '';

  static String get _prod =>
      defaultTargetPlatform == TargetPlatform.iOS ? _prodIos : _prodAndroid;

  /// المفتاح لهذه النسخة، أو null إن لم يُضبط (إصدار بلا مفتاح حقيقي)
  static String? get forThisBuild {
    if (!kReleaseMode) return _test;
    return _prod.isEmpty ? null : _prod;
  }
}
