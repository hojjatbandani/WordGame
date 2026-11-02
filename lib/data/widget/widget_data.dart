// عقد البيانات بين تطبيق Flutter وودجة الشاشة الرئيسية (أندرويد/iOS).
// منطق صرف: بلا استيراد Flutter وبلا `DateTime.now()` داخلي، فيُختبَر
// كوحدة ويُقرأ من الجانبين بنفس الشكل.
//
// **الودجة طبقة عرض فقط.** لا تحسب مكافأة، ولا تُطالب بها، ولا تلمس
// الألماس ولا السلسلة ولا التقدّم. كل ما تعرفه هو هذه اللقطة الجاهزة،
// وكل تغيير في حالة اللعبة يبقى بيد التطبيق وحده (راجع
// home_widget_service.dart لآلية النقل، وrewards_screen.dart للمطالبة
// الفعلية).
//
// لماذا JSON واحد بدل عشرين مفتاحا مسطّحا: العقد كله يعيش في ملف واحد
// مقروء، ويُختبر بدورة ترميز/فكّ واحدة. الجانبان الأصليان يفكّانه
// بمكتبة النظام (org.json في كوتلن، JSONSerialization في سويفت).

import 'dart:convert';

import '../rewards/reward_track.dart';
import 'widget_text.dart';

/// رقم نسخة العقد. الودجة الأصلية تتحقّق منه وتعرض حالة «افتح اللعبة»
/// المحايدة إن وجدت نسخة لا تعرفها — تحديث التطبيق قد يسبق إعادة تشغيل
/// عملية الودجة، فلا يجوز أن يُسقطها شكل لم تكن تتوقّعه.
const int kWidgetDataSchemaVersion = 1;

/// حالة طبقة جائزة واحدة كما تُعرض في الودجة
class WidgetTierState {
  final RewardTier tier;

  /// مبلغ المطالبة التالية بالألماس
  final int coins;

  final int claimed;
  final int totalClaims;

  final bool isReady;
  final bool isComplete;

  /// طُولب بها في اليوم الحالي — يفصل «✓ تم الاستلام، غدا مكافأة جديدة»
  /// عن «لم تحن بعد»
  final bool claimedToday;

  /// كم يوما مضى من دورة هذه الطبقة الحالية، من [cyclePeriodDays].
  /// هذا ما ترسمه نقاط التقدّم (● ● ● ○ ○ ○ ○) وسطر «4 / 7 أيام».
  final int cycleElapsedDays;
  final int cyclePeriodDays;

  /// null يعني لا مطالبة تالية أصلا (انتهت الطبقة)
  final int? daysUntilReady;

  const WidgetTierState({
    required this.tier,
    required this.coins,
    required this.claimed,
    required this.totalClaims,
    required this.isReady,
    required this.isComplete,
    required this.claimedToday,
    required this.cycleElapsedDays,
    required this.cyclePeriodDays,
    required this.daysUntilReady,
  });

  Map<String, Object?> toJson() => {
    'tier': tier.name,
    'coins': coins,
    'claimed': claimed,
    'total': totalClaims,
    'ready': isReady,
    'done': isComplete,
    'claimedToday': claimedToday,
    'cycleDone': cycleElapsedDays,
    'cycleLen': cyclePeriodDays,
    'inDays': daysUntilReady,
  };

  static WidgetTierState? fromJson(Map<String, Object?> json) {
    final name = json['tier'];
    final tier = RewardTier.values
        .where((t) => t.name == name)
        .firstOrNull;
    if (tier == null) return null;
    return WidgetTierState(
      tier: tier,
      coins: _int(json['coins']),
      claimed: _int(json['claimed']),
      totalClaims: _int(json['total']),
      isReady: json['ready'] == true,
      isComplete: json['done'] == true,
      claimedToday: json['claimedToday'] == true,
      cycleElapsedDays: _int(json['cycleDone']),
      cyclePeriodDays: _int(json['cycleLen'], fallback: 1),
      daysUntilReady: json['inDays'] is int ? json['inDays'] as int : null,
    );
  }

  static int _int(Object? v, {int fallback = 0}) =>
      v is int ? v : (v is num ? v.toInt() : fallback);
}

/// لقطة كاملة لما تعرضه الودجة. كل ما فيها للعرض لا غير.
class HomeWidgetData {
  /// رصيد الألماس الحالي
  final int diamonds;

  final int streakDays;

  /// الطبقات الثلاث بترتيب [RewardTier.values] دوما
  final List<WidgetTierState> tiers;

  /// الطبقة التي تتصدّر الودجة الصغيرة — راجع [WidgetDataBuilder.pickFocus].
  /// null يعني اكتمل المسار كله فلا شيء يُبرَز.
  final RewardTier? focusTier;

  /// إحصاءات الرحلة (تُعرض في الحجم الكبير وحده)
  final int stagesCompleted;
  final int chaptersCompleted;
  final int worldsCompleted;

  /// 'ar' أو 'en' — الودجة تتبع لغة اللعبة لا لغة النظام، وعليها يُبنى
  /// اتجاه التخطيط. لعبة معروضة بالعربية داخل هاتف إنجليزي يجب أن تبقى
  /// ودجتها عربية RTL.
  final String languageCode;

  final DateTime updatedAt;

  const HomeWidgetData({
    required this.diamonds,
    required this.streakDays,
    required this.tiers,
    required this.focusTier,
    required this.stagesCompleted,
    required this.chaptersCompleted,
    required this.worldsCompleted,
    required this.languageCode,
    required this.updatedAt,
  });

  bool get isRtl => languageCode != 'en';

  /// اكتمل المسار كله: لا طبقة بقيت فيها مطالبة
  bool get trackComplete => tiers.every((t) => t.isComplete);

  /// أي جائزة جاهزة الآن — تقود حالة «جاهزة للاستلام» ونقطة التنبيه
  bool get hasClaimable => tiers.any((t) => t.isReady);

  WidgetTierState? tierOf(RewardTier tier) =>
      tiers.where((t) => t.tier == tier).firstOrNull;

  WidgetTierState? get focus => focusTier == null ? null : tierOf(focusTier!);

  /// الرابط العميق الذي تفتحه نقرة الودجة — يقود إلى بطاقة الطبقة
  /// المُبرَزة داخل شاشة الجوائز
  String get deepLink => WidgetDeepLink.forTier(focusTier);

  /// النصوص المعروضة تُبنى هنا لا في الجانب الأصلي — راجع الشرح في
  /// widget_text.dart (صياغة عربية واحدة لثلاث منصّات)
  Map<String, Object?> toJson() => {
    'v': kWidgetDataSchemaVersion,
    'diamonds': diamonds,
    'streak': streakDays,
    'tiers': [for (final t in tiers) t.toJson()],
    'focus': focusTier?.name,
    'focusIndex': focusTier == null
        ? -1
        : tiers.indexWhere((t) => t.tier == focusTier),
    'hasClaimable': hasClaimable,
    'stages': stagesCompleted,
    'chapters': chaptersCompleted,
    'worlds': worldsCompleted,
    'lang': languageCode,
    'rtl': isRtl,
    'deepLink': deepLink,
    'tierDeepLinks': [
      for (final t in tiers) WidgetDeepLink.forTier(t.tier),
    ],
    'updatedAt': updatedAt.toIso8601String(),
    'text': WidgetText.of(this).toJson(),
  };

  String encode() => jsonEncode(toJson());

  /// null إن كان النصّ غائبا أو تالفا أو من نسخة عقد أحدث — يعرض
  /// المستدعي حينها حالة محايدة بدل أن يرسم أرقاما مخترَعة
  static HomeWidgetData? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      if (json['v'] != kWidgetDataSchemaVersion) return null;

      final tiers = <WidgetTierState>[];
      for (final entry in (json['tiers'] as List? ?? const [])) {
        if (entry is! Map) continue;
        final tier = WidgetTierState.fromJson(entry.cast<String, Object?>());
        if (tier != null) tiers.add(tier);
      }
      if (tiers.isEmpty) return null;

      return HomeWidgetData(
        diamonds: WidgetTierState._int(json['diamonds']),
        streakDays: WidgetTierState._int(json['streak']),
        tiers: tiers,
        focusTier: RewardTier.values
            .where((t) => t.name == json['focus'])
            .firstOrNull,
        stagesCompleted: WidgetTierState._int(json['stages']),
        chaptersCompleted: WidgetTierState._int(json['chapters']),
        worldsCompleted: WidgetTierState._int(json['worlds']),
        languageCode: json['lang'] is String ? json['lang'] as String : 'ar',
        updatedAt:
            DateTime.tryParse('${json['updatedAt']}') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    } catch (_) {
      return null;
    }
  }
}

/// الروابط العميقة التي تفتحها الودجة.
///
/// المخطّط `huruf://` مُعلَن أصلا في AndroidManifest وInfo.plist لروابط
/// الدعوة، فلا مخطّط ثانٍ يُضاف لأجل الودجة — راجع deep_link_service.dart.
class WidgetDeepLink {
  const WidgetDeepLink._();

  static const scheme = 'huruf';
  static const host = 'rewards';

  /// `huruf://rewards` أو `huruf://rewards/daily|weekly|monthly`
  static String forTier(RewardTier? tier) =>
      tier == null ? '$scheme://$host' : '$scheme://$host/${tier.name}';

  /// الطبقة المطلوبة من رابط وارد، أو null إن لم يكن رابط جوائز أصلا.
  ///
  /// يعيد `(true, null)` لرابط `huruf://rewards` بلا طبقة — «افتح شاشة
  /// الجوائز بلا إبراز شيء» حالة صحيحة لا فشلا.
  static (bool isRewards, RewardTier? tier) parse(Uri uri) {
    if (uri.scheme != scheme || uri.host != host) return (false, null);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return (true, null);
    return (
      true,
      RewardTier.values.where((t) => t.name == segments.first).firstOrNull,
    );
  }
}
