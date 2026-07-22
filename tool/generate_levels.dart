// مولد المراحل: يقرأ tool/wordlist.txt ويولد مراحل حتى الوصول إلى
// [targetTotal] مرحلة، ثم يدمجها مع المراحل اليدوية (1-20).
//
// استراتيجية التوليد:
//   1) عجلات من حروف كلمة أساس مباشرة
//   2) عجلات «موسعة»: حروف كلمة أساس + حرف شائع إضافي (نمط Wordscapes)
//   3) عجلات بحرفين إضافيين إن لزم
//
// التشغيل:  dart run tool/generate_levels.dart
import 'dart:convert';
import 'dart:io';

const handcraftedCount = 20;
const targetTotal = 500;
const maxTargetWords = 6;
const minWordLength = 3;
const maxWheelLetters = 6;

const commonExtras = [
  'ا', 'و', 'ي', 'م', 'ن', 'ر', 'ل', 'ب', 'ت', 'س',
  'د', 'ح', 'ك', 'ع', 'ف', 'ه', 'ق', 'ج', 'ص', 'ط',
];

void main() {
  final wordlist = _loadWordlist('tool/wordlist.txt');
  final levelsFile = File('assets/data/levels.json');
  final existing =
      (jsonDecode(levelsFile.readAsStringSync())['levels'] as List)
          .cast<Map<String, dynamic>>();
  final handcrafted =
      existing.where((l) => (l['id'] as int) <= handcraftedCount).toList();

  final usedLetterSets = <String>{
    for (final l in handcrafted)
      _multisetKey((l['letters'] as List).cast<String>()),
  };

  final generated = <Map<String, dynamic>>[];
  final sortedWords = wordlist.keys.toList()
    ..sort((a, b) {
      final byLen = b.length.compareTo(a.length);
      return byLen != 0 ? byLen : a.compareTo(b);
    });

  void tryWheel(List<String> wheel, {required int minWords}) {
    if (wheel.length < 3 || wheel.length > maxWheelLetters) return;
    final key = _multisetKey(wheel);
    if (usedLetterSets.contains(key)) return;

    final formable = wordlist.keys
        .where((w) =>
            w.length >= minWordLength && _isSubMultiset(w.split(''), wheel))
        .toList()
      ..sort((a, b) {
        final byLen = b.length.compareTo(a.length);
        return byLen != 0 ? byLen : a.compareTo(b);
      });
    if (formable.length < minWords) return;
    // أطول كلمة يجب أن تستهلك أغلب حروف العجلة كي لا تبدو حشوا
    if (formable.first.length < wheel.length - 1) return;

    usedLetterSets.add(key);
    final targets = formable.take(maxTargetWords).toList()
      ..sort((a, b) => a.length.compareTo(b.length));
    final bonus = formable.skip(maxTargetWords).toList();

    generated.add({
      'letters': wheel,
      'words': [
        for (final w in targets) {'word': w, 'definition': wordlist[w]},
      ],
      'bonus_words': bonus,
      'difficulty': _difficulty(wheel.length, targets.length),
    });
  }

  // المرور 1: عجلات الكلمات المباشرة
  for (final base in sortedWords) {
    tryWheel(base.split(''), minWords: 2);
  }

  // المرور 2: كلمة + حرف إضافي شائع
  for (final base in sortedWords) {
    if (generated.length >= targetTotal - handcraftedCount) break;
    if (base.length >= maxWheelLetters) continue;
    for (final extra in commonExtras) {
      if (generated.length >= targetTotal - handcraftedCount) break;
      tryWheel([...base.split(''), extra]..sort(), minWords: 3);
    }
  }

  // المرور 3: كلمة + حرفان إضافيان (عند الحاجة فقط)
  outer:
  for (final base in sortedWords) {
    if (generated.length >= targetTotal - handcraftedCount) break;
    if (base.length >= maxWheelLetters - 1) continue;
    for (var i = 0; i < commonExtras.length; i++) {
      for (var j = i + 1; j < commonExtras.length; j++) {
        if (generated.length >= targetTotal - handcraftedCount) {
          break outer;
        }
        tryWheel(
          [...base.split(''), commonExtras[i], commonExtras[j]]..sort(),
          minWords: 4,
        );
      }
    }
  }

  // الترتيب من الأسهل إلى الأصعب
  generated.sort((a, b) {
    final la = (a['letters'] as List).length;
    final lb = (b['letters'] as List).length;
    if (la != lb) return la.compareTo(lb);
    return (a['words'] as List).length.compareTo((b['words'] as List).length);
  });

  // أخذ عينة موزعة بانتظام للحفاظ على منحنى الصعوبة إن زاد العدد
  final need = targetTotal - handcraftedCount;
  var selected = generated;
  if (generated.length > need) {
    selected = [
      for (var i = 0; i < need; i++)
        generated[(i * generated.length) ~/ need],
    ];
  }

  for (var i = 0; i < selected.length; i++) {
    selected[i]['id'] = handcraftedCount + 1 + i;
  }

  final merged = {'levels': [...handcrafted, ...selected]};
  levelsFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(merged));

  stdout.writeln('اليدوية: ${handcrafted.length}');
  stdout.writeln('المرشحة: ${generated.length} — المختارة: ${selected.length}');
  stdout.writeln('المجموع: ${handcrafted.length + selected.length}');
  final byLetters = <int, int>{};
  for (final l in selected) {
    final n = (l['letters'] as List).length;
    byLetters[n] = (byLetters[n] ?? 0) + 1;
  }
  for (final e in (byLetters.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key)))) {
    stdout.writeln('  ${e.key} حروف: ${e.value} مرحلة');
  }
}

Map<String, String> _loadWordlist(String path) {
  final map = <String, String>{};
  for (final line in File(path).readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final parts = trimmed.split('|');
    if (parts.length != 2) {
      stderr.writeln('سطر غير صالح: $trimmed');
      continue;
    }
    map[parts[0].trim()] = parts[1].trim();
  }
  return map;
}

String _multisetKey(List<String> letters) => (List.of(letters)..sort()).join();

bool _isSubMultiset(List<String> small, List<String> big) {
  final counts = <String, int>{};
  for (final c in big) {
    counts[c] = (counts[c] ?? 0) + 1;
  }
  for (final c in small) {
    final left = (counts[c] ?? 0) - 1;
    if (left < 0) return false;
    counts[c] = left;
  }
  return true;
}

int _difficulty(int letterCount, int wordCount) {
  switch (letterCount) {
    case 3:
      return wordCount <= 2 ? 1 : 2;
    case 4:
      return wordCount <= 3 ? 3 : 4;
    default:
      return 5;
  }
}
