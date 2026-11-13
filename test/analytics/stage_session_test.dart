// جلسة المرحلة: الزمن الفعّال، الخصائص الموحّدة، التلفّظ JSON، واستعادة
// مرحلة أغلقها النظام في الخلفية.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/analytics/stage_session.dart';

StageSession _session({int nowMs = 0, StageProgressState? restored}) =>
    StageSession(
      sessionId: 's1',
      stageId: 7,
      worldId: 1,
      chapterId: 1,
      source: 'map',
      attempt: 2,
      isReplay: false,
      tutorial: false,
      wordsTotal: 2,
      nowMs: nowMs,
      restored: restored,
    );

const _standardKeys = {
  'stage_id', 'world_id', 'chapter_id', 'duration_ms', 'wrong_attempts',
  'hints_used', 'words_total', 'words_solved', 'bonus_words', 'attempt',
  'is_replay', 'source', 'resumed', 'tutorial',
};

void main() {
  test('active time excludes background', () {
    final s = _session();
    s.pause(10000);
    s.resume(70000);
    expect(s.activeMs(80000), 20000);
    expect(s.lifecycle, SessionLifecycle.foreground);
  });

  test('props has exactly the standard keys', () {
    final s = _session();
    s.addSolved('ملح');
    final props = s.props(nowMs: 5000, bonusWords: 1);
    expect(props.keys.toSet(), _standardKeys);
    expect(props['words_solved'], 1);
    expect(props['duration_ms'], 5000);
    expect(props['attempt'], 2);
    expect(props['resumed'], isFalse);
  });

  test('rejected words unique, min length 3, capped', () {
    final s = _session();
    const letters = 'ابتثجحخدذرزسشصضطظعغفقكلمن';
    for (var i = 0; i < 20; i++) {
      s.addWrong('م${letters[i]}ل', cap: 15);
    }
    s.addWrong('مل', cap: 15);
    s.addWrong('ما${letters[0]}', cap: 15);
    s.addWrong('ما${letters[0]}', cap: 15);
    expect(s.progress.wrongAttempts, 23);
    expect(s.progress.rejectedWords.length, 15);
    expect(s.progress.rejectedWords.toSet().length, 15);
    expect(s.progress.rejectedWords.any((w) => w.length < 3), isFalse);
  });

  test('hints count every revealed letter', () {
    final s = _session();
    s.addHint(word: 'ملح', position: 0, free: true);
    s.addHint(word: 'ملح', position: 1, free: false);
    expect(s.progress.hintsUsed, 2);
    expect(s.progress.freeHintUsed, isTrue);
    expect(s.progress.revealed['ملح'], {0, 1});
  });

  test('json round trip keeps progress and lifecycle', () {
    final s = _session()
      ..coinBalance = 90
      ..playerLevel = 3;
    s.addSolved('ملح');
    s.addWrong('لمح', cap: 15);
    s.addHint(word: 'حلم', position: 2, free: true);
    s.pause(4000);
    final back = StageSession.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
    );
    expect(back.lifecycle, SessionLifecycle.background);
    expect(back.lastSeenAtMs, 4000);
    expect(back.progress.solved, {'ملح'});
    expect(back.progress.revealed, {'حلم': {2}});
    expect(back.progress.rejectedWords, ['لمح']);
    expect(back.activeMs(99999), 4000);
    expect(back.coinBalance, 90);
    expect(back.playerLevel, 3);
  });

  test('restored progress marks the session resumed', () {
    final s = _session(
      restored: StageProgressState(solved: {'ملح'}, activeMs: 3000),
    );
    expect(s.resumed, isTrue);
    expect(s.props(nowMs: 1000, bonusWords: 0)['duration_ms'], 4000);
  });

  group('recovery', () {
    String persisted(void Function(StageSession) mutate) {
      final s = _session();
      mutate(s);
      return jsonEncode(s.toJson());
    }

    test('background → app_backgrounded', () {
      final events = recoveredExitEvents(
        persisted((s) => s.pause(9000)),
        nowMs: 100000,
        failThreshold: 2,
      );
      expect(events.map((e) => e.$1), ['stage_abandon']);
      final props = events.single.$2;
      expect(props['exit_reason'], 'app_backgrounded');
      expect(props['recovered'], isTrue);
      expect(props['ended_at_ms'], 9000);
      expect(props['last_state'], 'background');
      expect(props.keys.toSet().containsAll(_standardKeys), isTrue);
    });

    test('detached → app_closed', () {
      final events = recoveredExitEvents(
        persisted((s) => s.markDetached(5000)),
        nowMs: 100000,
        failThreshold: 2,
      );
      expect(events.single.$2['exit_reason'], 'app_closed');
      expect(events.single.$2['last_state'], 'detached');
    });

    test('foreground → app_closed with last_state foreground', () {
      final events = recoveredExitEvents(
        persisted((_) {}),
        nowMs: 100000,
        failThreshold: 2,
      );
      expect(events.single.$2['exit_reason'], 'app_closed');
      expect(events.single.$2['last_state'], 'foreground');
    });

    test('ended or missing → no events', () {
      expect(
        recoveredExitEvents(
          persisted((s) => s.ended = true),
          nowMs: 1,
          failThreshold: 2,
        ),
        isEmpty,
      );
      expect(recoveredExitEvents(null, nowMs: 1, failThreshold: 2), isEmpty);
      expect(recoveredExitEvents('garbage', nowMs: 1, failThreshold: 2), isEmpty);
    });

    test('fail threshold adds stage_fail', () {
      final events = recoveredExitEvents(
        persisted((s) {
          s.addWrong('لمح', cap: 15);
          s.addWrong('حمل', cap: 15);
          s.pause(9000);
        }),
        nowMs: 100000,
        failThreshold: 2,
      );
      expect(events.map((e) => e.$1), ['stage_abandon', 'stage_fail']);
    });
  });

  test('exit reasons have snake_case wire names', () {
    expect(ExitReason.backButton.wire, 'back_button');
    expect(ExitReason.systemBack.wire, 'system_back');
    expect(ExitReason.homeButton.wire, 'home_button');
    expect(ExitReason.appBackgrounded.wire, 'app_backgrounded');
    expect(ExitReason.appClosed.wire, 'app_closed');
    expect(ExitReason.stageChanged.wire, 'stage_changed');
    expect(ExitReason.worldChanged.wire, 'world_changed');
    expect(ExitReason.unknown.wire, 'unknown');
  });

  test('resume keeps the 3 most recent stages', () {
    final map = {
      for (final id in [1, 2, 3, 4]) id: StageProgressState(solved: {'w$id'}),
    };
    final json = encodeResume(map, keep: 3, recency: [4, 2, 3, 1]);
    final back = decodeResume(json);
    expect(back.keys.toSet(), {4, 2, 3});
    expect(back[2]!.solved, {'w2'});
    expect(decodeResume(null), isEmpty);
    expect(decodeResume('{broken'), isEmpty);
  });
}
