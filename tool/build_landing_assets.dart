// يجهّز صور صفحة الهبوط من أصول التطبيق: يصغّر الخلفيات والصور الشخصية
// ويحوّلها JPEG خفيفا (الأصل PNG بحجم ~2MB لكل خلفية، ثقيل جدا للويب)،
// وينسخ الأيقونات الشفافة كما هي لأنها تحتاج قناة ألفا.
//
// التشغيل:  dart run tool/build_landing_assets.dart
import 'dart:io';

import 'package:image/image.dart';

const outDir = 'landing/assets/img';

const worlds = [
  'forest',
  'valley',
  'mountains',
  'enchanted_forest',
  'oasis',
  'desert_river',
  'sunset_oasis',
  'golden_city',
];

const characters = [
  'puzzle_master',
  'wise_oldman',
  'clever_girl',
  'little_genius',
];

const icons = [
  'app_icon',
  'coin',
  'gems',
  'shop_chest',
  'dice',
  'challenge_proverb',
  'challenge_gulf',
  'challenge_verse',
  'challenge_word',
];

void main() {
  Directory(outDir).createSync(recursive: true);
  var saved = 0;

  void writeJpg(String from, String to, int width, {int quality = 78}) {
    final src = decodeImage(File(from).readAsBytesSync());
    if (src == null) {
      stderr.writeln('تعذّرت قراءة $from');
      return;
    }
    final resized = copyResize(
      src,
      width: width,
      interpolation: Interpolation.average,
    );
    final bytes = encodeJpg(resized, quality: quality);
    File('$outDir/$to').writeAsBytesSync(bytes);
    saved += File(from).lengthSync() - bytes.length;
    stdout.writeln('$to  ${(bytes.length / 1024).round()}KB');
  }

  for (final w in worlds) {
    writeJpg('assets/backgrounds/$w.png', '$w.jpg', 720);
  }
  for (final c in characters) {
    // الشخصيات تُعرض دائرية صغيرة، فـ360px تكفي بوضوح
    writeJpg('assets/characters/$c/images/portrait.png', 'char_$c.jpg', 360);
  }
  for (final i in icons) {
    // الأيقونات تبقى PNG لأن الشفافية جزء من تصميمها، لكن نصغّرها
    final src = decodeImage(File('assets/icons/$i.png').readAsBytesSync())!;
    final resized = copyResize(
      src,
      width: 160,
      interpolation: Interpolation.average,
    );
    final bytes = encodePng(resized, level: 9);
    File('$outDir/$i.png').writeAsBytesSync(bytes);
    stdout.writeln('$i.png  ${(bytes.length / 1024).round()}KB');
  }

  stdout.writeln(
    '\nوُفّر ${(saved / 1024 / 1024).toStringAsFixed(1)}MB مقارنة بالأصول الأصلية',
  );
}
