// محتوى المراحل الأولى والكلمات المقبولة (المواصفة §8): كلمة صحيحة لا
// تُرفض «خطأ»، وترتيب مراحل التعليم الذي اعتُمد لا يرجع بتوليد لاحق.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/sync_bonus_words.dart';

List<Map<String, dynamic>> _levels() =>
    (jsonDecode(File('assets/data/levels.json').readAsStringSync())['levels']
            as List)
        .cast<Map<String, dynamic>>();

Set<String> _core(Map<String, dynamic> level) => {
  for (final w in level['words'] as List) (w as Map)['word'] as String,
};

bool _formable(String word, List letters) {
  final pool = List.of(letters);
  for (final c in word.split('')) {
    if (!pool.remove(c)) return false;
  }
  return true;
}

void main() {
  late List<Map<String, dynamic>> levels;
  setUpAll(() => levels = _levels());

  test('every bonus word is formable and not core', () {
    for (final l in levels) {
      final core = _core(l);
      for (final b in (l['bonus_words'] as List).cast<String>()) {
        expect(_formable(b, l['letters'] as List), isTrue,
            reason: 'stage ${l['id']}: $b');
        expect(core.contains(b), isFalse, reason: 'stage ${l['id']}: $b');
      }
    }
  });

  test('sync invariant: no dictionary or accepted word is missing', () {
    final vocabulary = loadVocabulary();
    final missing = <String>[
      for (final l in levels)
        for (final w in missingBonus(l, vocabulary)) 'stage ${l['id']}: $w',
    ];
    expect(missing, isEmpty,
        reason: 'run: dart run tool/sync_bonus_words.dart');
  });

  test('stages 1–10: 3 letters and at most 2 core words', () {
    for (final l in levels.take(10)) {
      expect((l['letters'] as List).length, 3, reason: 'stage ${l['id']}');
      expect(_core(l).length, lessThanOrEqualTo(2), reason: 'stage ${l['id']}');
    }
  });

  test('onboarding order is the approved one', () {
    const approved = [
      {'قلم'},
      {'حرف', 'فرح'},
      {'ورد', 'دور'},
      {'ركب', 'كبر'},
      {'فرس', 'سفر'},
      {'حار', 'راح'},
      {'بعد', 'عبد'},
      {'برق', 'قرب'},
      {'بشر', 'شرب'},
      {'بصر', 'صبر'},
      {'حرس', 'سحر'},
      {'جسد', 'سجد'},
    ];
    for (var i = 0; i < approved.length; i++) {
      expect(levels[i]['id'], i + 1);
      expect(_core(levels[i]), approved[i], reason: 'stage ${i + 1}');
    }
  });

  test('stage 53 accepts سنام and the other natural answers', () {
    final bonus = (levels[52]['bonus_words'] as List).cast<String>();
    expect(bonus, containsAll(['سنام', 'ماس', 'نما', 'مسن']));
  });
}
