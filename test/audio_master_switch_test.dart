// الإعدادات لا تعرض إلا مفتاح صوت واحد، لكنّ التخزين كان يحمل مفتاحين:
// `music_enabled` (الذي تكتبه الواجهة) و`sfx_enabled` الذي لم يستدعِ
// أحدٌ كاتبَه قط، فبقي `true` أبدا. فمن أطفأ المفتاح سكتت الموسيقى
// وبقيت كل المؤثّرات القصيرة في اللعب تعمل بلا سبيل لإسكاتها.
//
// الآن المفتاح واحد فعلا: [AudioService.soundEnabled] يحكم الموسيقى
// والمؤثّرات وأصوات الشخصيات معا.

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/audio_service.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AudioService> _audio([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return AudioService(ProgressStore(await SharedPreferences.getInstance()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // لا إضافة صوت في بيئة الاختبار — نفحص البوّابة لا التشغيل
  setUpAll(() => AudioService.disabled = true);

  test('الصوت مفعّل على تثبيت جديد', () async {
    final audio = await _audio();
    addTearDown(audio.dispose);
    expect(audio.soundEnabled, isTrue);
  });

  test('إطفاء المفتاح يكتب المفتاحين معا في التخزين', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final audio = AudioService(ProgressStore(prefs));
    addTearDown(audio.dispose);

    await audio.setSoundEnabled(false);
    expect(audio.soundEnabled, isFalse);
    expect(prefs.getBool('music_enabled'), isFalse);
    expect(
      prefs.getBool('sfx_enabled'),
      isFalse,
      reason: 'وإلا بقيت المؤثّرات مفعّلة في التخزين رغم إطفاء الصوت',
    );

    await audio.setSoundEnabled(true);
    expect(prefs.getBool('music_enabled'), isTrue);
    expect(prefs.getBool('sfx_enabled'), isTrue);
  });

  test('لاعب أطفأ الموسيقى قبل التوحيد لا يسمع المؤثّرات بعده', () async {
    // الحالة على جهاز اللاعب فعلا: الموسيقى مطفأة والمؤثّرات مفعّلة
    final audio = await _audio({'music_enabled': false, 'sfx_enabled': true});
    addTearDown(audio.dispose);

    expect(
      audio.soundEnabled,
      isFalse,
      reason: 'المفتاح المخزَّن الوحيد الذي كتبته الواجهة هو music_enabled',
    );
  });

  test(
    'كل استدعاءات التشغيل تمرّ من نفس البوّابة ولا ترمي وهي مطفأة',
    () async {
      final audio = await _audio({'music_enabled': false});
      addTearDown(audio.dispose);

      // لا شيء يُشغَّل، ولا استثناء يخرج إلى اللعب — الصوت كماليات
      for (final sfx in Sfx.values) {
        await audio.play(sfx);
      }
      await audio.playCharacter('friendly_grandma');
      await audio.startMusic();
    },
  );
}
