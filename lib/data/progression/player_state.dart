// محفظة اللاعب وحالته الكاملة. منطق صرف، بلا استيراد Flutter.
//
// عملتان منفصلتان عمدا — لا تُدمَجان أبدا في مكان واحد:
//   coins  — قابلة للإنفاق، يمكن أن تنقص.
//   xp     — لا تُنفَق أبدا، تتزايد فقط، تحرّك مستوى اللاعب.
//
// فتح الفصول/العوالم لا يقرأ المحفظة أصلا: مصدره إتمام المراحل وحده
// (راجع progression_rules.dart).
//
// هذه المحفظة هي **الدفتر الوحيد** لعملات اللاعب وشحنات تلميحه منذ ربط
// EconomyService: كل كسب وكل إنفاق يمرّ عبر ذلك المحرّك ثم يُكتب هنا.
// مفتاحا ProgressStore القديمان (`points` و`banked_hint_charges`) لم
// يعودا يُكتبان، ويبقيان للقراءة مرة واحدة عند الهجرة لا أكثر.

import '../../config/balance_config.dart';

class PlayerWallet {
  final int coins;
  final int xp;
  final int hintCharges;

  const PlayerWallet({
    required this.coins,
    required this.xp,
    required this.hintCharges,
  });

  factory PlayerWallet.initial() =>
      const PlayerWallet(coins: 0, xp: 0, hintCharges: 0);

  PlayerWallet copyWith({int? coins, int? xp, int? hintCharges}) =>
      PlayerWallet(
        coins: coins ?? this.coins,
        xp: xp ?? this.xp,
        hintCharges: hintCharges ?? this.hintCharges,
      );

  Map<String, dynamic> toJson() => {
    'coins': coins,
    'xp': xp,
    'hintCharges': hintCharges,
  };

  factory PlayerWallet.fromJson(Map<String, dynamic> json) => PlayerWallet(
    coins: json['coins'] as int,
    xp: json['xp'] as int,
    hintCharges: json['hintCharges'] as int? ?? 0,
  );

  // تُقارَن بالقيمة لا بالهوية: [ProgressionRepository.runEconomy] يكتب
  // المحفظة الناتجة فقط إن تغيّرت فعلا، فلا يُعلَّم التخزين «قذرا» بعد
  // عملية لم تغيّر شيئا (اقتباس سعر، أو إنفاق فشل لعدم الكفاية).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerWallet &&
          other.coins == coins &&
          other.xp == xp &&
          other.hintCharges == hintCharges;

  @override
  int get hashCode => Object.hash(coins, xp, hintCharges);
}

/// أعلى مستوى مخطط الحالة يفهمه هذا الكود. تُقارَن بها القيمة المخزّنة
/// محليا لمعرفة إن كانت الهجرة من v1 لازمة.
const int kPlayerStateSchemaVersion = 2;

class PlayerState {
  final PlayerWallet wallet;
  final int level;
  final int currentStageId;
  final Set<int> unlockedWorldIds;
  final Set<int> unlockedChapterIds;

  /// عدد الكلمات الإضافية المكتشفة في كل عالم — يقارَن بعتبة جرّة ذلك
  /// العالم في BalanceConfig لفتح العالم التالي
  final Map<int, int> jarProgress;
  final int schemaVersion;

  /// معرّفات الفصول التي فُتح صندوقها *واستُلم* فعلا (لا يكفي أن يكون
  /// الصندوق مؤهّلا للفتح — راجع ChestState في map_view_model.dart)
  final Set<int> claimedChapterChestIds;

  /// العوالم التي عُرضت لها مراسم الفتح الكاملة فعلا. منفصل عمدا عن
  /// unlockedWorldIds: عالم يمكن أن يُفتح آليا (recomputeUnlocks) قبل أن
  /// تُعرض مراسمه فعلا على الشاشة — هذا الحقل يسجّل "عُرضت"، لا "فُتحت".
  final Set<int> ceremonyShownForWorldIds;

  /// أعلى طبقة جرّة طُولِب بمكافأتها لكل عالم — 0 (أو غياب المفتاح) يعني
  /// لا شيء بعد، 1 يعني طبقة الامتلاء الأولى (100% من العتبة)، 2 يعني
  /// الطبقة الثانية (150%). تُمنَح تلقائيا لحظة بلوغ العتبة (لا خطوة
  /// "استلام" يدوية) — راجع lib/data/progression/jar_rewards.dart
  final Map<int, int> claimedJarTierByWorld;

  const PlayerState({
    required this.wallet,
    required this.level,
    required this.currentStageId,
    required this.unlockedWorldIds,
    required this.unlockedChapterIds,
    required this.jarProgress,
    required this.schemaVersion,
    this.claimedChapterChestIds = const {},
    this.ceremonyShownForWorldIds = const {},
    this.claimedJarTierByWorld = const {},
  });

  /// حالة لاعب جديد تماما: أول 5 مراحل مفتوحة (BalanceConfig)، عالم1/فصل1
  /// مفتوحان، كل شيء آخر صفر. عالم1 يُسجَّل هنا كـ"عُرضت مراسمه" لأنه
  /// مفتوح منذ اللحظة الأولى — لا معنى لمراسم "فتح" لعالم لم يكن مقفلا قط.
  ///
  /// الرصيد يبدأ بـ[BalanceConfig.startingCoins] لا بصفر: هذه الحالة هي
  /// ما يُكتب بعد «البدء من جديد»، وبصفر كان اللاعب المُعيد يبدأ أفقر من
  /// لاعب جديد. [PlayerWallet.initial] تبقى صفرا — محفظة فارغة مفهوم
  /// مختلف عن «لاعب جديد».
  factory PlayerState.initial() => PlayerState(
    wallet: PlayerWallet.initial().copyWith(coins: BalanceConfig.startingCoins),
    level: 1,
    currentStageId: 1,
    unlockedWorldIds: {1},
    unlockedChapterIds: {1},
    jarProgress: const {},
    schemaVersion: kPlayerStateSchemaVersion,
    claimedChapterChestIds: const {},
    ceremonyShownForWorldIds: {1},
    claimedJarTierByWorld: const {},
  );

  PlayerState copyWith({
    PlayerWallet? wallet,
    int? level,
    int? currentStageId,
    Set<int>? unlockedWorldIds,
    Set<int>? unlockedChapterIds,
    Map<int, int>? jarProgress,
    int? schemaVersion,
    Set<int>? claimedChapterChestIds,
    Set<int>? ceremonyShownForWorldIds,
    Map<int, int>? claimedJarTierByWorld,
  }) => PlayerState(
    wallet: wallet ?? this.wallet,
    level: level ?? this.level,
    currentStageId: currentStageId ?? this.currentStageId,
    unlockedWorldIds: unlockedWorldIds ?? this.unlockedWorldIds,
    unlockedChapterIds: unlockedChapterIds ?? this.unlockedChapterIds,
    jarProgress: jarProgress ?? this.jarProgress,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    claimedChapterChestIds:
        claimedChapterChestIds ?? this.claimedChapterChestIds,
    ceremonyShownForWorldIds:
        ceremonyShownForWorldIds ?? this.ceremonyShownForWorldIds,
    claimedJarTierByWorld: claimedJarTierByWorld ?? this.claimedJarTierByWorld,
  );

  Map<String, dynamic> toJson() => {
    'wallet': wallet.toJson(),
    'level': level,
    'currentStageId': currentStageId,
    'unlockedWorldIds': unlockedWorldIds.toList()..sort(),
    'unlockedChapterIds': unlockedChapterIds.toList()..sort(),
    'jarProgress': jarProgress.map((k, v) => MapEntry(k.toString(), v)),
    'schemaVersion': schemaVersion,
    'claimedChapterChestIds': claimedChapterChestIds.toList()..sort(),
    'ceremonyShownForWorldIds': ceremonyShownForWorldIds.toList()..sort(),
    'claimedJarTierByWorld': claimedJarTierByWorld.map(
      (k, v) => MapEntry(k.toString(), v),
    ),
  };

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
    wallet: PlayerWallet.fromJson(json['wallet'] as Map<String, dynamic>),
    level: json['level'] as int,
    currentStageId: json['currentStageId'] as int,
    unlockedWorldIds: (json['unlockedWorldIds'] as List).cast<int>().toSet(),
    unlockedChapterIds: (json['unlockedChapterIds'] as List)
        .cast<int>()
        .toSet(),
    jarProgress: (json['jarProgress'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(int.parse(k), v as int),
    ),
    schemaVersion: json['schemaVersion'] as int,
    // حقلان أُضيفا لاحقا — أي حفظ v2 سابق لهذه الإضافة يفتقدهما.
    // claimedChapterChestIds تُهمَل بأمان بصفر (لا صندوق استُلم بعد).
    // ceremonyShownForWorldIds تفترض عالم1 فقط بأمان: لاعب موجود من
    // قبل قد يكون فتح عوالم أخرى فعلا؛ الافتراض الآمن هنا هو عرض
    // مراسمها مرة واحدة إضافية بدل افتراض عرضها ("مرة واحدة، ولو
    // متأخرة" أفضل من "لن تُعرض أبدا لمن فاتته").
    claimedChapterChestIds:
        (json['claimedChapterChestIds'] as List?)?.cast<int>().toSet() ??
        const {},
    ceremonyShownForWorldIds:
        (json['ceremonyShownForWorldIds'] as List?)?.cast<int>().toSet() ?? {1},
    // حقل أُضيف لاحقا — يُفترَض بأمان "لا شيء طُولِب به بعد" لحفظ
    // v2 سابق؛ الأسوأ الممكن هو منح مكافأة الطبقة1/2 مرة إضافية
    // للاعب قديم بلغ العتبة فعلا قبل هذا الحقل، لا فقدان تقدّم أبدا
    claimedJarTierByWorld:
        (json['claimedJarTierByWorld'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(int.parse(k), v as int),
        ) ??
        const {},
  );
}
