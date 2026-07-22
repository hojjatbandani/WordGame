import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/models.dart';

/// يتحقق أن كل مرحلة في levels.json صالحة للعب:
/// كل كلمة (هدف أو إضافية) قابلة للتكوين من حروف العجلة
void main() {
  test('all levels are valid and playable', () {
    final raw = File('assets/data/levels.json').readAsStringSync();
    final levels = ((jsonDecode(raw) as Map)['levels'] as List)
        .map((l) => GameLevel.fromJson(l as Map<String, dynamic>))
        .toList();

    expect(levels.length, greaterThanOrEqualTo(20));

    final seenLetterSets = <String>{};
    for (var i = 0; i < levels.length; i++) {
      final level = levels[i];
      expect(level.id, i + 1, reason: 'ids must be sequential');
      expect(level.words, isNotEmpty, reason: 'level ${level.id} has no words');
      expect(level.letters.length, inInclusiveRange(3, 7));

      final key = (List.of(level.letters)..sort()).join();
      expect(seenLetterSets.add(key), isTrue,
          reason: 'level ${level.id} duplicates letter set $key');

      for (final w in [
        ...level.words.map((e) => e.word),
        ...level.bonusWords,
      ]) {
        expect(_formable(w, level.letters), isTrue,
            reason: 'level ${level.id}: "$w" not formable from '
                '${level.letters.join()}');
      }
      for (final w in level.words) {
        expect(w.definition.trim(), isNotEmpty,
            reason: 'level ${level.id}: "${w.word}" missing definition');
      }
    }
  });
}

bool _formable(String word, List<String> letters) {
  final pool = <String, int>{};
  for (final c in letters) {
    pool[c] = (pool[c] ?? 0) + 1;
  }
  for (final c in word.split('')) {
    final left = (pool[c] ?? 0) - 1;
    if (left < 0) return false;
    pool[c] = left;
  }
  return true;
}
