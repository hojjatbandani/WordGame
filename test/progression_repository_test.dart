import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProgressionRepository> _freshRepo() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final legacy = ProgressStore(prefs);
  return ProgressionRepository.load(prefs: prefs, legacy: legacy);
}

/// يكمل كل مراحل العالم1 ويملأ جرّته (40 كلمة إضافية موزّعة على أول 40
/// مرحلة) كي يُفتح العالم2 فعليا — مستخدَمة في أكثر من اختبار هنا
void _completeWorld1AndFillJar(ProgressionRepository repo) {
  final world1 = repo.structure.worldById(1);
  for (var i = 0; i < world1.stageCount; i++) {
    final stageId = world1.stageStart + i;
    repo.recordStageCompletion(
      stageId: stageId,
      bonusWordsFoundThisRun: i < 40 ? {'w$stageId'} : const {},
      hintsUsedThisRun: 0,
      timeMs: 1000,
      now: DateTime(2026, 1, 1),
    );
  }
}

void main() {
  group('ProgressionRepository — صندوق الفصل والمراسم', () {
    test('عالم1 لا يظهر في قائمة "مراسم معلّقة" على تثبيت جديد — كان '
        'مفتوحا منذ البداية، لا معنى لمراسم "فتح" له', () async {
      final repo = await _freshRepo();
      expect(repo.worldsPendingCeremony, isEmpty);
    });

    test('مراسم عالم جديد تصبح "معلّقة" فور فتحه فعليا، لا قبل ذلك', () async {
      final repo = await _freshRepo();
      _completeWorld1AndFillJar(repo);

      expect(
        repo.state.unlockedWorldIds,
        contains(2),
        reason: 'العالم2 يجب أن يُفتح بعد إكمال العالم1 وملء جرّته',
      );
      expect(repo.worldsPendingCeremony, {2});
    });

    test(
      'اختبار قبول 5: المراسم تُعرَض مرة واحدة فقط عبر إعادة تشغيل '
      'التطبيق — markCeremonyShown يُثبَّت في SharedPreferences فعلا',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        var repo = await ProgressionRepository.load(
          prefs: prefs,
          legacy: ProgressStore(prefs),
        );

        _completeWorld1AndFillJar(repo);
        await repo.save();
        expect(repo.worldsPendingCeremony, {2});

        // "تُعرَض" المراسم الآن، وتُسجَّل فعليا
        await repo.markCeremonyShown(2);
        expect(repo.worldsPendingCeremony, isEmpty);

        // — محاكاة إعادة تشغيل كاملة للتطبيق: مثيل جديد تماما من نفس prefs —
        repo = await ProgressionRepository.load(
          prefs: prefs,
          legacy: ProgressStore(prefs),
        );
        expect(
          repo.worldsPendingCeremony,
          isEmpty,
          reason: 'يجب ألا تظهر المراسم مجددا بعد إعادة التشغيل',
        );
        expect(repo.state.ceremonyShownForWorldIds, contains(2));
      },
    );

    test('استلام صندوق فصل غير مكتمل لا يفعل شيئا', () async {
      final repo = await _freshRepo();
      await repo.claimChapterChest(1);
      expect(repo.state.claimedChapterChestIds, isEmpty);
    });

    test('استلام صندوق فصل مكتمل يثبَّت في التخزين عبر إعادة تشغيل', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var repo = await ProgressionRepository.load(
        prefs: prefs,
        legacy: ProgressStore(prefs),
      );
      final chapter1 = repo.structure.chapterById(1);
      for (final stageId in chapter1.stageIds) {
        repo.recordStageCompletion(
          stageId: stageId,
          bonusWordsFoundThisRun: const {},
          hintsUsedThisRun: 0,
          timeMs: 1000,
          now: DateTime(2026, 1, 1),
        );
      }
      await repo.claimChapterChest(1);
      expect(repo.state.claimedChapterChestIds, {1});

      repo = await ProgressionRepository.load(
        prefs: prefs,
        legacy: ProgressStore(prefs),
      );
      expect(repo.state.claimedChapterChestIds, {1});
    });
  });
  group('تسوية مع النظام القديم عند التحميل', () {
    /// يبني حالة v2 «ناقصة»: الهجرة جرت، والنظام القديم يعرف أن أربع
    /// مراحل اكتملت، لكن تقدّم v2 لا يعرف إلا الأولى — بالضبط ما كان
    /// يخلّفه عطل زرّ «التالي» (راجع _reconcileWithLegacy)
    Future<ProgressionRepository> loadWithGap() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final legacy = ProgressStore(prefs);

      // أول تحميل: هجرة على تقدّم صفر، ثم نسجّل المرحلة1 فقط
      final first = await ProgressionRepository.load(
        prefs: prefs,
        legacy: legacy,
      );
      first.recordStageCompletion(
        stageId: 1,
        bonusWordsFoundThisRun: const {},
        hintsUsedThisRun: 0,
        timeMs: 1000,
        now: DateTime(2026, 1, 1),
      );
      await first.save();

      // النظام القديم وحده يعرف أن 1..4 اكتملت (المرحلة الخامسة مفتوحة)
      await legacy.setMaxUnlocked(5);

      return ProgressionRepository.load(prefs: prefs, legacy: legacy);
    }

    test(
      'المراحل التي يعرف النظام القديم اكتمالها تُصلَح عند التحميل',
      () async {
        final repo = await loadWithGap();
        for (var stageId = 1; stageId <= 4; stageId++) {
          expect(
            repo.stageProgress[stageId]?.completed,
            isTrue,
            reason: 'المرحلة $stageId اكتملت في النظام القديم',
          );
        }
        expect(
          repo.stageProgress[5]?.completed ?? false,
          isFalse,
          reason: 'المرحلة5 لم تُلعب بعد — لا تُصلَح',
        );
      },
    );

    test('المرحلة الحالية تتقدّم إلى أول مرحلة غير مكتملة', () async {
      final repo = await loadWithGap();
      expect(repo.state.currentStageId, 5);
    });

    test('الإصلاح يُحفظ فورا فلا يتكرّر عند التحميل التالي', () async {
      await loadWithGap();
      final prefs = await SharedPreferences.getInstance();
      final legacy = ProgressStore(prefs);
      final reloaded = await ProgressionRepository.load(
        prefs: prefs,
        legacy: legacy,
      );
      expect(reloaded.stageProgress[4]?.completed, isTrue);
      // XP الإصلاح تُمنح مرة واحدة، لا تتراكم مع كل تحميل
      expect(reloaded.state.wallet.xp, lessThanOrEqualTo(12 * 20));
    });

    test('لا تسوية حين لا فجوة — حالة سليمة تبقى كما هي', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final legacy = ProgressStore(prefs);
      final repo = await ProgressionRepository.load(
        prefs: prefs,
        legacy: legacy,
      );
      expect(repo.stageProgress, isEmpty);
      expect(repo.state.currentStageId, 1);
    });
  });
}
