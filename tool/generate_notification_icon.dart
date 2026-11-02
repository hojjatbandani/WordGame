// أداة توليد أيقونة الإشعارات على Android (ic_stat_huruf).
//
// لماذا أيقونة منفصلة عن أيقونة التطبيق: منذ Android 5 يتجاهل النظام
// ألوان أيقونة الإشعار تماما ويستعمل قناة الشفافية وحدها كقناع، ثم
// يصبغها بلون واحد. تمرير @mipmap/ic_launcher (مربّع معتم بلا شفافية)
// يعطي بالضبط ما رآه اللاعب: مربّعا أبيض مصمتا بلا أي شكل — "إشعار بلا
// أيقونة". الحلّ الوحيد الصحيح هو رمز أحادي: أبيض صلب على شفاف.
//
// الرمز: شبكة 2×2 من مربّعات مستديرة — نفس نقشة بلاطات الحروف في هوية
// اللعبة (assets/icons/app_icon.png)، وهي تبقى مقروءة عند 24dp حيث تذوب
// أي تفصيلة أدقّ. لا شخصية ولا تدرّج: كلاهما يتحوّل إلى بقعة بيضاء
// بعد أن يطبّق النظام القناع.
//
// المقاسات مقاسات dp قياسية لأيقونة الإشعار (24dp) لكل كثافة.
//
// التشغيل:  dart run tool/generate_notification_icon.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// اسم المورد كما يُشار إليه من Dart وAndroidManifest
const _name = 'ic_stat_huruf';

/// 24dp لكل كثافة
const _densities = {
  'mdpi': 24,
  'hdpi': 36,
  'xhdpi': 48,
  'xxhdpi': 72,
  'xxxhdpi': 96,
};

/// هامش حول الرمز نسبة إلى الضلع — إرشادات Material تترك ~1dp من 24
const _padding = 0.06;

/// الفراغ بين بلاطات الشبكة نسبة إلى الضلع
const _gap = 0.075;

/// نصف قطر استدارة زوايا البلاطة نسبة إلى ضلع البلاطة
const _cornerRatio = 0.28;

void main() {
  // يُبنى بدقّة عالية ثم يُصغَّر: الرسم المباشر بـ24 بكسل يعطي زوايا
  // مسنّنة تظهر واضحة بعد صبغ النظام
  final master = _composeMark(512);

  for (final entry in _densities.entries) {
    final dir = Directory('android/app/src/main/res/drawable-${entry.key}');
    dir.createSync(recursive: true);
    final resized = img.copyResize(
      master,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.cubic,
    );
    final path = '${dir.path}/$_name.png';
    File(path).writeAsBytesSync(img.encodePng(resized));
    stdout.writeln('  $path (${entry.value}px)');
  }

  stdout.writeln('تمّ: ${_densities.length} أيقونة إشعار');
}

/// شبكة 2×2 من مربّعات مستديرة بيضاء على لوحة شفافة
img.Image _composeMark(int size) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  final pad = size * _padding;
  final gap = size * _gap;
  final tile = (size - pad * 2 - gap) / 2;
  final corner = tile * _cornerRatio;

  for (var row = 0; row < 2; row++) {
    for (var col = 0; col < 2; col++) {
      _roundedSquare(
        canvas,
        left: pad + col * (tile + gap),
        top: pad + row * (tile + gap),
        side: tile,
        corner: corner,
      );
    }
  }
  return canvas;
}

/// مربّع أبيض مستدير الزوايا بحافة ناعمة، يُرسم بمسافة موقّعة إلى شكل
/// المستطيل المستدير (أدقّ من رسم أربع دوائر وأربعة مستطيلات)
void _roundedSquare(
  img.Image dst, {
  required double left,
  required double top,
  required double side,
  required double corner,
}) {
  final cx = left + side / 2;
  final cy = top + side / 2;
  final half = side / 2 - corner;

  for (var y = top.floor() - 1; y <= (top + side).ceil() + 1; y++) {
    if (y < 0 || y >= dst.height) continue;
    for (var x = left.floor() - 1; x <= (left + side).ceil() + 1; x++) {
      if (x < 0 || x >= dst.width) continue;
      final dx = math.max((x + 0.5 - cx).abs() - half, 0.0);
      final dy = math.max((y + 0.5 - cy).abs() - half, 0.0);
      final distance = math.sqrt(dx * dx + dy * dy) - corner;
      final a = _edgeAlpha(-distance);
      if (a <= 0) continue;
      final p = dst.getPixel(x, y);
      final outA = a + (p.a / 255) * (1 - a);
      dst.setPixelRgba(x, y, 255, 255, 255, (outA * 255).round());
    }
  }
}

/// تدرّج خطّي بعرض بكسل واحد حول الحافة (0 خارجها، 1 داخلها)
double _edgeAlpha(double distanceInside) {
  if (distanceInside <= -0.5) return 0;
  if (distanceInside >= 0.5) return 1;
  return distanceInside + 0.5;
}
