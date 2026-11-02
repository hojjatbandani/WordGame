// مولد المراحل: يقرأ tool/wordlist.txt ويولد مراحل حتى الوصول إلى
// [targetTotal] مرحلة، ثم يدمجها مع المراحل اليدوية (1-20).
//
// قاعدة السلّم (الشرط المحوري): كل مرحلة تبدأ من كلمات ثلاثية ثم
// تتدرج طولا — 3 ثم 4 ثم 5 — بلا فجوات في الوسط، وقد تُختم بكلمة
// «تاج» واحدة أطول بدرجة أو درجتين على الأكثر (7 أو 8 أحرف كحد أقصى).
// لا مرحلة بلا كلمات ثلاثية إطلاقا، مهما تأخرت — التدرج داخل المرحلة
// نفسها هو ما يجعل الطويلة قابلة للتفكيك، لا مجرد حشو حروف.
//
// كان المولد السابق يسقط في ذيل مريض: آخر 17 مرحلة كلها الكلمات الثلاث
// نفسها (استكشاف/اكتشافات/استكشافات) بعجلات 10 حروف تختلف بحرف حشو
// واحد، بلا أي كلمة قصيرة وبلا كلمات إضافية. سببان: فقر القاموس في
// الأطوال الوسطى (عولج بإضافات wordlist)، وغياب أي قيد يفرض وجود
// الثلاثيات أو يمنع تكرار نفس مجموعة الأهداف بحروف حشو مختلفة.
//
// استراتيجية التوليد:
//   1) عجلات من حروف كلمة أساس مباشرة
//   2) عجلات «موسعة»: حروف كلمة أساس + حرف شائع إضافي (نمط Wordscapes)
//   3) عجلات بحرفين إضافيين إن لزم
//
// التشغيل:  dart run tool/generate_levels.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const handcraftedCount = 20;
const targetTotal = 500;
const maxTargetWords = 8;
const minWordLength = 3;

/// أقصى طول كلمة هدف — لا 9 ولا 10 مهما وُجدت في القاموس. الكلمات
/// الأطول تبقى في القاموس لكنها لا تُختار هدفا ولا تتكوّن أصلا من
/// عجلة مقصوصة على 8.
const maxTargetWordLength = 8;
const maxWheelLetters = 8;

/// أقصى قفزة بين قمة السلّم المتصل وكلمة التاج. للتيجان الكبيرة
/// (7-8) تُقبل قفزة 2 — سلّم 3-4-5-6 مختوم بـ8 — لأن القاموس نادرا ما
/// يوفر وسيطا بطول 7 من نفس الحروف، والقفزة عند الختام تُقرأ «كلمة
/// الزعيم». أما في وسط اللعبة (تاج 6 فما دون) فقفزة درجة واحدة فقط:
/// سلّم 3-4 مختوم بـ6 شعوره «قفز فوقي» لا «تحدّ أخير».
int maxCrownHopFor(int crownLen) => crownLen >= 7 ? 2 : 1;

/// حصة كل طول من كلمات الأهداف — تنازلية مع الطول: الثلاثيات أكثر
/// الحضور ثم تقل الحصص حتى كلمة تاج واحدة للأطوال 7-8
const lengthQuota = {3: 3, 4: 3, 5: 2, 6: 2, 7: 1, 8: 1};

/// أقصى عدد مراحل تظهر فيها الكلمة الواحدة هدفا.
///
/// سقف **لين** لا صلب: إن لم تجد المرحلة في عجلتها بديلا تحته أخذت
/// الأقل استعمالا ولو تجاوزه — درجة طول بلا هدف تكسر سلّم المرحلة،
/// وذلك أسوأ من كلمة تكرّرت مرة زائدة. راجع [rebalanceTargets].
const maxTargetReuse = 6;

const commonExtras = [
  'ا',
  'و',
  'ي',
  'م',
  'ن',
  'ر',
  'ل',
  'ب',
  'ت',
  'س',
  'د',
  'ح',
  'ك',
  'ع',
  'ف',
  'ه',
  'ق',
  'ج',
  'ص',
  'ط',
];

/// قناع البتات لحروف كلمة: بت لكل حرف مختلف من [allowedLetters].
///
/// كلمة لا تتكوّن من عجلة إن حوت حرفا ليس فيها، وهذا يُفحص بعملية
/// واحدة `(قناع الكلمة & ~قناع العجلة) != 0` بدل عدّ التكرارات حرفا
/// حرفا. بقاموس 3000 كلمة صار الفحص الكامل يُستدعى مئات ملايين المرات
/// (كل عجلة × كل كلمة) فتجاوز التوليد الساعة؛ القناع يرفض الأغلبية
/// الساحقة قبل بلوغها، ثم يتولّى [_isSubMultiset] الباقي وحده.
const _allowedLetters = 'ابةتثجحخدذرزسشصضطظعغفقكلمنهوي';

int _letterMask(Iterable<String> letters) {
  var mask = 0;
  for (final c in letters) {
    final i = _allowedLetters.indexOf(c);
    if (i >= 0) mask |= 1 << i;
  }
  return mask;
}

void main() {
  final wordlist = _loadWordlist('tool/wordlist.txt');
  final levelsFile = File('assets/data/levels.json');
  final existing = (jsonDecode(levelsFile.readAsStringSync())['levels'] as List)
      .cast<Map<String, dynamic>>();
  final handcrafted = existing
      .where((l) => (l['id'] as int) <= handcraftedCount)
      .toList();

  final usedLetterSets = <String>{
    for (final l in handcrafted)
      _multisetKey((l['letters'] as List).cast<String>()),
  };

  // منع «الاستنساخ بحرف حشو»: عجلتان بنفس كلمات الأهداف تماما هما
  // المرحلة نفسها مرتين مهما اختلفت الحروف — أصل عطل الذيل القديم
  final usedTargetSignatures = <String>{};

  final generated = <Map<String, dynamic>>[];
  final sortedWords = wordlist.keys.toList()
    ..sort((a, b) {
      final byLen = b.length.compareTo(a.length);
      return byLen != 0 ? byLen : a.compareTo(b);
    });

  // يُحسب مرة واحدة لكل كلمة بدل مرة لكل (كلمة، عجلة)
  final wordMasks = {
    for (final w in wordlist.keys)
      if (w.length >= minWordLength && w.length <= maxTargetWordLength)
        w: (_letterMask(w.split('')), w.split('')),
  };

  void tryWheel(List<String> wheel, {required int minWords}) {
    if (wheel.length < 3 || wheel.length > maxWheelLetters) return;
    final key = _multisetKey(wheel);
    if (usedLetterSets.contains(key)) return;

    final wheelMask = _letterMask(wheel);
    final formable = <String>[];
    for (final entry in wordMasks.entries) {
      final (mask, letters) = entry.value;
      if (mask & ~wheelMask != 0) continue;
      if (letters.length > wheel.length) continue;
      if (_isSubMultiset(letters, wheel)) formable.add(entry.key);
    }
    if (formable.length < minWords) return;

    final byLength = <int, List<String>>{};
    for (final w in formable) {
      byLength.putIfAbsent(w.length, () => []).add(w);
    }

    // لا مرحلة بلا ثلاثيات — القاعدة الأولى
    if (!byLength.containsKey(3)) return;

    // أطول كلمة يجب أن تستهلك أغلب حروف العجلة كي لا تبدو حشوا
    final crownLen = byLength.keys.reduce(max);
    if (crownLen < wheel.length - 1) return;

    // السلّم المتصل من 3 صعودا حتى أول طول مفقود
    var core = 3;
    while (byLength.containsKey(core + 1)) {
      core++;
    }

    // التاج فوق السلّم بدرجة أو درجتين كحد أقصى — أبعد من ذلك يعني
    // قفزة من القصيرة إلى الطويلة بلا درجات وسطى، وهي المرفوضة
    if (crownLen > core && crownLen - core > maxCrownHopFor(crownLen)) {
      return;
    }

    // اختيار الأهداف: من كل درجة في السلّم حصتها، ثم التاج إن كان فوقه
    final targets = <String>[];
    for (var len = 3; len <= min(core, crownLen); len++) {
      final pool = List.of(byLength[len]!)..sort();
      targets.addAll(pool.take(lengthQuota[len] ?? 1));
    }
    if (crownLen > core) {
      final pool = List.of(byLength[crownLen]!)..sort();
      targets.add(pool.first);
    }

    // القص إلى الحد الأقصى يبدأ من الدرجات الوسطى الأغنى، ولا يمسّ
    // أبدا آخر ممثل لدرجة ما (فجوة في الأهداف تكسر السلّم المعروض)
    // ولا كلمة التاج
    while (targets.length > maxTargetWords) {
      String? victim;
      var richest = 1;
      for (var len = 4; len <= core; len++) {
        final count = targets.where((w) => w.length == len).length;
        if (count > richest) {
          richest = count;
          victim = targets.lastWhere((w) => w.length == len);
        }
      }
      if (victim == null) {
        // كل الدرجات عند ممثل واحد — نقص الثلاثيات إلى اثنتين كحد أدنى
        final threes = targets.where((w) => w.length == 3).length;
        if (threes > 2) {
          victim = targets.lastWhere((w) => w.length == 3);
        } else {
          break;
        }
      }
      targets.remove(victim);
    }
    if (targets.length < minWords) return;

    final signature = (List.of(targets)..sort()).join('،');
    if (usedTargetSignatures.contains(signature)) return;

    usedLetterSets.add(key);
    usedTargetSignatures.add(signature);
    final bonus = formable.where((w) => !targets.contains(w)).toList();

    generated.add({
      'letters': wheel,
      'words': [
        for (final w in targets) {'word': w, 'definition': wordlist[w]},
      ],
      'bonus_words': bonus,
      'difficulty': _difficulty(crownLen, targets.length),
      // مخزونان مؤقتان تستهلكهما rebalanceTargets بعد اختيار المراحل
      // ثم يُحذفان قبل الكتابة — راجع _stripScratch
      '_formable': formable,
      '_byLength': byLength,
    });
  }

  // المرور 1: عجلات الكلمات المباشرة
  for (final base in sortedWords) {
    tryWheel(base.split(''), minWords: 2);
  }

  // المرور 2: كلمة + حرف إضافي شائع — بلا توقف مبكر: التوقف عند بلوغ
  // العدد كان يعني أن القواعد الطويلة (تُجرَّب أولا) تستهلك الحصة كلها
  // فيتضخم نطاق تيجانها ويجوع الوسط. نولّد الكل ثم نوزّع بحصص النطاقات.
  for (final base in sortedWords) {
    if (base.length >= maxWheelLetters) continue;
    for (final extra in commonExtras) {
      tryWheel([...base.split(''), extra]..sort(), minWords: 3);
    }
  }

  int crownOf(Map<String, dynamic> l) => (l['words'] as List)
      .map((w) => ((w as Map)['word'] as String).length)
      .reduce(max);

  // حصة كل نطاق تاج من المراحل الـ480 المولّدة — منحنى اللعبة نفسه:
  // بداية قصيرة سخية، وسط عريض من 5-6، وختام من 7 يتوّج بستّ مراحل 8.
  // نطاق ناقص عن حصته يمرّر الفائض لجاره الأطول.
  const bandQuota = {3: 30, 4: 90, 5: 130, 6: 130, 7: 94, 8: 6};

  bool everyBandSatisfied() {
    final counts = <int, int>{};
    for (final l in generated) {
      counts[crownOf(l)] = (counts[crownOf(l)] ?? 0) + 1;
    }
    return bandQuota.entries.every((e) => (counts[e.key] ?? 0) >= e.value);
  }

  // المرور 3: كلمة + حرفان إضافيان — مخرج الطوارئ لقاموس فقير، لا خطوة
  // عادية. عجلاته 190 ضعف عجلات المرور الأول، وبقاموس 3000 كلمة تكون
  // النطاقات كلها مشبعة قبله فيصير عشرات الدقائق من العمل لمرشّحات
  // تُرمى كلها عند التوزيع بالحصص.
  if (!everyBandSatisfied()) {
    for (final base in sortedWords) {
      if (base.length >= maxWheelLetters - 1) continue;
      for (var i = 0; i < commonExtras.length; i++) {
        for (var j = i + 1; j < commonExtras.length; j++) {
          tryWheel(
            [...base.split(''), commonExtras[i], commonExtras[j]]..sort(),
            minWords: 4,
          );
        }
      }
      if (everyBandSatisfied()) break;
    }
  }
  String crownWordOf(Map<String, dynamic> l) {
    final words = (l['words'] as List).cast<Map>();
    return words.reduce(
          (a, b) => (a['word'] as String).length >= (b['word'] as String).length
              ? a
              : b,
        )['word']
        as String;
  }

  final byBand = <int, List<Map<String, dynamic>>>{};
  for (final l in generated) {
    byBand.putIfAbsent(crownOf(l), () => []).add(l);
  }

  final selected = <Map<String, dynamic>>[];
  var carry = 0;
  for (final band in [3, 4, 5, 6, 7, 8]) {
    final want = (bandQuota[band] ?? 0) + carry;
    final pool = byBand[band] ?? const [];
    // مداورة على كلمات التاج: أول جولة تأخذ مرحلة واحدة من كل تاج
    // مختلف قبل أن يتكرر أي تاج — أقصى تنويع ممكن داخل النطاق
    final byCrown = <String, List<Map<String, dynamic>>>{};
    for (final l in pool) {
      byCrown.putIfAbsent(crownWordOf(l), () => []).add(l);
    }
    final crownKeys = byCrown.keys.toList()..sort();
    final picked = <Map<String, dynamic>>[];
    var round = 0;
    while (picked.length < want) {
      var any = false;
      for (final key in crownKeys) {
        final list = byCrown[key]!;
        if (round < list.length) {
          picked.add(list[round]);
          any = true;
          if (picked.length >= want) break;
        }
      }
      if (!any) break;
      round++;
    }
    carry = want - picked.length;
    // داخل النطاق: من الأصغر عجلة والأقل كلمات إلى الأكبر
    picked.sort((a, b) {
      final la = (a['letters'] as List).length;
      final lb = (b['letters'] as List).length;
      if (la != lb) return la.compareTo(lb);
      return (a['words'] as List).length.compareTo((b['words'] as List).length);
    });
    selected.addAll(picked);
  }
  if (carry > 0) {
    stderr.writeln('تحذير: نقص $carry مرحلة عن الهدف — وسّع القاموس');
  }

  // الآن فقط — بعد أن عُرفت المراحل الـ480 الباقية فعلا — تُوزَّع
  // الكلمات عليها. التوزيع قبل هذه اللحظة يعمل على آلاف المرشحات
  // التي يُرمى أغلبها، فيُنفق السقف على مراحل لن تدخل اللعبة.
  final reuse = rebalanceTargets(selected, wordlist);

  for (var i = 0; i < selected.length; i++) {
    selected[i]['id'] = handcraftedCount + 1 + i;
  }

  for (final level in selected) {
    _stripScratch(level);
  }

  final merged = {
    'levels': [...handcrafted, ...selected],
  };
  levelsFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(merged),
  );

  stdout.writeln('اليدوية: ${handcrafted.length}');
  stdout.writeln('المرشحة: ${generated.length} — المختارة: ${selected.length}');
  stdout.writeln('المجموع: ${handcrafted.length + selected.length}');
  final byCrown = <int, int>{};
  var withBonus = 0;
  for (final l in selected) {
    byCrown[crownOf(l)] = (byCrown[crownOf(l)] ?? 0) + 1;
    if ((l['bonus_words'] as List).isNotEmpty) withBonus++;
  }
  for (final e
      in (byCrown.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) {
    stdout.writeln('  أطول كلمة ${e.key} حروف: ${e.value} مرحلة');
  }
  stdout.writeln('مراحل فيها كلمات إضافية: $withBonus من ${selected.length}');

  final counts = reuse.values.toList()..sort();
  final total = counts.fold<int>(0, (a, b) => a + b);
  stdout.writeln(
    'كلمات هدف فريدة: ${reuse.length} — معدل التكرار: '
    '${(total / reuse.length).toStringAsFixed(1)} — الأقصى: ${counts.last} — '
    'فوق السقف ($maxTargetReuse): ${counts.where((c) => c > maxTargetReuse).length}',
  );
}

/// يعيد اختيار أهداف المراحل المختارة كي تتوزّع الكلمات عليها بدل أن
/// تحتكرها المتصدّرة أبجديا، ويعيد جدول «كم مرة استُعملت كل كلمة».
///
/// الاختيار داخل [main] يأخذ `pool.take(quota)` بعد ترتيب أبجدي، فتفوز
/// في كل عجلة الكلمةُ التي تسبق حروفها غيرها: «اسم» كانت هدفا في 62
/// مرحلة من 500 بينما مئات الكلمات لم تظهر قط. الترتيب هنا بعدد
/// الاستعمالات أولا وبالأبجدية ثانيا — والثانية ضرورية: بلا فاصل
/// حاسم يصير الخرج رهن ترتيب الخريطة، فلا يعود التوليد قابلا للتكرار.
///
/// ما لا تمسّه الدالة عمدا: **عدد** الأهداف في كل درجة طول. طول التاج
/// وعدد الكلمات والصعوبة ونطاق المرحلة كلها احتُسبت قبلها على هذا
/// العدد، وتغييره هنا يبطلها جميعا. الذي يتغيّر هو أي كلمة تشغل كل
/// خانة، لا كم خانة هناك.
Map<String, int> rebalanceTargets(
  List<Map<String, dynamic>> levels,
  Map<String, String> wordlist,
) {
  final use = <String, int>{};

  for (final level in levels) {
    final pools = level['_byLength'] as Map<int, List<String>>;
    final formable = (level['_formable'] as List).cast<String>();

    // بصمة المرحلة الحالية: كم هدفا لكل درجة طول
    final need = <int, int>{};
    for (final w in (level['words'] as List)) {
      final len = ((w as Map)['word'] as String).length;
      need[len] = (need[len] ?? 0) + 1;
    }

    final chosen = <String>[];
    for (final len in (need.keys.toList()..sort())) {
      final pool = List.of(pools[len] ?? const <String>[])
        ..sort((a, b) {
          final byUse = (use[a] ?? 0).compareTo(use[b] ?? 0);
          return byUse != 0 ? byUse : a.compareTo(b);
        });
      // المرشحون تحت السقف أولا؛ من تجاوزه يبقى احتياطا لا يُلجأ إليه
      // إلا إذا لم تكف العجلة، فلا تخرج المرحلة ناقصة درجة
      final under = pool.where((w) => (use[w] ?? 0) < maxTargetReuse);
      final over = pool.where((w) => (use[w] ?? 0) >= maxTargetReuse);
      chosen.addAll([...under, ...over].take(need[len]!));
    }

    for (final w in chosen) {
      use[w] = (use[w] ?? 0) + 1;
    }

    final targets = chosen.toSet();
    level['words'] = [
      for (final w in chosen) {'word': w, 'definition': wordlist[w]},
    ];
    level['bonus_words'] = formable
        .where((w) => !targets.contains(w))
        .toList();
  }

  return use;
}

/// يحذف المفاتيح المؤقتة التي لا تخصّ اللعبة قبل كتابة الملف
void _stripScratch(Map<String, dynamic> level) {
  level.remove('_formable');
  level.remove('_byLength');
}

Map<String, String> _loadWordlist(String path) {
  final map = <String, String>{};
  for (final line in File(path).readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final parts = trimmed.split('|');
    if (parts.length != 2) {
      stderr.writeln('سطر غير صالح: $trimmed');
      continue;
    }
    map[parts[0].trim()] = parts[1].trim();
  }
  return map;
}

String _multisetKey(List<String> letters) => (List.of(letters)..sort()).join();

bool _isSubMultiset(List<String> small, List<String> big) {
  final counts = <String, int>{};
  for (final c in big) {
    counts[c] = (counts[c] ?? 0) + 1;
  }
  for (final c in small) {
    final left = (counts[c] ?? 0) - 1;
    if (left < 0) return false;
    counts[c] = left;
  }
  return true;
}

/// الصعوبة من طول أطول كلمة هدف لا من حجم العجلة: التاج هو ما يواجهه
/// اللاعب فعلا، وحرف الحشو لا يجعل المرحلة أصعب
int _difficulty(int crownLen, int wordCount) {
  switch (crownLen) {
    case 3:
      return wordCount <= 2 ? 1 : 2;
    case 4:
      return wordCount <= 3 ? 3 : 4;
    case 5:
      return wordCount <= 4 ? 5 : 6;
    case 6:
      return wordCount <= 5 ? 6 : 7;
    case 7:
      return wordCount <= 6 ? 7 : 8;
    default:
      return wordCount <= 6 ? 8 : 9;
  }
}
