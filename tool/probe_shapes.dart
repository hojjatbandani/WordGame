// فحص جدوى: كم عجلة مختلفة تستطيع تحقيق كل شكل مطلوب في
// chapter_shapes.dart، قبل أن نبني عليه المراحل.
//
// السبب: بعض الأشكال قد تكون مستحيلة لا صعبة. «كلمتان ثماني من عجلة
// ثمانية حروف» يعني كلمتين متقلّبتين (anagram) بثمانية أحرف — قد لا
// توجد في القاموس ولا في العربية كلها. الأفضل معرفة ذلك الآن لا بعد
// ساعة من التوليد.
//
// التشغيل:  dart run tool/probe_shapes.dart

import 'dart:io';

import 'chapter_shapes.dart';
import 'wheel_index.dart';

void main() {
  final wordlist = loadWordlist('tool/wordlist.txt');
  stdout.writeln('القاموس: ${wordlist.length} كلمة');

  // كل شكل مطلوب مرة واحدة، مع كم مرحلة تطلبه
  final demand = <String, ({WordShape shape, int stages})>{};
  for (final chapter in chapterShapes) {
    final stageCount = chapter.worldId <= 4 ? 12 : 13;
    for (final shape in shapesForChapter(chapter, stageCount)) {
      final label = shapeLabel(shape);
      final previous = demand[label];
      demand[label] = (
        shape: shape,
        stages: (previous?.stages ?? 0) + 1,
      );
    }
  }
  // بدائل مرشّحة لأشكال الختام، تُقاس معها كي يكون الاقتراح على بيّنة
  // لا على تخمين. تُميَّز بعلامة «؟» في التقرير ولا تُحسب في النواقص.
  const alternatives = <WordShape>[
    {4: 1, 6: 1, 7: 1, 8: 1},
    {4: 1, 5: 1, 7: 1, 8: 1},
    {5: 1, 6: 1, 7: 1, 8: 1},
    {4: 1, 5: 1, 6: 1, 8: 1},
    {4: 2, 6: 1, 8: 1},
    {4: 1, 6: 2, 8: 1},
    {5: 1, 6: 2, 8: 1},
    {4: 1, 7: 1, 8: 1},
    {5: 1, 7: 1, 8: 1},
    {6: 1, 7: 1, 8: 1},
    {4: 1, 5: 1, 6: 1, 7: 2},
    {4: 1, 5: 1, 6: 2, 7: 1},
  ];
  for (final shape in alternatives) {
    demand.putIfAbsent(shapeLabel(shape), () => (shape: shape, stages: 0));
  }

  stdout.writeln('أشكال مطلوبة مختلفة: ${demand.length}');
  stdout.writeln('تعداد العجلات… (المرحلة الثالثة بطيئة)');

  final matches = {for (final label in demand.keys) label: 0};
  var wheelCount = 0;
  forEachWheel(wordlist, (wheel) {
    wheelCount++;
    for (final entry in demand.entries) {
      if (wheel.fits(entry.value.shape)) matches[entry.key] = matches[entry.key]! + 1;
    }
  });
  stdout.writeln('العجلات المختلفة: $wheelCount\n');

  final rows = [
    for (final entry in demand.entries)
      (
        label: entry.key,
        stages: entry.value.stages,
        wheels: matches[entry.key]!,
      ),
  ]..sort((a, b) => a.wheels.compareTo(b.wheels));

  stdout.writeln('الشكل                 مراحل  عجلات متاحة');
  stdout.writeln('─' * 46);
  for (final r in rows) {
    final flag = r.wheels == 0
        ? '  ✗ مستحيل'
        : r.wheels < r.stages
        ? '  ⚠ أقل من المطلوب'
        : '';
    stdout.writeln(
      '${r.label.padRight(22)}${r.stages.toString().padLeft(5)}'
      '${r.wheels.toString().padLeft(12)}$flag',
    );
  }

  final impossible = rows.where((r) => r.wheels == 0).toList();
  final tight = rows.where((r) => r.wheels > 0 && r.wheels < r.stages).toList();
  stdout.writeln('\nأشكال مستحيلة: ${impossible.length}');
  stdout.writeln('أشكال لا تكفي عجلاتها عدد مراحلها: ${tight.length}');
  final short = rows.fold<int>(
    0,
    (a, r) => a + (r.wheels < r.stages ? r.stages - r.wheels : 0),
  );
  stdout.writeln('مراحل بلا عجلة خاصة بها: $short من 500');
}
