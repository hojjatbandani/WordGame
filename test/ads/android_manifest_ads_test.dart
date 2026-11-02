// جمهور اللعبة يشمل الأطفال ولا بوّابة عمر فيها، فالبيان النهائي لا يطلب
// معرّف الإعلانات ولا واجهات Privacy Sandbox الإعلانية — مع أن حزمة
// Google Mobile Ads تعلنها كلها فتُدمج تلقائيا. الإزالة قائمة يدوية في
// android/app/src/main/AndroidManifest.xml (tools:node="remove")، وهذا الملف
// يمنع حذف سطر منها، أو إعادة إعلانه، بصمت.
//
// ويحرس معرّف تطبيق AdMob: معرّف حقيقي للوحدات مع معرّف تطبيق اختباري (أو
// من حساب آخر) نسخة لا يُحمَّل فيها إعلان واحد، ولا شيء في التطبيق يقول ذلك.
//
// الاختبار يقرأ بيان المصدر لا البيان المدموج (ذاك لا يوجد إلا بعد بناء
// Gradle)؛ فحص المدموج خطوة من قائمة الإصدار.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/ads/admob_ids.dart';

const _manifestPath = 'android/app/src/main/AndroidManifest.xml';
const _infoPlistPath = 'ios/Runner/Info.plist';

/// معرّفا تطبيق Google الاختباريان الرسميان
const _googleTestAppIds = {
  'ca-app-pub-3940256099942544~3347511713', // أندرويد
  'ca-app-pub-3940256099942544~1458002511', // iOS
};

final _appIdFormat = RegExp(r'^ca-app-pub-(\d+)~\d+$');
final _unitIdFormat = RegExp(r'^ca-app-pub-(\d+)/\d+$');

String _withoutComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

/// قيم com.google.android.gms.ads.APPLICATION_ID في البيان
List<String> _admobAppIdsIn(String manifest) => [
  for (final element in RegExp(
    r'<meta-data\b([^>]*)>',
  ).allMatches(_withoutComments(manifest)))
    if (element
        .group(1)!
        .contains('android:name="com.google.android.gms.ads.APPLICATION_ID"'))
      RegExp(
        r'android:value="([^"]*)"',
      ).firstMatch(element.group(1)!)!.group(1)!,
];

/// قيم عناصر `meta-data` باسم معيّن في البيان
List<String> _metaDataValues(String manifest, String name) => [
  for (final element in RegExp(
    r'<meta-data\b([^>]*)>',
  ).allMatches(_withoutComments(manifest)))
    if (element.group(1)!.contains('android:name="$name"'))
      RegExp(
        r'android:value="([^"]*)"',
      ).firstMatch(element.group(1)!)!.group(1)!,
];

/// يتحقّق من معرّفات وحدات منصّة ومعرّف تطبيقها معا: إمّا كلها فارغة (لم
/// يُعَدّ الحساب بعد — الإصدار بلا إعلانات)، وإمّا كلها حقيقية ومن الناشر
/// نفسه، ومعرّف التطبيق ليس الاختباري.
void _expectConsistentAdMobIds({
  required List<String> unitIds,
  required String appId,
}) {
  expect(appId, matches(_appIdFormat));
  final filled = unitIds.where((id) => id.isNotEmpty).toList();
  if (filled.isEmpty) return;

  expect(filled, hasLength(unitIds.length), reason: 'تُملأ الوحدات معا');
  expect(
    _googleTestAppIds,
    isNot(contains(appId)),
    reason: 'وحدات حقيقية بمعرّف تطبيق اختباري: لا يُحمَّل إعلان واحد',
  );
  final publisher = _appIdFormat.firstMatch(appId)!.group(1);
  for (final id in unitIds) {
    expect(id, matches(_unitIdFormat), reason: 'صيغة ca-app-pub-…/…');
    expect(
      _unitIdFormat.firstMatch(id)!.group(1),
      publisher,
      reason: '$id ليس من حساب الناشر صاحب $appId',
    );
  }
}

/// ما تعلنه play-services-ads 25.4.0 من صلاحيات إعلانية
const _removedAdPermissions = [
  'com.google.android.gms.permission.AD_ID',
  'android.permission.ACCESS_ADSERVICES_AD_ID',
  'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
  'android.permission.ACCESS_ADSERVICES_TOPICS',
];

/// كل عنصر `uses-permission` في البيان، بصفاته
List<Map<String, String>> _usesPermissions(String manifest) {
  // التعليقات أولا: قد تذكر الصلاحية نصّا دون أن تعلنها
  final attribute = RegExp(r'([\w:]+)\s*=\s*"([^"]*)"');
  return [
    for (final element in RegExp(
      r'<uses-permission\b([^>]*)>',
    ).allMatches(_withoutComments(manifest)))
      {
        for (final a in attribute.allMatches(element.group(1)!))
          a.group(1)!: a.group(2)!,
      },
  ];
}

void main() {
  final manifest = File(_manifestPath).readAsStringSync();
  final permissions = _usesPermissions(manifest);

  test('مساحة أسماء tools معلنة على الجذر — بدونها يفشل الدمج كله', () {
    expect(
      manifest,
      contains('xmlns:tools="http://schemas.android.com/tools"'),
    );
  });

  test('ضابط: القارئ يرى صلاحيات البيان الفعلية', () {
    expect(
      permissions.map((p) => p['android:name']),
      containsAll([
        'android.permission.INTERNET',
        'android.permission.RECEIVE_BOOT_COMPLETED',
      ]),
    );
  });

  for (final name in _removedAdPermissions) {
    test('$name مُزالة من البيان المدموج، ولا يعلنها التطبيق نفسه', () {
      final entries = [
        for (final p in permissions)
          if (p['android:name'] == name) p,
      ];
      expect(entries, hasLength(1), reason: 'سطر إزالة واحد لكل صلاحية');
      expect(entries.single['tools:node'], 'remove');
    });
  }

  test('PostHog: التهيئة التلقائية معطّلة — إعداداته من Dart وحده', () {
    expect(_metaDataValues(manifest, 'com.posthog.posthog.AUTO_INIT'), [
      'false',
    ]);
  });

  group('معرّف تطبيق AdMob', () {
    test('معلن في البيان مرة واحدة — بدونه ينهار التطبيق عند الإقلاع', () {
      final ids = _admobAppIdsIn(manifest);
      expect(ids, hasLength(1));
      expect(ids.single, matches(_appIdFormat));
    });

    test('أندرويد: الوحدات الحقيقية ومعرّف التطبيق في البيان من حساب واحد', () {
      _expectConsistentAdMobIds(
        unitIds: AdMobIds.prodUnitIdsFor(TargetPlatform.android),
        appId: _admobAppIdsIn(manifest).single,
      );
    });

    test('iOS: الوحدات الحقيقية ومعرّف التطبيق في Info.plist من حساب واحد', () {
      final plist = File(_infoPlistPath).readAsStringSync();
      final appId = RegExp(
        r'<key>GADApplicationIdentifier</key>\s*<string>([^<]*)</string>',
      ).firstMatch(plist)?.group(1);
      expect(appId, isNotNull);
      _expectConsistentAdMobIds(
        unitIds: AdMobIds.prodUnitIdsFor(TargetPlatform.iOS),
        appId: appId!,
      );
    });

    test('ضابط: الفاحص يرفض وحدات حقيقية بمعرّف تطبيق اختباري أو من حساب '
        'آخر', () {
      const units = [
        'ca-app-pub-1111111111111111/2222222222',
        'ca-app-pub-1111111111111111/3333333333',
      ];
      // متّسق: يمرّ
      _expectConsistentAdMobIds(
        unitIds: units,
        appId: 'ca-app-pub-1111111111111111~4444444444',
      );
      for (final appId in [
        'ca-app-pub-3940256099942544~3347511713',
        'ca-app-pub-9999999999999999~4444444444',
      ]) {
        expect(
          () => _expectConsistentAdMobIds(unitIds: units, appId: appId),
          throwsA(isA<TestFailure>()),
          reason: appId,
        );
      }
      expect(
        () => _expectConsistentAdMobIds(
          unitIds: [units.first, ''],
          appId: 'ca-app-pub-1111111111111111~4444444444',
        ),
        throwsA(isA<TestFailure>()),
        reason: 'وحدة واحدة ممتلئة والأخرى فارغة',
      );
    });
  });
}
