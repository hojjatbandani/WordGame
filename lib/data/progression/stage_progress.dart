// تقدّم اللاعب في مرحلة واحدة. منطق صرف، بلا استيراد Flutter.
//
// لا نجوم في هذا النظام: إتمام المرحلة ([completed]) هو كل ما يحرّك
// التقدّم، وباقي الحقول إحصاءات لا بوابات — [bonusWordsFound] مجموعة
// تتراكم عبر كل المحاولات ولا تُفرَّغ أبدا (تغذّي جرّة العالم)،
// و[hintsUsedBest] أقل عدد تلميحات في أي محاولة ناجحة (min)، و[completed]
// متى صار true لا يعود false. فكل حقل محفوظ هنا متزايد بطبيعته: إعادة
// اللعب لا تُنقص شيئا أبدا.

class StageProgress {
  final int stageId;
  final bool completed;
  final int? bestTimeMs;
  final int? hintsUsedBest;
  final Set<String> bonusWordsFound;
  final int attempts;
  final DateTime? lastPlayedAt;

  const StageProgress({
    required this.stageId,
    required this.completed,
    required this.bestTimeMs,
    required this.hintsUsedBest,
    required this.bonusWordsFound,
    required this.attempts,
    required this.lastPlayedAt,
  });

  factory StageProgress.empty(int stageId) => StageProgress(
        stageId: stageId,
        completed: false,
        bestTimeMs: null,
        hintsUsedBest: null,
        bonusWordsFound: const {},
        attempts: 0,
        lastPlayedAt: null,
      );

  StageProgress copyWith({
    bool? completed,
    int? bestTimeMs,
    int? hintsUsedBest,
    Set<String>? bonusWordsFound,
    int? attempts,
    DateTime? lastPlayedAt,
  }) =>
      StageProgress(
        stageId: stageId,
        completed: completed ?? this.completed,
        bestTimeMs: bestTimeMs ?? this.bestTimeMs,
        hintsUsedBest: hintsUsedBest ?? this.hintsUsedBest,
        bonusWordsFound: bonusWordsFound ?? this.bonusWordsFound,
        attempts: attempts ?? this.attempts,
        lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      );

  Map<String, dynamic> toJson() => {
        'stageId': stageId,
        'completed': completed,
        'bestTimeMs': bestTimeMs,
        'hintsUsedBest': hintsUsedBest,
        'bonusWordsFound': bonusWordsFound.toList(),
        'attempts': attempts,
        'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      };

  factory StageProgress.fromJson(Map<String, dynamic> json) => StageProgress(
        stageId: json['stageId'] as int,
        completed: json['completed'] as bool,
        bestTimeMs: json['bestTimeMs'] as int?,
        hintsUsedBest: json['hintsUsedBest'] as int?,
        bonusWordsFound:
            (json['bonusWordsFound'] as List).cast<String>().toSet(),
        attempts: json['attempts'] as int,
        lastPlayedAt: json['lastPlayedAt'] == null
            ? null
            : DateTime.parse(json['lastPlayedAt'] as String),
      );
}
