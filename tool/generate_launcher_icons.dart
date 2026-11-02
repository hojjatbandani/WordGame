// أداة توليد أيقونة التطبيق المثبّتة (Android + iOS) من شعار اللعبة.
//
// الهوية هنا هي نفسها هوية الشعار داخل التطبيق (راجع _LogoRow في
// home_screen.dart وشاشة البدء): قرص أبيض بحلقة ذهبية وداخله الشخصية.
// الخلفية بيضاء لا داكنة: الأيقونة الداكنة كانت تطبع مربّعا أسود حول
// الأيقونة على معظم مشغّلات Android.
//
// تُولَّد ثلاث عائلات معا:
//   - ic_launcher.png التقليدية (Android قديم + iOS)، مسطّحة على أبيض.
//   - ic_launcher_foreground.png للأيقونة التكيّفية (Android 8+): نفس
//     القرص بخلفية *شفافة* داخل منطقة الأمان (66% من الضلع)، وطبقة
//     الخلفية لون أبيض صلب في mipmap-anydpi-v26/ic_launcher.xml.
//   - أيقونة الإشعارات أحادية اللون تُولَّد في أداة منفصلة
//     (tool/generate_notification_icon.dart).
//
// لماذا لا حلقة تلامس الحافة: iOS يقصّ الأيقونة بمربّع مستدير الزوايا،
// وAndroid يقصّ الأيقونات التكيّفية بدائرة. قرص بقطر 88% من الضلع ينجو
// من القصّين معا، فالحلقة لا تُقطع على أي جهاز.
//
// iOS لا يقبل قناة شفافية في أيقونة التطبيق إطلاقا (يُرفض الرفع)، لذا
// تُسطَّح كل الأيقونات على خلفية صلبة.
//
// التشغيل:  dart run tool/generate_launcher_icons.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _source = 'assets/logo/portrait.png';

/// خلفية الأيقونة — أبيض صلب (يطابق @color/ic_launcher_background)
const _bg = (r: 0xFF, g: 0xFF, b: 0xFF);

/// HurufTheme.gold
const _gold = (r: 0xF4, g: 0xC4, b: 0x30);

/// قطر القرص الأبيض نسبة إلى ضلع الأيقونة
const _discRatio = 0.88;

/// قطر القرص داخل الأيقونة التكيّفية نسبة إلى ضلع اللوحة (108dp).
/// منطقة الأمان 72dp من 108 = 0.667؛ نبقى دونها قليلا فلا يقصّ أي
/// مشغّل حلقة الأيقونة مهما كان شكل القناع.
const _adaptiveDiscRatio = 0.63;

/// أحجام طبقة مقدّمة الأيقونة التكيّفية: 108dp لكل كثافة
const _adaptiveForeground = {
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};

/// سمك الحلقة الذهبية نسبة إلى الضلع
const _ringRatio = 0.035;

/// أحجام Android: كل كثافة وضلعها بالبكسل
const _android = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

/// أحجام iOS: اسم الملف كما هو في Contents.json وضلعه الفعلي
const _ios = {
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

void main() {
  final sourceFile = File(_source);
  if (!sourceFile.existsSync()) {
    stderr.writeln('لم يُعثر على الشعار: $_source');
    exitCode = 1;
    return;
  }
  final logo = img.decodePng(sourceFile.readAsBytesSync());
  if (logo == null) {
    stderr.writeln('تعذّر فكّ ترميز الشعار');
    exitCode = 1;
    return;
  }

  // يُبنى مرة واحدة بأعلى دقّة ثم يُصغَّر لكل مقاس: التوليد المباشر
  // بمقاسات صغيرة يعطي حوافّ مسنّنة في الحلقة والقرص
  final master = _composeIcon(logo, 1024);

  for (final entry in _android.entries) {
    final path = 'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png';
    _writeResized(master, entry.value, path);
  }

  for (final entry in _ios.entries) {
    final path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}';
    _writeResized(master, entry.value, path);
  }

  // طبقة المقدّمة التكيّفية: نفس القرص لكن بخلفية شفافة
  final foregroundMaster = _composeAdaptiveForeground(logo, 1024);
  for (final entry in _adaptiveForeground.entries) {
    final path =
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_foreground.png';
    _writeResized(foregroundMaster, entry.value, path);
  }

  stdout.writeln(
    'تمّ: ${_android.length} أيقونة Android و${_ios.length} أيقونة iOS '
    'و${_adaptiveForeground.length} طبقة مقدّمة تكيّفية',
  );
}

void _writeResized(img.Image master, int size, String path) {
  final resized = size == master.width
      ? master
      : img.copyResize(
          master,
          width: size,
          height: size,
          interpolation: img.Interpolation.cubic,
        );
  File(path).writeAsBytesSync(img.encodePng(resized));
  stdout.writeln('  $path (${size}px)');
}

/// يركّب أيقونة مربّعة واحدة بالضلع [size]
img.Image _composeIcon(img.Image logo, int size) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(_bg.r, _bg.g, _bg.b, 255));

  final center = size / 2;
  final discRadius = size * _discRatio / 2;
  final ringWidth = size * _ringRatio;

  // القرص الأبيض بحافة ناعمة يدويا: fillCircle في حزمة image تعطي
  // حافة مسنّنة
  _softDisc(canvas, center, center, discRadius, 255, 255, 255);

  // الشخصية أكبر من القرص قليلا ثم تُقصّ عليه: ملف الشعار مربّع بخلفية
  // بيضاء صلبة لا شفافة، فتركيبه كما هو يطبع مربّعا أبيض فوق القرص.
  final innerRadius = discRadius - ringWidth;
  final drawn = innerRadius * 2 * 1.04;
  final scaled = img.copyResize(
    logo,
    width: drawn.round(),
    height: drawn.round(),
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    canvas,
    scaled,
    dstX: ((size - scaled.width) / 2).round(),
    dstY: ((size - scaled.height) / 2).round(),
  );

  // القصّ: كل ما خرج عن القرص يعود لون الخلفية
  _punchOutside(canvas, center, center, innerRadius, _bg.r, _bg.g, _bg.b);

  // الحلقة أخيرا كي تعلو حافة الصورة المقصوصة بلا خيط أبيض بينهما
  _softRing(
    canvas,
    center,
    center,
    discRadius - ringWidth / 2,
    ringWidth,
    _gold.r,
    _gold.g,
    _gold.b,
  );

  // App Store يرفض أيقونة فيها قناة شفافية. مركّب الصورة قد يمرّر شفافية
  // المصدر كما هي، فتُسطَّح هنا صراحة بدل الاعتماد على أن الشعار معتم.
  for (var y = 0; y < canvas.height; y++) {
    for (var x = 0; x < canvas.width; x++) {
      final p = canvas.getPixel(x, y);
      if (p.a < 255) {
        final a = p.a / 255;
        canvas.setPixelRgba(
          x,
          y,
          (_bg.r * (1 - a) + p.r * a).round(),
          (_bg.g * (1 - a) + p.g * a).round(),
          (_bg.b * (1 - a) + p.b * a).round(),
          255,
        );
      }
    }
  }

  return canvas;
}

/// طبقة مقدّمة الأيقونة التكيّفية: خلفية شفافة تماما، وفي وسطها القرص
/// الأبيض بحلقته الذهبية والشخصية داخله. الخلفية البيضاء تأتي من طبقة
/// منفصلة (@color/ic_launcher_background) فلا تُرسم هنا.
img.Image _composeAdaptiveForeground(img.Image logo, int size) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  // شفاف بالكامل: img.Image الجديدة تبدأ بأصفار، لكن نصرّح بها كي لا
  // يعتمد الناتج على تفصيل داخلي في الحزمة
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

  final center = size / 2;
  final discRadius = size * _adaptiveDiscRatio / 2;
  final ringWidth = size * _ringRatio * (_adaptiveDiscRatio / _discRatio);

  _softDiscAlpha(canvas, center, center, discRadius, 255, 255, 255);

  final innerRadius = discRadius - ringWidth;
  final drawn = innerRadius * 2 * 1.04;
  final scaled = img.copyResize(
    logo,
    width: drawn.round(),
    height: drawn.round(),
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(
    canvas,
    scaled,
    dstX: ((size - scaled.width) / 2).round(),
    dstY: ((size - scaled.height) / 2).round(),
  );

  _clearOutside(canvas, center, center, innerRadius);
  _softRingAlpha(
    canvas,
    center,
    center,
    discRadius - ringWidth / 2,
    ringWidth,
    _gold.r,
    _gold.g,
    _gold.b,
  );
  return canvas;
}

/// يمسح (يجعل شفافا) كل ما خرج عن دائرة [radius]، بحافة ناعمة
void _clearOutside(img.Image dst, double cx, double cy, double radius) {
  for (var y = 0; y < dst.height; y++) {
    for (var x = 0; x < dst.width; x++) {
      final d = math.sqrt(
        math.pow(x + 0.5 - cx, 2) + math.pow(y + 0.5 - cy, 2),
      );
      final outside = _edgeAlpha(d - radius);
      if (outside <= 0) continue;
      final p = dst.getPixel(x, y);
      dst.setPixelRgba(
        x,
        y,
        p.r.toInt(),
        p.g.toInt(),
        p.b.toInt(),
        (p.a * (1 - outside)).round(),
      );
    }
  }
}

/// قرص ممتلئ على لوحة شفافة: يكتب اللون وقناة الشفافية معا
void _softDiscAlpha(
  img.Image dst,
  double cx,
  double cy,
  double radius,
  int r,
  int g,
  int b,
) {
  for (var y = 0; y < dst.height; y++) {
    for (var x = 0; x < dst.width; x++) {
      final d = math.sqrt(
        math.pow(x + 0.5 - cx, 2) + math.pow(y + 0.5 - cy, 2),
      );
      final a = _edgeAlpha(radius - d);
      if (a > 0) _blendAlpha(dst, x, y, r, g, b, a);
    }
  }
}

/// حلقة على لوحة شفافة
void _softRingAlpha(
  img.Image dst,
  double cx,
  double cy,
  double radius,
  double width,
  int r,
  int g,
  int b,
) {
  final half = width / 2;
  for (var y = 0; y < dst.height; y++) {
    for (var x = 0; x < dst.width; x++) {
      final d = math.sqrt(
        math.pow(x + 0.5 - cx, 2) + math.pow(y + 0.5 - cy, 2),
      );
      final a = _edgeAlpha(half - (d - radius).abs());
      if (a > 0) _blendAlpha(dst, x, y, r, g, b, a);
    }
  }
}

/// مزج فوق لوحة قد تكون شفافة: يرفع قناة الشفافية بدل افتراض 255
void _blendAlpha(img.Image dst, int x, int y, int r, int g, int b, double a) {
  final p = dst.getPixel(x, y);
  final srcA = a;
  final dstA = p.a / 255;
  final outA = srcA + dstA * (1 - srcA);
  if (outA <= 0) {
    dst.setPixelRgba(x, y, 0, 0, 0, 0);
    return;
  }
  double ch(num d, int s) => (s * srcA + d * dstA * (1 - srcA)) / outA;
  dst.setPixelRgba(
    x,
    y,
    ch(p.r, r).round(),
    ch(p.g, g).round(),
    ch(p.b, b).round(),
    (outA * 255).round(),
  );
}

/// يعيد كل بكسل خارج دائرة [radius] إلى لون الخلفية، بحافة ناعمة
void _punchOutside(
  img.Image dst,
  double cx,
  double cy,
  double radius,
  int r,
  int g,
  int b,
) {
  for (var y = 0; y < dst.height; y++) {
    for (var x = 0; x < dst.width; x++) {
      final d = math.sqrt(
        math.pow(x + 0.5 - cx, 2) + math.pow(y + 0.5 - cy, 2),
      );
      final a = _edgeAlpha(d - radius);
      if (a > 0) _blend(dst, x, y, r, g, b, a);
    }
  }
}

/// قرص ممتلئ بحافة ناعمة بعرض بكسل واحد
void _softDisc(
  img.Image dst,
  double cx,
  double cy,
  double radius,
  int r,
  int g,
  int b,
) {
  for (var y = 0; y < dst.height; y++) {
    for (var x = 0; x < dst.width; x++) {
      final d = math.sqrt(
        math.pow(x + 0.5 - cx, 2) + math.pow(y + 0.5 - cy, 2),
      );
      final a = _edgeAlpha(radius - d);
      if (a > 0) _blend(dst, x, y, r, g, b, a);
    }
  }
}

/// حلقة مركزها [radius] وسمكها [width]، بحافّتين ناعمتين
void _softRing(
  img.Image dst,
  double cx,
  double cy,
  double radius,
  double width,
  int r,
  int g,
  int b,
) {
  final half = width / 2;
  for (var y = 0; y < dst.height; y++) {
    for (var x = 0; x < dst.width; x++) {
      final d = math.sqrt(
        math.pow(x + 0.5 - cx, 2) + math.pow(y + 0.5 - cy, 2),
      );
      final a = _edgeAlpha(half - (d - radius).abs());
      if (a > 0) _blend(dst, x, y, r, g, b, a);
    }
  }
}

/// تدرّج خطّي بعرض بكسل واحد حول الحافة (0 خارجها، 1 داخلها)
double _edgeAlpha(double distanceInside) {
  if (distanceInside <= -0.5) return 0;
  if (distanceInside >= 0.5) return 1;
  return distanceInside + 0.5;
}

void _blend(img.Image dst, int x, int y, int r, int g, int b, double a) {
  final p = dst.getPixel(x, y);
  dst.setPixelRgba(
    x,
    y,
    (p.r * (1 - a) + r * a).round(),
    (p.g * (1 - a) + g * a).round(),
    (p.b * (1 - a) + b * a).round(),
    255,
  );
}
