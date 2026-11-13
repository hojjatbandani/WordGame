// أعلام رحلة اللاعب الأولى ومحفوظات جلسة المرحلة: تُكتب وتُقرأ، وما
// يخصّ «التثبيت» (لا اللعبة) يبقى بعد «البدء من جديد».

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProgressStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return ProgressStore(await SharedPreferences.getInstance());
}

void main() {
  test('journey accessors round-trip', () async {
    final s = await _store();
    expect(s.firstOpenAtMs, isNull);
    await s.ensureFirstOpenAt(1000);
    await s.ensureFirstOpenAt(5000); // لا يُستبدل
    expect(s.firstOpenAtMs, 1000);

    expect(s.firstStageStarted, isFalse);
    await s.setFirstStageStarted(true);
    expect(s.firstStageStarted, isTrue);

    expect(s.onboardingCompleted, isFalse);
    await s.setOnboardingCompleted(true);
    expect(s.onboardingCompleted, isTrue);

    expect(s.onboardingStartedAtMs, isNull);
    await s.setOnboardingStartedAtMs(77);
    expect(s.onboardingStartedAtMs, 77);

    expect(await s.bumpStageAttempt(3), 1);
    expect(await s.bumpStageAttempt(3), 2);
    expect(await s.bumpStageAttempt(4), 1);

    await s.setActiveStageSessionJson('{"a":1}');
    expect(s.activeStageSessionJson, '{"a":1}');
    await s.setActiveStageSessionJson(null);
    expect(s.activeStageSessionJson, isNull);

    await s.setStageResumeJson('{"3":{}}');
    expect(s.stageResumeJson, '{"3":{}}');

    expect(s.pendingRatingPrompt, isFalse);
    await s.setPendingRatingPrompt(true);
    expect(s.pendingRatingPrompt, isTrue);

    expect(s.bonusWordExplained, isFalse);
    await s.setBonusWordExplained(true);
    expect(s.bonusWordExplained, isTrue);
  });

  test('reset keeps install facts and clears game progress', () async {
    final s = await _store();
    await s.ensureFirstOpenAt(1000);
    await s.setFirstStageStarted(true);
    await s.setOnboardingCompleted(true);
    await s.setStageResumeJson('{}');
    await s.setActiveStageSessionJson('{}');
    await s.bumpStageAttempt(1);

    await s.resetProgress();

    expect(s.firstOpenAtMs, 1000);
    expect(s.firstStageStarted, isTrue);
    expect(s.onboardingCompleted, isFalse);
    expect(s.stageResumeJson, isNull);
    expect(s.activeStageSessionJson, isNull);
    expect(await s.bumpStageAttempt(1), 1);
  });
}
