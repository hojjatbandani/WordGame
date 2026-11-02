// أداة تجهيز أيقونات الواجهة ثلاثية الأبعاد.
//
// المصادر خام: 1024×1024 بخلفية صلبة وبلا قناة شفافية (~1MB لكل ملف).
// هذه الأداة:
//   1) تزيل الخلفية بتعبئة فيضية من الحواف مع تسامح لوني
//   2) تنعّم الحافة كي لا تظهر أسنان حادة
//   3) تقصّ الصورة على حدود الشكل
//   4) تصغّرها إلى 256×256 وتحفظها باسم دلالي
//
// التشغيل:  dart run tool/process_icons.dart
import 'dart:collection';
import 'dart:io';

import 'package:image/image.dart' as img;

/// ربط الملف الخام بالاسم الدلالي المستعمل في الواجهة.
/// المفتاح جزء مميّز من اسم الملف الخام.
const mapping = {
  '01ef3046': 'coin',
  '0d609c8f': 'gems',
  '2eaf2c28': 'app_icon',
  '32050830': 'challenge_proverb',
  '8ba8beea': 'challenge_verse',
  'baa3c814': 'challenge_gulf',
  'fbf7493f': 'shop_chest',
  'fe17507d': 'challenge_word',
  'dice': 'dice',
};

/// ملفات تُعالَج في مكانها (اسمها النهائي هو نفسه اسم المصدر)
const inPlace = {'dice'};

const outSize = 256;

/// حدود المات الناعم لكل أيقونة: [t0, t1]
/// المسافة اللونية عن الخلفية أقل من t0 ⇒ شفاف تماما (خلفية وظلال)
/// أكبر من t1 ⇒ معتم تماما (الشكل)، وبينهما تدرّج ناعم يذيب الظل والهالة
const matte = {
  // خلفية فاتحة قريبة من انعكاسات الزجاج ⇒ نطاق أضيق حتى لا يُؤكل الشكل
  'challenge_word': [22.0, 70.0],
  'app_icon': [18.0, 60.0],
  // الصندوق: توسيع النطاق يغسل ذهب الشكل نفسه، لذا نُبقيه على النطاق
  // الافتراضي ونتقبّل بقية ظلّ خفيفة لا تُرى بالحجم الصغير المستعمل
  'shop_chest': [34.0, 100.0],
  // النرد أزرق قريب لونيا من خلفيته الكحلية ⇒ نطاق ضيّق جدا
  // كي لا يُغسل جسم المكعّب نفسه
  'dice': [30.0, 62.0],
};
const defaultMatte = [34.0, 96.0];

/// قصّ مسبق للمصدر (بإحداثيات 1024) لعزل الشكل عن ظلّ ملوّن بعيد لونيا
/// عن الخلفية فلا تستطيع مطابقة الألوان إزالته
const sourceCrop = {
  'dice': [196, 152, 856, 812],
};

void main(List<String> args) {
  final dir = Directory('assets/icons');
  // يمكن تمرير أسماء بعينها لإعادة معالجتها فقط
  final only = args.toSet();

  final sources = dir.listSync().whereType<File>().where((f) {
    if (!f.path.endsWith('.png')) return false;
    final key = mapping.keys.firstWhere(
      (k) => f.path.contains(k),
      orElse: () => '',
    );
    if (key.isEmpty) return false;
    return only.isEmpty || only.contains(mapping[key]);
  }).toList();

  if (sources.isEmpty) {
    stderr.writeln('لم يُعثر على ملفات لمعالجتها.');
    exit(1);
  }

  for (final file in sources) {
    final key = mapping.keys.firstWhere(
      (k) => file.path.contains(k),
      orElse: () => '',
    );
    final name = mapping[key]!;
    // الملفات المعالَجة في مكانها لا تُعاد معالجتها إلا بطلب صريح
    if (inPlace.contains(name) && only.isEmpty) {
      stdout.writeln('تخطّي (معالَج مسبقا): $name.png');
      continue;
    }
    final m = matte[name] ?? defaultMatte;

    var image = img.decodePng(file.readAsBytesSync())!;
    image = image.convert(numChannels: 4); // إضافة قناة شفافية

    final crop = sourceCrop[name];
    if (crop != null) {
      image = img.copyCrop(
        image,
        x: crop[0],
        y: crop[1],
        width: crop[2] - crop[0],
        height: crop[3] - crop[1],
      );
    }

    _removeBackground(image, m[0], m[1]);
    final cropped = _trim(image);
    final resized = img.copyResize(
      cropped,
      width: outSize,
      height: outSize,
      maintainAspect: true,
      backgroundColor: img.ColorRgba8(0, 0, 0, 0),
      interpolation: img.Interpolation.cubic,
    );

    final out = File('assets/icons/$name.png');
    out.writeAsBytesSync(img.encodePng(resized, level: 9));
    final kb = (out.lengthSync() / 1024).round();
    stdout.writeln('$name.png  →  ${resized.width}×${resized.height}  ${kb}KB');
  }
}

/// مات ناعم: تعبئة فيضية من الإطار تمنح كل بكسل شفافية تتناسب مع بُعد لونه
/// عن لون الخلفية، فتذوب الظلال والهالات تدريجيا بدل قطعها بحدّ حاد
void _removeBackground(img.Image im, double t0, double t1) {
  final w = im.width, h = im.height;
  final visited = List<bool>.filled(w * h, false);
  final queue = Queue<int>();

  void seed(int x, int y) {
    final i = y * w + x;
    if (!visited[i]) {
      visited[i] = true;
      queue.add(i);
    }
  }

  for (var x = 0; x < w; x++) {
    seed(x, 0);
    seed(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    seed(0, y);
    seed(w - 1, y);
  }

  // متوسط لون الزوايا يمثّل لون الخلفية المرجعي
  final corners = [
    im.getPixel(0, 0),
    im.getPixel(w - 1, 0),
    im.getPixel(0, h - 1),
    im.getPixel(w - 1, h - 1),
  ];
  final br = corners.map((p) => p.r).reduce((a, b) => a + b) / 4;
  final bg = corners.map((p) => p.g).reduce((a, b) => a + b) / 4;
  final bb = corners.map((p) => p.b).reduce((a, b) => a + b) / 4;

  double distToBg(img.Pixel p) {
    final dr = p.r - br, dg = p.g - bg, db = p.b - bb;
    return (dr * dr + dg * dg + db * db).toDouble();
  }

  final t0sq = t0 * t0, t1sq = t1 * t1;

  while (queue.isNotEmpty) {
    final i = queue.removeFirst();
    final x = i % w, y = i ~/ w;
    final px = im.getPixel(x, y);
    final d = distToBg(px);

    // بعيد عن لون الخلفية ⇒ هذا هو الشكل، نتوقّف ولا نكمل الانتشار خلفه
    if (d >= t1sq) continue;

    if (d <= t0sq) {
      px.a = 0;
    } else {
      // تدرّج ناعم بين الخلفية والشكل يذيب الظل
      final t = (d - t0sq) / (t1sq - t0sq);
      px.a = (255 * t).round().clamp(0, 255);
    }
    im.setPixel(x, y, px);

    for (final dir in const [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ]) {
      final nx = x + dir[0], ny = y + dir[1];
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      final ni = ny * w + nx;
      if (visited[ni]) continue;
      visited[ni] = true;
      queue.add(ni);
    }
  }
}

/// قصّ الهوامش الشفافة مع ترك حاشية صغيرة، والإبقاء على شكل مربّع
img.Image _trim(img.Image im) {
  var minX = im.width, minY = im.height, maxX = -1, maxY = -1;
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      if (im.getPixel(x, y).a > 8) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return im; // لا شيء ظاهر — نُبقي الأصل

  // مربّع متمركز حول المحتوى كي لا تتشوّه النِّسَب
  final cx = (minX + maxX) ~/ 2, cy = (minY + maxY) ~/ 2;
  final side =
      ((maxX - minX).clamp(1, im.width) > (maxY - minY).clamp(1, im.height)
          ? (maxX - minX)
          : (maxY - minY)) +
      24; // حاشية
  final half = side ~/ 2;
  final x0 = (cx - half).clamp(0, im.width - 1);
  final y0 = (cy - half).clamp(0, im.height - 1);
  final x1 = (cx + half).clamp(0, im.width - 1);
  final y1 = (cy + half).clamp(0, im.height - 1);

  return img.copyCrop(
    im,
    x: x0,
    y: y0,
    width: (x1 - x0).clamp(1, im.width),
    height: (y1 - y0).clamp(1, im.height),
  );
}
