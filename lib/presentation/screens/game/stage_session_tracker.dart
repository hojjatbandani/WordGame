// يربط جلسة المرحلة (data/analytics/stage_session.dart) بالتخزين
// والتحليلات: كل تغيير يُحفظ فورا، فيُستأنف التقدّم بعد أي مغادرة، ويُعرف
// بعد إقلاع جديد أن النظام أغلق التطبيق أثناء مرحلة.
//
// المواصفة §4.3 و§9.3. الشاشة تنقل الأحداث فقط؛ القرار والخصائص هنا.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../../config/balance_config.dart';
import '../../../data/analytics/analytics_event.dart';
import '../../../data/analytics/analytics_service.dart';
import '../../../data/analytics/stage_session.dart';
import '../../../data/models.dart';
import '../../../data/progress_store.dart';

class StageSessionTracker {
  final ProgressStore store;
  final AnalyticsService? analytics;
  final StageSession session;

  /// الرصيد الحالي — يحمله السجلّ المحفوظ كي تحمله الأحداث المستعادة
  final int Function() _readCoins;

  /// سبب ضبطته جلسة أحدث فُتحت فوق هذه قبل أن تكتمل
  ExitReason? _pendingExit;
  bool _finished = false;

  /// الجلسة الجارية الآن على الشاشة (واحدة في أي لحظة)
  static StageSessionTracker? _active;

  StageSessionTracker._(
    this.store,
    this.analytics,
    this.session,
    this._readCoins,
  );

  bool get finished => _finished;

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  static StageSessionTracker start({
    required ProgressStore store,
    required AnalyticsService? analytics,
    required GameLevel level,
    required int worldId,
    required int chapterId,
    required String source,
    required bool isReplay,
    required bool tutorial,
    required int Function() readCoins,
    int? nowMs,
  }) {
    final now = nowMs ?? _now();

    // مرحلة أخرى فُتحت فوق مرحلة لم تكتمل: تُغلق تلك بسببها حين تُتلَف
    final previous = _active;
    if (previous != null && !previous._finished) {
      previous._pendingExit = previous.session.worldId == worldId
          ? ExitReason.stageChanged
          : ExitReason.worldChanged;
    }

    final attempt = store.stageAttemptCount(level.id) + 1;
    unawaited(store.bumpStageAttempt(level.id));

    final session = StageSession(
      sessionId: '${now}_${Random().nextInt(1 << 30)}',
      stageId: level.id,
      worldId: worldId,
      chapterId: chapterId,
      source: source,
      attempt: attempt,
      isReplay: isReplay,
      tutorial: tutorial,
      wordsTotal: level.words.length,
      nowMs: now,
      restored: _restoreFor(store, level),
    );
    final tracker = StageSessionTracker._(store, analytics, session, readCoins);
    _active = tracker;

    analytics?.updateContext(stageId: level.id);
    analytics?.log(Ev.stageStart, session.props(nowMs: now, bonusWords: 0));

    if (!store.firstStageStarted) {
      final firstOpen = store.firstOpenAtMs;
      analytics?.log(Ev.newGameStarted, {
        'stage_id': level.id,
        'source': source,
        'ms_since_first_open': ?(firstOpen == null ? null : now - firstOpen),
      });
      unawaited(store.setFirstStageStarted(true));
    }
    if (level.id == 1 &&
        !store.onboardingCompleted &&
        store.onboardingStartedAtMs == null) {
      analytics?.log(Ev.onboardingStarted, {'stage_id': 1, 'source': source});
      unawaited(store.setOnboardingStartedAtMs(now));
    }

    tracker._persist(now);
    return tracker;
  }

  /// تقدّم محفوظ لهذه المرحلة، منقّى من كلمات لم تعد فيها (محتوى تغيّر)
  static StageProgressState? _restoreFor(ProgressStore store, GameLevel level) {
    final saved = decodeResume(store.stageResumeJson)[level.id];
    if (saved == null) return null;
    final lengths = {for (final w in level.words) w.word: w.word.length};
    final revealed = <String, Set<int>>{
      for (final e in saved.revealed.entries)
        if (lengths.containsKey(e.key))
          e.key: {
            for (final p in e.value)
              if (p >= 0 && p < lengths[e.key]!) p,
          },
    }..removeWhere((_, v) => v.isEmpty);
    return StageProgressState(
      solved: saved.solved.where(lengths.containsKey).toSet(),
      revealed: revealed,
      wrongAttempts: saved.wrongAttempts,
      hintsUsed: revealed.values.fold(0, (sum, p) => sum + p.length),
      freeHintUsed: saved.freeHintUsed,
      activeMs: saved.activeMs,
      rejectedWords: saved.rejectedWords,
    );
  }

  void solved(String word) {
    session.addSolved(word);
    _persist(_now());
  }

  void wrong(String word) {
    session.addWrong(word, cap: BalanceConfig.rejectedWordsCap);
    _persist(_now());
  }

  void hint({required String word, required int position, required bool free}) {
    session.addHint(word: word, position: position, free: free);
    _persist(_now());
  }

  void lifecycle(AppLifecycleState state) {
    if (_finished) return;
    final now = _now();
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        session.pause(now);
      case AppLifecycleState.resumed:
        session.resume(now);
      case AppLifecycleState.detached:
        session.markDetached(now);
      case AppLifecycleState.inactive:
        return; // عابر (نافذة نظام، إعلان يبدأ) — لا يغيّر شيئا
    }
    _persist(now);
  }

  void complete({required int bonusWords, required bool perfect, int? nowMs}) {
    if (_finished) return;
    _finished = true;
    final now = nowMs ?? _now();
    analytics?.log(Ev.stageComplete, {
      ...session.props(nowMs: now, bonusWords: bonusWords),
      'perfect': perfect,
      'is_first_completion': !session.isReplay,
      'rejected_words': session.progress.rejectedWords,
    });
    unawaited(store.setActiveStageSessionJson(null));
    final resume = decodeResume(store.stageResumeJson)..remove(session.stageId);
    unawaited(
      store.setStageResumeJson(
        encodeResume(
          resume,
          keep: BalanceConfig.resumeStagesKept,
          recency: resume.keys.toList(),
        ),
      ),
    );

    if (session.stageId == BalanceConfig.onboardingStageCount &&
        !store.onboardingCompleted) {
      final started = store.onboardingStartedAtMs;
      final firstOpen = store.firstOpenAtMs;
      analytics?.log(Ev.onboardingCompleted, {
        'duration_ms': ?(started == null ? null : now - started),
        'ms_since_first_open': ?(firstOpen == null ? null : now - firstOpen),
      });
      unawaited(store.setOnboardingCompleted(true));
    }
    if (identical(_active, this)) _active = null;
  }

  /// مغادرة قبل الإتمام. التقدّم يبقى محفوظا للاستئناف
  void exit(ExitReason reason, {required int bonusWords}) {
    if (_finished) return;
    _finished = true;
    final now = _now();
    session.pause(now);
    final props = {
      ...session.props(nowMs: now, bonusWords: bonusWords),
      'exit_reason': (_pendingExit ?? reason).wire,
      'rejected_words': session.progress.rejectedWords,
    };
    analytics?.log(Ev.stageAbandon, props);
    // «لغز الكلمات لا يُخسَر»: المغادرة بعد تعثّر متكرّر تُميَّز بحدث
    // الفشل عن المغادرة لأن الهاتف رنّ
    if (session.progress.wrongAttempts >=
        BalanceConfig.safetyModeMinFailedAttempts) {
      analytics?.log(Ev.stageFail, props);
    }
    _saveResume(now);
    unawaited(store.setActiveStageSessionJson(null));
    if (identical(_active, this)) _active = null;
  }

  void _persist(int now) {
    session
      ..coinBalance = _readCoins()
      ..lastSeenAtMs = max(session.lastSeenAtMs, now);
    unawaited(store.setActiveStageSessionJson(jsonEncode(session.toJson())));
    _saveResume(now);
  }

  void _saveResume(int now) {
    final resume = decodeResume(store.stageResumeJson);
    resume[session.stageId] = session.snapshot(now);
    final recency = [
      session.stageId,
      for (final id in resume.keys)
        if (id != session.stageId) id,
    ];
    unawaited(
      store.setStageResumeJson(
        encodeResume(
          resume,
          keep: BalanceConfig.resumeStagesKept,
          recency: recency,
        ),
      ),
    );
  }
}

/// يُستدعى مرة عند الإقلاع (main.dart): جلسة محفوظة لم تنتهِ = أُغلق
/// التطبيق أثناء مرحلة. تُسجَّل مغادرتها الآن، ويبقى تقدّمها للاستئناف.
void recoverStageSessions(
  ProgressStore store,
  AnalyticsService? analytics,
  int nowMs,
) {
  final events = recoveredExitEvents(
    store.activeStageSessionJson,
    nowMs: nowMs,
    failThreshold: BalanceConfig.safetyModeMinFailedAttempts,
  );
  for (final (name, props) in events) {
    analytics?.log(name, props);
  }
  unawaited(store.setActiveStageSessionJson(null));
}
