// عدّاء المحاكاة الاقتصادية الكاملة: 1000 لاعب × 30 يوما.
//
// تشغيل:  flutter test test/simulation/simulation_test.dart
// (أمر اختبار Dart الواحد لحزمة Flutter — `dart test` المجرّد لا يعمل
// في حزمة تعتمد flutter_test.)
//
// يكتب التقرير إلى test/simulation/report.md دوما — نجحت التأكيدات أم
// فشلت — كي يكون التقرير متاحا للتشخيص عند الفشل لا عند النجاح فقط.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'report_builder.dart';
import 'sim_engine.dart';

void main() {
  test(
      'محاكاة 1000 لاعب × 30 يوما: التقرير والتأكيدات الخمسة (اختبار قبول)',
      () {
    final result = runSimulation();
    final outcomes = evaluateAssertions(result);

    final report = buildReport(result, outcomes);
    File('test/simulation/report.md').writeAsStringSync(report);

    // مطبوعات تشخيصية مختصرة — التفصيل الكامل في report.md
    for (final o in outcomes) {
      // ignore: avoid_print
      print('${o.passed ? 'PASS' : 'FAIL'}  ${o.name} — ${o.detail}');
    }

    for (final o in outcomes) {
      expect(o.passed, isTrue,
          reason: '${o.name} — ${o.detail} (التفصيل في test/simulation/report.md)');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
