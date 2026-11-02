import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

enum ChallengeCategory { proverb, gulfProverb, verse, word }

extension ChallengeCategoryInfo on ChallengeCategory {
  String get titleAr => switch (this) {
        ChallengeCategory.proverb => 'أكمل المثل',
        ChallengeCategory.gulfProverb => 'أمثال خليجية',
        ChallengeCategory.verse => 'أكمل البيت',
        ChallengeCategory.word => 'خمّن الكلمة',
      };

  String get subtitleAr => switch (this) {
        ChallengeCategory.proverb => 'أكمل المثل بالكلمة الناقصة',
        ChallengeCategory.gulfProverb => 'أمثال أهل الخليج',
        ChallengeCategory.verse => 'أكمل بيت الشعر',
        ChallengeCategory.word => 'خمّن الكلمة الأصيلة من معناها',
      };

  /// عناوين إنجليزية للقائمة فقط — التحدّي نفسه يبقى بالعربية دوما
  String get titleEn => switch (this) {
        ChallengeCategory.proverb => 'Complete the Proverb',
        ChallengeCategory.gulfProverb => 'Gulf Proverbs',
        ChallengeCategory.verse => 'Complete the Verse',
        ChallengeCategory.word => 'Guess the Word',
      };

  String get subtitleEn => switch (this) {
        ChallengeCategory.proverb => 'Complete the proverb with the missing word',
        ChallengeCategory.gulfProverb => 'Proverbs from the Gulf',
        ChallengeCategory.verse => 'Complete the line of verse',
        ChallengeCategory.word => 'Guess the Arabic word from its meaning',
      };

  /// أيقونة الفئة ثلاثية الأبعاد
  String get iconAsset => switch (this) {
        ChallengeCategory.proverb => 'assets/icons/challenge_proverb.png',
        ChallengeCategory.gulfProverb => 'assets/icons/challenge_gulf.png',
        ChallengeCategory.verse => 'assets/icons/challenge_verse.png',
        ChallengeCategory.word => 'assets/icons/challenge_word.png',
      };

  Color get accent => switch (this) {
        ChallengeCategory.proverb => const Color(0xFF34E89E),
        ChallengeCategory.verse => const Color(0xFF9B59B6),
        ChallengeCategory.word => const Color(0xFFF4C430),
        ChallengeCategory.gulfProverb => const Color(0xFFFF9F1C),
      };
}

/// عنصر تحدٍّ واحد: يعرض سياقًا بفراغ، واللاعب يكوّن [answer] من عجلة الحروف
class ChallengeItem {
  final ChallengeCategory category;

  /// سياق إضافي: للبيت = الشطر الآخر، للكلمة = المعنى، للمثل = ''
  final String clue;

  /// نص قبل الفراغ (للمثل/البيت)، فارغ للكلمة
  final String before;

  /// نص بعد الفراغ (للمثل/البيت)، فارغ للكلمة
  final String after;

  /// الحروف المجرّدة من التشكيل التي يكوّنها اللاعب
  final String answer;

  /// النص الكامل المعروض عند النجاح (قد يحوي سطرين للبيت)
  final String reveal;

  final String meaning;
  final String attribution;

  const ChallengeItem({
    required this.category,
    required this.clue,
    required this.before,
    required this.after,
    required this.answer,
    required this.reveal,
    required this.meaning,
    required this.attribution,
  });

  factory ChallengeItem.fromJson(
    Map<String, dynamic> json,
    ChallengeCategory category,
  ) =>
      ChallengeItem(
        category: category,
        clue: json['clue'] as String? ?? '',
        before: json['before'] as String? ?? '',
        after: json['after'] as String? ?? '',
        answer: json['answer'] as String,
        reveal: json['reveal'] as String,
        meaning: json['meaning'] as String? ?? '',
        attribution: json['poet'] as String? ?? '',
      );

  /// حروف عجلة اللعب: حروف الجواب + حروف مموّهة كثيرة تزيد صعوبة الاكتشاف،
  /// مخلوطة عشوائيا (بحد أقصى 10 حروف في العجلة).
  List<String> buildWheelLetters([Random? rng]) {
    final random = rng ?? Random();
    const pool = [
      'ا', 'ل', 'م', 'ن', 'ر', 'ب', 'ت', 'س', 'د', 'ح',
      'ك', 'ع', 'ف', 'ه', 'و', 'ي', 'ق', 'ج', 'ص', 'ط',
      'ش', 'ذ', 'ز', 'خ', 'ث', 'غ', 'ض', 'ظ',
    ];
    final letters = answer.split('');
    // حروف مموّهة أكثر: تجعل تمييز الجواب أصعب وتدفع لشراء التلميحات
    final extra = switch (letters.length) {
      <= 3 => 5,
      <= 5 => 4,
      _ => 3,
    };
    final target = min(10, letters.length + extra);
    final result = List<String>.of(letters);
    final available = pool.where((c) => !letters.contains(c)).toList()
      ..shuffle(random);
    var i = 0;
    while (result.length < target && i < available.length) {
      result.add(available[i]);
      i++;
    }
    result.shuffle(random);
    return result;
  }

  int get reward => switch (category) {
        ChallengeCategory.verse => 30,
        ChallengeCategory.word => 20,
        _ => 25,
      };
}

class ChallengeSet {
  final List<ChallengeItem> proverbs;
  final List<ChallengeItem> gulfProverbs;
  final List<ChallengeItem> verses;
  final List<ChallengeItem> words;

  const ChallengeSet({
    required this.proverbs,
    required this.gulfProverbs,
    required this.verses,
    required this.words,
  });

  List<ChallengeItem> byCategory(ChallengeCategory c) => switch (c) {
        ChallengeCategory.proverb => proverbs,
        ChallengeCategory.gulfProverb => gulfProverbs,
        ChallengeCategory.verse => verses,
        ChallengeCategory.word => words,
      };

  factory ChallengeSet.fromJson(Map<String, dynamic> json) {
    List<ChallengeItem> parse(String key, ChallengeCategory cat) =>
        (json[key] as List)
            .map((e) =>
                ChallengeItem.fromJson(e as Map<String, dynamic>, cat))
            .toList();
    return ChallengeSet(
      proverbs: parse('proverbs', ChallengeCategory.proverb),
      gulfProverbs: parse('gulf_proverbs', ChallengeCategory.gulfProverb),
      verses: parse('verses', ChallengeCategory.verse),
      words: parse('words', ChallengeCategory.word),
    );
  }
}

class ChallengeRepository {
  ChallengeSet? _cache;

  Future<ChallengeSet> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/challenges.json');
    _cache = ChallengeSet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return _cache!;
  }
}
