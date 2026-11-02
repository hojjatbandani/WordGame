# حروف — Landing Page

صفحة هبوط ثابتة (HTML/CSS/JS خالص، بلا أي إطار عمل أو اعتماد خارجي)
بنسختين: الإنجليزية والعربية، مع تحسين كامل لمحركات البحث ولمساعدات
الذكاء الاصطناعي.

A static landing page — plain HTML/CSS/JS, zero frameworks, zero external
requests — in English and Arabic, fully optimised for search engines and AI
assistants.

## الملفات / Files

```
landing/
├── index.html          الإنجليزية (LTR)
├── ar.html             العربية (RTL)
├── robots.txt          يسمح صراحة لزواحف الذكاء الاصطناعي
├── sitemap.xml         خريطة الموقع مع hreflang للنسختين
├── llms.txt            ملخّص منظّم للعبة تقرأه مساعدات الذكاء الاصطناعي
├── assets/
│   ├── css/styles.css  ورقة أنماط واحدة تخدم النسختين
│   ├── js/main.js      ظهور تدريجي + عدّادات + توزيع عجلة الحروف
│   ├── fonts/          IRANSans (نفس خط التطبيق)
│   └── img/            صور مُحسّنة للويب من أصول التطبيق
└── README.md
```

## التشغيل / Running

الصفحة ثابتة تماما — افتح `index.html` مباشرة، أو ارفع مجلد `landing/` كما
هو على أي استضافة ثابتة (Netlify, Vercel, GitHub Pages, Cloudflare Pages).

## ما تم في السيو / SEO implemented

**تقني / Technical**

- `<title>` و`meta description` مكتوبة حول كلمات بحث حقيقية لكل لغة
- `canonical` لكل صفحة
- `hreflang` كامل (`en` / `ar` / `x-default`) في الصفحتين وفي `sitemap.xml`
- `robots` بـ `max-image-preview:large` و`max-snippet:-1`
- Open Graph كامل + Twitter Card (بمقاسات الصورة ونصّها البديل)
- `width`/`height` على كل صورة و`loading="lazy"` لما تحت الطية — يمنع قفز
  التخطيط (CLS) ويسرّع أول رسم
- `alt` وصفي يحتوي كلمات مفتاحية على كل صورة
- عناوين هرمية سليمة (h1 واحد لكل صفحة، ثم h2/h3) و`aria-labelledby` لكل قسم

**بيانات منظمة / Structured data (JSON-LD)**

- `MobileApplication` — التصنيف، المنصّات، اللغة، قائمة المزايا، والأسعار
  الأربعة الحقيقية + المجاني
- `WebSite`
- `FAQPage` — 8 أسئلة في كل لغة

> تحقّق مطبَّق: نصّ كل إجابة في `FAQPage` **مطابق حرفيا** للنصّ الظاهر في
> الصفحة. جوجل يشترط ذلك، ويعاقب على البيانات المنظمة غير المرئية.

> لم نضف `aggregateRating` عمدا: لا توجد تقييمات حقيقية بعد، واختلاقها
> مخالف لإرشادات جوجل للبيانات المنظمة ومضلل للمستخدم. أضِفه بعد أن تصير
> عندك تقييمات فعلية على المتاجر.

**البحث في الذكاء الاصطناعي / AI search**

- `llms.txt` — ملخّص منظّم بالحقائق (المنصّات، الأسعار، المزايا، الأسئلة
  الشائعة) تقرأه مساعدات مثل ChatGPT وPerplexity وClaude بدل تخمين المحتوى
- `robots.txt` يسمح صراحة لـ `GPTBot`, `OAI-SearchBot`, `PerplexityBot`,
  `ClaudeBot`, `Google-Extended`, `Applebot-Extended`
- الأسئلة والأجوبة مكتوبة كجُمل مستقلّة كاملة المعنى، وهو ما تقتبسه هذه
  المساعدات عادة

**الكلمات المستهدَفة / Target keywords**

| العربية | English |
|---|---|
| لعبة كلمات عربية · لعبة حروف · ألغاز كلمات | Arabic word game · Arabic word puzzle |
| كلمات متقاطعة عربية · وصلة كلمات · تحدي كلمات | Arabic crossword · word connect Arabic |
| ألعاب ذكاء · تنمية الذكاء · تقوية الذاكرة | brain training game · memory game |
| أمثال عربية · أمثال خليجية · شعر عربي | Arabic proverbs game · classical Arabic poetry |
| لعبة كلمات بدون نت | offline Arabic word game |
| تعلم كلمات عربية | learn Arabic vocabulary |

## قبل النشر — 3 خطوات إلزامية / Before publishing

1. **النطاق** — استبدل `https://huruf.game/` بنطاقك الحقيقي في: `index.html`
   و`ar.html` (canonical + hreflang + og:url + og:image + JSON-LD)
   و`robots.txt` و`sitemap.xml` و`llms.txt`. ابحث عن `huruf.game`.
2. **رقم App Store** — رابط جوجل بلاي جاهز وصحيح لأنه مبني على معرّف الحزمة
   `com.huruf.huruf` وسيعمل فور نشر التطبيق. أما آبل فتعطي رقما رقميا بعد
   أول رفع؛ ابحث عن `id000000000` واستبدله بالرقم الحقيقي (5 مواضع).
3. **شارات المتاجر** — الشارات الحالية مرسومة يدويا بـ SVG. قبل الإطلاق
   نزّل الشارات الرسمية من
   [Google Play Brand Guidelines](https://play.google.com/intl/en_us/badges/)
   و[Apple Marketing Guidelines](https://developer.apple.com/app-store/marketing/guidelines/)
   واستبدلها — استخدام الشارة الرسمية شرط في اتفاقية العلامة التجارية لكل
   منهما.

بعد النشر: أضف الموقع إلى
[Google Search Console](https://search.google.com/search-console) وقدّم
`sitemap.xml`، واختبر البيانات المنظمة عبر
[Rich Results Test](https://search.google.com/test/rich-results).

## الألوان / Colours

كل الألوان مأخوذة حرفيا من `lib/core/theme.dart`:

| Token | Value | Source |
|---|---|---|
| `--bg-top` | `#0A0E27` | `HurufTheme.bgTop` |
| `--bg-bottom` | `#1A1F3A` | `HurufTheme.bgBottom` |
| `--gold` | `#F4C430` | `HurufTheme.gold` |
| `--gold-dark` | `#C99A10` | `HurufTheme.goldDark` |
| `--surface` | `#171C36` | `HurufTheme.surface` |
| `--tile` | `#232A4D` | `HurufTheme.tileEmpty` |
| `--text` | `#F2F1EC` | `HurufTheme.textPrimary` |
| `--muted` | `#9AA0BE` | `HurufTheme.textSecondary` |
| `--success` | `#34E89E` | `HurufTheme.success` |

## قسم المرشدين / The guides section

القالب المرجعي فيه «آراء عملاء». تعمّدنا عدم اختراع آراء لاعبين وهمية —
نشر شهادات مفبركة خداع للمستخدم وقد يخالف سياسات المتاجر. القسم الحالي
يستخدم شخصيات اللعبة الحقيقية وعباراتها الفعلية داخل التطبيق. إذا صار
عندك آراء حقيقية، استبدل محتوى `.quote-grid` بها (وعندها يصير مناسبا
إضافة `Review`/`aggregateRating` إلى JSON-LD).

## إعادة توليد الصور / Regenerating images

```bash
dart run tool/build_landing_assets.dart
```
