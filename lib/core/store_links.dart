/// روابط المتجر التي تُلحَق بكل نتيجة تُشارَك. Dart صرف.
///
/// الرابط هو نصف سبب وجود المشاركة أصلا: شبكة ملوّنة بلا طريق إلى
/// التطبيق منشور جميل بلا أثر. يُلحَق دوما، ومع رمز الداعي حين يكون
/// اللاعب مؤهَّلا للدعوة (راجع ShareTemplates.level).
library;

class StoreLinks {
  const StoreLinks._();

  /// اسم الحزمة كما هو في android/app/build.gradle.kts (applicationId).
  /// كان هنا اسم آخر لا وجود له، فيفتح طلبُ التقييم صفحةَ «العنصر غير
  /// موجود» ثم يُعلَّم اللاعب «قيّم» فلا يُسأل ثانية أبدا.
  static const androidPackage = 'com.huruf.huruf';

  /// TODO(قبل النشر): معرّف التطبيق الحقيقي من App Store Connect. حتى
  /// يُملأ، لا يُعرض طلب التقييم على iOS إطلاقا (راجع [hasIosAppId]).
  static const iosAppId = '0000000000';

  /// هل صار لدينا معرّف App Store حقيقي؟
  static bool get hasIosAppId => iosAppId != '0000000000';

  static const play =
      'https://play.google.com/store/apps/details?id=$androidPackage';
  static const appStore = 'https://apps.apple.com/app/id$iosAppId';

  /// رابط واحد يوزّع الزائر على متجره — صفحة الهبوط (landing/) هي التي
  /// تكتشف نظامه وتحوّله. رابط واحد في نصّ المشاركة أنظف من رابطين،
  /// ويعمل حين يُعاد إرسال المنشور بين أجهزة مختلفة.
  static const smart = 'https://huruf.game/get';
}
