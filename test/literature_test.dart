import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/literature_models.dart';

/// يتحقق من سلامة بنية المحتوى الأدبي — لا حقول فارغة ولا أبيات ناقصة
void main() {
  test('literature.json parses and has non-empty, well-formed entries', () {
    final raw = File('assets/data/literature.json').readAsStringSync();
    final lib =
        LiteratureLibrary.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(lib.proverbs, isNotEmpty);
    expect(lib.gulfProverbs, isNotEmpty);
    expect(lib.verses, isNotEmpty);
    expect(lib.words, isNotEmpty);

    for (final p in [...lib.proverbs, ...lib.gulfProverbs]) {
      expect(p.text.trim(), isNotEmpty);
      expect(p.meaning.trim(), isNotEmpty);
    }
    for (final v in lib.verses) {
      expect(v.first.trim(), isNotEmpty, reason: 'شطر أول ناقص');
      expect(v.second.trim(), isNotEmpty, reason: 'شطر ثانٍ ناقص');
      expect(v.poet.trim(), isNotEmpty, reason: 'القائل غير مذكور');
      expect(v.meaning.trim(), isNotEmpty, reason: 'شرح البيت ناقص');
    }
    for (final w in lib.words) {
      expect(w.word.trim(), isNotEmpty);
      expect(w.meaning.trim(), isNotEmpty);
    }
  });
}
