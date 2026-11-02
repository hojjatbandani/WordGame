// مفاتيح الإيقاف عن بعد. Dart صرف.
//
// كل ميزة تعتمد على خادم لها مفتاح. القيمة الافتراضية **مُشغَّل** دوما:
// لاعب بلا اتصال، أو خادم إعداد لا يستجيب، يجب أن يرى اللعبة كاملة لا
// ناقصة. المفتاح أداة إطفاء عند عطل، لا شرط تشغيل.
//
// وعقد الإطفاء صارم: المفتاح المطفأ **يُخفي مدخل الميزة** — لا يعطّله
// ولا يتركه يفتح شاشة فارغة. زر يفتح شيئا معطلا أسوأ من غياب الزر:
// اللاعب يظنّ اللعبة معطوبة، والدعم يستقبل بلاغات عن عطل مقصود.

class FeatureFlags {
  static const kInterstitialAds = 'ads_interstitial_enabled';
  static const kRewardedAds = 'ads_rewarded_enabled';
  static const kRewardTrack = 'reward_track_enabled';
  static const kStore = 'store_enabled';
  static const kReferral = 'referral_enabled';

  static const all = <String>[
    kInterstitialAds,
    kRewardedAds,
    kRewardTrack,
    kStore,
    kReferral,
  ];

  final Map<String, bool> _values;

  const FeatureFlags(this._values);

  /// كل شيء مُشغَّل — الحالة قبل وصول أي إعداد، وحالة انعدام الاتصال
  const FeatureFlags.allOn() : _values = const {};

  /// استثناءات القاعدة أدناه: ميزات مطفأة *محليا* حتى يجهز ما تحتاجه.
  /// فارغة الآن — مسار الجوائز يعمل محليا بالكامل بلا خادم، ومفتاحه
  /// (`reward_track_enabled: false`) أداة إطفاء للاقتصاد وحدها: مسار
  /// يمنح 2000 ألماسة على ستة أشهر يجب أن يكون له زرّ إيقاف عن بعد إن
  /// انحرف التوازن، لا أن ينتظر إصدارا جديدا في المتجر.
  static const _localDefaults = <String, bool>{};

  /// مطفأ إن قال الخادم صراحة false، أو إن كان من الاستثناءات المحلية
  /// أعلاه ولم يقل الخادم شيئا. غياب المفتاح لغير الاستثناءات = مُشغَّل.
  bool isOn(String key) => _values[key] ?? _localDefaults[key] ?? true;

  bool get interstitialAds => isOn(kInterstitialAds);
  bool get rewardedAds => isOn(kRewardedAds);
  bool get rewardTrack => isOn(kRewardTrack);
  bool get store => isOn(kStore);
  bool get referral => isOn(kReferral);

  Map<String, bool> get values => Map.unmodifiable(_values);

  /// يبني من قيم إعداد خام. غير البولياني يُتجاهل — «"true"» نصّا
  /// تُقبل أيضا لأن لوحات التحكّم ترسلها كذلك أحيانا.
  factory FeatureFlags.fromConfig(Map<String, Object?> config) {
    final out = <String, bool>{};
    for (final key in all) {
      final raw = config[key];
      final value = switch (raw) {
        bool() => raw,
        String() => raw.toLowerCase() == 'true'
            ? true
            : raw.toLowerCase() == 'false'
                ? false
                : null,
        num() => raw != 0,
        _ => null,
      };
      if (value != null) out[key] = value;
    }
    return FeatureFlags(out);
  }

  FeatureFlags copyWith(Map<String, bool> overrides) =>
      FeatureFlags({..._values, ...overrides});
}
