// إعادة ترتيب مراحل levels.json تصاعديا بالصعوبة.
//
// المشكلة: الملف مولَّد آليا بلا ضبط منحنى، فكانت الصعوبة تتذبذب —
// المرحلة 20 (عجلة 5 حروف، 6 كلمات) تليها المرحلة 21 (عجلة 3 حروف،
// كلمتان)، وهو هبوط حادّ يقرؤه اللاعب «اللعبة انكسرت» لا «استرحت».
// ثمانية هبوطات كبيرة كهذه، و26 فصلا زعيمُه ليس أصعب مراحله.
//
// الحلّ: ترتيب المراحل الخمسمئة تصاعديا بدرجة صعوبة محسوبة، ثم إعادة
// ترقيمها 1..500. الترقيم التسلسلي يبقى (levels_validation_test يشترطه)،
// ولا تُحذف مرحلة ولا تُضاف: نفس المحتوى بترتيب صحيح.
//
// جاز الترتيب العالمي لأن العوالم غير مصنَّفة موضوعيا أصلا: فحصُ
// الكلمات يُظهر أنها مجموعات تباديل حروف مولَّدة آليا، والعوالم مفصولة
// بحجم العجلة وحده. فلا موضوع يُكسر بالترتيب.
//
// التشغيل:  dart run tool/rebalance_levels.dart
// وللفحص بلا كتابة:  dart run tool/rebalance_levels.dart --dry-run

import 'dart:convert';
import 'dart:io';

const _path = 'assets/data/levels.json';

/// درجة صعوبة المرحلة.
///
/// الأوزان ليست اعتباطية:
/// - **حجم العجلة** أثقل عامل بفارق كبير: فضاء البحث ينمو مضروبيا مع كل
///   حرف يُضاف، فالقفزة من 4 حروف إلى 5 أصعب من إضافة كلمتين هدفا.
/// - **عدد الكلمات** يلي: كل كلمة عمل مستقلّ يجب إتمامه.
/// - **مجموع الأحرف** يلتقط الفرق بين خمس كلمات ثلاثية وخمس سُباعية.
/// - **أطول كلمة** لأن الكلمة الطويلة هي عادة عقدة المرحلة.
int difficultyScore(Map<String, dynamic> level) {
  final words = (level['words'] as List)
      .map((w) => (w as Map)['word'] as String)
      .toList();
  final letters = (level['letters'] as List).length;
  final sumLen = words.fold<int>(0, (a, w) => a + w.length);
  final maxLen = words.map((w) => w.length).reduce((a, b) => a > b ? a : b);
  return letters * 100 + words.length * 35 + sumLen * 5 + maxLen * 10;
}

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');
  final file = File(_path);
  final original = file.readAsStringSync();
  final root = jsonDecode(original) as Map<String, dynamic>;
  final levels = (root['levels'] as List).cast<Map<String, dynamic>>();

  final before = _profile(levels);

  // ترتيب تامّ (لا جزئي): عند تساوي الدرجة نفصل بحجم العجلة ثم عدد
  // الكلمات ثم المعرّف الأصلي، فيكون الناتج نفسه في كل تشغيل — تشغيل
  // الأداة مرتين لا يحرّك سطرا
  levels.sort((a, b) {
    final byScore = difficultyScore(a).compareTo(difficultyScore(b));
    if (byScore != 0) return byScore;
    final byLetters = (a['letters'] as List).length.compareTo(
      (b['letters'] as List).length,
    );
    if (byLetters != 0) return byLetters;
    final byWords = (a['words'] as List).length.compareTo(
      (b['words'] as List).length,
    );
    if (byWords != 0) return byWords;
    return (a['id'] as int).compareTo(b['id'] as int);
  });

  // إعادة الترقيم + حقل difficulty صادق: دالة رتيبة في الدرجة، فلا
  // يمكن أن يحمل رقما أعلى من مرحلة أصعب منه
  final scores = levels.map(difficultyScore).toList();
  final lo = scores.first;
  final hi = scores.last;
  for (var i = 0; i < levels.length; i++) {
    levels[i]['id'] = i + 1;
    levels[i]['difficulty'] = hi == lo
        ? 1
        : 1 + ((scores[i] - lo) * 9 / (hi - lo)).floor().clamp(0, 9);
  }

  final after = _profile(levels);
  _report('قبل', before);
  _report('بعد', after);

  if (dryRun) {
    stdout.writeln('\n(--dry-run: لم يُكتب شيء)');
    return;
  }

  // نهايات أسطر CRLF كما في الملف الأصلي، وإلا انقلب الملف كله في git
  final encoded = const JsonEncoder.withIndent('  ').convert(root);
  file.writeAsStringSync('$encoded\n'.replaceAll('\n', '\r\n'));
  stdout.writeln('\nكُتب $_path');
}

class _Profile {
  final int drops;
  final int bigDrops;
  final int chapterFloorBreaks;
  final int bossNotHardest;
  final List<String> worstDrops;
  final List<String> worlds;

  _Profile(
    this.drops,
    this.bigDrops,
    this.chapterFloorBreaks,
    this.bossNotHardest,
    this.worstDrops,
    this.worlds,
  );
}

/// حدود العوالم كما في BalanceConfig: 60 مرحلة للعوالم 1-4 و65 لما بعدها
int _worldStart(int world) =>
    world <= 4 ? (world - 1) * 60 + 1 : 240 + (world - 5) * 65 + 1;
int _worldSize(int world) => world <= 4 ? 60 : 65;

_Profile _profile(List<Map<String, dynamic>> levels) {
  final s = levels.map(difficultyScore).toList();

  var drops = 0;
  var bigDrops = 0;
  final worst = <String>[];
  for (var i = 1; i < s.length; i++) {
    final delta = s[i] - s[i - 1];
    if (delta < 0) drops++;
    if (delta <= -60) {
      bigDrops++;
      if (worst.length < 10) {
        worst.add('المرحلة ${i + 1}: ${s[i - 1]} → ${s[i]} ($delta)');
      }
    }
  }

  var floorBreaks = 0;
  var bossNotHardest = 0;
  var prevFloor = -1;
  final worlds = <String>[];
  for (var w = 1; w <= 8; w++) {
    final start = _worldStart(w);
    final size = _worldSize(w);
    final per = size ~/ 5;
    for (var c = 0; c < 5; c++) {
      final from = start + c * per;
      final to = c == 4 ? start + size - 1 : from + per - 1;
      final chapter = s.sublist(from - 1, to);
      final mn = chapter.reduce((a, b) => a < b ? a : b);
      final mx = chapter.reduce((a, b) => a > b ? a : b);
      if (prevFloor >= 0 && mn < prevFloor) floorBreaks++;
      prevFloor = mn;
      if (chapter.last != mx) bossNotHardest++;
    }
    final worldScores = s.sublist(start - 1, start + size - 1);
    final letters = levels
        .sublist(start - 1, start + size - 1)
        .map((l) => (l['letters'] as List).length);
    worlds.add(
      'عالم $w: درجة ${worldScores.first}–${worldScores.last}، '
      'حروف ${letters.reduce((a, b) => a < b ? a : b)}–'
      '${letters.reduce((a, b) => a > b ? a : b)}',
    );
  }

  return _Profile(drops, bigDrops, floorBreaks, bossNotHardest, worst, worlds);
}

void _report(String label, _Profile p) {
  stdout.writeln('\n=== $label ===');
  stdout.writeln('انحدارات: ${p.drops}   حادّة (≤ -60): ${p.bigDrops}');
  stdout.writeln('فصول قاعُها أدنى من السابق: ${p.chapterFloorBreaks}/40');
  stdout.writeln('فصول زعيمُها ليس أصعب مراحلها: ${p.bossNotHardest}/40');
  for (final line in p.worstDrops) {
    stdout.writeln('  $line');
  }
  for (final line in p.worlds) {
    stdout.writeln('  $line');
  }
}
