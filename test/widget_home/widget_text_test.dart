// نصوص الودجة: الصياغة العربية (المفرد/المثنى/الجمع)، والترجمة
// الإنجليزية، وأن الأرقام تدخل النصّ فعلا.
//
// تُختبر هنا لا في كوتلن/سويفت لأنها تُبنى هنا — الجانب الأصلي يرسم ما
// يصله حرفيا ولا يؤلّف جملة (راجع lib/data/widget/widget_text.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/rewards/reward_track.dart';
import 'package:huruf/data/widget/widget_data.dart';
import 'package:huruf/data/widget/widget_data_builder.dart';
import 'package:huruf/data/widget/widget_text.dart';

final _start = DateTime(2026, 5, 1);

DateTime _day(int n) => RewardTrackEngine.addDays(_start, n);

HomeWidgetData _build({
  int onDay = 0,
  int streak = 12,
  String lang = 'ar',
  Map<RewardTier, RewardTierProgress> tiers = const {},
}) => WidgetDataBuilder.build(
  track: RewardTrackState(startDay: _start, tiers: tiers),
  now: _day(onDay),
  diamonds: 1250,
  streakDays: streak,
  stagesCompleted: 137,
  chaptersCompleted: 11,
  worldsCompleted: 2,
  languageCode: lang,
);

WidgetText _text({
  int onDay = 0,
  int streak = 12,
  String lang = 'ar',
  Map<RewardTier, RewardTierProgress> tiers = const {},
}) => WidgetText.of(
  _build(onDay: onDay, streak: streak, lang: lang, tiers: tiers),
);

void main() {
  group('حالات المكافأة كما تُعرض', () {
    test('جاهزة للاستلام: العنوان والمبلغ والحالة', () {
      final text = _text();
      expect(text.focusTitle, 'المكافأة اليومية');
      expect(text.focusAmount, contains('20'));
      expect(text.focusAmount, contains('💎'));
      expect(text.focusStatus, 'جاهزة للاستلام');
      expect(text.cta, 'استلمها الآن');
    });

    test('استُلمت اليوم وبقيت طبقات: تتنحّى للأسبوعية', () {
      final text = _text(
        onDay: 3,
        tiers: {
          RewardTier.daily: RewardTierProgress(
            claimed: 4,
            lastClaimDay: _day(3),
          ),
        },
      );
      expect(text.focusTitle, 'المكافأة الأسبوعية');
      expect(text.cta, 'افتح اللعبة');
    });

    test('استُلمت اليوم ولا شيء غيرها: «✓ تم الاستلام · غدا مكافأة جديدة»', () {
      final text = _text(
        onDay: 3,
        tiers: {
          RewardTier.daily: RewardTierProgress(
            claimed: 4,
            lastClaimDay: _day(3),
          ),
          RewardTier.weekly: const RewardTierProgress(claimed: 4),
          RewardTier.monthly: const RewardTierProgress(claimed: 6),
        },
      );
      expect(text.focusTitle, 'المكافأة اليومية');
      expect(text.focusStatus, '✓ تم الاستلام');
      expect(text.focusHint, 'غدا مكافأة جديدة');
    });

    test('اكتمال المسار كله يُعلَن صراحة', () {
      final text = _text(
        onDay: 200,
        tiers: {
          for (final tier in RewardTier.values)
            tier: RewardTierProgress(claimed: tier.totalClaims),
        },
      );
      expect(text.focusTitle, 'اكتمل مسار الجوائز');
      expect(text.focusAmount, isEmpty);
      expect(text.cta, 'افتح اللعبة');
    });
  });

  group('صيغ الأيام العربية', () {
    test('السلسلة: المفرد والمثنى والجمع لكلٍّ لفظه', () {
      expect(_text(streak: 1).streak, contains('يوم واحد'));
      expect(_text(streak: 2).streak, contains('يومان'));
      expect(_text(streak: 5).streak, contains('5 أيام'));
      expect(_text(streak: 30).streak, contains('30 يوما'));
    });

    test('بلا سلسلة: دعوة لبدئها لا «0 يوم»', () {
      final streak = _text(streak: 0).streak;
      expect(streak, 'ابدأ سلسلتك اليوم');
      expect(streak, isNot(contains('0')));
    });

    test('«بعد كم يوم» يتبع نفس الصيغ', () {
      // الأسبوعية تُفتح اليوم السابع
      expect(
        _text(onDay: 6, tiers: {
          RewardTier.daily: RewardTierProgress(
            claimed: 7,
            lastClaimDay: _day(6),
          ),
        }).focusStatus,
        'غدا',
      );
      expect(
        _text(onDay: 5, tiers: {
          RewardTier.daily: RewardTierProgress(
            claimed: 7,
            lastClaimDay: _day(5),
          ),
        }).focusStatus,
        'بعد يومين',
      );
    });
  });

  group('تقدّم الدورة نصّا', () {
    test('الأسبوعية: «4 / 7 أيام»', () {
      final text = _text(
        onDay: 4,
        tiers: {
          RewardTier.daily: RewardTierProgress(
            claimed: 5,
            lastClaimDay: _day(4),
          ),
        },
      );
      expect(text.focusProgress, '4 / 7 أيام');
    });

    test('اليومية بلا تقدّم — دورتها يوم واحد', () {
      expect(_text().focusProgress, isEmpty);
    });

    test('الشهرية: «X / 30 يوما»', () {
      final text = _text(
        onDay: 12,
        tiers: {
          RewardTier.daily: RewardTierProgress(
            claimed: 7,
            lastClaimDay: _day(12),
          ),
          RewardTier.weekly: const RewardTierProgress(claimed: 4),
        },
      );
      expect(text.focusProgress, '12 / 30 يوما');
    });
  });

  group('العربية والإنجليزية', () {
    test('النصّ الإنجليزي بلا حرف عربي واحد', () {
      final arabic = RegExp(r'[؀-ۿ]');
      final text = _text(lang: 'en', onDay: 4);
      for (final value in [
        text.focusTitle,
        text.focusStatus,
        text.focusHint,
        text.focusProgress,
        text.cta,
        text.streak,
        text.allTitle,
        text.stats,
        text.emptyTitle,
        text.emptyHint,
        ...text.tierTitles,
        ...text.tierStatuses,
      ]) {
        expect(arabic.hasMatch(value), isFalse, reason: value);
      }
    });

    test('العناوين الثلاثة مختلفة في اللغتين', () {
      for (final lang in ['ar', 'en']) {
        expect(_text(lang: lang).tierTitles.toSet().length, 3);
      }
    });

    test('كل نصّ مطلوب غير فارغ', () {
      final text = _text(onDay: 4);
      expect(text.appName, isNotEmpty);
      expect(text.focusTitle, isNotEmpty);
      expect(text.focusStatus, isNotEmpty);
      expect(text.cta, isNotEmpty);
      expect(text.streak, isNotEmpty);
      expect(text.allTitle, isNotEmpty);
      expect(text.stats, isNotEmpty);
      expect(text.emptyTitle, isNotEmpty);
      expect(text.emptyHint, isNotEmpty);
      expect(text.tierTitles, hasLength(3));
      expect(text.tierStatuses, hasLength(3));
      expect(text.tierStatuses.every((s) => s.isNotEmpty), isTrue);
    });
  });

  group('الإحصاءات تحمل الأرقام الحيّة', () {
    test('المراحل والفصول والعوالم كلها في السطر', () {
      final stats = _text().stats;
      expect(stats, contains('137'));
      expect(stats, contains('11'));
      expect(stats, contains('2'));
    });
  });

  group('النصوص تصل إلى JSON الذي يقرؤه الجانب الأصلي', () {
    test('كل مفتاح نصّي مذكور في الودجة الأصلية موجود', () {
      final json = _build().toJson()['text'] as Map<String, Object?>;
      // مكتوبة حرفيا في HurufWidgetProvider.kt وHurufWidget.swift
      for (final key in [
        'focusTitle', 'focusAmount', 'focusStatus', 'focusProgress',
        'cta', 'streak', 'tierTitles', 'tierStatuses', 'allTitle', 'stats',
      ]) {
        expect(json.containsKey(key), isTrue, reason: 'المفتاح $key مفقود');
      }
    });
  });
}
