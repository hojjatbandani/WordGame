// يضيف إلى bonus_words كل مرحلة كلَّ كلمة صحيحة تتكوّن من حروفها ولم
// تُقبل بعد — من القاموس (tool/wordlist.txt) ومن الكلمات المقبولة
// (tool/accepted_words.txt).
//
// لماذا: levels.json وُلّد قبل آخر توسعة للقاموس، فكانت «بقر» و«قبر»
// مثلا تُرفض في مرحلة حروفها ب ر ق رغم أنهما في القاموس، ويرى اللاعب كلمة
// صحيحة تهتزّ حمراء. لا يحذف شيئا ولا يمسّ الحروف ولا الأهداف ولا الترقيم،
// وتشغيله مرتين لا يغيّر سطرا.
//
//   dart run tool/sync_bonus_words.dart

import 'dart:convert';
import 'dart:io';

const _levelsPath = 'assets/data/levels.json';

/// كلمات القاموس والكلمات المقبولة معا
Set<String> loadVocabulary({
  String wordlistPath = 'tool/wordlist.txt',
  String acceptedPath = 'tool/accepted_words.txt',
}) {
  final words = <String>{};
  for (final line in File(wordlistPath).readAsLinesSync()) {
    final s = line.trim();
    if (s.isEmpty || s.startsWith('#')) continue;
    words.add(s.split('|').first.trim());
  }
  final accepted = File(acceptedPath);
  if (accepted.existsSync()) {
    for (final line in accepted.readAsLinesSync()) {
      final s = line.trim();
      if (s.isEmpty || s.startsWith('#')) continue;
      words.add(s);
    }
  }
  return words;
}

bool _formable(String word, List<String> letters) {
  final pool = List.of(letters);
  for (final c in word.split('')) {
    if (!pool.remove(c)) return false;
  }
  return true;
}

/// الكلمات الصحيحة الممكنة في [level] وليست هدفا ولا إضافية بعد (مرتّبة)
List<String> missingBonus(Map level, Set<String> vocabulary) {
  final letters = (level['letters'] as List).cast<String>();
  final core = {
    for (final w in level['words'] as List) (w as Map)['word'] as String,
  };
  final bonus = (level['bonus_words'] as List).cast<String>().toSet();
  return [
    for (final w in vocabulary)
      if (w.length >= 3 &&
          w.length <= letters.length &&
          !core.contains(w) &&
          !bonus.contains(w) &&
          _formable(w, letters))
        w,
  ]..sort();
}

void main() {
  final file = File(_levelsPath);
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final levels = (root['levels'] as List).cast<Map<String, dynamic>>();
  final vocabulary = loadVocabulary();

  var added = 0;
  for (final level in levels) {
    final missing = missingBonus(level, vocabulary);
    if (missing.isEmpty) continue;
    (level['bonus_words'] as List).addAll(missing);
    added += missing.length;
    stdout.writeln('المرحلة ${level['id']}: + ${missing.join('، ')}');
  }
  file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(root)}\n');
  stdout.writeln('أُضيفت $added كلمة.');
}
