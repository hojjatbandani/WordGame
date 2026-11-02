import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/challenge_models.dart';

/// أهم اختبار: يضمن أن كل تحدٍّ قابل للعب فعلا —
/// الجواب مجرّد من التشكيل، وعجلة الحروف تحتوي كل حروف الجواب.
void main() {
  late ChallengeSet set;

  setUpAll(() {
    final raw = File('assets/data/challenges.json').readAsStringSync();
    set = ChallengeSet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  // علامات التشكيل والهمزات التي يصعب تكوينها في العجلة
  final forbidden = RegExp('[ً-ْءأإؤئ]');

  test('every category has challenges', () {
    expect(set.proverbs, isNotEmpty);
    expect(set.gulfProverbs, isNotEmpty);
    expect(set.verses, isNotEmpty);
    expect(set.words, isNotEmpty);
  });

  test('answers are bare letters with no diacritics or hamza', () {
    for (final item in _all(set)) {
      expect(forbidden.hasMatch(item.answer), isFalse,
          reason: 'الجواب "${item.answer}" يحوي تشكيلا/همزة يصعب تكوينها');
      expect(item.answer.trim(), isNotEmpty);
    }
  });

  test('wheel always contains every answer letter (multiset)', () {
    final rng = Random(1);
    for (final item in _all(set)) {
      // نجرّب عدة مرات لأن التمويه عشوائي
      for (var t = 0; t < 20; t++) {
        final wheel = item.buildWheelLetters(rng);
        expect(wheel.length, lessThanOrEqualTo(10));
        expect(_containsMultiset(wheel, item.answer.split('')), isTrue,
            reason: 'العجلة لا تكفي لتكوين "${item.answer}"');
      }
    }
  });

  test('fill challenges reveal and explain each answer', () {
    for (final item in [...set.proverbs, ...set.gulfProverbs, ...set.verses]) {
      expect(item.reveal.trim(), isNotEmpty);
      expect(item.meaning.trim(), isNotEmpty);
      // يجب أن يكون هناك سياق حول الفراغ
      expect(
        item.before.isNotEmpty ||
            item.after.isNotEmpty ||
            item.clue.isNotEmpty,
        isTrue,
        reason: 'التحدي بلا سياق حول الفراغ',
      );
    }
  });

  test('every category has an icon asset on disk', () {
    for (final c in ChallengeCategory.values) {
      expect(File(c.iconAsset).existsSync(), isTrue,
          reason: 'أيقونة مفقودة: ${c.iconAsset}');
    }
  });

  test('verses carry an attribution', () {
    for (final v in set.verses) {
      expect(v.attribution.trim(), isNotEmpty,
          reason: 'بيت بلا نسبة لقائله');
    }
  });
}

Iterable<ChallengeItem> _all(ChallengeSet s) =>
    [...s.proverbs, ...s.gulfProverbs, ...s.verses, ...s.words];

bool _containsMultiset(List<String> pool, List<String> needed) {
  final counts = <String, int>{};
  for (final c in pool) {
    counts[c] = (counts[c] ?? 0) + 1;
  }
  for (final c in needed) {
    final left = (counts[c] ?? 0) - 1;
    if (left < 0) return false;
    counts[c] = left;
  }
  return true;
}

