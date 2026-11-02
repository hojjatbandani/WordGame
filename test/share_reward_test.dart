import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/achievement_models.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/social_models.dart';
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

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  group('مكافأة المشاركة', () {
    test('أول مشاركة تمنح النقاط', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);

      expect(container.read(shareRewardProvider).canEarn, isTrue);
      final reward = container.read(shareRewardProvider.notifier).claim();

      expect(reward, ShareRewardNotifier.reward);
      expect(container.read(pointsProvider), ShareRewardNotifier.reward);
    });

    test('السقف يمنع تكرار المكافأة بلا نهاية', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);
      final notifier = container.read(shareRewardProvider.notifier);

      for (var i = 0; i < ShareRewardNotifier.maxTotal; i++) {
        expect(notifier.claim(), ShareRewardNotifier.reward);
      }

      // ما بعد السقف: لا نقاط إضافية مهما تكرّرت المشاركة
      expect(container.read(shareRewardProvider).canEarn, isFalse);
      expect(notifier.claim(), 0);
      expect(notifier.claim(), 0);
      expect(
        container.read(pointsProvider),
        ShareRewardNotifier.reward * ShareRewardNotifier.maxTotal,
      );
    });

    test('السقف لا يعود مع يوم جديد — هو سقف عمرٍ لا رصيد يومي', () async {
      // مفتاح التاريخ محفوظ من النسخة اليومية القديمة: وجوده لا يعيد
      // رصيدا، فقيمة العدّاد وحدها هي الحاكمة الآن
      final yesterday = _dateKey(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      final container = await _container({
        'points': 0,
        'share_reward_date': yesterday,
        'share_reward_count': ShareRewardNotifier.maxTotal,
      });
      addTearDown(container.dispose);

      expect(container.read(shareRewardProvider).canEarn, isFalse);
      expect(container.read(shareRewardProvider.notifier).claim(), 0);
      expect(container.read(pointsProvider), 0);
    });

    test('السقف يبقى ساريا بعد إعادة التشغيل', () async {
      final container = await _container({
        'points': 0,
        'share_reward_count': ShareRewardNotifier.maxTotal,
      });
      addTearDown(container.dispose);

      expect(container.read(shareRewardProvider).canEarn, isFalse);
      expect(container.read(shareRewardProvider.notifier).claim(), 0);
      expect(container.read(pointsProvider), 0);
    });

    test('مشاركة واحدة محفوظة تُبقي مكافأة واحدة متاحة', () async {
      final container = await _container({
        'points': 0,
        'share_reward_count': 1,
      });
      addTearDown(container.dispose);
      final notifier = container.read(shareRewardProvider.notifier);

      expect(notifier.claim(), ShareRewardNotifier.reward);
      expect(notifier.claim(), 0, reason: 'بلغ السقف الآن');
    });
  });

  group('نتيجة الدعوة', () {
    test('تترجم رموز السيرفر إلى رسائل عربية', () {
      expect(ReferralOutcome.fromCode('ok'), ReferralOutcome.ok);
      expect(
        ReferralOutcome.fromCode('already_redeemed'),
        ReferralOutcome.alreadyRedeemed,
      );
      expect(ReferralOutcome.fromCode('not_found'), ReferralOutcome.notFound);
      expect(ReferralOutcome.fromCode('self'), ReferralOutcome.self);
      expect(ReferralOutcome.fromCode('too_late'), ReferralOutcome.tooLate);
      // أي رمز غير متوقع يسقط على الفشل العام بدل أن يرمي
      expect(ReferralOutcome.fromCode('???'), ReferralOutcome.failed);
      expect(ReferralOutcome.fromCode(null), ReferralOutcome.failed);
    });

    test('كل حالة عدا النجاح تحمل رسالة للمستخدم', () {
      for (final o in ReferralOutcome.values) {
        if (o == ReferralOutcome.ok) continue;
        expect(o.messageAr.trim(), isNotEmpty, reason: o.name);
      }
    });
  });

  group('نطاق لوحة الترتيب', () {
    test('لكل نطاق عنوان عربي', () {
      for (final s in LeaderboardScope.values) {
        expect(s.titleAr.trim(), isNotEmpty);
      }
    });

    test('لا نطاق عالمي — حلّ محلّه نظام الدوري المجمَّع', () {
      expect(LeaderboardScope.values, [
        LeaderboardScope.friends,
      ], reason: 'اللوحة العالمية أُزيلت عمدا (راجع تعليق LeaderboardScope)');
    });
  });

  group('إنجازات الدعوة والمشاركة', () {
    // العدّاد يزيد دوما — الإنجاز يتبع تفعيل فئته. مكتوب بدلالة
    // `isEnabled` لا بقيمة ثابتة كي يبقى صحيحا يوم تُعاد «اجتماعي»:
    // يومها يقيس أن الإنجاز يُفتح، واليوم يقيس أنه لا يُفتح.
    test('عدّاد الدعوات يزيد، وفتح إنجازه يتبع تفعيل فئته', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);

      container
          .read(achievementsProvider.notifier)
          .bump(StatKey.friendsInvited);

      final state = container.read(achievementsProvider);
      expect(state.valueOf(StatKey.friendsInvited), 1);
      expect(
        state.isUnlocked('invite_1'),
        AchievementCategory.social.isEnabled,
        reason: 'إنجاز فئة معطّلة لا يُفتح ولا يدفع عملات',
      );
    });

    test('عدّاد المشاركة يزيد، وفتح إنجازه يتبع تفعيل فئته', () async {
      final container = await _container({'points': 0});
      addTearDown(container.dispose);

      container.read(achievementsProvider.notifier).bump(StatKey.resultsShared);

      final state = container.read(achievementsProvider);
      expect(state.valueOf(StatKey.resultsShared), 1);
      expect(state.isUnlocked('share_1'), AchievementCategory.social.isEnabled);
    });
  });
}
