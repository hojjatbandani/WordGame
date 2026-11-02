import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_config.dart';
import 'balance_overrides.dart';
import 'feature_flags.dart';

/// من أين جاء الإعداد المستخدَم فعلا — للتشخيص وللاختبار
enum RemoteConfigSource {
  /// وصل من الخادم في هذا الإقلاع
  network,

  /// آخر نسخة نجحت سابقا، محفوظة على الجهاز
  cache,

  /// لا شبكة ولا نسخة محفوظة — الأرقام المُصرَّفة في التطبيق
  defaults,
}

class RemoteConfigResult {
  final RemoteConfigSource source;
  final Map<String, Object?> values;
  final FeatureFlags flags;
  final int appliedKeys;

  const RemoteConfigResult({
    required this.source,
    required this.values,
    required this.flags,
    required this.appliedKeys,
  });
}

/// جلب إعدادات التوازن ومفاتيح الإيقاف.
///
/// **لا يُوقف الإقلاع أبدا.** المهلة ثانيتان، وأي فشل (شبكة، مهلة،
/// خادم، JSON تالف) يسقط إلى النسخة المحفوظة ثم إلى الأرقام المُصرَّفة.
/// هذا شرط قبول صريح: زمن الإقلاع بلا خادم يجب أن يساوي زمنه المعتاد،
/// فلا يجوز انتظار شيء أطول من المهلة ولا رمي استثناء يوقف التسلسل.
///
/// والتطبيق يقع مرة واحدة عند الإقلاع البارد لا في منتصف اللعب: تغيّر
/// سعر تلميح تحت يد اللاعب بين ضغطتين عطل لا ميزة.
class RemoteConfigRepository {
  RemoteConfigRepository(this._prefs);

  static const _kCacheKey = 'remote_config_cache_v1';
  static const timeout = Duration(seconds: 2);

  final SharedPreferences _prefs;

  SupabaseClient get _client => Supabase.instance.client;

  /// يجلب ويطبّق. يعيد ما طُبِّق ومن أين جاء.
  Future<RemoteConfigResult> loadAndApply({
    /// نسخة التطبيق الحالية — الخادم يرشّح ما يتطلّب نسخة أحدث
    required String appVersion,
  }) async {
    final fetched = await _fetch(appVersion);
    if (fetched != null) {
      await _cache(fetched);
      return _apply(fetched, RemoteConfigSource.network);
    }

    final cached = _readCache();
    if (cached != null) {
      return _apply(cached, RemoteConfigSource.cache);
    }

    return const RemoteConfigResult(
      source: RemoteConfigSource.defaults,
      values: {},
      flags: FeatureFlags.allOn(),
      appliedKeys: 0,
    );
  }

  Future<Map<String, Object?>?> _fetch(String appVersion) async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final rows = await _client
          .rpc('get_remote_config', params: {'p_app_version': appVersion})
          .timeout(timeout);
      final list = rows as List?;
      if (list == null) return null;
      final out = <String, Object?>{};
      for (final row in list) {
        final map = row as Map<String, dynamic>;
        out[map['key'] as String] = map['value'];
      }
      return out;
    } on TimeoutException {
      debugPrint('الإعداد عن بعد: انتهت المهلة، نكمل بالمحفوظ');
      return null;
    } catch (e) {
      debugPrint('الإعداد عن بعد: تعذّر الجلب — $e');
      return null;
    }
  }

  RemoteConfigResult _apply(
      Map<String, Object?> values, RemoteConfigSource source) {
    final applied = BalanceOverrides.applyAll(values);
    final unknown = BalanceOverrides.unknownKeys(values)
        .where((k) => !FeatureFlags.all.contains(k))
        .toList();
    if (unknown.isNotEmpty) {
      debugPrint('الإعداد عن بعد: مفاتيح غير معروفة تُجوهلت — $unknown');
    }
    return RemoteConfigResult(
      source: source,
      values: values,
      flags: FeatureFlags.fromConfig(values),
      appliedKeys: applied,
    );
  }

  Future<void> _cache(Map<String, Object?> values) async {
    try {
      await _prefs.setString(_kCacheKey, jsonEncode(values));
    } catch (e) {
      debugPrint('الإعداد عن بعد: تعذّر الحفظ — $e');
    }
  }

  Map<String, Object?>? _readCache() {
    final raw = _prefs.getString(_kCacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (_) {
      return null; // نسخة محفوظة تالفة — نكمل بالمُصرَّف
    }
  }
}
