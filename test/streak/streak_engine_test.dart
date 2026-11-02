import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/streak/streak_engine.dart';
import 'package:huruf/data/streak/streak_models.dart';

void main() {
  group('StreakEngine.recordActivityToday', () {
    test('أول نشاط على الإطلاق يبدأ سلسلة بطول 1', () {
      final result = StreakEngine.recordActivityToday(
        state: StreakState.initial(),
        now: DateTime(2026, 1, 10),
      );
      expect(result.currentStreak, 1);
      expect(result.longestStreak, 1);
      expect(result.securedThroughDateKey, '2026-01-10');
    });

    test('نشاط ثانٍ في نفس اليوم لا يزيد السلسلة (لا احتساب مضاعف)', () {
      final day1 = StreakEngine.recordActivityToday(
        state: StreakState.initial(),
        now: DateTime(2026, 1, 10),
      );
      final sameDayAgain = StreakEngine.recordActivityToday(
        state: day1,
        now: DateTime(2026, 1, 10, 22), // نفس اليوم، ساعة مختلفة
      );
      expect(sameDayAgain.currentStreak, 1);
    });

    test('نشاط في اليوم التالي مباشرة يزيد السلسلة', () {
      final day1 = StreakEngine.recordActivityToday(
        state: StreakState.initial(),
        now: DateTime(2026, 1, 10),
      );
      final day2 = StreakEngine.recordActivityToday(
        state: day1,
        now: DateTime(2026, 1, 11),
      );
      expect(day2.currentStreak, 2);
      expect(day2.longestStreak, 2);
    });

    test('longestStreak لا ينقص أبدا حتى بعد كسر السلسلة الحالية', () {
      var state = StreakState.initial();
      for (final day in [10, 11, 12, 13, 14]) {
        state = StreakEngine.recordActivityToday(
            state: state, now: DateTime(2026, 1, day));
      }
      expect(state.currentStreak, 5);
      expect(state.longestStreak, 5);

      // فجوة كبيرة بلا تجميدات — تنكسر السلسلة الحالية
      final broken = StreakEngine.recordActivityToday(
        state: state,
        now: DateTime(2026, 1, 25),
      );
      expect(broken.currentStreak, 1); // بدأت من جديد
      expect(broken.longestStreak, 5); // لكن الأطول يبقى محفوظا
    });
  });

  group('StreakEngine.reconcile — فجوات وتجميدات', () {
    test('فجوة يوم واحد بلا تجميدات تكسر السلسلة', () {
      var state = StreakEngine.recordActivityToday(
          state: StreakState.initial(), now: DateTime(2026, 1, 10));
      // اليوم 11 فات كليا بلا نشاط؛ نفتح التطبيق في 12
      final reconciled =
          StreakEngine.reconcile(state: state, now: DateTime(2026, 1, 12));
      expect(reconciled.currentStreak, 0);
      expect(reconciled.securedThroughDateKey, isNull);
    });

    test('فجوة يوم واحد مع تجميد واحد تُغطّى بالكامل — السلسلة لا تنكسر', () {
      var state = StreakEngine.recordActivityToday(
          state: StreakState.initial(), now: DateTime(2026, 1, 10));
      state = state.copyWith(freezesHeld: 1);

      final reconciled =
          StreakEngine.reconcile(state: state, now: DateTime(2026, 1, 12));
      expect(reconciled.currentStreak, 1); // لم تُصفَّر
      expect(reconciled.freezesHeld, 0); // استُهلك التجميد
      expect(reconciled.securedThroughDateKey, '2026-01-11'); // أمّن يوم الفجوة
      expect(reconciled.pendingFreezeNoticeCount, 1);

      // وبعدها، نشاط اليوم 12 نفسه يواصل من حيث توقّف (يوم3)
      final playedToday = StreakEngine.recordActivityToday(
          state: reconciled, now: DateTime(2026, 1, 12));
      expect(playedToday.currentStreak, 2);
    });

    test('فجوة يومين مع تجميدين تُغطّى كاملة', () {
      var state = StreakEngine.recordActivityToday(
          state: StreakState.initial(), now: DateTime(2026, 1, 10));
      state = state.copyWith(freezesHeld: 2);

      // فاتت 11 و12 كليا؛ يُفتح التطبيق في 13
      final reconciled =
          StreakEngine.reconcile(state: state, now: DateTime(2026, 1, 13));
      expect(reconciled.currentStreak, 1);
      expect(reconciled.freezesHeld, 0);
      expect(reconciled.pendingFreezeNoticeCount, 2);
      expect(reconciled.securedThroughDateKey, '2026-01-12');
    });

    test('فجوة يومين بتجميد واحد فقط لا تكفي — تنكسر، والتجميد المتبقي لا يُهدَر',
        () {
      var state = StreakEngine.recordActivityToday(
          state: StreakState.initial(), now: DateTime(2026, 1, 10));
      state = state.copyWith(freezesHeld: 1);

      final reconciled =
          StreakEngine.reconcile(state: state, now: DateTime(2026, 1, 13));
      expect(reconciled.currentStreak, 0);
      expect(reconciled.securedThroughDateKey, isNull);
      // التجميد لم يُستهلك أصلا — لا عقاب مضاعف على كسر أصلا حادث
      expect(reconciled.freezesHeld, 1);
      expect(reconciled.pendingFreezeNoticeCount, 0);
    });

    test('لا فجوة إن كان اليوم الحالي هو نفسه اليوم المؤمَّن أو غدا مباشرة', () {
      final state = StreakEngine.recordActivityToday(
          state: StreakState.initial(), now: DateTime(2026, 1, 10));
      expect(
          StreakEngine.reconcile(state: state, now: DateTime(2026, 1, 10))
              .currentStreak,
          1);
      expect(
          StreakEngine.reconcile(state: state, now: DateTime(2026, 1, 11))
              .currentStreak,
          1);
    });
  });

  group('StreakEngine.grantMilestoneFreezes', () {
    test('يمنح تجميدا واحدا عند بلوغ أول معلَم يوم-7', () {
      var state = StreakState.initial().copyWith(longestStreak: 7);
      state = StreakEngine.grantMilestoneFreezes(
          state: state, grantEveryDays: 7, maxHeld: 2);
      expect(state.freezesHeld, 1);
      expect(state.freezeMilestonesGranted, 1);
    });

    test('لا يمنح مرتين لنفس المعلَم عند إعادة الاستدعاء', () {
      var state = StreakState.initial().copyWith(longestStreak: 7);
      state = StreakEngine.grantMilestoneFreezes(
          state: state, grantEveryDays: 7, maxHeld: 2);
      state = StreakEngine.grantMilestoneFreezes(
          state: state, grantEveryDays: 7, maxHeld: 2);
      expect(state.freezesHeld, 1);
    });

    test('يمنح دفعة واحدة عن كل المعالم المتخطّاة دفعة واحدة (مثلا بعد استعادة سحابية)',
        () {
      var state = StreakState.initial().copyWith(longestStreak: 21);
      state = StreakEngine.grantMilestoneFreezes(
          state: state, grantEveryDays: 7, maxHeld: 2);
      // 3 معالم (7،14،21) لكن الحد الأقصى 2 — الزائد يُهدَر بصمت
      expect(state.freezesHeld, 2);
      expect(state.freezeMilestonesGranted, 3);
    });

    test('لا يمنح شيئا فوق الحد الأقصى حتى لو بلغ معلما جديدا', () {
      var state =
          StreakState.initial().copyWith(longestStreak: 14, freezesHeld: 2);
      state = StreakEngine.grantMilestoneFreezes(
          state: state, grantEveryDays: 7, maxHeld: 2);
      expect(state.freezesHeld, 2); // بقي عند الحد، لا يتجاوزه
      expect(state.freezeMilestonesGranted, 2);
    });
  });

  group('الشراء والإشعار', () {
    test('canPurchaseFreeze يمنع الشراء عند بلوغ الحد الأقصى', () {
      final atMax = StreakState.initial().copyWith(freezesHeld: 2);
      expect(StreakEngine.canPurchaseFreeze(state: atMax, maxHeld: 2), isFalse);
      final below = StreakState.initial().copyWith(freezesHeld: 1);
      expect(StreakEngine.canPurchaseFreeze(state: below, maxHeld: 2), isTrue);
    });

    test('takePendingFreezeNotice يعيد العدد ثم يصفّره — مرة واحدة فقط', () {
      final withNotice = StreakState.initial().copyWith(pendingFreezeNoticeCount: 1);
      final (cleared, count) = StreakEngine.takePendingFreezeNotice(withNotice);
      expect(count, 1);
      expect(cleared.pendingFreezeNoticeCount, 0);

      final (clearedAgain, countAgain) =
          StreakEngine.takePendingFreezeNotice(cleared);
      expect(countAgain, 0);
      expect(clearedAgain.pendingFreezeNoticeCount, 0);
    });
  });
}
