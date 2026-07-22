import 'package:flutter/material.dart';

/// عدد مراحل كل عالم (المجموع 500، ولا يقل عالم عن 50)
const worldSizes = [62, 62, 62, 62, 63, 63, 63, 63];

int get totalLevels => 500;

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
  final String background;
  final String guideId;
  final Color accent;
  final int completionReward;

  const WorldModel({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.taglineAr,
    required this.guideId,
    required this.accent,
    this.completionReward = 100,
  }) : background = 'assets/backgrounds/$slug.png';

  int get levelCount => worldSizes[id - 1];
  int get firstLevelId => worldStartLevel(id);
  int get lastLevelId => firstLevelId + levelCount - 1;

  factory WorldModel.fromJson(Map<String, dynamic> json) => WorldModel(
        id: json['id'] as int,
        slug: json['slug'] as String,
        nameAr: json['name_ar'] as String,
        taglineAr: json['tagline_ar'] as String,
        guideId: json['guide_id'] as String,
        accent: Color(json['accent'] as int),
        completionReward: json['completion_reward'] as int? ?? 100,
      );
}

const worlds = [
  WorldModel(
    id: 1,
    slug: 'forest',
    nameAr: 'الغابة',
    taglineAr: 'بداية الرحلة بين الأشجار',
    guideId: 'little_genius',
    accent: Color(0xFF34E89E),
  ),
  WorldModel(
    id: 2,
    slug: 'valley',
    nameAr: 'الوادي الملون',
    taglineAr: 'حيث تتفتح الكلمات كالأزهار',
    guideId: 'clever_girl',
    accent: Color(0xFFFF6B9D),
  ),
  WorldModel(
    id: 3,
    slug: 'mountains',
    nameAr: 'الجبال الضبابية',
    taglineAr: 'قمم عالية وكلمات أعلى',
    guideId: 'young_man',
    accent: Color(0xFF6FB7D9),
  ),
  WorldModel(
    id: 4,
    slug: 'enchanted_forest',
    nameAr: 'الغابة المسحورة',
    taglineAr: 'أسرار تختبئ خلف كل حرف',
    guideId: 'young_woman',
    accent: Color(0xFF9B59B6),
  ),
  WorldModel(
    id: 5,
    slug: 'oasis',
    nameAr: 'الواحة',
    taglineAr: 'استرح واسق عقلك بالكلمات',
    guideId: 'story_teller',
    accent: Color(0xFFF4C430),
  ),
  WorldModel(
    id: 6,
    slug: 'desert_river',
    nameAr: 'نهر الصحراء',
    taglineAr: 'ماء وسط الرمال الذهبية',
    guideId: 'friendly_grandma',
    accent: Color(0xFF4FC3F7),
  ),
  WorldModel(
    id: 7,
    slug: 'sunset_oasis',
    nameAr: 'واحة الغروب',
    taglineAr: 'ألوان الأصيل وحكمة الكلمات',
    guideId: 'wise_oldman',
    accent: Color(0xFFB388FF),
  ),
  WorldModel(
    id: 8,
    slug: 'golden_city',
    nameAr: 'مدينة القباب',
    taglineAr: 'التحدي الأخير في المدينة الذهبية',
    guideId: 'challenger_boy',
    accent: Color(0xFFFF9F1C),
    completionReward: 300,
  ),
];

WorldModel worldForLevel(int levelId) {
  for (final world in worlds) {
    if (levelId <= world.lastLevelId) return world;
  }
  return worlds.last;
}

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

  factory CharacterModel.fromJson(Map<String, dynamic> json) =>
      CharacterModel(
        id: json['id'] as String,
        nameAr: json['name_ar'] as String,
      );
}

const characters = <String, CharacterModel>{
  'puzzle_master': CharacterModel(id: 'puzzle_master', nameAr: 'أبو الحروف'),
  'little_genius': CharacterModel(id: 'little_genius', nameAr: 'العبقري الصغير'),
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
  CharacterEmotion.surprised: [
    'واو! كلمة إضافية!',
    'ما توقعتها! أحسنت',
  ],
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

  factory RewardModel.fromJson(Map<String, dynamic> json) => RewardModel(
        type: json['type'] as String,
        amount: json['amount'] as int,
      );

  Map<String, dynamic> toJson() => {'type': type, 'amount': amount};
}
