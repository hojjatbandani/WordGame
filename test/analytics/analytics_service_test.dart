import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/analytics/analytics_event.dart';
import 'package:huruf/data/analytics/analytics_service.dart';

void main() {
  group('التسجيل', () {
    test('بلا ناقل (سطح المكتب والاختبارات): لا يرمي', () {
      AnalyticsService().log(Ev.stageStart, {'stage_id': 1});
    });

    test('الحدث يصل إلى الناقل باسمه وخصائصه، والسياق يُلحَق به تلقائيا', () {
      final seen = <AnalyticsEvent>[];
      final s = AnalyticsService(sink: seen.add);
      s.updateContext(playerLevel: 7, stageId: 42, coinBalance: 310);
      s.log(Ev.hintUsed, {'type': 'reveal_letter'});

      final e = seen.single;
      expect(e.name, Ev.hintUsed);
      expect(e.playerLevel, 7);
      expect(e.stageId, 42);
      expect(e.coinBalance, 310);
      expect(e.properties['type'], 'reveal_letter');
    });

    test('تحديث السياق جزئي: ما لم يُمرَّر يبقى كما كان', () {
      final seen = <AnalyticsEvent>[];
      final s = AnalyticsService(sink: seen.add);
      s.updateContext(playerLevel: 3, stageId: 5);
      s.updateContext(coinBalance: 90);
      s.log(Ev.coinsEarned, {'amount': 20});

      expect(seen.single.playerLevel, 3);
      expect(seen.single.stageId, 5);
      expect(seen.single.coinBalance, 90);
    });

    test('مغادرة المرحلة تمسح سياقها فلا تُنسب أحداث المتجر إليها', () {
      final seen = <AnalyticsEvent>[];
      final s = AnalyticsService(sink: seen.add);
      s.updateContext(playerLevel: 7, stageId: 42);
      s.clearStage(42);
      s.log(Ev.shopViewed, {'source': 'home_nav'});

      expect(seen.single.stageId, isNull);
      expect(seen.single.playerLevel, 7, reason: 'مستوى اللاعب باقٍ');
    });

    test('clearStage ignores another stage', () {
      // شاشة المرحلة السابقة تُتلَف بعد أن تضبط اللاحقة سياقها (زرّ
      // «التالي»): مسحها يجب ألّا يمحو مرحلة لم تعد مرحلتها
      final seen = <AnalyticsEvent>[];
      final s = AnalyticsService(sink: seen.add);
      s.updateContext(stageId: 5);
      s.clearStage(4);
      s.log(Ev.coinsSpent);
      s.clearStage(5);
      s.log(Ev.coinsSpent);

      expect(seen.first.stageId, 5);
      expect(seen.last.stageId, isNull);
    });

    test('ناقل يرمي لا يُسقِط التسجيل ولا يمنع الأحداث التالية', () {
      var calls = 0;
      final s = AnalyticsService(
        sink: (_) {
          calls++;
          throw StateError('Firebase down');
        },
      );
      s.log(Ev.hintUsed);
      s.log(Ev.coinsSpent, {'amount': 30});

      expect(calls, 2);
    });
  });

  test('Ev.all is unique snake_case and has no ad_failed', () {
    final snake = RegExp(r'^[a-z]+(_[a-z]+)*$');
    for (final name in Ev.all) {
      expect(snake.hasMatch(name), isTrue, reason: name);
    }
    expect(Ev.all.toSet().length, Ev.all.length);
    expect(Ev.all, isNot(contains('ad_failed')));
    expect(Ev.all, isNot(contains('store_opened')));
    expect(
      Ev.all,
      containsAll([
        'home_viewed', 'continue_play_clicked', 'new_game_started',
        'onboarding_started', 'onboarding_completed', 'stage_selected',
        'next_stage_clicked', 'hint_viewed', 'hint_unavailable',
        'coins_spend_failed', 'world_viewed', 'rewards_viewed', 'shop_viewed',
        'purchase_failed', 'ad_requested', 'ad_eligible', 'ad_skipped',
        'ad_loaded', 'ad_load_failed', 'ad_shown', 'ad_clicked',
        'ad_reward_earned', 'ad_dismissed', 'ad_reward_granted',
      ]),
    );
  });
}
