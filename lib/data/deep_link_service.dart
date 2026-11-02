import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../core/referral_link.dart';
import 'progress_store.dart';

/// يلتقط روابط الدعوة الواردة ويحفظ رمزها كي يُملأ الحقل تلقائيا.
///
/// يغطّي حالتين مختلفتين تماما:
///  1) التطبيق مثبّت مسبقا والرابط نُقر عليه — [_links.uriLinkStream]
///     يصل فورا، وهذا ما تدعمه كل المنصّات التي عرّفنا فيها الرابط.
///  2) التطبيق غير مثبّت والرابط قاد إلى المتجر — لا يصل الرمز إلا لو
///     حمَلَته المنصّة عبر التثبيت (Deferred Deep Link)، وهذه خدمة
///     خارجية لا تقدّمها المنصّات مجانا. لذلك يبقى الرمز مكتوبا حرفيا
///     في نصّ الدعوة، ويبقى إدخاله يدويا مسارا كاملا لا خطّة طوارئ:
///     الرابط تحسين، لا شرط. راجع ReferralLink.
///
/// كل استدعاء هنا محروس: منصّة لا تدعم الروابط (سطح المكتب، الاختبارات)
/// أو إضافة لم تُسجَّل تجعل هذه الدالة تفشل بصمت بدل أن تُسقط الإقلاع.
class DeepLinkService {
  DeepLinkService(this._store, {AppLinks? links})
      : _links = links ?? AppLinks();

  final ProgressStore _store;
  final AppLinks _links;
  StreamSubscription<Uri>? _sub;

  /// يُستدعى مرة عند الإقلاع. [onCode] يُنادى لكل رمز يصل بعد الإقلاع
  /// أيضا (التطبيق يعمل واللاعب نقر رابطا).
  Future<void> start({void Function(String code)? onCode}) async {
    await _handle(await _initialUri(), onCode);
    try {
      _sub = _links.uriLinkStream.listen(
        (uri) => _handle(uri, onCode),
        onError: (Object e) => debugPrint('روابط الدعوة: تعذّرت القراءة — $e'),
      );
    } catch (e) {
      debugPrint('روابط الدعوة: غير مدعومة على هذه المنصّة — $e');
    }
  }

  Future<Uri?> _initialUri() async {
    try {
      return await _links.getInitialLink();
    } catch (e) {
      debugPrint('روابط الدعوة: تعذّرت قراءة الرابط الأول — $e');
      return null;
    }
  }

  Future<void> _handle(Uri? uri, void Function(String code)? onCode) async {
    if (uri == null) return;
    final code = ReferralLink.extractCode(uri.toString());
    if (code == null) return;

    // من استبدل رمزا من قبل لا يستفيد من ثان — لا نحفظ له رمزا يفتح
    // شاشة ثم يُرفض في الخادم
    if (_store.referralRedeemed) return;

    await _store.setPendingInviteCode(code);
    onCode?.call(code);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
