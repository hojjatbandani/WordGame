// خصوصية شبكات الوساطة: تُضبط قبل أول طلب إعلان (توصية دليل Unity Ads).
//
// Unity Ads تتنافس على الإعلان البيني وحده — لا تدعم قالب البيني الجائزي
// الذي تستعمله اللعبة للمكافآت. معاملة الطفل تصلها من إعداد الطلب
// (AdMobAdService.childSafeRequestConfiguration) ومن تصنيف المشروع نفسه في
// لوحة Unity «موجَّه للأطفال دون 13»؛ وهنا: لا بيع ولا مشاركة لبيانات اللاعب
// (CCPA). موافقة GDPR لا تُضبط يدويا — موافقة UMP/TCF وحدها تقرّر.

import 'package:flutter/foundation.dart';
import 'package:gma_mediation_unity/gma_mediation_unity.dart';

/// ما يلزم من إضافة Unity — واجهة كي تُختبر بلا قناة المنصّة
abstract class UnityPrivacy {
  Future<void> setCCPAConsent(bool consent);
  Future<void> setGDPRConsent(bool consent);
}

/// إضافة الوساطة الحقيقية
class GmaUnityPrivacy implements UnityPrivacy {
  final _plugin = GmaMediationUnity();

  @override
  Future<void> setCCPAConsent(bool consent) => _plugin.setCCPAConsent(consent);

  @override
  Future<void> setGDPRConsent(bool consent) => _plugin.setGDPRConsent(consent);
}

class MediationPrivacy {
  const MediationPrivacy._();

  /// لا يرمي أبدا: إعلانات بلا Unity أهون من إعلانات معطّلة
  static Future<void> apply({required UnityPrivacy unity}) async {
    try {
      await unity.setCCPAConsent(false);
    } catch (e) {
      debugPrint('الوساطة: تعذّر ضبط خصوصية Unity — $e');
    }
  }
}
