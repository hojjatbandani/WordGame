import 'package:flutter/material.dart';

import '../config/balance_config.dart';

/// عدد مراحل كل عالم — يُشتق من [BalanceConfig] لا يُكتب هنا: نظام
/// التقدّم (progression/world_defs.dart) يبني حدود العوالم من نفس
/// الأرقام، وقائمة منفصلة هنا كانت تعطي حدودا مختلفة (62/63 مقابل
/// 60/65) فتعرض شاشة اللعب خلفية عالم ومرشده لمراحل تنتمي فعلا للعالم
/// التالي، وتمنح مكافأة «إتمام العالم» في مرحلة غير مرحلته الأخيرة.
List<int> get worldSizes => [
  for (var worldId = 1; worldId <= BalanceConfig.worldCount; worldId++)
    BalanceConfig.worldStageCount(worldId),
];

int get totalLevels => BalanceConfig.totalStages;

/// أول مرحلة في العالم [worldId]
int worldStartLevel(int worldId) {
  var start = 1;
  for (var i = 0; i < worldId - 1; i++) {
    start += worldSizes[i];
  }
  return start;
}

/// عالم من عوالم اللعبة — قابل للتسلسل لاحقا من Laravel API
class WorldModel {
  final int id;
  final String slug;
  final String nameAr;
  final String taglineAr;

  /// اسم العالم بالإنجليزية — لخريطة العوالم في وضع الواجهة الإنجليزية فقط
  final String nameEn;
  final String taglineEn;
  final String background;
  final String guideId;
  final Color accent;

  const WorldModel({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.taglineAr,
    required this.nameEn,
    required this.taglineEn,
    required this.guideId,
    required this.accent,
  }) : background = 'assets/backgrounds/$slug.png';

  /// مكافأة إتمام العالم — الرقم الوحيد هو [BalanceConfig.coinsWorldComplete]:
  /// خريطة العوالم ومراسم الفتح تعدان به، وكان هنا رقم آخر (100، و300
  /// للعالم الأخير) هو ما يُدفع فعلا، فيرى اللاعب وعدا ويقبض غيره.
  int get completionReward => BalanceConfig.coinsWorldComplete;

  int get levelCount => worldSizes[id - 1];
  int get firstLevelId => worldStartLevel(id);
  int get lastLevelId => firstLevelId + levelCount - 1;

  factory WorldModel.fromJson(Map<String, dynamic> json) => WorldModel(
    id: json['id'] as int,
    slug: json['slug'] as String,
    nameAr: json['name_ar'] as String,
    taglineAr: json['tagline_ar'] as String,
    nameEn: json['name_en'] as String? ?? json['name_ar'] as String,
    taglineEn: json['tagline_en'] as String? ?? json['tagline_ar'] as String,
    guideId: json['guide_id'] as String,
    accent: Color(json['accent'] as int),
  );
}

const worlds = [
  WorldModel(
    id: 1,
    slug: 'forest',
    nameAr: 'الغابة',
    taglineAr: 'بداية الرحلة بين الأشجار',
    nameEn: 'The Forest',
    taglineEn: 'The journey begins among the trees',
    guideId: 'little_genius',
    accent: Color(0xFF34E89E),
  ),
  WorldModel(
    id: 2,
    slug: 'valley',
    nameAr: 'الوادي الملون',
    taglineAr: 'حيث تتفتح الكلمات كالأزهار',
    nameEn: 'The Colorful Valley',
    taglineEn: 'Where words bloom like flowers',
    guideId: 'clever_girl',
    accent: Color(0xFFFF6B9D),
  ),
  WorldModel(
    id: 3,
    slug: 'mountains',
    nameAr: 'الجبال الضبابية',
    taglineAr: 'قمم عالية وكلمات أعلى',
    nameEn: 'The Misty Mountains',
    taglineEn: 'High peaks and even higher words',
    guideId: 'young_man',
    accent: Color(0xFF6FB7D9),
  ),
  WorldModel(
    id: 4,
    slug: 'enchanted_forest',
    nameAr: 'الغابة المسحورة',
    taglineAr: 'أسرار تختبئ خلف كل حرف',
    nameEn: 'The Enchanted Forest',
    taglineEn: 'Secrets hide behind every letter',
    guideId: 'young_woman',
    accent: Color(0xFF9B59B6),
  ),
  WorldModel(
    id: 5,
    slug: 'oasis',
    nameAr: 'الواحة',
    taglineAr: 'استرح واسق عقلك بالكلمات',
    nameEn: 'The Oasis',
    taglineEn: 'Rest and nourish your mind with words',
    guideId: 'story_teller',
    accent: Color(0xFFF4C430),
  ),
  WorldModel(
    id: 6,
    slug: 'desert_river',
    nameAr: 'نهر الصحراء',
    taglineAr: 'ماء وسط الرمال الذهبية',
    nameEn: 'The Desert River',
    taglineEn: 'Water amid golden sands',
    guideId: 'friendly_grandma',
    accent: Color(0xFF4FC3F7),
  ),
  WorldModel(
    id: 7,
    slug: 'sunset_oasis',
    nameAr: 'واحة الغروب',
    taglineAr: 'ألوان الأصيل وحكمة الكلمات',
    nameEn: 'The Sunset Oasis',
    taglineEn: 'The colors of dusk and the wisdom of words',
    guideId: 'wise_oldman',
    accent: Color(0xFFB388FF),
  ),
  WorldModel(
    id: 8,
    slug: 'golden_city',
    nameAr: 'مدينة القباب',
    taglineAr: 'التحدي الأخير في المدينة الذهبية',
    nameEn: 'The City of Domes',
    taglineEn: 'The final challenge in the golden city',
    guideId: 'challenger_boy',
    accent: Color(0xFFFF9F1C),
  ),
];

WorldModel worldForLevel(int levelId) {
  for (final world in worlds) {
    if (levelId <= world.lastLevelId) return world;
  }
  return worlds.last;
}

/// الهوية البصرية للعالم رقم [worldId] (صورة الخلفية + شخصية المرشد).
///
/// جسر بين نظام التقدّم الجديد (WorldDef في progression/world_defs.dart)
/// وبين الأصول البصرية التي تعيش هنا. النظام الجديد يحمل
/// `guideCharacterId` نائبا مولَّدا من اسم العالم (`guide_waha`) لا
/// يقابله مجلد أصول حقيقي، بينما المجلدات الفعلية في assets/characters/
/// أسماؤها (wise_oldman، clever_girl..) وهي هنا. كلا النظامين ثمانية
/// عوالم بالمعرّفات 1..8، فالمطابقة بالمعرّف مباشرة — نفس الجسر الذي
/// تستخدمه شاشة اللعب عبر [worldForLevel].
WorldModel worldVisualsById(int worldId) =>
    worlds[(worldId - 1).clamp(0, worlds.length - 1)];

/// حالات الشخصية العاطفية
enum CharacterEmotion {
  idle,
  happy,
  thinking,
  celebrating,
  encouraging,
  surprised,
  sad,
}

/// شخصية مرافقة — صورة ثابتة + مقطع MP4 واحد لكل شخصية
class CharacterModel {
  final String id;
  final String nameAr;

  const CharacterModel({required this.id, required this.nameAr});

  String get portrait => 'assets/characters/$id/images/portrait.png';
  String get animation => 'assets/characters/$id/animations/main.mp4';

  factory CharacterModel.fromJson(Map<String, dynamic> json) => CharacterModel(
    id: json['id'] as String,
    nameAr: json['name_ar'] as String,
  );
}

const characters = <String, CharacterModel>{
  'puzzle_master': CharacterModel(id: 'puzzle_master', nameAr: 'أبو الحروف'),
  'little_genius': CharacterModel(
    id: 'little_genius',
    nameAr: 'العبقري الصغير',
  ),
  'clever_girl': CharacterModel(id: 'clever_girl', nameAr: 'الذكية'),
  'young_man': CharacterModel(id: 'young_man', nameAr: 'الشاب'),
  'young_woman': CharacterModel(id: 'young_woman', nameAr: 'الشابة'),
  'story_teller': CharacterModel(id: 'story_teller', nameAr: 'الحكواتي'),
  'friendly_grandma': CharacterModel(id: 'friendly_grandma', nameAr: 'الجدة'),
  'wise_oldman': CharacterModel(id: 'wise_oldman', nameAr: 'الحكيم'),
  'challenger_boy': CharacterModel(id: 'challenger_boy', nameAr: 'المتحدي'),
};

/// المرشد العام للعبة
const mascot = 'puzzle_master';

/// رسائل خليجية ودودة لكل حالة — تختار عشوائيا
const characterMessages = <CharacterEmotion, List<String>>{
  CharacterEmotion.idle: [
    'هيا نلعب! الحروف بانتظارك',
    'يالله نبدأ، الكلمات تناديك',
    'جاهز؟ أنا معك خطوة بخطوة',
  ],
  CharacterEmotion.happy: [
    'أحسنت! إجابة رائعة',
    'ما شاء الله عليك!',
    'ممتاز! كفو والله',
  ],
  CharacterEmotion.thinking: [
    'دعني أساعدك قليلا',
    'همم... لنفكر معا',
    'خذ وقتك، الحل قريب',
  ],
  CharacterEmotion.celebrating: [
    'مبروك! أتممت المرحلة',
    'لقد حصلت على مكافأة جديدة',
    'إنجاز يستحق الاحتفال!',
  ],
  CharacterEmotion.encouraging: [
    'قريب! حاول مرة أخرى',
    'لا بأس، المحاولة سر النجاح',
    'واصل، أنت على الطريق الصحيح',
  ],
  CharacterEmotion.surprised: ['واو! كلمة إضافية!', 'ما توقعتها! أحسنت'],
  CharacterEmotion.sad: [
    'لا تستسلم، جرب من جديد',
    'المرة القادمة أفضل بإذن الله',
  ],
};

/// مكافأة قابلة للتوسعة (نقاط، مفاتيح، بطاقات...)
class RewardModel {
  final String type;
  final int amount;

  const RewardModel({required this.type, required this.amount});

  factory RewardModel.fromJson(Map<String, dynamic> json) =>
      RewardModel(type: json['type'] as String, amount: json['amount'] as int);

  Map<String, dynamic> toJson() => {'type': type, 'amount': amount};
}
