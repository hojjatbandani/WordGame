import '../config/balance_config.dart';

/// العدّادات التي تُبنى عليها الإنجازات.
/// تُخزَّن محليا في ProgressStore بمفتاح `stat_<name>`.
enum StatKey {
  /// عدد المراحل المكتملة
  levelsCompleted,

  /// مجموع الكلمات الهدف التي حُلّت
  wordsFound,

  /// الكلمات الإضافية (خارج اللوح)
  bonusWords,

  /// المراحل التي أُنهيت دون أي تلميح
  perfectLevels,

  /// عدد التلميحات المشتراة — يُحصى للتقارير فقط. لا إنجاز عليه عمدا:
  /// مكافأة شراء التلميحات تكافئ سلوكا نريده أن يقلّ لا أن يزيد.
  hintsUsed,

  /// العوالم المكتملة بالكامل
  worldsCompleted,

  /// أطول كلمة كوّنها اللاعب (بعدد الحروف)
  longestWord,

  /// الأيام التقويمية التي لعب فيها اللاعب فعلا (مرّة واحدة لكل يوم،
  /// مهما تعدّدت جلساته). كان `dailyCompleted` (أيام التحدي اليومي
  /// المكتملة)، وحلّ محلّه عدّاد أيام اللعب بعد استبدال التحدي اليومي
  /// بمسار الجوائز: سبعة إنجازات مربوطة بعدّاد لا شيء يزيده صارت
  /// مستحيلة، والمعنى المقصود («ما فوّت يوما») يقيسه اللعب لا التحدي.
  daysPlayed,

  /// أطول سلسلة أيام متتالية
  bestStreak,

  /// تحدّيات الأمثال والشعر والكلمات المحلولة
  challengesSolved,

  /// الأصدقاء المضافون
  friendsAdded,

  /// دورات عجلة الحظ
  wheelSpins,

  /// مجموع العملات المكتسبة عبر اللعب
  pointsEarned,

  /// عدد اللاعبين الذين انضمّوا برمز دعوتك
  friendsInvited,

  /// مرات مشاركة النتيجة خارج التطبيق
  resultsShared,

  /// الفصول المكتملة بالكامل (كل مراحل الفصل) — العملة الفعلية للتقدّم
  /// بعد إزالة نظام النجوم
  chaptersCompleted,
}

extension StatKeyInfo on StatKey {
  /// فئة الإنجاز تُشتقّ من العدّاد ولا تُكتب في كل صف: كل عدّاد ينتمي
  /// لفئة واحدة بطبيعته، وكتابتها يدويا مئة مرة تدعو للتناقض.
  AchievementCategory get category => switch (this) {
    StatKey.levelsCompleted ||
    StatKey.worldsCompleted ||
    StatKey.chaptersCompleted => AchievementCategory.journey,
    StatKey.wordsFound ||
    StatKey.bonusWords ||
    StatKey.longestWord => AchievementCategory.words,
    StatKey.perfectLevels ||
    StatKey.challengesSolved ||
    StatKey.pointsEarned ||
    StatKey.hintsUsed => AchievementCategory.mastery,
    StatKey.bestStreak ||
    StatKey.daysPlayed ||
    StatKey.wheelSpins => AchievementCategory.daily,
    StatKey.friendsAdded ||
    StatKey.friendsInvited ||
    StatKey.resultsShared => AchievementCategory.social,
  };
}

enum AchievementTier { bronze, silver, gold, legend }

extension AchievementTierInfo on AchievementTier {
  String get titleAr => switch (this) {
    AchievementTier.bronze => 'برونزي',
    AchievementTier.silver => 'فضّي',
    AchievementTier.gold => 'ذهبي',
    AchievementTier.legend => 'أسطوري',
  };

  String get titleEn => switch (this) {
    AchievementTier.bronze => 'Bronze',
    AchievementTier.silver => 'Silver',
    AchievementTier.gold => 'Gold',
    AchievementTier.legend => 'Legendary',
  };

  /// لون الشارة — يقابل ألوان التطبيق في lib/core/theme.dart
  int get color => switch (this) {
    AchievementTier.bronze => 0xFFCD7F32,
    AchievementTier.silver => 0xFFB8C0D9,
    AchievementTier.gold => 0xFFF4C430,
    AchievementTier.legend => 0xFF9B59B6,
  };
}

enum AchievementCategory { journey, words, mastery, daily, social }

extension AchievementCategoryInfo on AchievementCategory {
  String get titleAr => switch (this) {
    AchievementCategory.journey => 'الرحلة',
    AchievementCategory.words => 'الكلمات',
    AchievementCategory.mastery => 'الإتقان',
    AchievementCategory.daily => 'المثابرة',
    AchievementCategory.social => 'اجتماعي',
  };

  String get titleEn => switch (this) {
    AchievementCategory.journey => 'Journey',
    AchievementCategory.words => 'Words',
    AchievementCategory.mastery => 'Mastery',
    AchievementCategory.daily => 'Persistence',
    AchievementCategory.social => 'Social',
  };

  String get emoji => switch (this) {
    AchievementCategory.journey => '🗺',
    AchievementCategory.words => '📖',
    AchievementCategory.mastery => '🎯',
    AchievementCategory.daily => '🔥',
    AchievementCategory.social => '🤝',
  };

  /// فئة معطّلة: لا تظهر في شاشة الإنجازات، ولا تُفتح إنجازاتها، ولا
  /// تدفع عملات، ولا تدخل في عدّ «مفتوح من أصل».
  ///
  /// «اجتماعي» معطّلة حتى إطلاق الميزات الاجتماعية: عرض «أضف أول صديق»
  /// في نسخة لا تُبرز شاشة الأصدقاء وعدٌ لا يُوفى. تُعاد بتغيير هذا
  /// السطر وحده، وتُلتقط إنجازاتها المستحقّة عند أول تغيّر في عدّادها
  /// بعد إعادتها.
  bool get isEnabled => this != AchievementCategory.social;
}

class Achievement {
  /// معرّف داخلي ثابت — لا يتغيّر أبدا بعد النشر لأن التقدّم محفوظ عليه
  final String id;
  final String titleAr;
  final String descriptionAr;

  /// نص إنجليزي — لشاشة الإنجازات في وضع الواجهة الإنجليزية فقط
  final String titleEn;
  final String descriptionEn;

  /// رمز تعبيري من Emoji 5.0 فأقدم حصرا — راجع
  /// test/ui/emoji_font_coverage_test.dart: خطّ التطبيق لا يحوي رموزا
  /// تعبيرية والنظام هو من يرسمها، فرمز أحدث من نسخة أندرويد يظهر
  /// مربّعا فارغا.
  final String emoji;
  final AchievementTier tier;
  final StatKey stat;

  /// القيمة المطلوبة لفتح الإنجاز
  final int target;

  const Achievement({
    required this.id,
    required this.emoji,
    required this.tier,
    required this.stat,
    required this.target,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
  });

  AchievementCategory get category => stat.category;

  /// مكافأة العملات عند الفتح — تُشتقّ من الطبقة ولا تُكتب في كل صف،
  /// لأن الطبقة هي مقياس الصعوبة الوحيد هنا. الأرقام في [BalanceConfig]
  /// فتقبل الضبط عن بعد.
  int get reward => switch (tier) {
    AchievementTier.bronze => BalanceConfig.coinsAchievementBronze,
    AchievementTier.silver => BalanceConfig.coinsAchievementSilver,
    AchievementTier.gold => BalanceConfig.coinsAchievementGold,
    // الأسطوري بلا عملات عمدا: مكافأته [cosmeticRewardId] وحدها
    AchievementTier.legend => 0,
  };

  /// معرّف عنصر زخرفي حصري — للطبقة الأسطورية فقط. هذا العنصر لا يُمنح
  /// من أي مصدر آخر ولا يُشترى بالعملات ولا بالشراء داخل التطبيق؛ فتح
  /// هذا الإنجاز هو الطريقة الوحيدة للحصول عليه. مشتقّ لا مكتوب، فلا
  /// يمكن أن يُنسى في صف ولا أن يخالف نمط التسمية.
  String? get cosmeticRewardId =>
      tier == AchievementTier.legend ? 'legend_$id' : null;

  double progressFor(int value) =>
      target <= 0 ? 1 : (value / target).clamp(0.0, 1.0);

  bool isEarnedAt(int value) => value >= target;
}

typedef _T = AchievementTier;
typedef _S = StatKey;

/// صف واحد في جدول الإنجازات. الوسائط بالترتيب: المعرّف، الرمز،
/// الطبقة، العدّاد، الهدف، العنوان عربي/إنجليزي، الوصف عربي/إنجليزي.
///
/// موضعية عمدا: مئة صف بوسائط مسمّاة تعني 1200 سطر لا تمسحها العين،
/// والمقصود هنا أن يُقرأ الجدول جدولا — الأهداف والطبقات في أعمدة
/// متحاذية — فيُرى تدرّج الصعوبة داخل كل عدّاد دفعة واحدة.
Achievement _a(
  String id,
  String emoji,
  _T tier,
  _S stat,
  int target,
  String titleAr,
  String titleEn,
  String descriptionAr,
  String descriptionEn,
) => Achievement(
  id: id,
  emoji: emoji,
  tier: tier,
  stat: stat,
  target: target,
  titleAr: titleAr,
  titleEn: titleEn,
  descriptionAr: descriptionAr,
  descriptionEn: descriptionEn,
);

/// كل إنجازات اللعبة — مئة إنجاز عبر خمس فئات، مرتّبة داخل كل عدّاد من
/// الأسهل للأصعب. المعرّفات إنجليزية عمدا لأنها مفاتيح تقنية تُربط
/// بمعرّفات Google Play Games (راجع lib/data/games_services_sync.dart)،
/// أما كل ما يراه اللاعب فعربي.
///
/// **كل هدف هنا قابل للبلوغ فعلا**: رُوجعت الأسقف مقابل المحتوى الموجود
/// — 500 مرحلة، 2907 كلمة أساسية، 2151 كلمة إضافية، 62 تحدّيا لغويا، 40
/// فصلا، 8 عوالم، وأطول كلمة في levels.json ثمانية حروف. أي هدف يتجاوز
/// سقفه وعدٌ لا يُوفى لا تحدٍّ.
///
/// ثلاثة إنجازات على الأقل قابلة للفتح خلال أول جلسة (~6 دقائق):
/// first_step، bonus_1، perfect_1.
///
/// ملاحظة على التغيير: أي لاعب فتح معرّفا حُذف يحتفظ به بصمت في
/// `unlocked_achievements` المحلي بلا أي أثر — نفس نمط تجاهل المعرّفات
/// غير الموجودة المتّبع أصلا في نظام المهمات.
final achievements = <Achievement>[
  // ═════════════════ الرحلة — المراحل المكتملة (13) ═════════════════
  _a(
    'first_step',
    '👣',
    _T.bronze,
    _S.levelsCompleted,
    1,
    'أول الطريق',
    'First Step',
    'أكمل أول مرحلة',
    'Complete your first stage',
  ),
  _a(
    'levels_5',
    '🚶',
    _T.bronze,
    _S.levelsCompleted,
    5,
    'خطوات أولى',
    'Getting Going',
    'أكمل 5 مراحل',
    'Complete 5 stages',
  ),
  _a(
    'levels_10',
    '🏃',
    _T.bronze,
    _S.levelsCompleted,
    10,
    'صرت تجري',
    'Picking Up Speed',
    'أكمل 10 مراحل',
    'Complete 10 stages',
  ),
  _a(
    'levels_25',
    '🐫',
    _T.silver,
    _S.levelsCompleted,
    25,
    'راحلة لا تتعب',
    'Tireless',
    'أكمل 25 مرحلة',
    'Complete 25 stages',
  ),
  _a(
    'levels_50',
    '🌴',
    _T.silver,
    _S.levelsCompleted,
    50,
    'ماشي بثبات',
    'Steady Progress',
    'أكمل 50 مرحلة',
    'Complete 50 stages',
  ),
  _a(
    'levels_75',
    '⛺',
    _T.gold,
    _S.levelsCompleted,
    75,
    'مخيّم في الطريق',
    'Camp on the Road',
    'أكمل 75 مرحلة',
    'Complete 75 stages',
  ),
  _a(
    'levels_100',
    '💯',
    _T.gold,
    _S.levelsCompleted,
    100,
    'مئة مرحلة',
    'One Hundred',
    'أكمل 100 مرحلة',
    'Complete 100 stages',
  ),
  _a(
    'levels_150',
    '🏜',
    _T.gold,
    _S.levelsCompleted,
    150,
    'عبرت الصحراء',
    'Across the Desert',
    'أكمل 150 مرحلة',
    'Complete 150 stages',
  ),
  _a(
    'levels_200',
    '⛰',
    _T.gold,
    _S.levelsCompleted,
    200,
    'منتصف الرحلة',
    'Halfway Through',
    'أكمل 200 مرحلة',
    'Complete 200 stages',
  ),
  _a(
    'levels_250',
    '🏔',
    _T.gold,
    _S.levelsCompleted,
    250,
    'فوق القمّة',
    'Above the Peak',
    'أكمل 250 مرحلة',
    'Complete 250 stages',
  ),
  _a(
    'levels_300',
    '🌅',
    _T.gold,
    _S.levelsCompleted,
    300,
    'فجر جديد',
    'A New Dawn',
    'أكمل 300 مرحلة',
    'Complete 300 stages',
  ),
  _a(
    'levels_375',
    '🏰',
    _T.gold,
    _S.levelsCompleted,
    375,
    'على أبواب القلعة',
    'At the Castle Gates',
    'أكمل 375 مرحلة',
    'Complete 375 stages',
  ),
  _a(
    'levels_450',
    '🕌',
    _T.gold,
    _S.levelsCompleted,
    450,
    'قاب قوسين',
    'Almost There',
    'أكمل 450 مرحلة',
    'Complete 450 stages',
  ),

  // ═════════════════ الرحلة — العوالم (6) ═════════════════
  _a(
    'world_1',
    '🌳',
    _T.bronze,
    _S.worldsCompleted,
    1,
    'خرجت من الغابة',
    'Out of the Forest',
    'أكمل عالما كاملا',
    'Complete a full world',
  ),
  _a(
    'world_2',
    '🏞',
    _T.bronze,
    _S.worldsCompleted,
    2,
    'عالمان خلفك',
    'Two Worlds Behind',
    'أكمل عالمين',
    'Complete 2 worlds',
  ),
  _a(
    'world_3',
    '🌊',
    _T.silver,
    _S.worldsCompleted,
    3,
    'عبرت النهر',
    'Across the River',
    'أكمل 3 عوالم',
    'Complete 3 worlds',
  ),
  _a(
    'world_4',
    '🗺',
    _T.silver,
    _S.worldsCompleted,
    4,
    'رحّالة',
    'Wanderer',
    'أكمل 4 عوالم',
    'Complete 4 worlds',
  ),
  _a(
    'world_6',
    '🌌',
    _T.gold,
    _S.worldsCompleted,
    6,
    'ستّة عوالم',
    'Six Worlds',
    'أكمل 6 عوالم',
    'Complete 6 worlds',
  ),
  _a(
    'world_8',
    '🏙',
    _T.legend,
    _S.worldsCompleted,
    8,
    'فاتح المدينة الذهبية',
    'Conqueror of the Golden City',
    'أكمل العوالم الثمانية كلها',
    'Complete all 8 worlds',
  ),

  // ═════════════════ الرحلة — الفصول (7) ═════════════════
  _a(
    'chapters_1',
    '📖',
    _T.bronze,
    _S.chaptersCompleted,
    1,
    'أول فصل',
    'First Chapter',
    'أكمل فصلا كاملا',
    'Complete a full chapter',
  ),
  _a(
    'chapters_3',
    '📗',
    _T.bronze,
    _S.chaptersCompleted,
    3,
    'ثلاثة فصول',
    'Three Chapters',
    'أكمل 3 فصول',
    'Complete 3 chapters',
  ),
  _a(
    'chapters_5',
    '📘',
    _T.silver,
    _S.chaptersCompleted,
    5,
    'خمسة فصول',
    'Five Chapters',
    'أكمل 5 فصول',
    'Complete 5 chapters',
  ),
  _a(
    'chapters_10',
    '📙',
    _T.silver,
    _S.chaptersCompleted,
    10,
    'عشرة فصول',
    'Ten Chapters',
    'أكمل 10 فصول',
    'Complete 10 chapters',
  ),
  _a(
    'chapters_20',
    '📚',
    _T.gold,
    _S.chaptersCompleted,
    20,
    'نصف الكتاب',
    'Half the Book',
    'أكمل 20 فصلا',
    'Complete 20 chapters',
  ),
  _a(
    'chapters_30',
    '📜',
    _T.gold,
    _S.chaptersCompleted,
    30,
    'ثلاثون فصلا',
    'Thirty Chapters',
    'أكمل 30 فصلا',
    'Complete 30 chapters',
  ),
  _a(
    'chapters_40',
    '🏆',
    _T.legend,
    _S.chaptersCompleted,
    40,
    'كل الفصول',
    'Every Chapter',
    'أكمل الأربعين فصلا كلها',
    'Complete all 40 chapters',
  ),

  // ═════════════════ الكلمات — الكلمات الأساسية (9) ═════════════════
  _a(
    'words_50',
    '📝',
    _T.bronze,
    _S.wordsFound,
    50,
    'جامع الكلمات',
    'Word Collector',
    'كوّن 50 كلمة',
    'Form 50 words',
  ),
  _a(
    'words_100',
    '📋',
    _T.bronze,
    _S.wordsFound,
    100,
    'مئة كلمة',
    'One Hundred Words',
    'كوّن 100 كلمة',
    'Form 100 words',
  ),
  _a(
    'words_150',
    '🔍',
    _T.bronze,
    _S.wordsFound,
    150,
    'عين لا تخطئ',
    'A Sharp Eye',
    'كوّن 150 كلمة',
    'Form 150 words',
  ),
  _a(
    'words_300',
    '📊',
    _T.bronze,
    _S.wordsFound,
    300,
    'ثلاثمئة كلمة',
    'Three Hundred Words',
    'كوّن 300 كلمة',
    'Form 300 words',
  ),
  _a(
    'words_500',
    '📚',
    _T.silver,
    _S.wordsFound,
    500,
    'حصيلة تكبر',
    'Growing Vocabulary',
    'كوّن 500 كلمة',
    'Form 500 words',
  ),
  _a(
    'words_1000',
    '📓',
    _T.silver,
    _S.wordsFound,
    1000,
    'ألف كلمة',
    'A Thousand Words',
    'كوّن 1000 كلمة',
    'Form 1000 words',
  ),
  _a(
    'words_1500',
    '💡',
    _T.gold,
    _S.wordsFound,
    1500,
    'لسان فصيح',
    'Eloquent Tongue',
    'كوّن 1500 كلمة',
    'Form 1500 words',
  ),
  _a(
    'words_2000',
    '🧠',
    _T.gold,
    _S.wordsFound,
    2000,
    'قاموس ماشي',
    'Walking Dictionary',
    'كوّن 2000 كلمة',
    'Form 2000 words',
  ),
  _a(
    'words_2500',
    '🐋',
    _T.legend,
    _S.wordsFound,
    2500,
    'بحر لا ينضب',
    'Bottomless Sea',
    'كوّن 2500 كلمة',
    'Form 2500 words',
  ),

  // ═════════════════ الكلمات — الكلمات الإضافية (8) ═════════════════
  _a(
    'bonus_1',
    '🎁',
    _T.bronze,
    _S.bonusWords,
    1,
    'أول اكتشاف',
    'First Discovery',
    'اكتشف أول كلمة إضافية',
    'Find your first bonus word',
  ),
  _a(
    'bonus_10',
    '🌸',
    _T.bronze,
    _S.bonusWords,
    10,
    'عشر إضافيات',
    'Ten Extras',
    'اكتشف 10 كلمات إضافية',
    'Discover 10 bonus words',
  ),
  _a(
    'bonus_25',
    '🎣',
    _T.bronze,
    _S.bonusWords,
    25,
    'صيّاد مبتدئ',
    'Novice Hunter',
    'اكتشف 25 كلمة إضافية',
    'Discover 25 bonus words',
  ),
  _a(
    'bonus_50',
    '🎯',
    _T.silver,
    _S.bonusWords,
    50,
    'عين على الخفيّ',
    'Eye for the Hidden',
    'اكتشف 50 كلمة إضافية',
    'Discover 50 bonus words',
  ),
  _a(
    'bonus_100',
    '🏺',
    _T.silver,
    _S.bonusWords,
    100,
    'صيّاد الكلمات',
    'Word Hunter',
    'اكتشف 100 كلمة إضافية',
    'Discover 100 bonus words',
  ),
  _a(
    'bonus_200',
    '🗝',
    _T.gold,
    _S.bonusWords,
    200,
    'كنز مخبوء',
    'Hidden Treasure',
    'اكتشف 200 كلمة إضافية',
    'Discover 200 bonus words',
  ),
  _a(
    'bonus_350',
    '🔑',
    _T.gold,
    _S.bonusWords,
    350,
    'مفتاح كل جرّة',
    'Key to Every Jar',
    'اكتشف 350 كلمة إضافية',
    'Discover 350 bonus words',
  ),
  _a(
    'bonus_500',
    '🦅',
    _T.legend,
    _S.bonusWords,
    500,
    'ما يفوته شي',
    'Nothing Escapes You',
    'اكتشف 500 كلمة إضافية',
    'Discover 500 bonus words',
  ),

  // ═════════════════ الكلمات — أطول كلمة (5) ═════════════════
  _a(
    'word_len_4',
    '🔤',
    _T.bronze,
    _S.longestWord,
    4,
    'أربعة حروف',
    'Four Letters',
    'كوّن كلمة من 4 حروف',
    'Form a 4-letter word',
  ),
  _a(
    'word_len_5',
    '✏',
    _T.bronze,
    _S.longestWord,
    5,
    'خمسة حروف',
    'Five Letters',
    'كوّن كلمة من 5 حروف',
    'Form a 5-letter word',
  ),
  _a(
    'word_len_6',
    '📏',
    _T.silver,
    _S.longestWord,
    6,
    'ستّة حروف',
    'Six Letters',
    'كوّن كلمة من 6 حروف',
    'Form a 6-letter word',
  ),
  _a(
    'word_len_7',
    '📐',
    _T.gold,
    _S.longestWord,
    7,
    'سبعة حروف',
    'Seven Letters',
    'كوّن كلمة من 7 حروف',
    'Form a 7-letter word',
  ),
  _a(
    'word_len_8',
    '👑',
    _T.legend,
    _S.longestWord,
    8,
    'أطول كلمة في اللعبة',
    'The Longest Word',
    'كوّن كلمة من 8 حروف',
    'Form an 8-letter word',
  ),

  // ═════════════════ الإتقان — بلا تلميح (10) ═════════════════
  _a(
    'perfect_1',
    '✨',
    _T.bronze,
    _S.perfectLevels,
    1,
    'بلا مساعدة',
    'No Help Needed',
    'أنهِ مرحلة دون أي تلميح',
    'Finish a stage without any hint',
  ),
  _a(
    'perfect_5',
    '⭐',
    _T.bronze,
    _S.perfectLevels,
    5,
    'خمس نظيفة',
    'Five Clean',
    'أنهِ 5 مراحل دون تلميح',
    'Finish 5 stages without hints',
  ),
  _a(
    'perfect_15',
    '🌠',
    _T.bronze,
    _S.perfectLevels,
    15,
    'خمس عشرة نظيفة',
    'Fifteen Clean',
    'أنهِ 15 مرحلة دون تلميح',
    'Finish 15 stages without hints',
  ),
  _a(
    'perfect_30',
    '💫',
    _T.silver,
    _S.perfectLevels,
    30,
    'ثلاثون بلا تلميح',
    'Thirty Clean',
    'أنهِ 30 مرحلة دون تلميح',
    'Finish 30 stages without hints',
  ),
  _a(
    'perfect_50',
    '❄',
    _T.silver,
    _S.perfectLevels,
    50,
    'عقل صافي',
    'Sharp Mind',
    'أنهِ 50 مرحلة دون تلميح',
    'Finish 50 stages without hints',
  ),
  _a(
    'perfect_75',
    '🔎',
    _T.silver,
    _S.perfectLevels,
    75,
    'نظر ثاقب',
    'Piercing Sight',
    'أنهِ 75 مرحلة دون تلميح',
    'Finish 75 stages without hints',
  ),
  _a(
    'perfect_100',
    '🥇',
    _T.gold,
    _S.perfectLevels,
    100,
    'مئة بلا مساعدة',
    'A Hundred Unaided',
    'أنهِ 100 مرحلة دون تلميح',
    'Finish 100 stages without hints',
  ),
  _a(
    'perfect_150',
    '💎',
    _T.gold,
    _S.perfectLevels,
    150,
    'ما يحتاج أحد',
    'Self-Sufficient',
    'أنهِ 150 مرحلة دون تلميح',
    'Finish 150 stages without hints',
  ),
  _a(
    'perfect_250',
    '🏅',
    _T.gold,
    _S.perfectLevels,
    250,
    'إتقان راسخ',
    'Rooted Mastery',
    'أنهِ 250 مرحلة دون تلميح',
    'Finish 250 stages without hints',
  ),
  _a(
    'perfect_400',
    '🔮',
    _T.legend,
    _S.perfectLevels,
    400,
    'إتقان مطلق',
    'Absolute Mastery',
    'أنهِ 400 مرحلة دون تلميح',
    'Finish 400 stages without hints',
  ),

  // ═════════════════ الإتقان — التحدّيات اللغوية (7) ═════════════════
  _a(
    'challenge_1',
    '🎭',
    _T.bronze,
    _S.challengesSolved,
    1,
    'أول تحدٍّ',
    'First Challenge',
    'حلّ أول تحدٍّ لغوي',
    'Solve your first language challenge',
  ),
  _a(
    'challenge_5',
    '🎪',
    _T.bronze,
    _S.challengesSolved,
    5,
    'خمسة تحدّيات',
    'Five Challenges',
    'حلّ 5 تحدّيات لغوية',
    'Solve 5 language challenges',
  ),
  _a(
    'challenge_10',
    '🎬',
    _T.silver,
    _S.challengesSolved,
    10,
    'عشرة تحدّيات',
    'Ten Challenges',
    'حلّ 10 تحدّيات لغوية',
    'Solve 10 language challenges',
  ),
  _a(
    'challenge_20',
    '🎤',
    _T.silver,
    _S.challengesSolved,
    20,
    'راوي الأمثال',
    'Teller of Proverbs',
    'حلّ 20 تحدّيا لغويا',
    'Solve 20 language challenges',
  ),
  _a(
    'challenge_35',
    '🎵',
    _T.gold,
    _S.challengesSolved,
    35,
    'شاعر',
    'Poet',
    'حلّ 35 تحدّيا لغويا',
    'Solve 35 language challenges',
  ),
  _a(
    'challenge_50',
    '🎶',
    _T.gold,
    _S.challengesSolved,
    50,
    'خمسون تحدّيا',
    'Fifty Challenges',
    'حلّ 50 تحدّيا لغويا',
    'Solve 50 language challenges',
  ),
  _a(
    'challenge_60',
    '🏛',
    _T.legend,
    _S.challengesSolved,
    60,
    'حافظ التراث',
    'Keeper of Heritage',
    'حلّ 60 تحدّيا لغويا',
    'Solve 60 language challenges',
  ),

  // ═════════════════ الإتقان — العملات المكتسبة (5) ═════════════════
  _a(
    'coins_500',
    '🎈',
    _T.bronze,
    _S.pointsEarned,
    500,
    'أول خمسمئة',
    'First Five Hundred',
    'اكسب 500 عملة',
    'Earn 500 coins',
  ),
  _a(
    'coins_2000',
    '🎊',
    _T.bronze,
    _S.pointsEarned,
    2000,
    'جيب ثقيل',
    'Heavy Pocket',
    'اكسب 2000 عملة',
    'Earn 2000 coins',
  ),
  _a(
    'coins_5000',
    '🥈',
    _T.silver,
    _S.pointsEarned,
    5000,
    'خمسة آلاف',
    'Five Thousand',
    'اكسب 5000 عملة',
    'Earn 5000 coins',
  ),
  _a(
    'coins_15000',
    '📈',
    _T.gold,
    _S.pointsEarned,
    15000,
    'ثروة تنمو',
    'Growing Fortune',
    'اكسب 15000 عملة',
    'Earn 15000 coins',
  ),
  _a(
    'coins_50000',
    '💍',
    _T.legend,
    _S.pointsEarned,
    50000,
    'كنز الحروف',
    'Treasure of Letters',
    'اكسب 50000 عملة',
    'Earn 50000 coins',
  ),

  // ═════════════════ المثابرة — السلسلة (9) ═════════════════
  _a(
    'streak_2',
    '⏰',
    _T.bronze,
    _S.bestStreak,
    2,
    'يومان متتاليان',
    'Two Days',
    'سلسلة يومين متتاليين',
    'A 2-day streak',
  ),
  _a(
    'streak_3',
    '🔥',
    _T.bronze,
    _S.bestStreak,
    3,
    'ثلاثة على التوالي',
    'Three in a Row',
    'سلسلة 3 أيام متتالية',
    'A 3-day streak',
  ),
  _a(
    'streak_5',
    '☀',
    _T.bronze,
    _S.bestStreak,
    5,
    'خمسة أيام',
    'Five Days',
    'سلسلة 5 أيام متتالية',
    'A 5-day streak',
  ),
  _a(
    'streak_7',
    '📅',
    _T.silver,
    _S.bestStreak,
    7,
    'أسبوع كامل',
    'A Full Week',
    'سلسلة 7 أيام متتالية',
    'A 7-day streak',
  ),
  _a(
    'streak_14',
    '🌙',
    _T.silver,
    _S.bestStreak,
    14,
    'أسبوعان',
    'Two Weeks',
    'سلسلة 14 يوما متتاليا',
    'A 14-day streak',
  ),
  _a(
    'streak_21',
    '⚡',
    _T.silver,
    _S.bestStreak,
    21,
    'ثلاثة أسابيع',
    'Three Weeks',
    'سلسلة 21 يوما متتاليا',
    'A 21-day streak',
  ),
  _a(
    'streak_30',
    '🌋',
    _T.gold,
    _S.bestStreak,
    30,
    'نار ما تنطفي',
    'Unstoppable Fire',
    'سلسلة 30 يوما متتاليا',
    'A 30-day streak',
  ),
  _a(
    'streak_60',
    '☄',
    _T.gold,
    _S.bestStreak,
    60,
    'شهران بلا انقطاع',
    'Two Months Unbroken',
    'سلسلة 60 يوما متتاليا',
    'A 60-day streak',
  ),
  _a(
    'streak_100',
    '🎆',
    _T.legend,
    _S.bestStreak,
    100,
    'مئة يوم أسطورية',
    'Legendary Hundred',
    'سلسلة 100 يوم متتالٍ',
    'A 100-day streak',
  ),

  // ═════════════════ المثابرة — أيام اللعب (7) ═════════════════
  //
  // المعرّفات `daily_*` باقية كما هي رغم تغيّر معناها: التقدّم المحفوظ
  // محليا وفي Google Play Games مربوط بها، وتغييرها يمسح ما فُتح فعلا.
  // الأهداف نفسها (1..100) بقيت أيضا — «مئة يوم لعب» طلب مكافئ لـ«مئة
  // تحدٍّ يومي» في الصعوبة والمدّة.
  _a(
    'daily_1',
    '📆',
    _T.bronze,
    _S.daysPlayed,
    1,
    'اليوم الأول',
    'Day One',
    'العب في يوم واحد',
    'Play on one day',
  ),
  _a(
    'daily_5',
    '🗓',
    _T.bronze,
    _S.daysPlayed,
    5,
    'خمسة أيام',
    'Five Days',
    'العب في 5 أيام مختلفة',
    'Play on 5 different days',
  ),
  _a(
    'daily_10',
    '✅',
    _T.bronze,
    _S.daysPlayed,
    10,
    'عشرة أيام',
    'Ten Days',
    'العب في 10 أيام مختلفة',
    'Play on 10 different days',
  ),
  _a(
    'daily_25',
    '⌛',
    _T.silver,
    _S.daysPlayed,
    25,
    'خمسة وعشرون يوما',
    'Twenty-Five Days',
    'العب في 25 يوما مختلفا',
    'Play on 25 different days',
  ),
  _a(
    'daily_50',
    '⏳',
    _T.silver,
    _S.daysPlayed,
    50,
    'خمسون يوما',
    'Fifty Days',
    'العب في 50 يوما مختلفا',
    'Play on 50 different days',
  ),
  _a(
    'daily_75',
    '🥉',
    _T.gold,
    _S.daysPlayed,
    75,
    'خمسة وسبعون يوما',
    'Seventy-Five Days',
    'العب في 75 يوما مختلفا',
    'Play on 75 different days',
  ),
  _a(
    'daily_100',
    '🎖',
    _T.legend,
    _S.daysPlayed,
    100,
    'ما فوّت يوم',
    'Never Missed a Day',
    'العب في 100 يوم مختلف',
    'Play on 100 different days',
  ),

  // ═════════════════ المثابرة — عجلة الحظ (5) ═════════════════
  _a(
    'wheel_1',
    '🎡',
    _T.bronze,
    _S.wheelSpins,
    1,
    'أول دورة',
    'First Spin',
    'أدر عجلة الحظ أول مرة',
    'Spin the lucky wheel once',
  ),
  _a(
    'wheel_10',
    '🎢',
    _T.bronze,
    _S.wheelSpins,
    10,
    'حظّ يدور',
    'Spinning Luck',
    'أدر عجلة الحظ 10 مرات',
    'Spin the lucky wheel 10 times',
  ),
  _a(
    'wheel_25',
    '🎠',
    _T.silver,
    _S.wheelSpins,
    25,
    'خمس وعشرون دورة',
    'Twenty-Five Spins',
    'أدر عجلة الحظ 25 مرة',
    'Spin the lucky wheel 25 times',
  ),
  _a(
    'wheel_50',
    '🎲',
    _T.silver,
    _S.wheelSpins,
    50,
    'خمسون دورة',
    'Fifty Spins',
    'أدر عجلة الحظ 50 مرة',
    'Spin the lucky wheel 50 times',
  ),
  _a(
    'wheel_100',
    '🍀',
    _T.legend,
    _S.wheelSpins,
    100,
    'ابن الحظّ',
    "Fortune's Child",
    'أدر عجلة الحظ 100 مرة',
    'Spin the lucky wheel 100 times',
  ),

  // ═════════════════ اجتماعي — معطّلة مؤقّتا (9) ═════════════════
  // راجع AchievementCategoryInfo.isEnabled: لا تظهر ولا تُفتح حتى إطلاق
  // الميزات الاجتماعية. تبقى هنا كي تعود بسطر واحد لا بإعادة كتابة.
  _a(
    'friend_1',
    '🤝',
    _T.bronze,
    _S.friendsAdded,
    1,
    'ما تلعب لحالك',
    'Not Playing Alone',
    'أضف أول صديق',
    'Add your first friend',
  ),
  _a(
    'friend_5',
    '👏',
    _T.silver,
    _S.friendsAdded,
    5,
    'خمسة أصدقاء',
    'Five Friends',
    'أضف 5 أصدقاء',
    'Add 5 friends',
  ),
  _a(
    'friend_15',
    '🙌',
    _T.gold,
    _S.friendsAdded,
    15,
    'جماعة كبيرة',
    'A Big Circle',
    'أضف 15 صديقا',
    'Add 15 friends',
  ),
  _a(
    'invite_1',
    '💌',
    _T.bronze,
    _S.friendsInvited,
    1,
    'جبت لنا واحد',
    'Brought One In',
    'انضم لاعب برمز دعوتك',
    'A player joined with your invite code',
  ),
  _a(
    'invite_5',
    '📣',
    _T.silver,
    _S.friendsInvited,
    5,
    'خمس دعوات',
    'Five Invites',
    'انضم 5 لاعبين برمز دعوتك',
    '5 players joined with your invite code',
  ),
  _a(
    'invite_25',
    '🌟',
    _T.legend,
    _S.friendsInvited,
    25,
    'شيخ الجماعة',
    'Community Leader',
    'انضم 25 لاعبا برمز دعوتك',
    '25 players joined with your invite code',
  ),
  _a(
    'share_1',
    '📤',
    _T.bronze,
    _S.resultsShared,
    1,
    'فاخر بنتيجتك',
    'Proud of Your Score',
    'شارك نتيجتك أول مرة',
    'Share your result for the first time',
  ),
  _a(
    'share_10',
    '📢',
    _T.silver,
    _S.resultsShared,
    10,
    'عشر مشاركات',
    'Ten Shares',
    'شارك نتيجتك 10 مرات',
    'Share your result 10 times',
  ),
  _a(
    'share_25',
    '🌐',
    _T.gold,
    _S.resultsShared,
    25,
    'صيتك وصل',
    'Word Gets Around',
    'شارك نتيجتك 25 مرة',
    'Share your result 25 times',
  ),
];

/// فهرس سريع بالمعرّف — يشمل المعطّلة كي تبقى قابلة للاستعلام
final achievementsById = {for (final a in achievements) a.id: a};

/// ما يراه اللاعب فعلا: الفئات المفعّلة وحدها. كل عدد يظهر في الواجهة
/// («12 من 91») يُشتقّ من هذه لا من [achievements].
final visibleAchievements = achievements
    .where((a) => a.category.isEnabled)
    .toList(growable: false);

List<Achievement> achievementsIn(AchievementCategory category) =>
    achievements.where((a) => a.category == category).toList();
