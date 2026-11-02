// مزامنة التقدّم مع Supabase (جدول player_progress، راجع
// supabase/schema_progression.sql). يتبع نمط مستودعات Supabase الأخرى
// تماما: isAvailable/_client/_userId، ويعود بهدوء دون رمي أي شيء
// إن لم تُضبط مفاتيح Supabase أو انقطع الاتصال — المزامنة تبقى دوما
// طبقة فوق التخزين المحلي، لا اعتمادا حاجزا له.
//
// خوارزمية الدمج الفعلية (الاتحاد لكل مرحلة، أكبر قيمة لكل عدّاد) تعيش
// في progression/progression_merge.dart المُختبَرة بمعزل تام. دالة
// sync_player_progress في SQL حارس أمان إضافي على الخادم للأرقام
// الثلاثة السهلة القياس فقط، وليست محرّك الدمج التفصيلي — راجع الشرح
// في رأس ذلك الملف.
//
// الجدولة (foreground/background/كل 5 دقائق) مبنية هنا كخطّافات عامة
// (onAppForeground/onAppBackground/startPeriodicSync) يستخدم Timer من
// dart:async فقط — لا WidgetsBindingObserver ولا أي استيراد Flutter UI،
// كي يبقى هذا الملف طبقة بيانات لا طبقة واجهة. ربط هذه الخطّافات الفعلي
// بدورة حياة التطبيق (main.dart أو مزوّد Riverpod) مهمة لاحقة — خارج
// نطاق "نموذج البيانات وطبقة التخزين" المطلوب هنا.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'progression/player_state.dart';
import 'progression/progression_merge.dart';
import 'progression/stage_progress.dart';
import 'progression/world_defs.dart';
import 'progression_repository.dart';
import 'supabase_config.dart';

class RemoteProgress {
  final PlayerState state;
  final Map<int, StageProgress> stageProgress;
  final int clientVersion;

  const RemoteProgress({
    required this.state,
    required this.stageProgress,
    required this.clientVersion,
  });
}

class ProgressionSyncRepository {
  /// إصدار شكل البيانات المُرسَل — لا علاقة له بـschemaVersion المحلي؛
  /// يُستخدم في عمود client_version لتشخيص مستقبلي عند تعدّد الإصدارات
  static const int _clientVersion = 2;

  bool get isAvailable => SupabaseConfig.isConfigured;

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  Future<RemoteProgress?> fetchRemote() async {
    if (!isAvailable || _userId == null) return null;
    try {
      final row = await _client
          .from('player_progress')
          .select('state_json, stage_progress_json, client_version')
          .eq('user_id', _userId!)
          .maybeSingle();
      if (row == null) return null;

      final stateJson = row['state_json'] as Map<String, dynamic>;
      final stageJson = row['stage_progress_json'] as Map<String, dynamic>;
      return RemoteProgress(
        state: PlayerState.fromJson(stateJson),
        stageProgress: stageJson.map(
          (k, v) => MapEntry(
              int.parse(k), StageProgress.fromJson(v as Map<String, dynamic>)),
        ),
        clientVersion: row['client_version'] as int? ?? 1,
      );
    } catch (e) {
      debugPrint('progression sync: تعذّر جلب التقدّم البعيد — $e');
      return null;
    }
  }

  Future<void> pushLocal(
      PlayerState state, Map<int, StageProgress> stageProgress) async {
    if (!isAvailable || _userId == null) return;
    try {
      await _client.rpc('sync_player_progress', params: {
        'new_state': state.toJson(),
        'new_stage_progress':
            stageProgress.map((k, v) => MapEntry(k.toString(), v.toJson())),
        'new_client_version': _clientVersion,
      });
    } catch (e) {
      debugPrint('progression sync: تعذّر رفع التقدّم المحلي — $e');
    }
  }

  /// دورة مزامنة كاملة: جلب → دمج (صرف، مُختبَر) → حفظ محلي → رفع.
  /// لا تفعل شيئا بهدوء إن لم تتوفر شبكة أو حساب — العميل يبقى المصدر
  /// الوحيد الموثوق دوما دون اتصال.
  Future<void> syncNow({
    required ProgressionRepository local,
    required ProgressionStructure structure,
  }) async {
    if (!isAvailable) return;
    final remote = await fetchRemote();
    if (remote == null) {
      // لا صف بعد، أو تعذّر الجلب — نرفع المحلي كما هو ليصبح هو الأساس
      await pushLocal(local.state, local.stageProgress);
      return;
    }

    final merged = ProgressionMerge.merge(
      local: local.state,
      localProgress: local.stageProgress,
      remote: remote.state,
      remoteProgress: remote.stageProgress,
      structure: structure,
    );

    local.replaceState(merged.state, merged.stageProgress);
    await local.save();
    await pushLocal(merged.state, merged.stageProgress);
  }
}

/// جدولة مزامنة دوريّة + عند التبديل بين المقدّمة/الخلفية، بحدّ أدنى
/// (debounce) بين محاولتين متتاليتين كي لا تتكرّر الطلبات عبثا عند
/// أحداث متقاربة (مثلا: عودة سريعة للمقدّمة بعد خلفية قصيرة).
class ProgressionSyncScheduler {
  final ProgressionSyncRepository sync;
  final ProgressionRepository local;
  final ProgressionStructure structure;
  final Duration periodicInterval;
  final Duration debounce;

  Timer? _periodicTimer;
  DateTime? _lastSyncAt;
  bool _syncInFlight = false;

  ProgressionSyncScheduler({
    required this.sync,
    required this.local,
    required this.structure,
    this.periodicInterval = const Duration(minutes: 5),
    this.debounce = const Duration(seconds: 10),
  });

  void startPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(periodicInterval, (_) => _trigger());
  }

  void onAppForeground() => _trigger();

  void onAppBackground() => _trigger();

  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<void> _trigger() async {
    if (_syncInFlight) return;
    final now = DateTime.now();
    if (_lastSyncAt != null && now.difference(_lastSyncAt!) < debounce) {
      return;
    }
    _syncInFlight = true;
    _lastSyncAt = now;
    try {
      await sync.syncNow(local: local, structure: structure);
    } finally {
      _syncInFlight = false;
    }
  }
}
