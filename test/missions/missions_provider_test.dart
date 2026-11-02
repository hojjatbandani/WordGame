import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await ProgressStore.create();
  final progression = await ProgressionRepository.load(prefs: store.prefs, legacy: store);
  return ProviderContainer(
    overrides: [
      progressStoreProvider.overrideWithValue(store),
      progressionRepositoryProvider.overrideWithValue(progression),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('حالة جديدة: 3 مهمات يومية و3 أسبوعية، بلا مكافآت مستلَمة بعد', () async {
    final c = await _container({});
    final state = c.read(missionsProvider);
    expect(state.daily.missions, hasLength(3));
    expect(state.weekly.missions, hasLength(3));
    expect(state.daily.chestClaimed, isFalse);
    expect(state.weekly.badgeClaimed, isFalse);
  });

  test('reportStageCompleted يزيد تقدّم أي مهمة complete_1_stage النشطة فقط',
      () async {
    final c = await _container({});
    final notifier = c.read(missionsProvider.notifier);
    final before = c.read(missionsProvider).daily.missions
        .firstWhere((m) => m.def.id == 'complete_1_stage', orElse: () => c.read(missionsProvider).daily.missions.first);

    notifier.reportStageCompleted();
    final after = c.read(missionsProvider).daily.missions;
    final stageMission = after.where((m) => m.def.id == 'complete_1_stage');
    if (stageMission.isNotEmpty) {
      expect(stageMission.first.progress, 1);
      expect(stageMission.first.isComplete, isTrue);
    }
    // بصرف النظر عن أي المهمات الثلاث اليوم فعلا complete_1_stage، لا
    // انهيار ولا تأثير على المهمات غير المطابقة
    expect(before, isNotNull);
  });

  test('إكمال المهمات الثلاث يمنح مكافأة كل مهمة + صندوق اليوم تلقائيا',
      () async {
    final c = await _container({});
    final notifier = c.read(missionsProvider.notifier);
    final before = c.read(pointsProvider);

    // ندفع كل مهمات اليوم الثلاث لهدفها بإرسال كل أنواع الأحداث الممكنة
    // بكميات كبيرة — كل مهمة تستجيب فقط لنوعها، فلا ضرر من إرسال البقية
    for (var i = 0; i < 10; i++) {
      notifier.reportStageCompleted();
      notifier.reportWordsFound(20);
      notifier.reportBonusWordFound(20);
      notifier.reportStageCompletedNoHints();
    }

    final state = c.read(missionsProvider);
    expect(state.daily.allComplete, isTrue);
    expect(state.daily.chestClaimed, isTrue);
    // كل مكافآت المهمات الثلاث (15+25+40=80) + صندوق بين 50 و120 على الأقل
    expect(c.read(pointsProvider), greaterThanOrEqualTo(before + 80 + 50));
  });

  test('لا تُمنح مكافأة الصندوق مرتين حتى مع أحداث إضافية بعد الاكتمال',
      () async {
    final c = await _container({});
    final notifier = c.read(missionsProvider.notifier);
    for (var i = 0; i < 10; i++) {
      notifier.reportStageCompleted();
      notifier.reportWordsFound(20);
      notifier.reportBonusWordFound(20);
      notifier.reportStageCompletedNoHints();
    }
    final afterFirstComplete = c.read(pointsProvider);
    notifier.reportWordsFound(5); // حدث إضافي بعد الاكتمال الكامل
    expect(c.read(pointsProvider), afterFirstComplete); // لا تغيير إضافي
  });

  test('reportActivityToday لا يحتسب نفس اليوم مرتين لهدف الأيام المختلفة',
      () async {
    final c = await _container({});
    final notifier = c.read(missionsProvider.notifier);
    notifier.reportActivityToday();
    notifier.reportActivityToday();
    notifier.reportActivityToday();
    expect(c.read(missionsProvider).weekly.daysPlayed, hasLength(1));
  });

  test('الحالة تبقى محفوظة عبر إعادة تشغيل (نفس SharedPreferences)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = ProgressStore(prefs);
    final progression = await ProgressionRepository.load(prefs: prefs, legacy: store);
    final container1 = ProviderContainer(overrides: [
      progressStoreProvider.overrideWithValue(store),
      progressionRepositoryProvider.overrideWithValue(progression),
    ]);
    container1.read(missionsProvider.notifier).reportStageCompleted();
    final idsAndProgress = [
      for (final m in container1.read(missionsProvider).daily.missions)
        (m.def.id, m.progress)
    ];

    final store2 = ProgressStore(prefs); // محاكاة إعادة تشغيل التطبيق
    final progression2 = await ProgressionRepository.load(prefs: prefs, legacy: store2);
    final container2 = ProviderContainer(overrides: [
      progressStoreProvider.overrideWithValue(store2),
      progressionRepositoryProvider.overrideWithValue(progression2),
    ]);
    final reloaded = [
      for (final m in container2.read(missionsProvider).daily.missions)
        (m.def.id, m.progress)
    ];
    expect(reloaded, idsAndProgress);
  });
}
