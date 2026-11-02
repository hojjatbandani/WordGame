import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('طابور فارغ افتراضيا', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final outbox = Outbox(prefs, 'test_feature');
    expect(outbox.pending, isEmpty);
  });

  test('enqueue يضيف عنصرا يظهر في pending فورا', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final outbox = Outbox(prefs, 'test_feature');

    await outbox.enqueue(OutboxEntry(
      id: 'a1',
      payload: {'x': 1},
      queuedAt: DateTime(2026, 1, 1),
    ));

    expect(outbox.pending, hasLength(1));
    expect(outbox.pending.first.id, 'a1');
    expect(outbox.pending.first.payload, {'x': 1});
  });

  test('remove يزيل العنصر المطلوب فقط، يبقي الباقي', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final outbox = Outbox(prefs, 'test_feature');

    await outbox.enqueue(
        OutboxEntry(id: 'a1', payload: const {}, queuedAt: DateTime(2026, 1, 1)));
    await outbox.enqueue(
        OutboxEntry(id: 'a2', payload: const {}, queuedAt: DateTime(2026, 1, 2)));
    await outbox.remove('a1');

    expect(outbox.pending, hasLength(1));
    expect(outbox.pending.first.id, 'a2');
  });

  test('يبقى محفوظا عبر إعادة تشغيل (مثيل Outbox جديد على نفس التخزين)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await Outbox(prefs, 'test_feature').enqueue(
        OutboxEntry(id: 'a1', payload: const {'k': 'v'}, queuedAt: DateTime(2026, 1, 1)));

    final reloaded = Outbox(prefs, 'test_feature');
    expect(reloaded.pending, hasLength(1));
    expect(reloaded.pending.first.payload, {'k': 'v'});
  });

  test('enqueue بنفس id يستبدل العنصر القديم بدل تكديسه بجانبه', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final outbox = Outbox(prefs, 'test_feature');

    await outbox.enqueue(
        OutboxEntry(id: 'a1', payload: const {'score': 10}, queuedAt: DateTime(2026, 1, 1)));
    await outbox.enqueue(
        OutboxEntry(id: 'a1', payload: const {'score': 95}, queuedAt: DateTime(2026, 1, 2)));

    expect(outbox.pending, hasLength(1));
    expect(outbox.pending.first.payload['score'], 95);
  });

  test('مساحات أسماء مختلفة (namespace) لا تتداخل', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await Outbox(prefs, 'feature_a')
        .enqueue(OutboxEntry(id: 'a1', payload: const {}, queuedAt: DateTime(2026, 1, 1)));

    final featureB = Outbox(prefs, 'feature_b');
    expect(featureB.pending, isEmpty);
  });
}
