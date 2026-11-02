// إعداد goldie لمتجر Google Play — نسختان: إنجليزية وعربية.
//
// ملاحظة مهمة عن اللقطات الخام:
// المرحلة `capture` في goldie تشغّل التطبيق على محاكي أندرويد، ولا يوجد
// على هذا الجهاز أي emulator ولا system-image ولا AVD (تحقّقنا: مجلد
// system-images غير موجود و avdmanager يعطي قائمة فارغة). لذلك تُولَّد
// اللقطات الخام بخط golden في Flutter عبر:
//
//   flutter test test/generate_screenshots.dart --update-goldens \
//     --plain-name "pixel-10-pro"
//
// وهو يرسم الشاشات الحقيقية بمقاس 1280×2856 — أي مقاس شاشة هيكل
// Pixel 10 Pro بالضبط — ويكتبها مباشرة في goldie/out/raw/pixel-10-pro/.
// بعدها تعمل بقية مراحل goldie (frame / manifest / studio) كالمعتاد.
//
// الحقائق في النصوص التسويقية مأخوذة من بيانات اللعبة نفسها:
// 500 مرحلة في assets/data/levels.json، 8 عوالم في lib/data/world_models.dart،
// 62 تحديا لغويا في assets/data/challenges.json.

const APP_ROOT = "D:/Personal Projects/Words Game";

const config = {
  appRoot: APP_ROOT,

  // متجر Play فقط: هذا الجهاز ويندوز، ومحاكي iOS يحتاج macOS.
  devices: ["pixel-10-pro"],
  locales: ["en-US", "ar"],
  appearance: "dark",

  android: {
    appPath: `${APP_ROOT}/build/app/outputs/flutter-apk/app-release.apk`,
    applicationId: "com.huruf.huruf",
  },

  // هيكل أندرويد يُستعمل تلقائيا لجهاز Play، لكن goldie يقرأ هذا الحقل
  // قبل أن يعرف المنصّة، فتركه فارغا يوقف الأمر
  frame: { variant: "17-pro-silver" },

  theme: {
    // خلفية داكنة مشتقّة من ألوان التطبيق نفسها (HurufTheme):
    // bgTop ‎#0A0E27 وbgBottom ‎#1A1F3A، فتبدو البطاقات امتدادا للّعبة.
    background:
      "linear-gradient(165deg, #0A0E27 0%, #141A38 55%, #1A1F3A 100%)",
    headlineColor: "#F4C430", // ذهبي التطبيق
    subheadColor: "#9AA0BE", // textSecondary
    // خط يحوي حروفا عربية: خطوط goldie المضمّنة لاتينية فقط، ولو تُركت
    // لظهر العنوان العربي مربّعات فارغة.
    fontFamily: '"Segoe UI", Tahoma, Arial, sans-serif',
    copyHeightRatio: 0.26,
    deviceWidthRatio: 0.82,
    // لا panorama: قالب editorial يبدأ ببطاقة عرضية تُقسم مشهد الرئيسية
    // على بطاقتين، فتخرج البطاقة الأولى شبه فارغة — وهي أهم بطاقة في
    // صفحة المتجر. هذا التسلسل يجعل كل بطاقة قائمة بذاتها مع تنويع الشكل.
    template: ["hero", "classic", "offset", "classic", "tilt"],
    layout: "classic",
  },

  store: {
    name: "حروف",
    subtitle: {
      "en-US": "Arabic word puzzle",
      ar: "‏لعبة كلمات عربية",
    },
    developer: "Huruf",
    category: "Word",
    rating: 0,
    ratingCount: "New",
    ageRating: "3+",
    price: "Free",
    description: {
      "en-US":
        "Huruf is an Arabic word puzzle that sharpens your mind. Swipe across the letter wheel to uncover every hidden word across 500 hand-tuned levels set in 8 illustrated worlds.\n\nBeyond the campaign, 62 curated challenges are built from real Arabic proverbs, Gulf sayings and classical poetry — you solve them, you do not just read them.\n\nFree to play, works offline, and needs no account.",
      ar: "‏حروف لعبة كلمات عربية تشحذ ذهنك. اسحب على عجلة الحروف وطلّع كل الكلمات المخبّأة عبر 500 مرحلة مضبوطة في 8 عوالم مرسومة.\n\nوإلى جانب الرحلة، 62 تحديا منتقى من أمثال عربية وخليجية وأبيات من الشعر الكلاسيكي — تحلّها بنفسك لا تقرأها فقط.\n\nمجانية، وتشتغل بدون إنترنت، وبلا تسجيل حساب",
    },
  },

  scenes: [
    {
      kind: "screenshot",
      id: "home",
      // أسماء التدفّقات محفوظة للمستقبل: حين يتوفّر محاكي أندرويد يمكن
      // تشغيل `capture` بدل مولّد الـ golden دون تغيير هذا الملف.
      flow: "store-01-home",
      headline: {
        "en-US": "Arabic words, one swipe away",
        ar: "‏كلمات عربية بلمسة واحدة",
      },
      subhead: {
        "en-US": "500 hand-tuned levels across 8 illustrated worlds.",
        ar: "‏500 مرحلة مضبوطة في 8 عوالم مرسومة",
      },
    },
    {
      kind: "screenshot",
      id: "gameplay",
      flow: "store-02-gameplay",
      headline: {
        "en-US": "Swipe. Build. Discover.",
        ar: "‏اسحب. كوّن. اكتشف",
      },
      subhead: {
        "en-US": "Drag across the wheel to uncover every hidden word.",
        ar: "‏اسحب على العجلة وطلّع كل الكلمات المخبّأة",
      },
    },
    {
      kind: "screenshot",
      id: "level_map",
      flow: "store-03-level-map",
      headline: {
        "en-US": "A journey, not a level list",
        ar: "‏رحلة، لا قائمة مراحل",
      },
      subhead: {
        "en-US": "Eight worlds, each with its own map and animated guide.",
        ar: "‏ثمانية عوالم، لكل واحد خريطته ومرشده المتحرّك",
      },
    },
    {
      kind: "screenshot",
      id: "challenge",
      flow: "store-04-challenge",
      headline: {
        "en-US": "Proverbs and poetry, as a game",
        ar: "‏أمثال وأشعار، كلعبة",
      },
      subhead: {
        "en-US": "62 challenges you solve — real sayings, not filler.",
        ar: "‏62 تحديا تحلّها بنفسك — أمثال أصيلة لا حشو",
      },
    },
    {
      kind: "screenshot",
      id: "achievements",
      flow: "store-05-achievements",
      headline: {
        "en-US": "Every step counts",
        ar: "‏كل خطوة تُحتسب",
      },
      subhead: {
        "en-US": "Badges that track how far your Arabic has come.",
        ar: "‏شارات تتابع تقدّمك في العربية",
      },
    },
  ],
};

export default config;
