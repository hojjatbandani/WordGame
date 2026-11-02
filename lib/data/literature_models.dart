import 'dart:convert';

import 'package:flutter/services.dart';

/// مثَل أو حكمة: نص + شرح معناه
class Proverb {
  final String text;
  final String meaning;

  const Proverb({required this.text, required this.meaning});

  factory Proverb.fromJson(Map<String, dynamic> json) => Proverb(
        text: json['text'] as String,
        meaning: json['meaning'] as String,
      );
}

/// بيت شعري: شطران + قائل + شرح المعنى
class Verse {
  final String first;
  final String second;
  final String poet;
  final String meaning;

  const Verse({
    required this.first,
    required this.second,
    required this.poet,
    required this.meaning,
  });

  factory Verse.fromJson(Map<String, dynamic> json) => Verse(
        first: json['first'] as String,
        second: json['second'] as String,
        poet: json['poet'] as String,
        meaning: json['meaning'] as String,
      );
}

/// كلمة عربية أصيلة + معناها
class AuthenticWord {
  final String word;
  final String meaning;

  const AuthenticWord({required this.word, required this.meaning});

  factory AuthenticWord.fromJson(Map<String, dynamic> json) => AuthenticWord(
        word: json['word'] as String,
        meaning: json['meaning'] as String,
      );
}

/// مكتبة المحتوى الأدبي المحمّلة من assets/data/literature.json
class LiteratureLibrary {
  final List<Proverb> proverbs;
  final List<Proverb> gulfProverbs;
  final List<Verse> verses;
  final List<AuthenticWord> words;

  const LiteratureLibrary({
    required this.proverbs,
    required this.gulfProverbs,
    required this.verses,
    required this.words,
  });

  factory LiteratureLibrary.fromJson(Map<String, dynamic> json) =>
      LiteratureLibrary(
        proverbs: (json['proverbs'] as List)
            .map((e) => Proverb.fromJson(e as Map<String, dynamic>))
            .toList(),
        gulfProverbs: (json['gulf_proverbs'] as List)
            .map((e) => Proverb.fromJson(e as Map<String, dynamic>))
            .toList(),
        verses: (json['verses'] as List)
            .map((e) => Verse.fromJson(e as Map<String, dynamic>))
            .toList(),
        words: (json['words'] as List)
            .map((e) => AuthenticWord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class LiteratureRepository {
  LiteratureLibrary? _cache;

  Future<LiteratureLibrary> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/literature.json');
    _cache = LiteratureLibrary.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return _cache!;
  }
}
