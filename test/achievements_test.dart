import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/data/achievement_models.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = ProgressStore(await SharedPreferences.getInstance());
  return ProviderContainer(
    overrides: [progressStoreProvider.overrideWithValue(store)],
  );
}

void main() {
  group('كتالوج الإنجازات', () {
    test('كل المعرّفات فريدة', () {
      final ids = achievements.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('كل النصوص المرئية عربية وغير فارغة', () {
      final arabic = RegExp(r'[؀-ۿ]');
      for (final a in achievements) {
        expect(a.titleAr.trim(), isNotEmpty, reason: a.id);
        expect(a.descriptionAr.trim(), isNotEmpty, reason: a.id);
        expect(
          arabic.hasMatch(a.titleAr),
          isTrue,
          reason: '${a.id}: العنوان يجب أن يكون عربيا',
        );
        expect(
          arabic.hasMatch(a.descriptionAr),
          isTrue,
          reason: '${a.id}: الوصف يجب أن يكون عربيا',
        );
      }
    });

    test('كل هدف موجب، وكل مكافأة تطابق قاعدة الطبقة الأسطورية', () {
      for (final a in achievements) {
        expect(a.target, greaterThan(0), reason: a.id);
        if (a.tier == AchievementTier.legend) {
          // الطبقة الأسطورية: صفر عملات، وعنصر زخرفي حصري إلزامي
          expect(a.reward, 0, reason: '${a.id}: أسطوري يجب أن يكون بلا عملات');
          expect(
            a.cosmeticRewardId,
            isNotNull,
            reason: '${a.id}: أسطوري يجب أن يمنح عنصرا زخرفيا',
          );
        } else {
          expect(a.reward, greaterThan(0), reason: a.id);
          expect(
            a.cosmeticRewardId,
            isNull,
            reason: '${a.id}: غير الأسطوري لا يمنح عنصرا زخرفيا',
          );
        }
      }
    });

    test('المكافأة تتدرّج مع الصعوبة: 20 / 40 / 90 / زخرفي', () {
      expect(BalanceConfig.coinsAchievementBronze, 20);
      expect(BalanceConfig.coinsAchievementSilver, 40);
      expect(BalanceConfig.coinsAchievementGold, 90);
      for (final a in achievements) {
        expect(a.reward, switch (a.tier) {
          AchievementTier.bronze => BalanceConfig.coinsAchievementBronze,
          AchievementTier.silver => BalanceConfig.coinsAchievementSilver,
          AchievementTier.gold => BalanceConfig.coinsAchievementGold,
          AchievementTier.legend => 0,
        }, reason: a.id);
      }
      // الترتيب نفسه لا الأرقام: مكافأة الطبقة الأصعب أكبر دوما
      expect(
        BalanceConfig.coinsAchievementBronze,
        lessThan(BalanceConfig.coinsAchievementSilver),
      );
      expect(
        BalanceConfig.coinsAchievementSilver,
        lessThan(BalanceConfig.coinsAchievementGold),
      );
    });

    test('سلّم المراحل تصاعدي فعلا — لا يدفع 25 مرحلة ما تدفعه مرحلة واحدة',
        () {
      // المطلوب «مكافآت متدرّجة لا رقم واحد لكل إنجاز». الطبقات وحدها
      // لا تكفي: كان السلّم برونزيا حتى المرحلة الخمسين، فيقبض من أتمّ
      // 25 مرحلة ما يقبضه من أتمّ واحدة.
      final ladder = achievements
          .where((a) => a.stat == StatKey.levelsCompleted)
          .toList()
        ..sort((a, b) => a.target.compareTo(b.target));

      expect(ladder.length, greaterThan(8), reason: 'سلّم قصير لا يُقاس');

      // لا نزول أبدا مع تقدّم الهدف
      for (var i = 1; i < ladder.length; i++) {
        expect(
          ladder[i].reward,
          greaterThanOrEqualTo(ladder[i - 1].reward),
          reason: '${ladder[i].id} (${ladder[i].target} مرحلة) يدفع أقل من '
              '${ladder[i - 1].id}',
        );
      }

      // ويصعد فعلا لا يبقى مسطّحا: آخر السلّم أضعاف أوّله
      expect(
        ladder.last.reward,
        greaterThanOrEqualTo(ladder.first.reward * 4),
        reason: 'الفارق بين أول السلّم وآخره باهت',
      );

      // والصعود يبدأ مبكرا: هدف الـ25 مرحلة تجاوز الطبقة الأولى
      final at25 = ladder.firstWhere((a) => a.target == 25);
      expect(
        at25.reward,
        greaterThan(BalanceConfig.coinsAchievementBronze),
        reason: '25 مرحلة يجب أن تُشعَر أكثر من أول مرحلة',
      );
    });

    test('ميزانية الإنجازات لم تنفلت مع تحديد المنحنى', () {
      // المنحنى تغيّر، والميزانية يجب ألّا تتضخّم معه
      final total = visibleAchievements.fold<int>(0, (s, a) => s + a.reward);
      expect(
        total,
        inInclusiveRange(3500, 5000),
        reason: 'مجموع ما تدفعه الإنجازات على مدى اللعبة كلها: $total',
      );
      expect(
        BalanceConfig.coinsAchievementSilver,
        lessThan(BalanceConfig.coinsAchievementGold),
      );
    });

    test('المكافأة تُصرَف من BalanceConfig لا من رقم مثبّت', () {
      final before = achievementsById['first_step']!.reward;
      BalanceConfig.coinsAchievementBronze = 7;
      addTearDown(() => BalanceConfig.coinsAchievementBronze = before);
      expect(achievementsById['first_step']!.reward, 7);
    });

    test('بالضبط 100 إنجاز', () {
      expect(achievements.length, 100);
    });

    test('كل فئة فيها إنجازات، وكل عدّاد مستخدم فعلا', () {
      for (final c in AchievementCategory.values) {
        expect(achievementsIn(c), isNotEmpty, reason: c.name);
      }
      final used = achievements.map((a) => a.stat).toSet();
      // hintsUsed وحده بلا إنجاز عمدا: مكافأة شراء التلميحات تكافئ
      // سلوكا نريده أن يقلّ لا أن يزيد
      final expected = StatKey.values.toSet()..remove(StatKey.hintsUsed);
      expect(used, expected);
    });

    test('«اجتماعي» معطّلة: مخفيّة عن العرض ومستثناة من العدّ', () {
      expect(AchievementCategory.social.isEnabled, isFalse);
      for (final c in AchievementCategory.values) {
        if (c == AchievementCategory.social) continue;
        expect(c.isEnabled, isTrue, reason: c.name);
      }
      expect(
        visibleAchievements.any(
          (a) => a.category == AchievementCategory.social,
        ),
        isFalse,
      );
      expect(
        visibleAchievements.length,
        achievements.length - achievementsIn(AchievementCategory.social).length,
      );
    });

    test('كل هدف قابل للبلوغ فعلا بالمحتوى الموجود', () {
      // الأسقف الحقيقية — راجع assets/data/levels.json و challenges.json
      // وBalanceConfig. هدف يتجاوز سقفه وعدٌ لا يُوفى.
      const ceilings = {
        StatKey.levelsCompleted: 500,
        StatKey.wordsFound: 2907,
        StatKey.bonusWords: 2151,
        StatKey.perfectLevels: 500,
        StatKey.worldsCompleted: 8,
        StatKey.longestWord: 8,
        StatKey.chaptersCompleted: 40,
        StatKey.challengesSolved: 62,
      };
      for (final a in achievements) {
        final ceiling = ceilings[a.stat];
        if (ceiling == null) continue; // عدّاد بلا سقف (أيام، عملات، أصدقاء)
        expect(
          a.target,
          lessThanOrEqualTo(ceiling),
          reason: '${a.id}: الهدف ${a.target} فوق السقف الممكن $ceiling',
        );
      }
    });

    test('«سيّد الحروف» (levels_500) محذوف', () {
      expect(achievementsById.containsKey('levels_500'), isFalse);
      expect(
        achievements
            .where((a) => a.stat == StatKey.levelsCompleted)
            .map((a) => a.target),
        isNot(contains(500)),
      );
    });

    test(
      'اختبار قبول: 3 إنجازات على الأقل قابلة للفتح خلال أول جلسة قصيرة',
      () {
        // نفس الأمثلة الثلاثة المعطاة حرفيا في المهمة، بأهداف تتحقق فعليا
        // خلال دقائق من تثبيت جديد بلا أي اعتماد على وقت تقويمي أو لاعبين
        // آخرين (بخلاف friend_1/wheel_10/streak_3 مثلا)
        for (final id in ['first_step', 'bonus_1', 'perfect_1']) {
          final a = achievementsById[id]!;
          expect(
            a.target,
            lessThanOrEqualTo(3),
            reason: '$id يجب أن يبلغه لاعب جديد خلال دقائق قليلة',
          );
        }
      },
    );

    test('أهداف نفس العدّاد تتصاعد بلا تكرار', () {
      final byStat = <StatKey, List<int>>{};
      for (final a in achievements) {
        byStat.putIfAbsent(a.stat, () => []).add(a.target);
      }
      for (final entry in byStat.entries) {
        final targets = entry.value;
        expect(
          targets.toSet().length,
          targets.length,
          reason: 'هدف مكرّر في ${entry.key.name}',
        );
      }
    });
  });

  group('فتح الإنجازات', () {
    test('يفتح الإنجاز عند بلوغ الهدف ويمنح مكافأته', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);
      final notifier = container.read(achievementsProvider.notifier);

      expect(
        container.read(achievementsProvider).isUnlocked('first_step'),
        isFalse,
      );

      notifier.bump(StatKey.levelsCompleted);

      final state = container.read(achievementsProvider);
      expect(state.isUnlocked('first_step'), isTrue);
      expect(state.valueOf(StatKey.levelsCompleted), 1);
      // مكافأة «أول الطريق» 20 عملة (برونزي)
      expect(
        container.read(pointsProvider),
        BalanceConfig.coinsAchievementBronze,
      );
    });

    test('لا يُفتح الإنجاز نفسه مرتين ولا تتكرّر مكافأته', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);
      final notifier = container.read(achievementsProvider.notifier);

      notifier.bump(StatKey.levelsCompleted);
      final afterFirst = container.read(pointsProvider);
      notifier.takeJustUnlocked();

      notifier.bump(StatKey.levelsCompleted);
      expect(
        container.read(pointsProvider),
        afterFirst,
        reason: 'المرحلة الثانية لا تفتح «أول الطريق» من جديد',
      );
      expect(notifier.takeJustUnlocked(), isEmpty);
    });

    test('قفزة واحدة قد تفتح أكثر من إنجاز معا', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);
      final notifier = container.read(achievementsProvider.notifier);

      notifier.bump(StatKey.levelsCompleted, 100);

      final unlocked = notifier.takeJustUnlocked().map((a) => a.id).toSet();
      expect(unlocked, containsAll(['first_step', 'levels_50']));
      expect(unlocked.contains('levels_200'), isFalse);
    });

    test('reportBest يأخذ الأعلى فقط ولا يتراجع', () async {
      final container = await _container();
      addTearDown(container.dispose);
      final notifier = container.read(achievementsProvider.notifier);

      notifier.reportBest(StatKey.bestStreak, 7);
      expect(
        container.read(achievementsProvider).valueOf(StatKey.bestStreak),
        7,
      );
      expect(
        container.read(achievementsProvider).isUnlocked('streak_7'),
        isTrue,
      );

      // سلسلة أقصر بعدها لا تُنقص الرقم القياسي
      notifier.reportBest(StatKey.bestStreak, 4);
      expect(
        container.read(achievementsProvider).valueOf(StatKey.bestStreak),
        7,
      );
    });

    test('التقدّم يُحفظ ويُقرأ من التخزين المحلي', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);
      container
          .read(achievementsProvider.notifier)
          .bump(StatKey.wordsFound, 50);
      container.dispose();

      // جلسة جديدة على نفس التخزين
      final store = ProgressStore(await SharedPreferences.getInstance());
      final revived = ProviderContainer(
        overrides: [progressStoreProvider.overrideWithValue(store)],
      );
      addTearDown(revived.dispose);

      final state = revived.read(achievementsProvider);
      expect(state.valueOf(StatKey.wordsFound), 50);
      expect(state.isUnlocked('words_50'), isTrue);
    });

    test('عدّاد لا يخصّ إنجازا لا يفتح شيئا', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);
      final notifier = container.read(achievementsProvider.notifier);

      notifier.bump(StatKey.hintsUsed, 99);

      expect(notifier.takeJustUnlocked(), isEmpty);
      expect(container.read(pointsProvider), 0);
      expect(
        container.read(achievementsProvider).valueOf(StatKey.hintsUsed),
        99,
      );
    });
  });
}
