// خطّ التطبيق (IRANSans) لا يحوي محرفا تعبيريا واحدا، وFlutter لا يشحن
// خطّ إيموجي: كل رمز تعبيري يُرسَم من خطّ النظام. وخطّ النظام يُحدَّث مع
// أندرويد نفسه، فرمز صدر بعد نسخة الجهاز يظهر **مربّعا فارغا**.
//
// minSdk = 24 (أندرويد 7 / 2016). فكل رمز أحدث من Emoji 5.0 مخاطرة على
// شريحة من الأجهزة.
//
// هذا الاختبار سياج لا مكنسة: يمنع تسلّل رمز **جديد** غير مراجَع إلى
// lib/. أي رمز غير مذكور أدناه يُفشل الاختبار حتى يقرّر أحد صراحة أين
// يقع — [_safeEmoji] أم [_needsNewerAndroid].
//
// مناسبة كتابته: `'🎟$charges'` في سطر مقاسه 10 بكسل أسفل زرّي التلميح
// (راجع hint_button_label_test.dart). القاعدة العملية: الرمز التعبيري
// للاحتفال والعناوين الكبيرة، وIcons.* للأسطر الصغيرة والشارات.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _isPictographic(int rune) =>
    (rune >= 0x1F000 && rune <= 0x1FAFF) ||
    (rune >= 0x2600 && rune <= 0x27BF) ||
    (rune >= 0x2B00 && rune <= 0x2BFF);

/// Emoji 5.0 فأقدم — مدعومة على كل جهاز يشغّل التطبيق (minSdk 24)
const _safeEmoji = {
  // رموز نصّية ومحارف هندسية
  '⚙', '✅', '✓', '✕', '✏', '✨', '⬛', '⭐', '❄', '☀', '☄', '⚡', //
  '⌛', '⏳', '⏰', '⛰', '⛺', //
  // طبيعة وأماكن
  '🌊', '🌋', '🌌', '🌍', '🌐', '🌙', '🌠', '🌟', '🌳', '🌴', '🌸', '🌅', //
  '🍀', '🏔', '🏜', '🏞', '🏰', '🏛', '🏙', '🏠', '🕌', //
  // حيوانات وأشخاص
  '🐫', '🐋', '🦅', '🚶', '🏃', '👣', '👏', '🙌', '🤝', '🧑', '🧠', //
  // احتفال وجوائز
  '🎁', '🎈', '🎉', '🎊', '🎆', '🎖', '🎟', '🎠', '🎡', '🎢', '🎣', //
  '🎤', '🎨', '🎬', '🎭', '🎪', '🎯', '🎲', '🎵', '🎶', //
  '🏁', '🏅', '🏆', '🏺', '🥇', '🥈', '🥉', '👑', '💍', '💎', '💫', '💯', //
  // كتب وأدوات
  '📅', '📆', '📈', '📊', '📋', '📏', '📐', '📓', '📖', '📗', '📘', '📙', //
  '📚', '📜', '📝', '📢', '📣', '📤', '💡', '🔍', '🔎', '🔑', '🔒', //
  '🔄', '🔤', '🔥', '💌', '🔊', '🔮', '🗓', '🗝', '🗺', '🙂', '🚩', '🚫', '🛒',
};

/// رموز تحتاج خطّ نظام أحدث من minSdk — تظهر مربّعا على الأجهزة الأقدم.
/// موجودة عمدا حتى الآن، وكل واحدة قرار قائم لا سهو:
///
/// - 🫙 (Emoji 14.0 / أندرويد 13) — «الجرّة» شعار اللعبة نفسه، في 5
///   مواضع. استبدالها قرار تصميمي لا إصلاح خطأ. البديل الجاهز:
///   `AppIcons` أو أصل رسومي، فيظهر على كل جهاز ويبقى نفس الشكل.
/// - 🟨 🟩 (Emoji 12.0 / أندرويد 10) — شبكة نتيجة التحدي اليومي
///   المُشارَكة نصّا. تُقرأ في تطبيق المستقبِل لا عندنا، فالمخاطرة أقل.
/// - 🧊 🧪 🧭 (Emoji 11.0 / أندرويد 9) — شارات إنجازات وشاشات ثانوية.
const _needsNewerAndroid = {'🫙', '🟨', '🟩', '🧊', '🧪', '🧭'};

void main() {
  test('كل رمز تعبيري في lib/ مراجَع ومصنَّف حسب دعم خطّ النظام', () {
    final found = <String, Set<String>>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final file = entity.uri.pathSegments.last;
      for (final rune in entity.readAsStringSync().runes) {
        if (!_isPictographic(rune)) continue;
        found
            .putIfAbsent(String.fromCharCode(rune), () => <String>{})
            .add(file);
      }
    }

    final known = {..._safeEmoji, ..._needsNewerAndroid};
    final unreviewed = found.keys.where((e) => !known.contains(e)).toList();

    expect(
      unreviewed,
      isEmpty,
      reason:
          'رموز تعبيرية جديدة غير مراجَعة: '
          '${unreviewed.map((e) => '$e (U+${e.runes.first.toRadixString(16).toUpperCase()}) '
              'في ${found[e]!.join('، ')}').join(' | ')}\n'
          'تحقّق من نسخة Emoji التي صدر فيها الرمز: إن كانت 5.0 فأقدم '
          'أضفه إلى _safeEmoji، وإلا فإلى _needsNewerAndroid مع سبب بقائه. '
          'وإن كان في سطر صغير أو شارة، استعمل Icons.* بدلا منه.',
    );
  });

  test('لا رمز تعبيري في أسطر التلميح الصغيرة داخل شاشة اللعب', () {
    // الشاشة الوحيدة التي بها نصّ بمقاس 10 بكسل يبدّل محتواه وقت التشغيل
    final source = File(
      'lib/presentation/screens/game_screen.dart',
    ).readAsStringSync();
    for (final line in source.split('\n')) {
      if (!line.contains('label:')) continue;
      expect(
        line.runes.any(_isPictographic),
        isFalse,
        reason: 'رمز تعبيري في وسم زر: $line',
      );
    }
  });
}
