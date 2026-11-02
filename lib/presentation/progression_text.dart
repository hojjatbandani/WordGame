// نصوص عرض نظام التقدّم الجديد. WorldDef/ChapterDef/StageDef (المهمة
// السابقة) تحمل معرّفات فقط (nameKey/themeId/mechanicId) عمدا، لا نصا —
// هذا الملف وحده يحوّلها لعربي/إنجليزي عبر lang.t()، تماما كبقية
// الشاشات في هذا المشروع. لا شاشة تكتب نص عالم مباشرة، كلها تمرّ من هنا.

import '../core/app_language.dart';
import '../data/progression/map_view_model.dart';

String worldName(String nameKey, AppLanguage lang) {
  switch (nameKey) {
    case 'bidaya':
      return lang.t('البداية', 'The Beginning');
    case 'waha':
      return lang.t('الواحة', 'The Oasis');
    case 'souq':
      return lang.t('السوق', 'The Market');
    case 'madina':
      return lang.t('المدينة', 'The City');
    case 'diwan':
      return lang.t('الديوان', 'The Court');
    case 'khaleej':
      return lang.t('الخليج', 'The Gulf');
    case 'hikma':
      return lang.t('أرض الحكمة', 'Land of Wisdom');
    case 'ustura':
      return lang.t('الأسطورة', 'The Legend');
    default:
      return nameKey;
  }
}

String worldSubtitle(String themeId, AppLanguage lang) {
  switch (themeId) {
    case 'journey_start':
      return lang.t('بداية الرحلة', 'The journey begins');
    case 'oasis':
      return lang.t('استرح واسق عقلك بالكلمات', 'Rest and refresh with words');
    case 'market':
      return lang.t('كلمات التجارة والثقافة', 'Words of trade and culture');
    case 'city':
      return lang.t('أمثال المدينة', 'Proverbs of the city');
    case 'royal_court':
      return lang.t('شعر الديوان', 'The poetry of the court');
    case 'the_gulf':
      return lang.t('لهجة أهل الخليج', 'Gulf dialect words');
    case 'land_of_wisdom':
      return lang.t('خمّن من المعنى', 'Guess from the meaning');
    case 'legend':
      return lang.t('تحدٍّ أخير، بلا خلط', 'The final challenge, no shuffle');
    default:
      return themeId;
  }
}

/// وصف قصير للميكانيكا الجديدة — تُعرض في بطاقة "ميكانيكا جديدة" في
/// مراسم فتح العالم فقط؛ لا تُنفَّذ الميكانيكا فعليا بعد (سلوكها مهمة
/// لاحقة، تماما كما وُثّق في المهمة الأولى: "behavior comes in a later task")
String mechanicName(String mechanicId, AppLanguage lang) {
  switch (mechanicId) {
    case 'base':
      return lang.t('العجلة الأساسية', 'The basic wheel');
    case 'bonus_jar':
      return lang.t('جرّة الكلمات الإضافية', 'The bonus word jar');
    case 'locked_letters':
      return lang.t('حروف مقفلة', 'Locked letters');
    case 'complete_proverb':
      return lang.t('أكمل المثل', 'Complete the proverb');
    case 'complete_verse':
      return lang.t('أكمل البيت', 'Complete the verse');
    case 'timed':
      return lang.t('مراحل موقوتة', 'Timed stages');
    case 'guess_from_definition':
      return lang.t('خمّن من التعريف', 'Guess from the definition');
    case 'combined_no_shuffle':
      return lang.t('تحدٍّ مركّب، بلا خلط', 'Combined challenge, no shuffle');
    default:
      return mechanicId;
  }
}

String nearRewardBannerText(NearRewardBannerData data, AppLanguage lang) {
  switch (data.kind) {
    case NearRewardKind.wordsToJar:
      return lang.t(
        '${data.remaining} كلمات لملء الجرّة',
        '${data.remaining} words to fill the jar',
      );
    case NearRewardKind.stagesToChest:
      return lang.t(
        '${data.remaining} مراحل للصندوق',
        '${data.remaining} stages to the chest',
      );
    case NearRewardKind.worldCompletionPercent:
      final percent = data.percent.round();
      return lang.t(
        'أكملت $percent٪ من هذا العالم',
        '$percent% of this world complete',
      );
  }
}

/// جملة شرط فتح عالم — تُركَّب من بيانات خام (WorldUnlockConditionData)،
/// لا نصا جاهزا، كي تبقى صحيحة أيا كانت أرقام BalanceConfig وقتها
String worldUnlockConditionText(
  WorldUnlockConditionData condition,
  String requiredWorldNameKey,
  AppLanguage lang,
) {
  return lang.t(
    'أكمل عالم «${worldName(requiredWorldNameKey, lang)}»',
    'Finish "${worldName(requiredWorldNameKey, lang)}"',
  );
}
