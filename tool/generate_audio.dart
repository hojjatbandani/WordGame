// مولّد الصوت — يركّب موسيقى اللعبة ومؤثّراتها رقميا من الصفر.
//
// لماذا التوليد بدل التنزيل؟ لأن المطلوب صوت «بلا حقوق ولا رخصة مقيّدة»،
// وأي ملف من الإنترنت يبقى رهن رخصة يجب تتبّعها ونسبها. ما يُولَّد هنا
// أصلي بالكامل ومملوك للعبة، ولا يحتاج إسنادا لأحد.
//
// الموسيقى مبنية على مقام الحجاز (ري، مي بيمول، فا دييز، صول، لا، سي
// بيمول، دو) وهو المقام الأشهر في الموسيقى العربية، بإيقاع هادئ 72 نبضة
// ودرون مستمر كما في التقاليد المقامية.
//
// التشغيل:  dart run tool/generate_audio.dart
// الخرج:    assets/audio/
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const sampleRate = 22050; // كافٍ لموسيقى هادئة، ونصف حجم 44.1kHz
const outDir = 'assets/audio';

// ─────────────────────── أدوات التركيب ───────────────────────

/// مخزن عيّنات أحادي القناة بقيَم عشرية (-1..1)
class Track {
  final Float64List samples;

  Track(double seconds) : samples = Float64List((seconds * sampleRate).round());

  int get length => samples.length;
  double get seconds => length / sampleRate;

  void add(int index, double value) {
    if (index < 0 || index >= length) return;
    samples[index] += value;
  }

  /// مرشّح تمرير منخفض بقطب واحد — يزيل حدّة الموجات ويعطي دفئا
  void lowPass(double cutoffHz) {
    final dt = 1 / sampleRate;
    final rc = 1 / (2 * pi * cutoffHz);
    final alpha = dt / (rc + dt);
    var previous = samples[0];
    for (var i = 1; i < length; i++) {
      previous += alpha * (samples[i] - previous);
      samples[i] = previous;
    }
  }

  /// صدى بسيط متعدّد النقاط — يوهم باتساع المكان دون مكتبة تأثيرات
  void reverb({double mix = 0.28}) {
    const taps = [0.071, 0.113, 0.177, 0.241];
    const gains = [0.50, 0.36, 0.26, 0.18];
    final wet = Float64List(length);
    for (var t = 0; t < taps.length; t++) {
      final delay = (taps[t] * sampleRate).round();
      final gain = gains[t];
      for (var i = delay; i < length; i++) {
        wet[i] += samples[i - delay] * gain;
      }
    }
    for (var i = 0; i < length; i++) {
      samples[i] = samples[i] * (1 - mix) + wet[i] * mix;
    }
  }

  /// يطبّع الذروة إلى [peak] ويضيف تشبّعا لطيفا بدل القصّ الحاد
  void normalize(double peak) {
    var maxAbs = 0.0;
    for (final s in samples) {
      final a = s.abs();
      if (a > maxAbs) maxAbs = a;
    }
    if (maxAbs == 0) return;
    final scale = peak / maxAbs;
    for (var i = 0; i < length; i++) {
      final v = samples[i] * scale;
      // tanh يلطّف القمم بدل بترها فلا يظهر تشويه
      samples[i] = _tanh(v * 1.2) / _tanh(1.2);
    }
  }

  void fadeIn(double seconds) {
    final n = (seconds * sampleRate).round();
    for (var i = 0; i < n && i < length; i++) {
      samples[i] *= i / n;
    }
  }

  void fadeOut(double seconds) {
    final n = (seconds * sampleRate).round();
    for (var i = 0; i < n && i < length; i++) {
      samples[length - 1 - i] *= i / n;
    }
  }

  /// يجعل النهاية تعانق البداية كي تدور الحلقة بلا فجوة مسموعة
  void crossfadeLoop(double seconds) {
    final n = (seconds * sampleRate).round();
    if (n * 2 >= length) return;
    for (var i = 0; i < n; i++) {
      final t = i / n;
      final tail = samples[length - n + i];
      samples[i] = samples[i] * t + tail * (1 - t);
    }
    // نقصّ الذيل الذي دُمج في البداية
    for (var i = length - n; i < length; i++) {
      samples[i] = 0;
    }
  }
}

double _tanh(double x) {
  final e2 = exp(2 * x);
  return (e2 - 1) / (e2 + 1);
}

/// غلاف ADSR مبسّط
double _envelope(
  double t,
  double duration, {
  double attack = 0.01,
  double decay = 0.2,
  double sustain = 0.6,
  double release = 0.3,
}) {
  if (t < 0 || t > duration) return 0;
  final releaseStart = duration - release;
  if (t < attack) return t / attack;
  if (t < attack + decay) {
    final d = (t - attack) / decay;
    return 1 - (1 - sustain) * d;
  }
  if (t < releaseStart) return sustain;
  final r = (t - releaseStart) / release;
  return sustain * (1 - r).clamp(0.0, 1.0);
}

/// نغمة وترية مقطوفة تشبه القانون/العود: توافقيات تتلاشى بسرعات مختلفة
void pluck(
  Track track,
  double startSec,
  double freq,
  double duration,
  double amp,
) {
  final start = (startSec * sampleRate).round();
  final count = (duration * sampleRate).round();
  const harmonics = [1.0, 2.0, 3.0, 4.0, 5.0];
  const weights = [1.0, 0.45, 0.22, 0.11, 0.06];
  for (var i = 0; i < count; i++) {
    final t = i / sampleRate;
    // كل توافقية أعلى تخبو أسرع، وهذا ما يعطي الإحساس الوتري
    var value = 0.0;
    for (var h = 0; h < harmonics.length; h++) {
      final decay = exp(-t * (2.6 + harmonics[h] * 1.5));
      value += sin(2 * pi * freq * harmonics[h] * t) * weights[h] * decay;
    }
    track.add(start + i, value * amp);
  }
}

/// طبقة مدّ ناعمة (pad): موجات مزاحة قليلا فتتموّج ببطء
void pad(
  Track track,
  double startSec,
  double freq,
  double duration,
  double amp,
) {
  final start = (startSec * sampleRate).round();
  final count = (duration * sampleRate).round();
  const detune = [0.997, 1.0, 1.004];
  for (var i = 0; i < count; i++) {
    final t = i / sampleRate;
    final env = _envelope(
      t,
      duration,
      attack: duration * 0.28,
      decay: 0.4,
      sustain: 0.85,
      release: duration * 0.35,
    );
    // تموّج بطيء يمنع الطبقة من الجمود
    final shimmer = 1 + 0.06 * sin(2 * pi * 0.13 * t);
    var value = 0.0;
    for (final d in detune) {
      value += sin(2 * pi * freq * d * t);
    }
    track.add(start + i, value / detune.length * env * amp * shimmer);
  }
}

/// نفخة تشبه الناي — أساسها جيبية مع نَفَس خفيف
void ney(
  Track track,
  double startSec,
  double freq,
  double duration,
  double amp,
  Random rng,
) {
  final start = (startSec * sampleRate).round();
  final count = (duration * sampleRate).round();
  var breath = 0.0;
  for (var i = 0; i < count; i++) {
    final t = i / sampleRate;
    final env = _envelope(
      t,
      duration,
      attack: 0.12,
      decay: 0.15,
      sustain: 0.8,
      release: 0.25,
    );
    // اهتزاز خفيف في النغمة (vibrato) يشبه النفخ البشري
    final vibrato = 1 + 0.006 * sin(2 * pi * 5.2 * t);
    breath = breath * 0.995 + (rng.nextDouble() - 0.5) * 0.05;
    final tone =
        sin(2 * pi * freq * vibrato * t) +
        0.18 * sin(2 * pi * freq * 2 * vibrato * t);
    track.add(start + i, (tone * 0.7 + breath) * env * amp);
  }
}

// ─────────────────────── كتابة WAV ───────────────────────

void writeWav(String path, Track track, {double peak = 0.86}) {
  track.normalize(peak);
  final n = track.length;
  final dataBytes = n * 2;
  final bytes = BytesBuilder();

  void str(String s) => bytes.add(s.codeUnits);
  void u32(int v) => bytes.add(
    Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little),
  );
  void u16(int v) => bytes.add(
    Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little),
  );

  str('RIFF');
  u32(36 + dataBytes);
  str('WAVE');
  str('fmt ');
  u32(16); // حجم كتلة fmt
  u16(1); // PCM
  u16(1); // أحادي القناة
  u32(sampleRate);
  u32(sampleRate * 2); // بايتات في الثانية
  u16(2); // محاذاة الكتلة
  u16(16); // بت لكل عيّنة
  str('data');
  u32(dataBytes);

  final pcm = Uint8List(dataBytes);
  final view = pcm.buffer.asByteData();
  for (var i = 0; i < n; i++) {
    final v = (track.samples[i].clamp(-1.0, 1.0) * 32767).round();
    view.setInt16(i * 2, v, Endian.little);
  }
  bytes.add(pcm);

  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes.takeBytes());
  stdout.writeln(
    '${path.split('/').last}  ${(file.lengthSync() / 1024).round()}KB  '
    '${track.seconds.toStringAsFixed(1)}s',
  );
}

// ─────────────────────── مقام الحجاز ───────────────────────

/// درجات مقام الحجاز على ري (بالهرتز، أوكتاف رابع)
class Hijaz {
  static const d = 293.66; // ري
  static const eb = 311.13; // مي بيمول
  static const fs = 369.99; // فا دييز — الوثبة المميزة للحجاز
  static const g = 392.00; // صول
  static const a = 440.00; // لا
  static const bb = 466.16; // سي بيمول
  static const c = 523.25; // دو
  static const d5 = 587.33; // ري (أعلى)

  static const scale = [d, eb, fs, g, a, bb, c, d5];
}

// ─────────────────────── الموسيقى الخلفية ───────────────────────

/// حلقة هادئة ~40 ثانية: درون مستمر + مدّ + جمل مقطوفة + ناي متفرّق
void buildMusic() {
  const bpm = 72.0;
  const beat = 60.0 / bpm; // 0.833 ثانية
  const bar = beat * 4;
  const bars = 12;
  const tail = 3.0; // مساحة لذيل الصدى قبل دمج الحلقة
  final track = Track(bars * bar + tail);
  final rng = Random(20260817); // بذرة ثابتة كي يكون الخرج قابلا للتكرار

  // 1) درون: ري منخفض مستمر تحت كل شيء — أساس الموسيقى المقامية
  for (var b = 0; b < bars; b += 2) {
    pad(track, b * bar, Hijaz.d / 2, bar * 2 + 0.6, 0.20);
    pad(track, b * bar, Hijaz.a / 2, bar * 2 + 0.6, 0.10);
  }

  // 2) طبقة مدّ تتلوّن كل 4 أبيات فتتنفّس القطعة
  const padPlan = [
    [Hijaz.d, Hijaz.a],
    [Hijaz.g, Hijaz.bb],
    [Hijaz.d, Hijaz.fs],
  ];
  for (var phrase = 0; phrase < 3; phrase++) {
    final start = phrase * 4 * bar;
    for (final f in padPlan[phrase]) {
      pad(track, start, f, bar * 4 + 0.8, 0.12);
    }
  }

  // 3) جملة مقطوفة هادئة — نازلة ثم صاعدة، تتكرّر بتنويع خفيف
  const phraseA = [
    [0.0, Hijaz.a],
    [0.75, Hijaz.g],
    [1.5, Hijaz.fs],
    [2.25, Hijaz.eb],
    [3.0, Hijaz.d],
    [4.5, Hijaz.fs],
    [5.25, Hijaz.g],
    [6.0, Hijaz.a],
  ];
  const phraseB = [
    [0.0, Hijaz.d5],
    [0.75, Hijaz.c],
    [1.5, Hijaz.bb],
    [2.25, Hijaz.a],
    [3.0, Hijaz.g],
    [4.5, Hijaz.fs],
    [5.25, Hijaz.eb],
    [6.0, Hijaz.d],
  ];
  for (var phrase = 0; phrase < 3; phrase++) {
    final start = phrase * 4 * bar;
    final notes = phrase == 1 ? phraseB : phraseA;
    for (final n in notes) {
      // الصوت يخفت قليلا في التكرار الأخير فتنساب الحلقة
      final amp = phrase == 2 ? 0.20 : 0.26;
      pluck(track, start + n[0] * beat, n[1], 2.2, amp);
    }
  }

  // 4) ناي متفرّق في الأعلى — لمسة عربية بلا ازدحام
  ney(track, bar * 2 + beat, Hijaz.d5, 2.4, 0.10, rng);
  ney(track, bar * 6 + beat * 2, Hijaz.c, 2.0, 0.09, rng);
  ney(track, bar * 10, Hijaz.a, 2.8, 0.10, rng);

  track.lowPass(4200); // دفء: نقصّ الحدّة العالية
  track.reverb(mix: 0.32);
  track.crossfadeLoop(1.6); // حلقة بلا فاصل مسموع
  // تنبيه: موسيقى الخلفية صارت ملفا حقيقيا (assets/audio/music_theme.mp3)
  // لا مولَّدة. هذا السطر يكتب music_theme.wav الذي *لا يقرأه التطبيق*
  // بعد الآن (راجع AudioService.startMusic) — أي إعادة تشغيل لهذه الأداة
  // لن تغيّر الموسيقى المسموعة، وستترك ملفا إضافيا بلا مستخدم. احذف
  // الملف الناتج أو هذا السطر إن أردت.
  writeWav('$outDir/music_theme.wav', track, peak: 0.62); // هادئة عمدا
}

// ─────────────────────── أصوات الشخصيات ───────────────────────

/// لكل شخصية بصمة صوتية: نغمات قصيرة تعبّر عن طبعها.
/// ليست كلاما منطوقا — تركيب الكلام العربي يحتاج نموذج أصوات حقيقيا،
/// وهذه بدائل موسيقية مميّزة يعرف اللاعب كل شخصية منها.
class CharacterVoice {
  final String id;

  /// درجات النغمة بالنسبة لأساس الشخصية
  final List<double> notes;
  final double base;
  final double noteLength;
  final bool breathy; // ناي (دافئ) أم قطف (نشيط)

  const CharacterVoice(
    this.id,
    this.base,
    this.notes,
    this.noteLength, {
    this.breathy = false,
  });
}

const voices = [
  // أبو الحروف — المرشد الأساسي: دافئ وواثق
  CharacterVoice('puzzle_master', 220.0, [1.0, 1.25, 1.5], 0.34, breathy: true),
  // العبقري الصغير: سريع وقافز
  CharacterVoice('little_genius', 523.25, [1.0, 1.5, 2.0], 0.16),
  // الذكية: خفيف ولمّاع
  CharacterVoice('clever_girl', 587.33, [1.0, 1.2, 1.5], 0.18),
  // الشاب: متوسط وحازم
  CharacterVoice('young_man', 293.66, [1.0, 1.33], 0.24),
  // الشابة: ناعم ومتوسط عالٍ
  CharacterVoice('young_woman', 440.0, [1.0, 1.2, 1.33], 0.22, breathy: true),
  // الحكواتي: سردي كالناي
  CharacterVoice(
    'story_teller',
    329.63,
    [1.0, 1.125, 1.25, 1.5],
    0.30,
    breathy: true,
  ),
  // الجدة: دافئ ومنخفض
  CharacterVoice('friendly_grandma', 261.63, [1.0, 1.2], 0.36, breathy: true),
  // الحكيم: عميق ورزين
  CharacterVoice('wise_oldman', 174.61, [1.0, 1.2, 1.5], 0.42, breathy: true),
  // المتحدي: نشيط وسريع
  CharacterVoice('challenger_boy', 392.0, [1.0, 1.5, 1.25, 2.0], 0.14),
];

void buildVoices() {
  final rng = Random(7);
  for (final v in voices) {
    final total = v.notes.length * v.noteLength + 0.9;
    final track = Track(total);
    for (var i = 0; i < v.notes.length; i++) {
      final at = i * v.noteLength;
      final freq = v.base * v.notes[i];
      if (v.breathy) {
        ney(track, at, freq, v.noteLength + 0.25, 0.5, rng);
      } else {
        pluck(track, at, freq, v.noteLength + 0.5, 0.5);
      }
    }
    track.lowPass(5200);
    track.reverb(mix: 0.22);
    track.fadeOut(0.25);
    writeWav('$outDir/voice_${v.id}.wav', track, peak: 0.78);
  }
}

// ─────────────────────── مؤثّرات الواجهة ───────────────────────

void buildSfx() {
  final rng = Random(99);

  // كلمة صحيحة: نغمتان صاعدتان مريحتان
  {
    final t = Track(1.0);
    pluck(t, 0.0, Hijaz.a, 0.7, 0.55);
    pluck(t, 0.09, Hijaz.d5, 0.8, 0.5);
    t.reverb(mix: 0.24);
    writeWav('$outDir/sfx_correct.wav', t);
  }

  // كلمة خاطئة: نغمة منخفضة قصيرة، غير قاسية كي لا تزعج مع التكرار
  {
    final t = Track(0.7);
    pluck(t, 0.0, 146.83, 0.45, 0.45); // ري منخفض
    pluck(t, 0.06, 138.59, 0.5, 0.35);
    t.lowPass(1200); // كتم الحدّة تماما
    writeWav('$outDir/sfx_wrong.wav', t, peak: 0.55);
  }

  // كلمة إضافية: ومضة عالية
  {
    final t = Track(1.2);
    pluck(t, 0.0, Hijaz.d5, 0.6, 0.4);
    pluck(t, 0.07, Hijaz.fs * 2, 0.6, 0.34);
    pluck(t, 0.14, Hijaz.a * 2, 0.8, 0.3);
    t.reverb(mix: 0.3);
    writeWav('$outDir/sfx_bonus.wav', t);
  }

  // إتمام المرحلة: جملة صاعدة قصيرة بمقام الحجاز
  {
    final t = Track(2.4);
    const seq = [Hijaz.d, Hijaz.fs, Hijaz.a, Hijaz.d5];
    for (var i = 0; i < seq.length; i++) {
      pluck(t, i * 0.13, seq[i], 1.4, 0.5);
    }
    pad(t, 0.0, Hijaz.d / 2, 2.2, 0.16);
    t.reverb(mix: 0.34);
    writeWav('$outDir/sfx_level_complete.wav', t);
  }

  // إنجاز مفتوح: أطول وأكثر احتفالا
  {
    final t = Track(2.8);
    const seq = [Hijaz.d, Hijaz.g, Hijaz.bb, Hijaz.d5, Hijaz.fs * 2];
    for (var i = 0; i < seq.length; i++) {
      pluck(t, i * 0.11, seq[i], 1.6, 0.46);
    }
    pad(t, 0.05, Hijaz.d, 2.4, 0.14);
    t.reverb(mix: 0.36);
    writeWav('$outDir/sfx_achievement.wav', t);
  }

  // تلميح: رنّة ناعمة واحدة
  {
    final t = Track(1.1);
    ney(t, 0.0, Hijaz.c, 0.8, 0.42, rng);
    t.reverb(mix: 0.28);
    writeWav('$outDir/sfx_hint.wav', t, peak: 0.7);
  }

  // لمس حرف على العجلة: نقرة خفيفة جدا تتكرّر كثيرا
  {
    final t = Track(0.28);
    pluck(t, 0.0, Hijaz.a * 2, 0.22, 0.3);
    t.lowPass(6000);
    writeWav('$outDir/sfx_tap.wav', t, peak: 0.42);
  }

  // دوران عجلة الحظ: نقرة أوضح
  {
    final t = Track(0.4);
    pluck(t, 0.0, Hijaz.g, 0.3, 0.4);
    t.lowPass(5000);
    writeWav('$outDir/sfx_spin.wav', t, peak: 0.6);
  }
}

void main() {
  Directory(outDir).createSync(recursive: true);
  stdout.writeln('— الموسيقى —');
  buildMusic();
  stdout.writeln('\n— أصوات الشخصيات —');
  buildVoices();
  stdout.writeln('\n— مؤثّرات الواجهة —');
  buildSfx();

  final total = Directory(
    outDir,
  ).listSync().whereType<File>().fold<int>(0, (sum, f) => sum + f.lengthSync());
  stdout.writeln(
    '\nالمجموع: ${(total / 1024 / 1024).toStringAsFixed(2)}MB في $outDir',
  );
}
