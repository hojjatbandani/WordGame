// شبكات الوساطة (Unity Ads) تُبلَّغ قبل أول طلب إعلان: لا بيع ولا مشاركة
// لبيانات اللاعب (CCPA)، ولا موافقة GDPR يدوية — موافقة UMP/TCF وحدها
// تقرّر في أوروبا، واللعبة بلا بوّابة عمر فكل لاعب قد يكون طفلا.

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/ads/mediation_privacy.dart';

class _RecordingUnity implements UnityPrivacy {
  final calls = <String>[];
  @override
  Future<void> setCCPAConsent(bool consent) async =>
      calls.add('ccpa:$consent');
  @override
  Future<void> setGDPRConsent(bool consent) async =>
      calls.add('gdpr:$consent');
}

void main() {
  test('Unity is told not to sell player data, GDPR left to UMP', () async {
    final unity = _RecordingUnity();
    await MediationPrivacy.apply(unity: unity);
    expect(unity.calls, ['ccpa:false']);
  });

  test('a failing mediation privacy call never breaks ad init', () async {
    await MediationPrivacy.apply(unity: _ThrowingUnity());
  });
}

class _ThrowingUnity implements UnityPrivacy {
  @override
  Future<void> setCCPAConsent(bool consent) async =>
      throw StateError('no plugin');
  @override
  Future<void> setGDPRConsent(bool consent) async =>
      throw StateError('no plugin');
}
