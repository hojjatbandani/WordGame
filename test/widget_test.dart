import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/models.dart';

GameLevel _level({required int id, required int difficulty}) =>
    GameLevel.fromJson({
      'id': id,
      'letters': ['ب', 'ح', 'ر'],
      'words': [
        {'word': 'بحر', 'definition': 'الماء الواسع المالح'},
      ],
      'bonus_words': ['برح'],
      'difficulty': difficulty,
    });

void main() {
  test('GameLevel parses from JSON', () {
    final level = _level(id: 3, difficulty: 2);
    expect(level.letters.length, 3);
    expect(level.words.single.word, 'بحر');
  });

  test('early levels (<=20) are more generous than later ones', () {
    // نفس الصعوبة: المرحلة المبكرة تعطي +10 لتشجيع المبتدئ
    expect(_level(id: 3, difficulty: 2).completionReward, 25); // 15 + 10
    expect(_level(id: 30, difficulty: 2).completionReward, 15); // القاعدة فقط
  });
}
