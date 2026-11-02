import 'app_language.dart';
import 'referral_link.dart';
import 'store_links.dart';

/// حالة كلمة واحدة لأغراض المشاركة — مستقلة عن أي شاشة كي يُستخدم نفس
/// المولّد للتحدي اليومي والمراحل العادية على حد سواء.
///
/// المربّع هو *كل* ما يُنشر عن الكلمة: لا حروفها، ولا طولها، ولا أول
/// حرف منها. هذا ليس تفصيل تصميم — منشور يكشف الحلّ يقتل السبب الوحيد
/// لفتح الرابط، فيتحوّل أنجح ما في المشاركة إلى أضرّ ما فيها.
enum ShareWordStatus {
  /// حُلَّت من أول محاولة بلا تلميح
  solved,

  /// حُلَّت لكن بتلميح
  hinted,

  /// لم تُوجَد
  missed,
}

String _squareFor(ShareWordStatus s) => switch (s) {
      ShareWordStatus.solved => '🟩',
      ShareWordStatus.hinted => '🟨',
      ShareWordStatus.missed => '⬛',
    };

/// يبني نص المشاركة القابل للنسخ/الإرسال.
///
/// عقد ثابت لكل ما في هذا الملف: لا دالة هنا تقبل نصّ كلمة إطلاقا. أقرب
/// ما تقبله هو [ShareWordStatus] — لون بلا محتوى. أي تغيير يضيف معاملا
/// اسمه word/answer/solution إلى هذا الملف تغيير خاطئ بحكم التعريف،
/// ويكسر test/share_templates_test.dart عمدا.
class ShareTemplates {
  static const appName = 'حروف';
  static const appNameEn = 'Huruf';

  static String _squares(List<ShareWordStatus> words) =>
      words.map(_squareFor).join();

  /// تاريخ ميلادي مختصر (2026-08-26) — لا يعتمد على intl، ويُقرأ في كل
  /// لغة، ويبقى مرتّبا نصّيا حين تُجمع المنشورات
  static String formatDate(DateTime date) {
    final d = date.toUtc();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// سطر الترتيب. null يعني تعذّر جلبه (بلا اتصال) فيُحذف السطر كاملا
  /// بدل نشر «الترتيب: —» الذي لا يقول شيئا.
  static String? rankLine({
    required int? rank,
    required int totalPlayers,
    required AppLanguage lang,
  }) {
    if (rank == null || rank < 1) return null;
    if (totalPlayers < 2) return null; // «الأول من ١» ليس إنجازا
    return lang.t('🏅 الترتيب $rank من $totalPlayers',
        '🏅 Rank $rank of $totalPlayers');
  }

  static String level({
    required int levelId,
    required List<ShareWordStatus> words,
    required int bonusFound,
    required AppLanguage lang,
    String? inviteCode,
    String storeLink = StoreLinks.smart,
  }) {
    final solved = words.where((w) => w != ShareWordStatus.missed).length;
    final lines = <String>[
      lang.t('$appName — المرحلة $levelId', '$appNameEn — Level $levelId'),
      _squares(words),
      lang.t('$solved/${words.length} كلمات', '$solved/${words.length} words'),
    ];

    if (bonusFound >= 1) {
      lines.add(lang.t('🫙 $bonusFound كلمة إضافية',
          '🫙 $bonusFound bonus words'));
    }

    lines.add('');
    if (inviteCode == null) {
      lines.add(storeLink);
    } else {
      lines.add(ReferralLink.forCode(inviteCode));
      lines.add(lang.t('رمز دعوتي: $inviteCode', 'My invite code: $inviteCode'));
    }

    return lines.join('\n');
  }

  /// نصّ دعوة صديق — منفصل عن نصوص النتائج لأنه لا يحمل شبكة ولا نتيجة
  static String invite({
    required String code,
    required AppLanguage lang,
    int joinerReward = 100,
  }) =>
      lang.t(
          'تعال العب حروف معي! 🎯\n'
              'أدخل رمز دعوتي $code وخذ $joinerReward عملة هدية للبداية.\n'
              '${ReferralLink.forCode(code)}',
          'Come play Huruf with me! 🎯\n'
              'Enter my invite code $code and get $joinerReward bonus coins.\n'
              '${ReferralLink.forCode(code)}');
}
