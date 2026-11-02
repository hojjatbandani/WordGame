import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// إعداد Supabase — يُمرَّر عبر --dart-define عند التشغيل/البناء كي لا
/// يُكتب المفتاح داخل الكود مباشرة:
///
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///                --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
///
/// أنشئ مشروعا في supabase.com، شغّل supabase/schema.sql ثم
/// tool/daily_pool_seed.sql في SQL Editor، وفعّل Anonymous Sign-Ins من
/// Authentication → Providers → Anonymous.
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// المفاتيح ممرَّرة عند البناء
  static bool get hasKeys => url.isNotEmpty && publishableKey.isNotEmpty;

  /// نجح الاتصال فعلا. الواجهة تعتمد على هذا لا على [hasKeys]: بلا شبكة
  /// تبقى الميزات السحابية مخفية بدل أن تظهر ثم تفشل عند الضغط.
  static bool _ready = false;
  static bool get isConfigured => hasKeys && _ready;

  /// يهيّئ Supabase دون أن يُسقط التطبيق أبدا.
  ///
  /// كان أي فشل شبكة هنا (DNS، طيران، انقطاع المزوّد) يرمي استثناء غير
  /// ملتقط قبل `runApp` فلا تُقلع اللعبة إطلاقا — رغم أن 500 مرحلة
  /// والتحدّيات كلها تعمل بلا إنترنت. الآن نبتلع الخطأ ونكمل محليا.
  /// أقصى انتظار للاتصال عند الإقلاع. شبكة «ثقب أسود» (واي‌فاي بلا
  /// إنترنت) لا ترمي خطأ سريعا بل تعلّق حتى مهلة النظام، فتبقى شاشة
  /// البدء الأصلية معلّقة معها. بعد هذه المهلة نكمل محليا.
  static const startupTimeout = Duration(seconds: 8);

  static Future<void> initIfConfigured() async {
    if (!hasKeys) return;
    try {
      await Supabase.initialize(
        url: url,
        publishableKey: publishableKey,
      ).timeout(startupTimeout);
      if (Supabase.instance.client.auth.currentSession == null) {
        await Supabase.instance.client.auth
            .signInAnonymously()
            .timeout(startupTimeout);
      }
      _ready = true;
    } catch (e) {
      debugPrint('Supabase: تعذّر الاتصال، نكمل بالوضع المحلي — $e');
      _ready = false;
    }
  }
}
