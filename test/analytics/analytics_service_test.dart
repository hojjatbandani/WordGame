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
      s.clearStage();
      s.log(Ev.storeOpened, {'source': 'nav_bar'});

      expect(seen.single.stageId, isNull);
      expect(seen.single.playerLevel, 7, reason: 'مستوى اللاعب باقٍ');
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
}
