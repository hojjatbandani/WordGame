# حروف — Landing page

صفحة هبوط ثابتة للعبة (HTML/CSS/JS خالص، بلا إطار عمل ولا أي سكربت تحليلات أو تتبّع)،
بنسختين: العربية `index.html` (الأساسية، RTL) والإنجليزية `en.html`. ألوانها
مأخوذة حرفيا من `lib/core/theme.dart` وصورها من أصول اللعبة نفسها.

A static landing page for Huruf — plain HTML/CSS/JS, no framework, and no analytics or
tracking scripts. Arabic (`index.html`, RTL,
primary) and English (`en.html`).

## ما فيها / What's inside

- **عرض حيّ قابل للعب** في الواجهة: عجلة حروف حقيقية (سحب أو نقر أو لوحة
  مفاتيح) على مرحلة من ثلاث كلمات (حلم، ملح، لحم)، والتباديل الثلاثة الأخرى
  (محل، لمح، حمل) كلمات إضافية كما في جرّة اللعبة.
- الأرقام كلها من بيانات اللعبة الفعلية: 500 مرحلة، 8 عوالم، 62 تحديا،
  2,887 كلمة، 9 شخصيات.
- SEO: canonical وhreflang وOpen Graph وبيانات منظّمة (MobileApplication +
  FAQPage مطابقة حرفيا للنصّ الظاهر). لا تقييمات مختلَقة.
- إمكانية الوصول: رابط تخطٍّ، تركيز مرئي، العرض الحيّ يعمل بلوحة المفاتيح،
  واحترام `prefers-reduced-motion`.

```
landing-page/
├── index.html / en.html
├── app-ads.txt          ← AdMob (pub-3678223996715179)
├── robots.txt / sitemap.xml
├── assets/              css · js · fonts · img (WebP) · svg
└── graphics/            رسومات المتجر والمشاركة (PNG) + قوالبها
```

## النشر / Deploy

المستودع: `github.com/hojjatbandani/huruf` — محتوى هذا المجلّد في جذره. النشر
عبر GitHub Pages: Settings → Pages → Deploy from a branch → `main` / `(root)`،
فتصير الصفحة على `https://hojjatbandani.github.io/huruf/`. (Pages المجانية
تشترط مستودعا عامّا.)

**مهمّ لـAdMob:** يبحث AdMob عن `app-ads.txt` في **جذر النطاق** المكتوب في
Google Play (Store settings → Website)، لا في مسار فرعي. الملف هنا يُخدَم على
`hojjatbandani.github.io/huruf/app-ads.txt` — وهذا لا يكفي وحده. الحلّ: مستودع
باسم `hojjatbandani.github.io` فيه `app-ads.txt` فقط، أو نطاق خاصّ يُربط بهذا
المستودع (ملف `CNAME`).

**الروابط المطلقة** (canonical وhreflang وog:image وsitemap) على
`https://hojjatbandani.github.io/huruf/`. عند ربط نطاق خاصّ استبدلها في
`index.html` و`en.html` و`robots.txt` و`sitemap.xml`.

## الرسومات / Graphics

| الملف | المقاس | الاستعمال |
|---|---|---|
| `graphics/feature-graphic.png` | 1024×500 | Play Console → Main store listing → **Feature graphic** |
| `graphics/og-image.png` | 1200×630 | صورة معاينة الرابط (مستعملة في الصفحتين) |
| `graphics/social-square.png` | 1080×1080 | منشورات إنستغرام وX |

لإعادة توليدها بعد تعديل `graphics/src/graphics.html` (يحتاج Node 22+ وEdge
أو Chrome):

```
node landing-page/graphics/src/render.mjs
```
