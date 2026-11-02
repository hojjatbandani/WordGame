// منحنى الصعوبة عبر الخمسمئة مرحلة.
//
// كان الملف مولَّدا آليا بلا ضبط منحنى: 85 انحدارا، تسعة منها حادّة —
// أسوأها المرحلة 21 (عجلة 3 حروف، كلمتان) بعد المرحلة 20 (عجلة 5 حروف،
// ست كلمات) — و28 فصلا من أربعين زعيمُه ليس أصعب مراحله.
//
// أُعيد الترتيب بـ tool/rebalance_levels.dart. هذا الاختبار يمنع عودة
// الخلل: أي مرحلة تُضاف أو تُعدَّل في غير موضعها من المنحنى تُفشله.
//
// الشروط الأربعة معا هي ما يعنيه «تدرّج صحيح»: لا هبوط بين مرحلتين
// متتاليتين، ولا بين فصل وفصل، ولا بين عالم وعالم، والزعيم أصعب فصله.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';

import '../tool/rebalance_levels.dart' show difficultyScore;

List<Map<String, dynamic>> _levels() {
  final raw = File('assets/data/levels.json').readAsStringSync();
  return ((jsonDecode(raw) as Map)['levels'] as List)
      .cast<Map<String, dynamic>>();
}

/// حدود الفصول من BalanceConfig لا من أرقام مكتوبة: لو تغيّر حجم عالم
/// تغيّرت معه حدود الاختبار
Iterable<({int world, int chapter, int from, int to})> _chapters() sync* {
  var next = 1;
  for (var w = 1; w <= BalanceConfig.worldCount; w++) {
    final size = BalanceConfig.worldStageCount(w);
    final per = size ~/ BalanceConfig.chaptersPerWorld;
    final start = next;
    for (var c = 1; c <= BalanceConfig.chaptersPerWorld; c++) {
      final from = start + (c - 1) * per;
      final to = c == BalanceConfig.chaptersPerWorld
          ? start + size - 1
          : from + per - 1;
      yield (world: w, chapter: c, from: from, to: to);
    }
    next = start + size;
  }
}

void main() {
  late List<Map<String, dynamic>> levels;
  late List<int> scores;

  setUpAll(() {
    levels = _levels();
    scores = levels.map(difficultyScore).toList();
  });

  test('عدد المراحل يطابق البنية، والترقيم تسلسلي', () {
    expect(levels.length, BalanceConfig.totalStages);
    for (var i = 0; i < levels.length; i++) {
      expect(levels[i]['id'], i + 1);
    }
  });

  test('لا مرحلة أسهل من التي قبلها', () {
    final drops = <String>[];
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] < scores[i - 1]) {
        drops.add('المرحلة ${i + 1}: ${scores[i - 1]} → ${scores[i]}');
      }
    }
    expect(
      drops,
      isEmpty,
      reason:
          'انحدار في المنحنى — شغّل: dart run tool/rebalance_levels.dart\n'
          '${drops.take(10).join('\n')}',
    );
  });

  test('زعيم كل فصل أصعب مراحله', () {
    for (final ch in _chapters()) {
      final block = scores.sublist(ch.from - 1, ch.to);
      expect(
        block.last,
        block.reduce((a, b) => a > b ? a : b),
        reason: 'الفصل ${ch.world}.${ch.chapter}: آخر مرحلة يجب أن تكون الأصعب',
      );
    }
  });

  test('قاع كل فصل لا يقلّ عن قاع الفصل السابق', () {
    var previous = -1;
    for (final ch in _chapters()) {
      final floor = scores
          .sublist(ch.from - 1, ch.to)
          .reduce((a, b) => a < b ? a : b);
      expect(
        floor,
        greaterThanOrEqualTo(previous),
        reason: 'الفصل ${ch.world}.${ch.chapter} يبدأ أسهل من الفصل قبله',
      );
      previous = floor;
    }
  });

  test('أول مرحلة في كل عالم لا تقلّ عن آخر مرحلة في العالم السابق', () {
    var previousLast = -1;
    var next = 1;
    for (var w = 1; w <= BalanceConfig.worldCount; w++) {
      final size = BalanceConfig.worldStageCount(w);
      final first = scores[next - 1];
      expect(
        first,
        greaterThanOrEqualTo(previousLast),
        reason: 'العالم $w يبدأ أسهل مما انتهى إليه العالم ${w - 1}',
      );
      previousLast = scores[next + size - 2];
      next += size;
    }
  });

  test('المرحلة الأولى أسهل مراحل اللعبة، والأخيرة أصعبها', () {
    expect(scores.first, scores.reduce((a, b) => a < b ? a : b));
    expect(scores.last, scores.reduce((a, b) => a > b ? a : b));
    // ومقدّمة معقولة فعلا: كلمة واحدة على عجلة ثلاثية
    expect((levels.first['letters'] as List).length, 3);
    expect((levels.first['words'] as List).length, 1);
  });

  test('حقل difficulty رتيب — لا مرحلة تحمل رقما أعلى من أصعب منها', () {
    for (var i = 1; i < levels.length; i++) {
      expect(
        levels[i]['difficulty'] as int,
        greaterThanOrEqualTo(levels[i - 1]['difficulty'] as int),
        reason: 'المرحلة ${i + 1}',
      );
    }
    expect(levels.first['difficulty'], 1);
  });
}
