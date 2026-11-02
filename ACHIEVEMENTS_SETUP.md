# ربط الإنجازات بـ Google Play Games

الإنجازات تعمل **محليا بالكامل الآن** — تُفتح، وتُمنح مكافآتها، وتُحفظ على
الجهاز، بلا إنترنت وبلا تسجيل دخول. الخطوات أدناه تضيف طبقة واحدة فوق ذلك:
حفظ الإنجاز في حساب Google الخاص باللاعب كي لا يضيع عند تغيير الجهاز.

> هذه الخطوات لا يمكن إنجازها من الكود — لازم تُنشأ الإنجازات يدويا في
> Play Console لأن جوجل هي من تولّد معرّفاتها.

## 1. تفعيل Play Games Services

1. [Google Play Console](https://play.google.com/console) → اختر تطبيق حروف
2. **Grow → Play Games Services → Setup and management → Configuration**
3. اضغط *Create new Play Games Services project* واربطه بالتطبيق
4. من **Credentials** أضف بيانات اعتماد Android:
   - اسم الحزمة: `com.huruf.huruf`
   - بصمة SHA-1 لمفتاح التوقيع (من Play Console → Setup → App signing)

## 2. إضافة رقم المشروع إلى التطبيق

بعد إنشاء المشروع تحصل على **App ID** (رقم طويل مثل `123456789012`).

في `android/app/src/main/res/values/strings.xml` (أنشئه إن لم يوجد):

```xml
<resources>
    <string name="game_services_app_id">123456789012</string>
</resources>
```

وفي `android/app/src/main/AndroidManifest.xml` داخل وسم `<application>`:

```xml
<meta-data
    android:name="com.google.android.gms.games.APP_ID"
    android:value="@string/game_services_app_id" />
```

## 3. إنشاء الإنجازات في Play Console

**Play Games Services → Achievements → Create achievement**

أنشئ 40 إنجازا بنفس العناوين والأوصاف العربية الموجودة في
`lib/data/achievement_models.dart`. لكل واحد:

- **Name** = `titleAr`
- **Description** = `descriptionAr`
- **Icon** = أيقونة 512×512 (يمكن استخدام الإيموجي المقابل كتصميم مبدئي)
- **Initial state** = Revealed (كي يرى اللاعب ما ينتظره)

بعد الحفظ ينسخ لك جوجل معرّفا لكل إنجاز يشبه `CgkI8О_bxxxxEAIQAQ`.

## 4. لصق المعرّفات في الكود

في `lib/data/games_services_sync.dart` املأ الخريطة:

```dart
static const Map<String, String> _playGamesIds = {
  'first_step': 'CgkI...EAIQAQ',
  'levels_10' : 'CgkI...EAIQAg',
  // ... بقية الإنجازات
};
```

المفتاح الأيسر هو `id` من `achievement_models.dart` — **لا تغيّره أبدا بعد
النشر**، لأن تقدّم اللاعبين محفوظ عليه.

قائمة المعرّفات الداخلية الأربعين:

```
first_step, levels_10, levels_50, levels_100, levels_250, levels_500,
world_1, world_4, world_8,
words_50, words_250, words_1000, words_2500,
bonus_10, bonus_100, bonus_500,
long_word_6, long_word_8, long_word_10,
perfect_1, perfect_25, perfect_100,
challenge_1, challenge_20, challenge_62,
points_1000, points_10000,
daily_1, daily_30, daily_100,
streak_3, streak_7, streak_30,
wheel_10, wheel_100,
friend_1, friend_10,
duel_1, duel_win_1, duel_win_25
```

## 5. الاختبار قبل النشر

Play Games Services تعمل فقط لحسابات مضافة كمختبِرين قبل النشر:

**Play Games Services → Testers** → أضف بريدك.

ثم ثبّت نسخة موقّعة (لا debug) وسجّل الدخول بذلك الحساب.

---

## ماذا يحدث قبل إكمال هذه الخطوات؟

لا شيء يتعطّل. `GamesServicesSync` مصمّم ليفشل بصمت:

| الحالة | السلوك |
|---|---|
| الخريطة فارغة | الإنجازات محلية فقط، بلا أي خطأ |
| اللاعب غير مسجّل | الإنجازات محلية فقط |
| لا إنترنت | الإنجازات محلية فقط |
| الويب/سطح المكتب | تُتخطّى الخدمة تماما |

وشاشة الإنجازات تعرض تنبيها لطيفا («سجّل دخولك في Google Play كي تبقى
إنجازاتك محفوظة») فقط حين لا يكون اللاعب مسجّلا.

## iOS (اختياري)

نفس الشيء عبر Game Center في App Store Connect، وتُلصق المعرّفات في
`_gameCenterIds` بنفس الملف.
