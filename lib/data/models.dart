import 'world_models.dart';

class WordEntry {
  final String word;
  final String definition;

  const WordEntry({required this.word, required this.definition});

  factory WordEntry.fromJson(Map<String, dynamic> json) => WordEntry(
        word: json['word'] as String,
        definition: json['definition'] as String,
      );
}

class GameLevel {
  final int id;
  final List<String> letters;
  final List<WordEntry> words;
  final List<String> bonusWords;
  final int difficulty;

  const GameLevel({
    required this.id,
    required this.letters,
    required this.words,
    required this.bonusWords,
    required this.difficulty,
  });

  factory GameLevel.fromJson(Map<String, dynamic> json) => GameLevel(
        id: json['id'] as int,
        letters: (json['letters'] as List).cast<String>(),
        words: (json['words'] as List)
            .map((w) => WordEntry.fromJson(w as Map<String, dynamic>))
            .toList(),
        bonusWords: (json['bonus_words'] as List).cast<String>(),
        difficulty: json['difficulty'] as int,
      );

  /// مكافأة إتمام المرحلة حسب الصعوبة (10–30 نقطة)
  int get completionReward => 5 + difficulty * 5;

  /// العالم الذي تنتمي إليه المرحلة
  int get worldId => worldForLevel(id).id;

  /// ترتيب المرحلة داخل عالمها (يبدأ من 1)
  int get indexInWorld => id - worldForLevel(id).firstLevelId + 1;
}
