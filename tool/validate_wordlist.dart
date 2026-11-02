// فاحص القاموس: يُشغَّل قبل توليد المراحل كي لا يدخل خطأ صامت إلى
// اللعبة. القاموس ملف نصّي يكتبه إنسان، وأخطاؤه لا تظهر عند التوليد
// بل بعده: كلمة بحرف همزة لا تتكوّن من عجلة أبدا فتصير وزنا ميتا،
// وتعريف يذكر الكلمة نفسها يحرق اللغز، وكلمة مكرّرة تُسقِط سطرا كاملا
// بلا إشعار (الخريطة تكتب فوق المفتاح).
//
// التشغيل:  dart run tool/validate_wordlist.dart [مسار]
// يخرج برمز 1 عند أي خطأ كي يوقف أي سلسلة بناء.
//
// المنطق في [validateWordlist] لا في main كي يستدعيه اختبار الوحدة
// أيضا — بنفس نمط tool/rebalance_levels.dart.

import 'dart:io';

/// الحروف المسموحة: 28 حرفا عربيا + التاء المربوطة.
///
/// الهمزات (أ إ آ ئ ؤ ء) والألف المقصورة (ى) مستبعدة عمدا لا سهوا:
/// عجلة الحروف تعرض حرفا واحدا لكل شكل، فلو دخلت «أ» صارت في العجلة
/// خانة ثانية بجانب «ا» يستحيل على اللاعب تمييز أيّهما يخصّ أيّ كلمة.
/// القاعدة إذن: تُكتب الكلمات بالصور المجرّدة، وما لا يُكتب بها أصلا
/// (ماء، سماء، رئيس) لا يدخل القاموس.
const allowedLetters = 'ابةتثجحخدذرزسشصضطظعغفقكلمنهوي';

/// حدود الطول: أقصر من 3 لا يصنع لغزا، وأطول من 8 لا تسعه العجلة
/// (maxTargetWordLength في generate_levels.dart). الكلمات خارج المدى
/// ليست خطأ لغويا لكنها وزن ميت: تُقرأ ولا تُستعمل أبدا.
const minLength = 3;
const maxLength = 8;

/// التعريف يُعرض في بطاقة صغيرة تحت الكلمة — الأطول منه يُقصّ
const maxDefinitionLength = 60;

class WordlistReport {
  final List<String> errors;
  final List<String> warnings;

  /// كم كلمة لكل طول
  final Map<int, int> byLength;

  /// الحروف المسموحة التي لا تظهر في أي كلمة
  final List<String> unusedLetters;

  const WordlistReport({
    required this.errors,
    required this.warnings,
    required this.byLength,
    required this.unusedLetters,
  });

  int get count => byLength.values.fold(0, (a, b) => a + b);
  bool get isValid => errors.isEmpty;
}

WordlistReport validateWordlist(String path) {
  final errors = <String>[];
  final warnings = <String>[];
  final seen = <String, int>{};
  final byLength = <int, int>{};
  final letterUse = <String>{};

  final lines = File(path).readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final lineNo = i + 1;
    final raw = lines[i];
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    if (raw != trimmed) {
      warnings.add('$lineNo: مسافات زائدة في طرفي السطر');
    }

    final parts = trimmed.split('|');
    if (parts.length != 2) {
      errors.add(
        '$lineNo: يجب أن يحوي السطر فاصلا واحدا «|» — وجدنا '
        '${parts.length - 1}\n        $trimmed',
      );
      continue;
    }

    final word = parts[0].trim();
    final definition = parts[1].trim();

    if (word.isEmpty) {
      errors.add('$lineNo: كلمة فارغة');
      continue;
    }

    // حروف غير مسموحة — أكثر الأخطاء شيوعا وأصعبها اكتشافا بالعين
    final bad = <String>{};
    for (final c in word.split('')) {
      if (!allowedLetters.contains(c)) {
        bad.add(c);
      } else {
        letterUse.add(c);
      }
    }
    if (bad.isNotEmpty) {
      errors.add(
        '$lineNo: «$word» فيه حرف غير مسموح: ${bad.join(' ')}'
        '${_suggest(word, bad)}',
      );
    }

    if (word.length < minLength || word.length > maxLength) {
      final where = word.length < minLength ? 'أقصر' : 'أطول';
      errors.add(
        '$lineNo: «$word» طوله ${word.length} — $where من المدى '
        '$minLength-$maxLength',
      );
    }

    final previous = seen[word];
    if (previous != null) {
      errors.add('$lineNo: «$word» مكرّرة — وردت في السطر $previous');
    } else {
      seen[word] = lineNo;
    }

    if (definition.isEmpty) {
      errors.add('$lineNo: «$word» بلا تعريف');
    } else {
      // التعريف الذي يذكر الكلمة يحرق اللغز قبل أن يبدأ
      if (definition.contains(word)) {
        errors.add('$lineNo: تعريف «$word» يذكر الكلمة نفسها فيحرق اللغز');
      }
      if (definition.length > maxDefinitionLength) {
        warnings.add(
          '$lineNo: تعريف «$word» طوله ${definition.length} '
          '(الحد $maxDefinitionLength) — سيُقصّ في البطاقة',
        );
      }
    }

    byLength[word.length] = (byLength[word.length] ?? 0) + 1;
  }

  // حرف بلا كلمة واحدة يعني أن اللاعب لن يراه في عجلة أبدا
  final unused = [
    for (final c in allowedLetters.split(''))
      if (!letterUse.contains(c)) c,
  ];
  if (unused.isNotEmpty) {
    warnings.add('حروف لا تظهر في أي كلمة: ${unused.join(' ')}');
  }

  return WordlistReport(
    errors: errors,
    warnings: warnings,
    byLength: byLength,
    unusedLetters: unused,
  );
}

void main(List<String> args) {
  final path = args.isNotEmpty ? args.first : 'tool/wordlist.txt';
  if (!File(path).existsSync()) {
    stderr.writeln('لا يوجد ملف: $path');
    exit(1);
  }

  final report = validateWordlist(path);

  stdout.writeln('القاموس: $path');
  stdout.writeln('الكلمات: ${report.count}');
  stdout.writeln('التوزيع بالطول:');
  for (final len in (report.byLength.keys.toList()..sort())) {
    stdout.writeln('  $len أحرف: ${report.byLength[len]}');
  }

  if (report.warnings.isNotEmpty) {
    stdout.writeln('\nتنبيهات (${report.warnings.length}):');
    for (final w in report.warnings) {
      stdout.writeln('  ⚠ $w');
    }
  }

  if (!report.isValid) {
    stderr.writeln('\nأخطاء (${report.errors.length}):');
    for (final e in report.errors) {
      stderr.writeln('  ✗ $e');
    }
    exit(1);
  }

  stdout.writeln('\n✓ لا أخطاء');
}

/// يقترح الصورة المجرّدة للكلمة عند وجود همزة أو ألف مقصورة، فالخطأ
/// شبه دائما هذا ولا فائدة من ترك المحرّر يخمّن الإصلاح
String _suggest(String word, Set<String> bad) {
  const normalize = {
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ٱ': 'ا',
    'ى': 'ي',
    'ئ': 'ي',
    'ؤ': 'و',
  };
  if (!bad.every(normalize.containsKey)) return '';
  var fixed = word;
  normalize.forEach((from, to) => fixed = fixed.replaceAll(from, to));
  return ' — اكتبها «$fixed»';
}
