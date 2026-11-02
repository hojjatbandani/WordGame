import 'store_links.dart';

/// روابط صفحة التقييم في المتجر. Dart صرف بلا أي استيراد من Flutter كي
/// تُختبر مباشرة — البناء هو كل المنطق هنا، والفتح مجرّد تنفيذ.
class StoreReview {
  const StoreReview._();

  /// روابط مرتّبة بالأفضلية لمنصّة أندرويد: تطبيق المتجر أولا (يفتح
  /// الصفحة داخله مباشرة)، ثم رابط الويب لمن لا متجر مثبّت عنده.
  static const androidUrls = <String>[
    'market://details?id=${StoreLinks.androidPackage}',
    StoreLinks.play,
  ];

  /// iOS: `action=write-review` يفتح ورقة كتابة التقييم لا صفحة التطبيق
  /// وحدها — الفارق بين «قيّمنا» وبين «شوف صفحتنا»
  static const iosUrls = <String>[
    '${StoreLinks.appStore}?action=write-review',
    StoreLinks.appStore,
  ];

  /// الروابط المرشّحة بحسب المنصّة. [isIOS] يُمرَّر صراحة (لا Platform هنا)
  /// كي تبقى الدالة قابلة للاختبار على أي منصّة تشغّل الاختبارات.
  static List<String> urlsFor({required bool isIOS}) =>
      isIOS ? iosUrls : androidUrls;
}
