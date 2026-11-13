// يعيد ترتيب المراحل 2-22 بحسب ألفة الكلمات (المواصفة §8.2). كلها بنفس
// درجة الصعوبة (difficultyScore = 430: ثلاثة حروف وهدفان)، فالترتيب لا
// يكسر المنحنى ولا شرط «زعيم الفصل أصعب مراحله» — لكن «رهن» مثلا لم تعد
// المرحلة الثانية التي يلقاها لاعب جديد.
//
// تشغيل لمرة واحدة؛ يرفض التشغيل الثاني (المرحلة 2 صارت حرف/فرح).
//
//   dart run tool/reorder_onboarding_stages.dart

import 'dart:convert';
import 'dart:io';

const _levelsPath = 'assets/data/levels.json';

/// المرحلة الجديدة ← المرحلة القديمة
const newToOld = {
  2: 15, // حرف / فرح
  3: 6, // ورد / دور
  4: 4, // ركب / كبر
  5: 5, // فرس / سفر
  6: 13, // حار / راح
  7: 21, // بعد / عبد
  8: 9, // برق / قرب
  9: 18, // بشر / شرب
  10: 19, // بصر / صبر
  11: 14, // حرس / سحر
  12: 12, // جسد / سجد (زعيم الفصل الأول)
  13: 3, // درس / سرد
  14: 16, // بدل / بلد
  15: 17, // برج / جبر
  16: 7, // كرم / مكر
  17: 8, // بات / تاب
  18: 10, // تحف / فتح
  19: 20, // بصل / صلب
  20: 11, // جرد / درج
  21: 2, // نهر / رهن
  22: 22, // بغض / غضب
};

void main() {
  final file = File(_levelsPath);
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final levels = (root['levels'] as List).cast<Map<String, dynamic>>();

  final stage2Words = {
    for (final w in levels[1]['words'] as List) (w as Map)['word'],
  };
  if (stage2Words.contains('حرف')) {
    stdout.writeln('سبق الترتيب — لا تغيير.');
    return;
  }
  if (newToOld.values.toSet().length != newToOld.length) {
    throw StateError('خريطة غير تقابلية');
  }

  final byOldId = {for (final l in levels) l['id'] as int: l};
  final moved = {
    for (final e in newToOld.entries)
      e.key: Map<String, dynamic>.of(byOldId[e.value]!)..['id'] = e.key,
  };
  for (final e in moved.entries) {
    levels[e.key - 1] = e.value;
  }
  file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(root)}\n');
  stdout.writeln('أُعيد ترتيب ${moved.length} مرحلة.');
}
