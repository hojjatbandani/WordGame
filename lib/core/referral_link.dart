/// روابط الدعوة ورموزها. Dart صرف — بلا أي استيراد Flutter — كي يُختبر
/// التحليل بوحدات دون بيئة تشغيل.
///
/// لماذا رابط *ونصّ* معا: الرابط يملأ الرمز تلقائيا حيث تسمح المنصّة
/// (App Links / Universal Links)، لكن نصف الدعوات في الخليج تُرسَل في
/// واتساب حيث قد لا ينقر المستقبِل رابطا أصلا. لذلك يبقى الرمز مكتوبا
/// حرفيا داخل نصّ الدعوة دوما: تفشل الروابط، لا تفشل الحروف الثمانية.
library;

class ReferralLink {
  const ReferralLink._();

  /// نطاق صفحة الهبوط (landing/) — نفس النطاق المستخدم في وسوم canonical
  /// هناك. تغييره يتطلب تحديث assetlinks.json وapple-app-site-association
  /// على الخادم أيضا، وإلا فُتح الرابط في المتصفّح بدل التطبيق.
  static const domain = 'huruf.game';

  /// مسار الدعوة. قصير عمدا: يُقرأ ويُملى صوتيا.
  static const path = 'i';

  /// مخطّط مخصّص كخطّة ثانية حيث لا تعمل روابط الويب (مشاركة داخل
  /// تطبيقات لا تفتح http، أو جهاز لم يُتحقّق من ملكيته للنطاق بعد)
  static const scheme = 'huruf';

  static const codeLength = 8;

  /// الأبجدية نفسها المستخدمة في generate_friend_code بالخادم: بلا
  /// المحارف الملتبسة (0/O و1/I) كي يصحّ إملاء الرمز في مكالمة
  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String forCode(String code) =>
      'https://$domain/$path/${normalize(code)}';

  /// يوحّد شكل الرمز قبل أي مقارنة أو إرسال: أحرف كبيرة، بلا فراغات
  static String normalize(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');

  /// رمز صالح شكليا. لا يعني أنه موجود — الخادم وحده يعرف ذلك.
  static bool isWellFormed(String raw) {
    final code = normalize(raw);
    if (code.length != codeLength) return false;
    return code.split('').every(alphabet.contains);
  }

  /// يستخرج الرمز من أي شكل قد يصل به: رابط ويب، مخطّط مخصّص، معامل
  /// استعلام، أو الرمز وحده منسوخا من رسالة. يعيد null إن لم يجد رمزا
  /// صالحا — لا يرمي أبدا مهما كان المدخل، فمصدره غير موثوق دوما.
  static String? extractCode(String? input) {
    if (input == null) return null;
    final raw = input.trim();
    if (raw.isEmpty) return null;

    // الرمز وحده (اللصق اليدوي من رسالة)
    if (isWellFormed(raw)) return normalize(raw);

    final uri = Uri.tryParse(raw);
    if (uri == null) return null;

    // ?code=XXXXXXXX أو ?i=XXXXXXXX
    for (final key in const ['code', 'i', 'invite', 'ref']) {
      final value = uri.queryParameters[key];
      if (value != null && isWellFormed(value)) return normalize(value);
    }

    // huruf.game/i/XXXXXXXX أو huruf://i/XXXXXXXX — نمسح كل المقاطع بدل
    // افتراض موقع ثابت: بعض المنصّات تضيف مقاطع تتبّع قبل مقطعنا
    for (final segment in uri.pathSegments.reversed) {
      if (isWellFormed(segment)) return normalize(segment);
    }

    return null;
  }

  /// هل يبدو هذا الرابط رابط دعوة لنا أصلا؟ (لتمييزه عن روابط عميقة
  /// أخرى قد تصل للتطبيق لاحقا)
  static bool isInviteUri(Uri uri) =>
      (uri.scheme == scheme || uri.host == domain || uri.host == 'www.$domain')
          ? extractCode(uri.toString()) != null
          : false;
}
