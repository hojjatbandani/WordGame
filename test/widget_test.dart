import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/models.dart';

void main() {
  test('GameLevel parses from JSON and computes reward', () {
    final level = GameLevel.fromJson({
      'id': 3,
      'letters': ['ب', 'ح', 'ر'],
      'words': [
        {'word': 'بحر', 'definition': 'الماء الواسع المالح'},
      ],
      'bonus_words': ['برح'],
      'difficulty': 2,
    });
    expect(level.letters.length, 3);
    expect(level.words.single.word, 'بحر');
    expect(level.completionReward, 15);
  });
}
