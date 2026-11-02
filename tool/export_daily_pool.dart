// يصدّر عيّنة موزّعة بانتظام من assets/data/levels.json كملف SQL يُلصق
// داخل supabase/schema.sql (جدول daily_puzzle_pool) — مصدر بيانات التحدي
// اليومي، منفصل عن حملة اللاعب المحلية.
//
// التشغيل:  dart run tool/export_daily_pool.dart > tool/daily_pool_seed.sql
import 'dart:convert';
import 'dart:io';

const poolSize = 80;

void main() {
  final raw = File('assets/data/levels.json').readAsStringSync();
  final levels = (jsonDecode(raw) as Map)['levels'] as List;
  // نتخطى المراحل الأولى السهلة جدا (اليدوية) ونأخذ عيّنة موزّعة على
  // طول منحنى الصعوبة الباقي
  final pool = levels.skip(20).toList();
  final step = pool.length / poolSize;
  final selected = [
    for (var i = 0; i < poolSize; i++) pool[(i * step).floor()],
  ];

  final buffer = StringBuffer();
  buffer.writeln('insert into public.daily_puzzle_pool (puzzle_data) values');
  for (var i = 0; i < selected.length; i++) {
    final l = selected[i] as Map<String, dynamic>;
    final puzzle = {
      'letters': l['letters'],
      'words': l['words'],
      'bonus_words': l['bonus_words'],
    };
    final json = jsonEncode(puzzle).replaceAll("'", "''");
    final comma = i == selected.length - 1 ? ';' : ',';
    buffer.writeln("  ('$json')$comma");
  }
  stdout.write(buffer.toString());
}
