// تعداد عجلات الحروف المرشّحة، مشتركا بين المولد وأداة فحص الجدوى.
//
// «العجلة» هنا مجموعةُ حروفٍ متعدِّدة (multiset) تُعرض على اللاعب،
// و«ما تكوّنه» كل كلمات القاموس التي حروفها جزء منها. التعداد يمرّ
// بثلاث مراحل تتوسّع تدريجيا: حروف كلمة أساس، ثم بحرف شائع إضافي، ثم
// بحرفين — وهذا ما يعطي عجلات تكوّن كلمات أكثر من كلمة الأساس وحدها.
//
// البثّ عبر [forEachWheel] لا إرجاع قائمة: المرحلة الثالثة وحدها تجرّب
// مئات الآلاف من العجلات، وحفظ قائمة كلماتها كلها في الذاكرة يتجاوز
// عدة غيغابايت. المستهلك يحتفظ بما يحتاجه فقط.

import 'dart:io';
import 'dart:math';

import 'chapter_shapes.dart';

const minWordLength = 3;
const maxTargetWordLength = 8;
const maxWheelLetters = 8;

/// حروف عربية شائعة تُضاف إلى كلمة الأساس لتوسيع العجلة (نمط Wordscapes)
const commonExtras = [
  'ا', 'و', 'ي', 'م', 'ن', 'ر', 'ل', 'ب', 'ت', 'س', //
  'د', 'ح', 'ك', 'ع', 'ف', 'ه', 'ق', 'ج', 'ص', 'ط', //
];

/// الحروف المسموحة — نفس قائمة tool/validate_wordlist.dart
const allowedLetters = 'ابةتثجحخدذرزسشصضطظعغفقكلمنهوي';

class Wheel {
  final List<String> letters;

  /// كلمات القاموس التي تتكوّن من هذه الحروف، مبوّبة بالطول
  final Map<int, List<String>> byLength;

  const Wheel(this.letters, this.byLength);

  Iterable<String> get formable => byLength.values.expand((w) => w);

  /// هل في العجلة ما يكفي من كل طول لتحقيق [shape]؟
  bool satisfies(WordShape shape) =>
      shape.entries.every((e) => (byLength[e.key]?.length ?? 0) >= e.value);

  /// [satisfies] مع شرط الحجم: عجلة أكبر من أطول كلمة فيها بحرفين
  /// فأكثر تعني حروفا ميتة لا تدخل أي كلمة — يراها اللاعب حشوا.
  bool fits(WordShape shape) {
    final maxLen = shapeMaxLength(shape);
    if (letters.length < maxLen || letters.length > maxLen + 1) return false;
    return satisfies(shape);
  }
}

Map<String, String> loadWordlist(String path) {
  final map = <String, String>{};
  for (final line in File(path).readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final parts = trimmed.split('|');
    if (parts.length != 2) continue;
    map[parts[0].trim()] = parts[1].trim();
  }
  return map;
}

/// قناع بتّي لحروف كلمة — بت لكل حرف مختلف.
///
/// كلمة لا تتكوّن من عجلة إن حوت حرفا ليس فيها، وهذا يُفحص بعملية واحدة
/// `(قناع الكلمة & ~قناع العجلة) != 0`. بقاموس 3000 كلمة يُستدعى الفحص
/// مئات ملايين المرات، فالقناع يرفض الأغلبية الساحقة قبل عدّ التكرارات.
int letterMask(Iterable<String> letters) {
  var mask = 0;
  for (final c in letters) {
    final i = allowedLetters.indexOf(c);
    if (i >= 0) mask |= 1 << i;
  }
  return mask;
}

String multisetKey(List<String> letters) => (List.of(letters)..sort()).join();

bool isSubMultiset(List<String> small, List<String> big) {
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

/// يبثّ كل عجلة مرشّحة مرة واحدة (بلا تكرار مجموعة الحروف).
///
/// [deep] يشغّل المرحلة الثالثة (حرفان إضافيان) — أثقل المراحل بفارق
/// كبير، ولا تلزم إلا حين تعجز الأولى والثانية عن تغطية شكل مطلوب.
void forEachWheel(
  Map<String, String> wordlist,
  void Function(Wheel) visit, {
  bool deep = true,
}) {
  final words = [
    for (final w in wordlist.keys)
      if (w.length >= minWordLength && w.length <= maxTargetWordLength)
        (word: w, mask: letterMask(w.split('')), letters: w.split('')),
  ];
  // الأطول أولا: عجلاتها أغنى، فتُملأ الأشكال الصعبة مبكرا
  words.sort((a, b) {
    final byLen = b.word.length.compareTo(a.word.length);
    return byLen != 0 ? byLen : a.word.compareTo(b.word);
  });

  final seen = <String>{};

  void tryWheel(List<String> wheel) {
    if (wheel.length < minWordLength || wheel.length > maxWheelLetters) return;
    final key = multisetKey(wheel);
    if (!seen.add(key)) return;

    final wheelMask = letterMask(wheel);
    final byLength = <int, List<String>>{};
    for (final w in words) {
      if (w.mask & ~wheelMask != 0) continue;
      if (w.letters.length > wheel.length) continue;
      if (!isSubMultiset(w.letters, wheel)) continue;
      byLength.putIfAbsent(w.word.length, () => []).add(w.word);
    }
    if (byLength.isEmpty) return;
    visit(Wheel(wheel, byLength));
  }

  // 1) حروف كلمة الأساس مباشرة
  for (final w in words) {
    tryWheel(List.of(w.letters)..sort());
  }

  // 2) كلمة الأساس + حرف شائع
  for (final w in words) {
    if (w.letters.length >= maxWheelLetters) continue;
    for (final extra in commonExtras) {
      tryWheel([...w.letters, extra]..sort());
    }
  }

  if (!deep) return;

  // 3) كلمة الأساس + حرفان
  for (final w in words) {
    if (w.letters.length >= maxWheelLetters - 1) continue;
    for (var i = 0; i < commonExtras.length; i++) {
      for (var j = i; j < commonExtras.length; j++) {
        tryWheel([...w.letters, commonExtras[i], commonExtras[j]]..sort());
      }
    }
  }
}

/// أقصى عدد مراحل تظهر فيها الكلمة الواحدة هدفا — سقف لين: إن لم تجد
/// المرحلة بديلا تحته أخذت الأقل استعمالا ولو تجاوزه.
const maxTargetReuse = 6;

/// يختار من [wheel] كلماتِ [shape] مفضّلا الأقلّ استعمالا حتى الآن،
/// ويحدّث [use]. الترتيب الثانوي أبجدي كي يبقى الخرج قابلا للتكرار.
List<String>? pickTargets(
  Wheel wheel,
  WordShape shape,
  Map<String, int> use,
) {
  final chosen = <String>[];
  for (final len in (shape.keys.toList()..sort())) {
    final pool = List.of(wheel.byLength[len] ?? const <String>[])
      ..sort((a, b) {
        final byUse = (use[a] ?? 0).compareTo(use[b] ?? 0);
        return byUse != 0 ? byUse : a.compareTo(b);
      });
    if (pool.length < shape[len]!) return null;
    final under = pool.where((w) => (use[w] ?? 0) < maxTargetReuse);
    final over = pool.where((w) => (use[w] ?? 0) >= maxTargetReuse);
    chosen.addAll([...under, ...over].take(shape[len]!));
  }
  return chosen;
}

/// صعوبة معروضة (1..10) مشتقّة من الشكل وحده: أطول كلمة أولا ثم العدد
int difficultyForShape(WordShape shape) {
  final maxLen = shapeMaxLength(shape);
  final count = shapeWordCount(shape);
  return min(10, max(1, (maxLen - 2) * 2 + (count > 3 ? 1 : 0)));
}
