// جلسة مرحلة واحدة: من دخول شاشة اللعب إلى مغادرتها. Dart صرف — بلا
// Flutter وبلا ساعة: كل زمن يُمرَّر صريحا، فتُختبر كل قاعدة بأرقام ثابتة.
//
// الجلسة هي مصدر الخصائص الموحّدة لأحداث المرحلة الأربعة
// (stage_start/complete/fail/abandon)، وهي أيضا ما يُحفظ على القرص كي:
//  1) يُعرف بعد إقلاع جديد أن النظام أغلق التطبيق أثناء مرحلة
//     (recoveredExitEvents)، فلا تضيع مغادرة بلا حدث كما كانت تضيع؛
//  2) يُستأنف تقدّم المرحلة بدل البدء من الصفر (StageProgressState).

import 'dart:convert';

/// لماذا غادر اللاعب مرحلة لم يُتمّها
enum ExitReason {
  /// سهم الرجوع داخل شاشة اللعب
  backButton,

  /// زرّ/إيماءة الرجوع في النظام — يُفصل عن السهم لأن إيماءة الحافة قد
  /// تقع خطأً أثناء سحب الحروف
  systemBack,

  /// محجوز: لا زرّ «رئيسية» داخل شاشة اللعب في هذا الإصدار
  homeButton,

  /// النظام أغلق التطبيق وهو في الخلفية — يُسجَّل في الإقلاع التالي
  appBackgrounded,

  /// أُغلق التطبيق (سُحب من التطبيقات الأخيرة، أُوقف، أو انهار وهو ظاهر)
  appClosed,

  /// فُتحت مرحلة أخرى من العالم نفسه فوق مرحلة لم تكتمل
  stageChanged,

  /// فُتحت مرحلة من عالم آخر فوق مرحلة لم تكتمل
  worldChanged,

  unknown,
}

extension ExitReasonWire on ExitReason {
  String get wire => switch (this) {
    ExitReason.backButton => 'back_button',
    ExitReason.systemBack => 'system_back',
    ExitReason.homeButton => 'home_button',
    ExitReason.appBackgrounded => 'app_backgrounded',
    ExitReason.appClosed => 'app_closed',
    ExitReason.stageChanged => 'stage_changed',
    ExitReason.worldChanged => 'world_changed',
    ExitReason.unknown => 'unknown',
  };
}

enum SessionLifecycle { foreground, background, detached }

/// تقدّم المرحلة القابل للاستئناف
class StageProgressState {
  final Set<String> solved;
  final Map<String, Set<int>> revealed;
  int wrongAttempts;
  int hintsUsed;
  bool freeHintUsed;

  /// الزمن الفعّال المتراكم من جلسات سابقة على هذه المرحلة
  int activeMs;
  final List<String> rejectedWords;

  StageProgressState({
    Set<String>? solved,
    Map<String, Set<int>>? revealed,
    this.wrongAttempts = 0,
    this.hintsUsed = 0,
    this.freeHintUsed = false,
    this.activeMs = 0,
    List<String>? rejectedWords,
  }) : solved = solved ?? <String>{},
       revealed = revealed ?? <String, Set<int>>{},
       rejectedWords = rejectedWords ?? <String>[];

  /// لا شيء يستحق الاستئناف
  bool get isEmpty =>
      solved.isEmpty && revealed.isEmpty && wrongAttempts == 0 && !freeHintUsed;

  Map<String, Object?> toJson() => {
    'solved': solved.toList(),
    'revealed': {
      for (final e in revealed.entries) e.key: (e.value.toList()..sort()),
    },
    'wrong': wrongAttempts,
    'hints': hintsUsed,
    'free_hint_used': freeHintUsed,
    'active_ms': activeMs,
    'rejected': rejectedWords,
  };

  factory StageProgressState.fromJson(Map<String, dynamic> json) =>
      StageProgressState(
        solved: {for (final w in (json['solved'] as List? ?? const [])) '$w'},
        revealed: {
          for (final e in ((json['revealed'] as Map?) ?? const {}).entries)
            '${e.key}': {
              for (final p in (e.value as List)) (p as num).toInt(),
            },
        },
        wrongAttempts: (json['wrong'] as num?)?.toInt() ?? 0,
        hintsUsed: (json['hints'] as num?)?.toInt() ?? 0,
        freeHintUsed: json['free_hint_used'] as bool? ?? false,
        activeMs: (json['active_ms'] as num?)?.toInt() ?? 0,
        rejectedWords: [
          for (final w in (json['rejected'] as List? ?? const [])) '$w',
        ],
      );
}

class StageSession {
  final String sessionId;
  final int stageId;
  final int worldId;
  final int chapterId;
  final String source;
  final int attempt;
  final bool isReplay;
  final bool tutorial;
  final int wordsTotal;

  /// استُعيد تقدّم من جلسة سابقة على المرحلة نفسها
  final bool resumed;
  final StageProgressState progress;

  SessionLifecycle lifecycle = SessionLifecycle.foreground;
  int lastSeenAtMs;
  bool ended = false;

  /// آخر رصيد ومستوى معروفين — تحملهما الأحداث المستعادة في إقلاع لاحق
  /// حين لا يكون سياق التحليلات قد ضُبط بعد
  int? coinBalance;
  int? playerLevel;

  /// بداية الفترة الأمامية الجارية؛ null والتطبيق في الخلفية
  int? _resumedAtMs;

  /// زمن هذه الجلسة الفعّال قبل الفترة الجارية
  int _sessionActiveMs = 0;

  StageSession({
    required this.sessionId,
    required this.stageId,
    required this.worldId,
    required this.chapterId,
    required this.source,
    required this.attempt,
    required this.isReplay,
    required this.tutorial,
    required this.wordsTotal,
    required int nowMs,
    StageProgressState? restored,
  }) : resumed = restored != null && !restored.isEmpty,
       progress = restored ?? StageProgressState(),
       lastSeenAtMs = nowMs,
       _resumedAtMs = nowMs;

  void pause(int nowMs) {
    _closeSpan(nowMs);
    lifecycle = SessionLifecycle.background;
  }

  void resume(int nowMs) {
    _resumedAtMs ??= nowMs;
    lifecycle = SessionLifecycle.foreground;
    lastSeenAtMs = nowMs;
  }

  void markDetached(int nowMs) {
    _closeSpan(nowMs);
    lifecycle = SessionLifecycle.detached;
  }

  void _closeSpan(int nowMs) {
    final start = _resumedAtMs;
    if (start != null && nowMs > start) _sessionActiveMs += nowMs - start;
    _resumedAtMs = null;
    lastSeenAtMs = nowMs;
  }

  /// الزمن الفعّال كاملا: الجلسات السابقة المستعادة + هذه بلا الخلفية
  int activeMs(int nowMs) {
    final start = _resumedAtMs;
    final running = start != null && nowMs > start ? nowMs - start : 0;
    return progress.activeMs + _sessionActiveMs + running;
  }

  void addSolved(String word) => progress.solved.add(word);

  /// كل خطأ يُعدّ، والكلمات (3 حروف فأكثر) تُحفظ بلا تكرار حتى [cap] —
  /// منها تُكتشف كلمات صحيحة ينقصها القاموس
  void addWrong(String word, {required int cap}) {
    progress.wrongAttempts++;
    if (word.length < 3) return;
    if (progress.rejectedWords.contains(word)) return;
    if (progress.rejectedWords.length >= cap) return;
    progress.rejectedWords.add(word);
  }

  void addHint({
    required String word,
    required int position,
    required bool free,
  }) {
    progress.revealed.putIfAbsent(word, () => <int>{}).add(position);
    progress.hintsUsed++;
    if (free) progress.freeHintUsed = true;
  }

  /// الخصائص الموحّدة لأحداث المرحلة (المواصفة §4.2)
  Map<String, Object?> props({required int nowMs, required int bonusWords}) => {
    'stage_id': stageId,
    'world_id': worldId,
    'chapter_id': chapterId,
    'duration_ms': activeMs(nowMs),
    'wrong_attempts': progress.wrongAttempts,
    'hints_used': progress.hintsUsed,
    'words_total': wordsTotal,
    'words_solved': progress.solved.length,
    'bonus_words': bonusWords,
    'attempt': attempt,
    'is_replay': isReplay,
    'source': source,
    'resumed': resumed,
    'tutorial': tutorial,
  };

  /// التقدّم كما يُحفظ للاستئناف: الزمن الفعّال يضمّ هذه الجلسة
  StageProgressState snapshot(int nowMs) => StageProgressState(
    solved: Set.of(progress.solved),
    revealed: {
      for (final e in progress.revealed.entries) e.key: Set.of(e.value),
    },
    wrongAttempts: progress.wrongAttempts,
    hintsUsed: progress.hintsUsed,
    freeHintUsed: progress.freeHintUsed,
    activeMs: activeMs(nowMs),
    rejectedWords: List.of(progress.rejectedWords),
  );

  Map<String, Object?> toJson() => {
    'session_id': sessionId,
    'stage_id': stageId,
    'world_id': worldId,
    'chapter_id': chapterId,
    'source': source,
    'attempt': attempt,
    'is_replay': isReplay,
    'tutorial': tutorial,
    'words_total': wordsTotal,
    'resumed': resumed,
    'lifecycle': lifecycle.name,
    'last_seen_at_ms': lastSeenAtMs,
    'ended': ended,
    'coin_balance': coinBalance,
    'player_level': playerLevel,
    // الزمن الفعّال حتى آخر ظهور، مطويّا في التقدّم
    'progress': snapshot(lastSeenAtMs).toJson(),
  };

  factory StageSession.fromJson(Map<String, dynamic> json) {
    final progress = StageProgressState.fromJson(
      (json['progress'] as Map).cast<String, dynamic>(),
    );
    final lastSeen = (json['last_seen_at_ms'] as num).toInt();
    final session = StageSession(
      sessionId: '${json['session_id']}',
      stageId: (json['stage_id'] as num).toInt(),
      worldId: (json['world_id'] as num).toInt(),
      chapterId: (json['chapter_id'] as num).toInt(),
      source: '${json['source']}',
      attempt: (json['attempt'] as num).toInt(),
      isReplay: json['is_replay'] as bool? ?? false,
      tutorial: json['tutorial'] as bool? ?? false,
      wordsTotal: (json['words_total'] as num).toInt(),
      nowMs: lastSeen,
      restored: progress,
    );
    // الجلسة المستعادة لا تجري: زمنها كله داخل progress.activeMs
    session._resumedAtMs = null;
    session.lifecycle = SessionLifecycle.values.firstWhere(
      (l) => l.name == json['lifecycle'],
      orElse: () => SessionLifecycle.foreground,
    );
    session.ended = json['ended'] as bool? ?? false;
    session.coinBalance = (json['coin_balance'] as num?)?.toInt();
    session.playerLevel = (json['player_level'] as num?)?.toInt();
    return session;
  }
}

/// أحداث مغادرة لم تُسجَّل: جلسة محفوظة لم تنتهِ تعني أن التطبيق أُغلق
/// أثناء المرحلة. تُستدعى مرة واحدة عند الإقلاع.
List<(String, Map<String, Object?>)> recoveredExitEvents(
  String? activeJson, {
  required int nowMs,
  required int failThreshold,
}) {
  if (activeJson == null) return const [];
  final StageSession session;
  try {
    session = StageSession.fromJson(
      (jsonDecode(activeJson) as Map).cast<String, dynamic>(),
    );
  } catch (_) {
    return const [];
  }
  if (session.ended) return const [];

  final reason = session.lifecycle == SessionLifecycle.background
      ? ExitReason.appBackgrounded
      : ExitReason.appClosed;
  final props = <String, Object?>{
    ...session.props(nowMs: session.lastSeenAtMs, bonusWords: 0),
    // الاستعادة تُصدِر بعد إقلاع جديد: الجلسة كانت «مستأنفة» بمعنى
    // سجلّها فقط، والخاصية هنا عن الجلسة الأصلية
    'resumed': false,
    'exit_reason': reason.wire,
    'last_state': session.lifecycle.name,
    'recovered': true,
    'ended_at_ms': session.lastSeenAtMs,
    'minutes_since_end': ((nowMs - session.lastSeenAtMs) / 60000).floor(),
    'rejected_words': session.progress.rejectedWords,
    'player_level': ?session.playerLevel,
    'coin_balance': ?session.coinBalance,
  };
  return [
    ('stage_abandon', props),
    if (session.progress.wrongAttempts >= failThreshold) ('stage_fail', props),
  ];
}

/// تقدّم المراحل غير المكتملة: المفتاح رقم المرحلة
Map<int, StageProgressState> decodeResume(String? json) {
  if (json == null) return {};
  try {
    final map = (jsonDecode(json) as Map).cast<String, dynamic>();
    return {
      for (final e in map.entries)
        int.parse(e.key): StageProgressState.fromJson(
          (e.value as Map).cast<String, dynamic>(),
        ),
    };
  } catch (_) {
    return {};
  }
}

/// يحفظ أحدث [keep] مراحل بحسب [recency] (الأحدث أولا)
String encodeResume(
  Map<int, StageProgressState> states, {
  required int keep,
  required List<int> recency,
}) {
  final kept = recency.where(states.containsKey).take(keep);
  return jsonEncode({for (final id in kept) '$id': states[id]!.toJson()});
}
