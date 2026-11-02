// القاموس (tool/wordlist.txt) هو المادة الخام لكل مراحل اللعبة، وهو
// ملف نصّي يُحرَّر باليد. خطأ فيه لا ينفجر عند التحرير بل بعد التوليد
// بمرحلة: كلمة بهمزة تصير وزنا ميتا لا تتكوّن من عجلة أبدا، وتعريف
// يذكر الكلمة نفسها يحرق اللغز على الشاشة، وكلمة مكرّرة تُسقِط سطرا
// كاملا بصمت. هذه الاختبارات تجعل ذلك خطأ بناء لا مفاجأة على الجهاز.
//
// وتقفل كذلك ما كسب القاموس الموسَّع: 452 كلمة كانت تعني أن «اسم»
// تظهر هدفا في 62 مرحلة من 500 (معدل تكرار 7.2). القيود أدناه تمنع
// العودة إلى ذلك الفقر.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/validate_wordlist.dart';

/// حدّ أدنى لحجم القاموس. ليس رقما تعسّفيا: بأقل منه تجوع الأطوال
/// الوسطى (5-8) فيعجز المولد عن ملء حصص النطاقات، ويحذّر صراحة
/// «نقص N مرحلة عن الهدف — وسّع القاموس».
const _minWords = 2800;

/// أقصى عدد مراحل تظهر فيها كلمة واحدة هدفا. سقف المولد اللين 6،
/// وهذا الرقم يترك له هامشا للحالات التي لا تجد فيها العجلة بديلا.
const _maxLevelsPerWord = 20;

List<Map<String, dynamic>> _levels() =>
    (jsonDecode(File('assets/data/levels.json').readAsStringSync())['levels']
            as List)
        .cast<Map<String, dynamic>>();

void main() {
  group('القاموس صالح', () {
    late WordlistReport report;

    setUpAll(() => report = validateWordlist('tool/wordlist.txt'));

    test('لا أخطاء صيغة ولا حروف ممنوعة ولا تكرار ولا تعريف حارق', () {
      expect(
        report.errors,
        isEmpty,
        reason: 'شغّل: dart run tool/validate_wordlist.dart\n'
            '${report.errors.take(10).join('\n')}',
      );
    });

    test('حجمه يكفي لملء 500 مرحلة بلا فقر', () {
      expect(report.count, greaterThanOrEqualTo(_minWords));
    });

    test('كل طول من 3 إلى 8 ممثَّل تمثيلا معتبرا', () {
      // الأطوال الوسطى هي التي جاعت سابقا (53 كلمة بطول 5، و14 بطول 7)
      // فخرج ذيل اللعبة كله من الكلمات الثلاث نفسها
      const floors = {3: 400, 4: 400, 5: 300, 6: 150, 7: 80, 8: 30};
      floors.forEach((len, floor) {
        expect(
          report.byLength[len] ?? 0,
          greaterThanOrEqualTo(floor),
          reason: 'الطول $len فقير — المولد سيجوع في نطاقه',
        );
      });
    });

    test('كل حرف عربي مسموح يظهر في كلمة واحدة على الأقل', () {
      // «ض» لم تكن في أي كلمة قط — أشهر حرف في العربية غائب عن اللعبة
      expect(report.unusedLetters, isEmpty);
    });
  });

  group('المراحل المولَّدة توزّع القاموس ولا تحتكره', () {
    late Map<String, int> use;

    setUpAll(() {
      use = <String, int>{};
      for (final level in _levels()) {
        for (final w in (level['words'] as List)) {
          final word = (w as Map)['word'] as String;
          use[word] = (use[word] ?? 0) + 1;
        }
      }
    });

    test('لا كلمة تحتكر عشرات المراحل', () {
      final worst = use.entries.reduce((a, b) => a.value >= b.value ? a : b);
      expect(
        worst.value,
        lessThanOrEqualTo(_maxLevelsPerWord),
        reason: '«${worst.key}» تظهر في ${worst.value} مرحلة',
      );
    });

    test('معدل التكرار قريب من الواحد لا من السبعة', () {
      final total = use.values.fold<int>(0, (a, b) => a + b);
      expect(total / use.length, lessThan(3.0));
    });

    test('المراحل تستعمل أكثر من ألف كلمة مختلفة', () {
      expect(use.length, greaterThan(1000));
    });

    test('كل كلمة هدف موجودة في القاموس بتعريف غير فارغ', () {
      final defined = {
        for (final line in File('tool/wordlist.txt').readAsLinesSync())
          if (line.trim().isNotEmpty && !line.trim().startsWith('#'))
            line.trim().split('|')[0].trim(),
      };
      // المراحل اليدوية (1-20) قد تحمل كلمات خاصة بها، فتُفحص المولَّدة
      for (final level in _levels().where((l) => (l['id'] as int) > 20)) {
        for (final w in (level['words'] as List)) {
          final word = (w as Map)['word'] as String;
          expect(
            defined,
            contains(word),
            reason: 'المرحلة ${level['id']}: «$word» ليست في القاموس',
          );
          expect((w)['definition'], isNotEmpty, reason: 'تعريف «$word» فارغ');
        }
      }
    });
  });
}
