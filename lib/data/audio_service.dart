import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import 'progress_store.dart';

/// كل أصوات اللعبة — مولّدة رقميا من الصفر عبر tool/generate_audio.dart
/// فهي أصلية بالكامل وبلا أي حقوق طرف ثالث.
enum Sfx {
  correct('sfx_correct.wav'),
  wrong('sfx_wrong.wav'),
  bonus('sfx_bonus.wav'),
  levelComplete('sfx_level_complete.wav'),
  achievement('sfx_achievement.wav'),
  hint('sfx_hint.wav'),
  tap('sfx_tap.wav'),
  spin('sfx_spin.wav');

  final String file;
  const Sfx(this.file);
}

/// مشغّل الصوت المركزي: حلقة موسيقى + مجمّع مشغّلات للمؤثّرات.
///
/// - الموسيقى تُدار بمشغّل واحد يدور بلا نهاية وتُوقَف عند تخفّي التطبيق.
/// - المؤثّرات تمرّ على مجمّع صغير من المشغّلات كي لا يقطع صوتٌ صوتا
///   قبله (لمس الحروف يتكرّر أسرع من مدة الملف).
/// - أصوات الشخصيات ملفات `voice_<id>.wav` ولها مشغّل مستقل حتى لا
///   تُقاطعها المؤثّرات القصيرة.
/// - كل استدعاء يفشل بصمت: الصوت كماليات، وأي عطل فيه (منع التشغيل
///   التلقائي في المتصفح مثلا) يجب ألا يمسّ اللعب أبدا.
class AudioService with WidgetsBindingObserver {
  final ProgressStore store;

  /// يُرفع في بيئات بلا إضافة صوت (اختبارات، مولّد اللقطات) فلا يُنشأ أي
  /// مشغّل أصلا. إنشاء AudioPlayer يسجّل مستمعا على قناة أحداث، وغياب
  /// الإضافة يرمي MissingPluginException من داخل الإضافة نفسها — خارج
  /// أي try/catch عندنا — فيُفشل الاختبار رغم أن الصوت كماليات.
  static bool disabled = false;

  AudioService(this.store) {
    WidgetsBinding.instance.addObserver(this);
  }

  // إنشاء كسول: لا نلمس الإضافة إلا عند أول تشغيل فعلي
  AudioPlayer? _musicPlayer;
  AudioPlayer? _voicePlayer;
  List<AudioPlayer>? _sfxPlayers;
  var _sfxIndex = 0;

  AudioPlayer? get _music =>
      disabled ? null : (_musicPlayer ??= AudioPlayer(playerId: 'music'));

  AudioPlayer? get _voice =>
      disabled ? null : (_voicePlayer ??= AudioPlayer(playerId: 'voice'));

  List<AudioPlayer> get _sfxPool {
    if (disabled) return const [];
    return _sfxPlayers ??= [
      for (var i = 0; i < 3; i++) AudioPlayer(playerId: 'sfx_$i'),
    ];
  }

  /// مفتاح الصوت الوحيد في اللعبة: يحكم الموسيقى والمؤثّرات وأصوات
  /// الشخصيات معا.
  ///
  /// كانا مفتاحين منفصلين في التخزين، لكن الإعدادات لا تعرض إلا واحدا
  /// («الصوت») ولم يستدعِ أحد `setSfxEnabled` قط — فبقي `sfx_enabled`
  /// على `true` أبدا. النتيجة أن إطفاء المفتاح يُسكت الموسيقى ويترك كل
  /// صوت قصير في اللعب يعمل، بلا أي سبيل في الواجهة لإسكاته.
  ///
  /// المفتاح المخزَّن هو `music_enabled` لأنه الوحيد الذي كتبته الواجهة
  /// فعلا، فيبقى اختيار كل لاعب حالي كما تركه.
  bool get soundEnabled => store.musicEnabled;

  bool _musicStarted = false;

  /// يبدأ حلقة الموسيقى إن كانت مفعّلة. آمن للاستدعاء المتكرّر.
  ///
  /// في الويب قد يمنع المتصفح التشغيل قبل أول لمسة — عندها نتذكّر أنها
  /// لم تبدأ ونعيد المحاولة في أول مؤثّر صوتي (وهو دائما بعد لمسة).
  Future<void> startMusic() async {
    if (disabled || !soundEnabled || _musicStarted) return;
    try {
      final music = _music!;
      await music.setReleaseMode(ReleaseMode.loop);
      await music.setVolume(0.45); // خلفية لا تنافس المؤثّرات
      await music.play(AssetSource('audio/music_theme.mp3'));
      _musicStarted = true;
    } catch (e) {
      debugPrint('Audio: تعذّر بدء الموسيقى — $e');
    }
  }

  Future<void> stopMusic() async {
    _musicStarted = false;
    try {
      await _musicPlayer?.stop();
    } catch (_) {}
  }

  /// يطفئ ويشعل صوت اللعبة كله: الموسيقى تتوقّف فورا، والمؤثّرات وأصوات
  /// الشخصيات تتوقّف عن الصدور من [play] و[playCharacter].
  ///
  /// يكتب المفتاحين معا كي يبقى `sfx_enabled` متّسقا مع ما يسمعه اللاعب،
  /// فلو فُصل المفتاحان في الإعدادات لاحقا لم يجد لاعبٌ قيمة مخزّنة
  /// تناقض ما اختاره.
  Future<void> setSoundEnabled(bool enabled) async {
    await store.setMusicEnabled(enabled);
    await store.setSfxEnabled(enabled);
    if (enabled) {
      await startMusic();
    } else {
      await stopMusic();
      // المؤثّر القصير قد يكون منتصف التشغيل لحظة الإطفاء
      for (final player in _sfxPlayers ?? const <AudioPlayer>[]) {
        try {
          await player.stop();
        } catch (_) {}
      }
      try {
        await _voicePlayer?.stop();
      } catch (_) {}
    }
  }

  /// يشغّل مؤثّرا قصيرا عبر المجمّع الدوّار
  Future<void> play(Sfx sfx) async {
    if (disabled || !soundEnabled) return;
    // المتصفح يمنع الصوت قبل أول إيماءة؛ المؤثّرات تأتي دائما بعد إيماءة
    // فهي أفضل لحظة لإنقاذ الموسيقى الممنوعة
    if (!_musicStarted) startMusic();
    final pool = _sfxPool;
    if (pool.isEmpty) return;
    final player = pool[_sfxIndex];
    _sfxIndex = (_sfxIndex + 1) % pool.length;
    try {
      await player.stop();
      await player.play(AssetSource('audio/${sfx.file}'));
    } catch (e) {
      debugPrint('Audio: تعذّر تشغيل ${sfx.name} — $e');
    }
  }

  /// بصمة الشخصية الصوتية — تُسمع مع ظهور فقاعة المرشد
  Future<void> playCharacter(String characterId) async {
    if (disabled || !soundEnabled) return;
    try {
      final voice = _voice!;
      await voice.stop();
      await voice.setVolume(0.8);
      await voice.play(AssetSource('audio/voice_$characterId.wav'));
    } catch (e) {
      debugPrint('Audio: تعذّر صوت الشخصية $characterId — $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // الموسيقى تصمت في الخلفية وتعود مع التطبيق
    if (state == AppLifecycleState.resumed) {
      if (soundEnabled && _musicStarted) _musicPlayer?.resume();
    } else {
      _musicPlayer?.pause();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _musicPlayer?.dispose();
    _voicePlayer?.dispose();
    for (final p in _sfxPlayers ?? const <AudioPlayer>[]) {
      p.dispose();
    }
  }
}
