// كتالوج المشتريات. Dart صرف — بلا Flutter — كي يُختبر ترتيب القيمة
// وحساب «أصغر حزمة كافية» بلا شجرة ودجات.
//
// المبدأ الحاكم لكل ما في هذا الملف: **يُدفَع للتسريع أو للتجميل، لا
// للاستمرار.** لا مرحلة ولا عالم ولا نمط لعب خلف أي منتج هنا، ولا يوجد
// أصلا نوع منتج في هذا الملف يمكنه أن يفتح محتوى — القيد بنيوي لا اتفاق
// شفهي.

library;

/// معرّفات المنتجات كما ستُسجَّل في المتجرين. ثابتة إلى الأبد بعد أول
/// إصدار: تغييرها يكسر إيصالات المشترين السابقين.
class SkuIds {
  const SkuIds._();

  static const coins500 = 'coins_500';
  static const coins1650 = 'coins_1650';
  // هذان سُجّلا في Play Console بهذه الصيغة، ومعرّف المنتج هناك لا يُعدَّل
  // ولا يُعاد استعماله بعد الحذف — فالشيفرة تتبع المتجر لا العكس
  static const coins4800 = '4800coins';
  static const coins16000 = '16000coins';
  static const removeAds = 'remove_ads';
  static const starterPack = 'starter_pack';
  static const subscription = 'huruf_plus_monthly';

  /// تُستهلك بعد التسليم فتُشترى مرارا (Play Console: Consumable)
  static const consumables = {coins500, coins1650, coins4800, coins16000};

  /// تُشترى مرة واحدة لكل حساب Google وتُستعاد عند إعادة التثبيت
  static const nonConsumables = {removeAds, starterPack};

  /// كل ما يُباع اليوم — الاشتراك مطفأ ([StoreCatalog.subscriptionEnabled])
  static const forSale = {...consumables, ...nonConsumables};
}

class CoinPack {
  final String id;
  final int coins;

  /// السعر المرجعي بالدولار. السعر المعروض فعلا يأتي من المتجر بعملة
  /// السوق — هذا للترتيب والحساب الداخلي فقط.
  final double referenceUsd;

  /// نسبة القيمة المعلنة على الشارة، كما حدّدها تصميم الاقتصاد.
  ///
  /// ملاحظة مقصودة: هذه النسبة *أقل* من القيمة المحسوبة فعليا
  /// ([valueVsBaselinePercent]) في كل الحزم. أُبقيت كما وردت في تصميم
  /// الاقتصاد لأنها نصّ تسويقي مقصود، والوعد الأقل من الحقيقة أسلم من
  /// العكس. من يريد إظهار القيمة الحقيقية يبدّل السطر في الواجهة لا
  /// الأرقام هنا.
  final int advertisedBonusPercent;

  final String nameAr;
  final String nameEn;
  final String? badgeAr;
  final String? badgeEn;

  const CoinPack({
    required this.id,
    required this.coins,
    required this.referenceUsd,
    required this.advertisedBonusPercent,
    required this.nameAr,
    required this.nameEn,
    this.badgeAr,
    this.badgeEn,
  });

  double get coinsPerUsd => coins / referenceUsd;

  String get referencePriceLabel => '\$${referenceUsd.toStringAsFixed(2)}';

  /// القيمة الحقيقية مقارنة بالحزمة الأساس (الأولى)
  int valueVsBaselinePercent(CoinPack baseline) =>
      ((coinsPerUsd / baseline.coinsPerUsd - 1) * 100).round();
}

class StoreCatalog {
  const StoreCatalog._();

  /// الحزمة الأساس التي تُقاس عليها القيمة — الأصغر دوما
  static CoinPack get baseline => coinPacks.first;

  static CoinPack? packById(String id) {
    for (final pack in coinPacks) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  /// مرتّبة تصاعديا بالسعر. الترتيب جزء من العقد: «أصغر حزمة كافية»
  /// تعتمد عليه، وكذلك ترتيب العرض في المتجر.
  static const coinPacks = <CoinPack>[
    CoinPack(
      id: SkuIds.coins500,
      coins: 500,
      referenceUsd: 0.99,
      advertisedBonusPercent: 0,
      nameAr: 'كيس عملات',
      nameEn: 'Coin Pouch',
    ),
    CoinPack(
      id: SkuIds.coins1650,
      coins: 1650,
      referenceUsd: 2.49,
      advertisedBonusPercent: 24,
      nameAr: 'حقيبة عملات',
      nameEn: 'Coin Bag',
    ),
    CoinPack(
      id: SkuIds.coins4800,
      coins: 4800,
      referenceUsd: 5.99,
      advertisedBonusPercent: 46,
      nameAr: 'صندوق عملات',
      nameEn: 'Coin Chest',
      badgeAr: 'الأكثر مبيعا',
      badgeEn: 'Best Seller',
    ),
    CoinPack(
      id: SkuIds.coins16000,
      coins: 16000,
      referenceUsd: 14.99,
      advertisedBonusPercent: 93,
      nameAr: 'كنز العملات',
      nameEn: 'Coin Treasure',
      badgeAr: 'الأفضل قيمة',
      badgeEn: 'Best Value',
    ),
  ];

  /// أصغر حزمة تكفي لبلوغ [target] بالنظر إلى [balance]. تُستخدم في ورقة
  /// «ينقصك القليل»: عرض الكتالوج كاملا هناك يحوّل لحظة قرار واضحة إلى
  /// اختيار من أربعة، وأصغر حزمة كافية هي الاقتراح الوحيد الصادق.
  static CoinPack? smallestSufficient({
    required int balance,
    required int target,
  }) {
    final missing = target - balance;
    if (missing <= 0) return null;
    for (final pack in coinPacks) {
      if (pack.coins >= missing) return pack;
    }
    return coinPacks.last; // لا حزمة تكفي — الأكبر أقرب ما نملك
  }

  // ─────────────────────── منتجات غير استهلاكية ───────────────────────

  static const removeAdsReferenceUsd = 4.99;

  /// هدية ترافق إزالة الإعلانات — «أخذت أكثر من المعروض» من أول شراء
  static const removeAdsGiftCoins = 300;

  /// أدنى شريحة سعر حقيقية في المتجرين. لا يوجد ما دونها: كل خصم
  /// يهبط تحتها يعرض على اللاعب رقما لن يراه في ورقة الدفع.
  static const minimumStorePriceUsd = 0.99;

  // ─────────────────────── حزمة البداية ───────────────────────
  //
  // أرخص شريحة في المتجر (0.99$)، وقيمتها أعلى من كيس العملات بنفس
  // السعر — وهذا مقصود لا سهو: حزمة البداية تُشترى **مرة واحدة لكل
  // حساب**، ووظيفتها كسر حاجز أول دفعة لا الربح منها. لهذا يجب أن تحمل
  // البطاقة «مرة واحدة» صراحة، وإلا قرأ اللاعب كيس العملات غشّا.
  //
  // وتُسلَّم على ثلاثة أيام لا دفعة واحدة: الدفعة الواحدة تُنفق في جلسة
  // ثم يعود اللاعب إلى حائطه نفسه، والتقسيط يعطيه سببا للعودة يومين
  // إضافيين — وهو ما تشتريه اللعبة فعلا من هذا المنتج.
  //
  // القسط لا يسقط بفوات يومه أبدا (راجع starter_pack.dart): دفع اللاعب
  // مالا حقيقيا، وإسقاط ما دفع ثمنه لأنه لم يفتح التطبيق طلبُ استرداد
  // وتقييمُ نجمة واحدة.

  static const starterPackReferenceUsd = minimumStorePriceUsd;

  /// جدول التسليم: قسط لكل يوم. الأول يُمنح لحظة الشراء.
  ///
  /// تنازلي عمدا: أكبر قسط في اللحظة التي دفع فيها اللاعب، فالشعور
  /// بأن الدفع أُجيب فورا هو ما يصنع الشراء الثاني.
  ///
  /// رُفع المجموع من 600 إلى 800 (400/250/150): بهذا السعر يجب أن تكون
  /// الحزمة أوضح صفقة في المتجر بفارق لا يُناقَش — راجع اختبار
  /// «حزمة البداية أوفر من كيس العملات بنفس السعر» في store_offers_test.
  static const starterPackDailyCoins = <int>[400, 250, 150];

  /// مجموع ما تعطيه الحزمة من عملات — مشتقّ من الجدول لا رقم ثان
  /// يُنسى تحديثه
  static int get starterPackCoins =>
      starterPackDailyCoins.fold(0, (sum, c) => sum + c);

  static int get starterPackDays => starterPackDailyCoins.length;

  /// التلميحات كلها مع القسط الأول: من اشترى حزمة بداية اشتراها وهو
  /// عالق الآن، لا بعد يومين
  static const starterPackHintCharges = 5;

  static const starterPackAvatarId = 'avatar_starter_rare';
  static const starterPackFrameId = 'frame_starter_exclusive';

  // ─────────────────────── الاشتراك (المرحلة الثالثة) ───────────────────────
  //
  // معرَّف هنا كي لا يُعاد تصميمه لاحقا، ومطفأ عمدا: الاشتراك يحتاج
  // تدفّق محتوى شهريا (زينة حصرية كل شهر) لا يوجد قبل استقرار اللعبة،
  // واشتراك يتوقّف محتواه بعد شهرين أسوأ من عدم إطلاقه.
  //
  // وكذلك تذكرة القتال (Battle Pass): لا تُبنى قبل تجاوز ~5000 مستخدم
  // يومي — تكلفة إنتاج محتواها الموسمي تفوق عائدها تحت ذلك الحد.
  static const subscriptionEnabled = false;
  static const subscriptionReferenceUsd = 3.99;
  static const subscriptionDailyCoins = 100;
  static const subscriptionWeeklyStreakFreezes = 1;
}
