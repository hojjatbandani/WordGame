import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/app_language.dart';
import 'package:huruf/core/referral_link.dart';
import 'package:huruf/core/share_templates.dart';
import 'package:huruf/core/store_links.dart';
import 'package:huruf/data/social_models.dart';

/// كلمات لغز افتراضي — لا تُمرَّر لأي دالة مشاركة إطلاقا (لا تقبل نصّ
/// كلمة أصلا). وجودها هنا كي نبحث عنها في المخرجات ونثبت غيابها.
const _solutionWords = ['قلم', 'كتاب', 'مدرسة', 'قمر', 'شمس'];

void main() {
  String level({
    List<ShareWordStatus> words = const [
      ShareWordStatus.solved,
      ShareWordStatus.hinted,
      ShareWordStatus.missed,
    ],
    String? inviteCode,
    AppLanguage lang = AppLanguage.ar,
  }) => ShareTemplates.level(
        levelId: 137,
        words: words,
        bonusFound: 3,
        inviteCode: inviteCode,
        lang: lang,
      );

  // ─────────────── اختبار القبول: لا كشف للحلّ إطلاقا ───────────────
  group('المشاركة لا تكشف أي كلمة', () {
    test('نصّ المشاركة خال من كلمات الحل بكل حالاتها', () {
      for (final statuses in [
        List.filled(5, ShareWordStatus.solved),
        List.filled(5, ShareWordStatus.hinted),
        List.filled(5, ShareWordStatus.missed),
        const [
          ShareWordStatus.solved,
          ShareWordStatus.missed,
          ShareWordStatus.hinted,
          ShareWordStatus.solved,
          ShareWordStatus.missed,
        ],
      ]) {
        final text = level(words: statuses, inviteCode: 'ABCD2345');
        for (final word in _solutionWords) {
          expect(text, isNot(contains(word)),
              reason: 'كلمة «$word» ظهرت في نصّ المشاركة');
        }

        // والأقوى من البحث عن كلمات بعينها: السطر الذي يصف الكلمات لا
        // يحتوي إلا مربّعات. أي حرف يتسرّب يوما إلى ذلك السطر يكسر هذا.
        final gridLine = text
            .split('\n')
            .firstWhere((l) => l.contains(RegExp('[🟩🟨⬛]')));
        expect(gridLine.replaceAll(RegExp('[🟩🟨⬛]'), ''), isEmpty,
            reason: 'سطر الشبكة يحوي شيئا غير المربّعات: $gridLine');
        expect(gridLine.runes.length, statuses.length);
      }
    });

    test('المربّعات وحدها هي ما يصف الكلمات — لا أحرف ولا أطوال', () {
      final text = level(
        words: const [ShareWordStatus.solved, ShareWordStatus.missed],
        lang: AppLanguage.en,
      );

      expect(text, contains('🟩⬛'));
      expect(text, isNot(contains('_')));
      expect(text, isNot(contains('?')));
    });
  });

  group('سطر الترتيب', () {
    test('الترتيب المجهول (بلا اتصال) يُحذف سطره لا يُعرض صفرا', () {
      expect(
        ShareTemplates.rankLine(
            rank: null, totalPlayers: 4300, lang: AppLanguage.ar),
        isNull,
      );
    });

    test('«الأول من واحد» ليس إنجازا فلا يُعرض', () {
      expect(
        ShareTemplates.rankLine(
            rank: 1, totalPlayers: 1, lang: AppLanguage.ar),
        isNull,
      );
    });

    test('الترتيب المعروف يحمل الرقمين معا', () {
      final line = ShareTemplates.rankLine(
          rank: 12, totalPlayers: 4300, lang: AppLanguage.ar);
      expect(line, contains('12'));
      expect(line, contains('4300'));
    });
  });

  group('رمز الدعوة داخل نصّ النتيجة', () {
    test('رمز الدعوة يحلّ محلّ رابط المتجر حين يُمرَّر', () {
      final text = level(inviteCode: 'ABCD2345');

      expect(text, contains('ABCD2345'));
      expect(text, contains(ReferralLink.forCode('ABCD2345')));
    });

    test('بلا رمز دعوة: رابط المتجر وحده، بلا أي رمز', () {
      final text = level();

      expect(text, contains(StoreLinks.smart));
      expect(text, isNot(contains('رمز دعوتي')));
    });
  });

  group('نص المشاركة — المرحلة العادية', () {
    test('يذكر رقم المرحلة والكلمات الإضافية', () {
      final text = ShareTemplates.level(
        levelId: 137,
        words: const [ShareWordStatus.solved, ShareWordStatus.solved],
        bonusFound: 3,
        lang: AppLanguage.ar,
      );

      expect(text, contains('المرحلة 137'));
      expect(text, contains('🟩🟩'));
      expect(text, contains('2/2'));
      expect(text, contains('3 كلمة إضافية'));
      expect(text, contains(StoreLinks.smart));
    });
  });

  group('نصّ الدعوة', () {
    test('يحمل الرمز والرابط والمكافأة', () {
      final text = ShareTemplates.invite(
        code: 'ABCD2345',
        lang: AppLanguage.ar,
        joinerReward: 100,
      );

      expect(text, contains('ABCD2345'));
      expect(text, contains(ReferralLink.forCode('ABCD2345')));
      expect(text, contains('100'));
    });
  });

  group('نتيجة إضافة صديق', () {
    test('تترجم رموز الخادم إلى رسائل عربية', () {
      expect(AddFriendOutcome.fromCode('sent'), AddFriendOutcome.sent);
      expect(AddFriendOutcome.fromCode('accepted'), AddFriendOutcome.accepted);
      expect(AddFriendOutcome.fromCode('not_found'), AddFriendOutcome.notFound);
      expect(AddFriendOutcome.fromCode('self'), AddFriendOutcome.self);
      expect(AddFriendOutcome.fromCode('full'), AddFriendOutcome.full);
      expect(
          AddFriendOutcome.fromCode('target_full'), AddFriendOutcome.targetFull);
      expect(AddFriendOutcome.fromCode('pending'), AddFriendOutcome.pending);
      // أي رمز غير متوقع يسقط على حالة الفشل العامة بدل أن يرمي
      expect(AddFriendOutcome.fromCode('???'), AddFriendOutcome.failed);
      expect(AddFriendOutcome.fromCode(null), AddFriendOutcome.failed);
    });

    test('الصداقة تُحتسب عند اكتمالها فقط لا عند إرسال الطلب', () {
      expect(AddFriendOutcome.accepted.isNewFriendship, isTrue);
      expect(AddFriendOutcome.sent.isNewFriendship, isFalse);
      expect(AddFriendOutcome.pending.isNewFriendship, isFalse);
      expect(AddFriendOutcome.exists.isNewFriendship, isFalse);
    });
  });
}
