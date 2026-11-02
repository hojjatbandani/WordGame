import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import 'analytics_event.dart';

/// ناقل الأحداث إلى PostHog — نظام التحليلات الوحيد في التطبيق.
///
/// القاعدتان نفسهما اللتان تحكمان [AnalyticsService]: لا يُسقِط التطبيق
/// ولا ينتظره أحد. التهيئة تجري في الخلفية، وما يُسجَّل قبل انتهائها
/// ينتظر دوره في السلسلة نفسها فلا يضيع.
///
/// جمهور اللعبة يشمل الأطفال (سياسة العائلات): لا تسجيل جلسات ولا
/// استبيانات ولا هوية — اللاعب مجهول دائما (لا identify)، فلا ملفّ شخص
/// يُنشأ له. عناوين IP تُجهَّل في إعدادات المشروع (anonymize_ips).
class PostHogSink {
  PostHogSink._(this._ready);

  /// مفتاح مشروع PostHog العامّ (phc_). مصمَّم ليُضمَّن في التطبيق:
  /// يكتب أحداثا فقط ولا يقرأ شيئا.
  static const _apiKey = 'phc_v8CdmLwjm7PX8tEfXBjduxtix7Z68TUJM5i3LzSF74VS';
  static const _host = 'https://eu.i.posthog.com';

  /// التهيئة اليدوية مُعدّة لأندرويد وحده (AndroidManifest.xml يعطّل
  /// التهيئة التلقائية)
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final Future<bool> _ready;

  /// يُنشأ مرة واحدة عند الإقلاع. null حيث لا دعم.
  static PostHogSink? create() {
    if (!isSupported) return null;
    return PostHogSink._(_init());
  }

  static Future<bool> _init() async {
    try {
      final config = PostHogConfig(_apiKey)
        ..host = _host
        ..personProfiles = PostHogPersonProfiles.identifiedOnly
        ..sessionReplay = false
        ..captureApplicationLifecycleEvents = true
        ..debug = kDebugMode;
      await Posthog().setup(config);
      return true;
    } catch (e) {
      debugPrint('PostHog: تعذّرت التهيئة — $e');
      return false;
    }
  }

  void track(AnalyticsEvent e) {
    final properties = propertiesFor(e);
    unawaited(
      _ready
          .then((ready) async {
            if (!ready) return;
            await Posthog().capture(eventName: e.name, properties: properties);
          })
          .catchError((Object err) {
            debugPrint('PostHog: تعذّر التسجيل — $err');
          }),
    );
  }

  /// الخصائص كما تعبر قناة المنصّة إلى SDK أندرويد ثم JSON: نصّ ورقم
  /// منته وبولياني وقوائم/خرائط منها، وما عداها نصّا. السياق (المستوى،
  /// المرحلة، الرصيد) أولا، والفارغ يُسقَط.
  @visibleForTesting
  static Map<String, Object> propertiesFor(AnalyticsEvent e) {
    final out = <String, Object>{};
    void put(String key, Object? rawValue) {
      final value = _value(rawValue);
      if (key.isNotEmpty && value != null) out[key] = value;
    }

    put('player_level', e.playerLevel);
    put('stage_id', e.stageId);
    put('coin_balance', e.coinBalance);
    e.properties.forEach(put);
    return out;
  }

  static Object? _value(Object? v) => switch (v) {
    null => null,
    bool() || String() => v,
    num n => n.isFinite ? n : null,
    List l => [for (final x in l) ?_value(x)],
    Map m => {
      for (final MapEntry(:key, :value) in m.entries) '$key': ?_value(value),
    },
    _ => '$v',
  };
}
