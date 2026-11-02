// طبقة التخزين المحلي لنظام التقدّم الجديد (v2). SharedPreferences تبقى
// مصدر الحقيقة، تماما كـProgressStore القديم — لا يلمس هذا الملف أي
// مفتاح من مفاتيح ProgressStore الحالية، فقط يقرأ منها للهجرة مرة واحدة.
//
// الكتابة "مجمّعة لا مع كل ضغطة": كل التعديلات (recordStageCompletion..)
// تُحدَّث في الذاكرة فقط وتُعلَّم "قذرة"؛ الكتابة الفعلية إلى
// SharedPreferences تحدث دفعة واحدة عبر save()، لا حقلا حقلا مع كل
// تغيير — يستدعيها المستدعي (طبقة الحالة لاحقا) بعد انتهاء الجلسة أو
// حدث اللعب، لا مع كل تفاعل صغير.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/balance_config.dart';
import 'economy/economy_events.dart';
import 'economy/economy_service.dart';
import 'progress_store.dart';
import 'progression/player_level_curve.dart';
import 'progression/player_state.dart';
import 'progression/progression_engine.dart';
import 'progression/progression_migration.dart';
import 'progression/progression_rules.dart';
import 'progression/stage_progress.dart';
import 'progression/world_defs.dart';

/// فشل تحميل بيانات محفوظة فعليا (لا حالة "لا يوجد شيء بعد" — تلك تُعامَل
/// بإنشاء حالة ابتدائية بصمت). يُرمى بدل تجاهله بصمت وإعادة تعيين حالة
/// اللاعب: بيانات تقدّم حقيقية تالفة مسؤولية طبقة أعلى (واجهة/حالة)
/// تقرّر كيف تُعرَض للاعب، لا مسؤولية طبقة التخزين أن تمحوها بصمت.
class ProgressionCorruptDataException implements Exception {
  final String message;
  final Object cause;

  const ProgressionCorruptDataException(this.message, this.cause);

  @override
  String toString() => 'ProgressionCorruptDataException: $message ($cause)';
}

class ProgressionRepository {
  static const _kPlayerStateKey = 'khroof_player_state_v2';
  static const _kStageProgressKey = 'khroof_stage_progress_v2';
  static const _kMigrationDoneFlag = 'migration_v2_done';
  static const _kPendingWelcomeChestKey = 'khroof_pending_welcome_chest_coins';

  final SharedPreferences _prefs;
  final ProgressionStructure structure;

  PlayerState _state;
  Map<int, StageProgress> _stageProgress;
  bool _dirty = false;

  ProgressionRepository._({
    required this._prefs,
    required this.structure,
    required this._state,
    required this._stageProgress,
  });

  PlayerState get state => _state;
  Map<int, StageProgress> get stageProgress => Map.unmodifiable(_stageProgress);

  /// صندوق ترحيب الهجرة المعلّق، أو 0 إن لم تُشغَّل هجرة قط أو سبق
  /// استلامه. القراءة/الاستلام الفعلي (مهمة لاحقة) يستدعي
  /// [claimPendingWelcomeChest].
  int get pendingWelcomeChestCoins =>
      _prefs.getInt(_kPendingWelcomeChestKey) ?? 0;

  /// يحمّل الحالة من SharedPreferences، ويشغّل هجرة v1→v2 مرة واحدة فقط
  /// إن لم تُشغَّل من قبل. لا يكتب شيئا هنا سوى علامة الهجرة ونتيجتها —
  /// استدعِ [save] بعدها إن أردت تثبيت الحالة المهاجَرة فورا.
  static Future<ProgressionRepository> load({
    required SharedPreferences prefs,
    required ProgressStore legacy,
  }) async {
    final repo = loadSync(prefs: prefs, legacy: legacy);
    await repo.save();
    return repo;
  }

  /// نفس [load] بلا انتظار. [SharedPreferences] تحتفظ بنسخة في الذاكرة
  /// وتُرجع Future للكتابة على القرص وحدها، فكل قراءة لاحقة في هذه
  /// الجلسة ترى القيمة الجديدة فورا — ولا شيء هنا يقرأ ما كتبه للتوّ.
  ///
  /// وجودها ليس تحسين أداء: المزوّد ([progressionRepositoryProvider])
  /// مزوّد متزامن، وبلا هذه الدالة كان لا بدّ من تجاوزه يدويا من `main`
  /// وكان يرمي `UnimplementedError` في كل سياق آخر — فبقي نظاما لا
  /// تستطيع بقية المزوّدات (ولا أي اختبار) الوصول إليه.
  static ProgressionRepository loadSync({
    required SharedPreferences prefs,
    required ProgressStore legacy,
  }) {
    final structure = ProgressionStructure.generate();
    final migrationDone = prefs.getBool(_kMigrationDoneFlag) ?? false;

    if (!migrationDone) {
      return _rebuildFromLegacy(
        prefs: prefs,
        legacy: legacy,
        structure: structure,
      );
    }

    final stateJson = prefs.getString(_kPlayerStateKey);
    final stageJson = prefs.getString(_kStageProgressKey);

    if (stateJson == null) {
      // علامة الهجرة مضبوطة لكن لا حالة محفوظة — لا يُفترض حدوثه، لكن
      // نتعامل معه كأول تشغيل بدل الانهيار
      return ProgressionRepository._(
        prefs: prefs,
        structure: structure,
        state: PlayerState.initial(),
        stageProgress: {},
      );
    }

    late final PlayerState state;
    try {
      state = PlayerState.fromJson(
        jsonDecode(stateJson) as Map<String, dynamic>,
      );
    } catch (e) {
      // حالة تالفة لا يجوز أن تُبقي التطبيق على شاشة فارغة إلى الأبد:
      // هذا يُستدعى قبل runApp ولا طبقة فوقه تعرض شيئا للاعب. نعيد
      // البناء من النظام القديم (maxUnlocked/points ما زالا محفوظين)
      // تماما كأول تشغيل — يُفقد سجلّ التلميحات والكلمات الإضافية
      // فقط، ويبقى كل إتمام مرحلة.
      debugPrint(
        'progression: حالة اللاعب المحفوظة تالفة، تُعاد من النظام '
        'القديم: $e',
      );
      return _rebuildFromLegacy(
        prefs: prefs,
        legacy: legacy,
        structure: structure,
      );
    }

    final stageProgress = <int, StageProgress>{};
    if (stageJson != null) {
      Map<String, dynamic> rawMap;
      try {
        rawMap = jsonDecode(stageJson) as Map<String, dynamic>;
      } catch (e) {
        // تقدّم المراحل وحده تالف: نبدأ بخريطة فارغة ويستعيد
        // _reconcileWithLegacy أدناه كل ما يعرف النظام القديم أنه اكتمل
        debugPrint(
          'progression: تقدّم المراحل المحفوظ تالف، يُستعاد من النظام '
          'القديم: $e',
        );
        rawMap = <String, dynamic>{};
      }
      for (final entry in rawMap.entries) {
        // عطل جزئي في قيمة واحدة لا يُسقط كل التقدّم — يُتجاوَز مع
        // تحذير، بخلاف عطل الحالة العامة أعلاه الذي يبقى قاتلا فعليا
        try {
          stageProgress[int.parse(entry.key)] = StageProgress.fromJson(
            entry.value as Map<String, dynamic>,
          );
        } catch (e) {
          debugPrint(
            'progression: تجاوز إدخال تقدّم تالف للمرحلة '
            '${entry.key}: $e',
          );
        }
      }
    }

    final repo = ProgressionRepository._(
      prefs: prefs,
      structure: structure,
      state: state,
      stageProgress: stageProgress,
    );
    // تسوية مع النظام القديم قبل أن يرى أحد الحالة — راجع الشرح أسفل
    if (repo._reconcileWithLegacy(legacy)) unawaited(repo.save());
    return repo;
  }

  /// يبني الحالة من النظام القديم (هجرة v1→v2) ويثبّتها فورا. المسار
  /// الواحد لأول تشغيل ولاستعادة حالة تالفة معا — كي لا يختلف السلوك
  /// بينهما يوما.
  static ProgressionRepository _rebuildFromLegacy({
    required SharedPreferences prefs,
    required ProgressStore legacy,
    required ProgressionStructure structure,
  }) {
    final result = ProgressionMigration.migrateFromV1(
      legacyPoints: legacy.points,
      legacyCompletedCount: (legacy.maxUnlocked - 1).clamp(0, 1 << 30),
      legacyBonusJar: legacy.bonusJar,
      // المحفظة صارت دفتر العملات والشحنات الوحيد — تُنقل القيمتان
      // القديمتان هنا مرة واحدة ثم لا يُكتب مفتاحاهما ثانية أبدا
      legacyHintCharges: legacy.bankedHintCharges,
      structure: structure,
    );
    unawaited(prefs.setBool(_kMigrationDoneFlag, true));
    unawaited(
      prefs.setInt(_kPendingWelcomeChestKey, result.pendingWelcomeChestCoins),
    );
    final repo = ProgressionRepository._(
      prefs: prefs,
      structure: structure,
      state: result.state,
      stageProgress: result.stageProgress,
    );
    repo._dirty = true;
    unawaited(repo.save());
    return repo;
  }

  // ─────────────────────── جسر محرّك الاقتصاد ───────────────────────

  /// نقطة الدخول **الوحيدة** إلى [EconomyService]: تبني المحرّك حول
  /// المحفظة الحالية، تنفّذ [action]، ثم تُعيد المحفظة الناتجة إلى
  /// الحالة. لا أحد يمسّ `wallet.coins` أو `wallet.hintCharges` خارج
  /// هذا المسار.
  ///
  /// المحرّك يُبنى في كل نداء لا مرة واحدة: الحالة قد تتغيّر من مسار
  /// آخر بينهما (إتمام مرحلة يزيد XP في نفس المحفظة)، ومحرّك مُعمَّر
  /// يحمل نسخة قديمة كان سيُعيد كتابتها فوق الجديدة.
  T runEconomy<T>(
    T Function(EconomyService economy) action, {
    EconomyEventSink onEvent = noopEconomyEventSink,
  }) {
    final economy = EconomyService(wallet: _state.wallet, onEvent: onEvent);
    final result = action(economy);
    if (economy.wallet != _state.wallet) {
      _state = _state.copyWith(wallet: economy.wallet);
      _dirty = true;
    }
    return result;
  }

  /// إصلاح ذاتي لما يعرف النظام القديم أنه اكتمل وينقص هنا.
  ///
  /// النظام القديم خطّي: maxUnlocked هو «أول مرحلة لم تُلعب»، فكل ما
  /// قبلها مكتمل يقينا. عطل سابق كان يفوّت تسجيل كل مرحلة تُحلّ بزرّ
  /// «التالي» داخل شاشة اللعب — التسجيل كان يقع في شاشة المسار بعد
  /// العودة إليها، وذلك الزرّ يستبدل مسار شاشة اللعب فلا تعود — فبقيت
  /// تلك العقد رمادية على الخريطة رغم حلّها. أُصلح المصدر في
  /// GameScreen._recordProgressionCompletion، وهذه تستعيد ما فات.
  ///
  /// يُنقل الإتمام وحده (لا سجل تلميحات ولا كلمات إضافية في النظام
  /// القديم يُحكم به رجعيا). ولا عملات — النظام القديم دفعها وقت الحلّ
  /// فعلا، ومنحها ثانية تضخيم لا إصلاح.
  bool _reconcileWithLegacy(ProgressStore legacy) {
    final knownCompleted = (legacy.maxUnlocked - 1).clamp(
      0,
      BalanceConfig.totalStages,
    );
    final repaired = <int>[
      for (var stageId = 1; stageId <= knownCompleted; stageId++)
        if (!(_stageProgress[stageId]?.completed ?? false)) stageId,
    ];
    if (repaired.isEmpty) return false;

    final progress = Map<int, StageProgress>.from(_stageProgress);
    for (final stageId in repaired) {
      progress[stageId] = StageProgress(
        stageId: stageId,
        completed: true,
        bestTimeMs: null,
        hintsUsedBest: null,
        bonusWordsFound: const {},
        attempts: 1,
        lastPlayedAt: null,
      );
    }

    // العقد وحدها لا تكفي: فصل أو عالم اكتمل بهذا الإصلاح يجب أن تُفتح
    // بوّابته أيضا، وإلا بقي اللاعب محبوسا خلف باب فتحه فعلا
    final recomputed = ProgressionRules.recomputeUnlocks(
      structure: structure,
      progress: progress,
      previouslyUnlockedWorldIds: _state.unlockedWorldIds,
      previouslyUnlockedChapterIds: _state.unlockedChapterIds,
    );
    // العوالم التي فتحها الإصلاح وصلها اللاعب فعلا في الماضي — مراسم
    // «عالم جديد!» لها بعد اليوم زائفة. أما عوالم لم يبلغها بعد فتبقى
    // مراسمها مستحقّة، فلا تُعلَّم هنا جملةً.
    final worldsRepairOpened = recomputed.worlds.difference(
      _state.unlockedWorldIds,
    );

    final xp =
        _state.wallet.xp +
        repaired.length * BalanceConfig.migrationXpPerCompletedStage;

    _stageProgress = progress;
    _state = _state.copyWith(
      wallet: _state.wallet.copyWith(xp: xp),
      level: PlayerLevelCurve.currentLevel(xp),
      // يتقدّم ولا يتراجع: قد يكون تقدّم v2 أبعد من الخطّي القديم أصلا
      currentStageId: _state.currentStageId > knownCompleted
          ? _state.currentStageId
          : (knownCompleted + 1).clamp(1, BalanceConfig.totalStages),
      unlockedWorldIds: recomputed.worlds,
      unlockedChapterIds: recomputed.chapters,
      ceremonyShownForWorldIds: {
        ..._state.ceremonyShownForWorldIds,
        ...worldsRepairOpened,
      },
    );
    _dirty = true;
    debugPrint(
      'progression: أُصلح تقدّم ${repaired.length} مرحلة كان النظام '
      'القديم يعرف اكتمالها',
    );
    return true;
  }

  /// يستدعيها استعراض/استلام صندوق الترحيب (مهمة لاحقة) — يضيف المبلغ
  /// إلى wallet.coins فعليا ويصفّر العلامة المعلّقة، مرة واحدة فقط.
  Future<int> claimPendingWelcomeChest() async {
    final amount = pendingWelcomeChestCoins;
    if (amount <= 0) return 0;
    _state = _state.copyWith(
      wallet: _state.wallet.copyWith(coins: _state.wallet.coins + amount),
    );
    _dirty = true;
    await _prefs.setInt(_kPendingWelcomeChestKey, 0);
    await save();
    return amount;
  }

  /// يثبّت كلمة إضافية **لحظة اكتشافها** لا عند إتمام المرحلة.
  ///
  /// يعيد true إن كانت جديدة فعلا (فتستحقّ عملاتها)، وfalse إن سبق
  /// اكتشافها في أي محاولة سابقة لنفس المرحلة.
  ///
  /// سبب وجودها: العملات كانت تُدفع عند الاكتشاف بينما المجموعة
  /// المحفوظة لا تُكتب إلا في [recordStageCompletion]. فمن يجد كلمة
  /// إضافية ثم **يغادر المرحلة قبل إتمامها** يعود إليها ومجموعتها
  /// فارغة، فيجدها ثانية ويُدفع له ثانية — بلا حدّ. الحلّ أن يتحرّك
  /// الدفتر مع الدفع لا بعده بمرحلة كاملة.
  ///
  /// الكتابة إلى القرص تبقى مجمّعة كبقية الملف: تُعلَّم الحالة قذرة
  /// و[save] هي من يكتب.
  bool recordBonusWordFound(int stageId, String word) {
    final old = _stageProgress[stageId] ?? StageProgress.empty(stageId);
    if (old.bonusWordsFound.contains(word)) return false;

    _stageProgress = {
      ..._stageProgress,
      stageId: old.copyWith(
        bonusWordsFound: {...old.bonusWordsFound, word},
      ),
    };
    _dirty = true;
    return true;
  }

  /// نقطة الدخول الوحيدة لتسجيل إتمام مرحلة — تُطبّق المحرّك الصرف ثم
  /// تُحدّث الذاكرة فقط (استدعِ [save] لاحقا للكتابة الفعلية المجمّعة)
  StageCompletionResult recordStageCompletion({
    required int stageId,
    required Set<String> bonusWordsFoundThisRun,
    required int hintsUsedThisRun,
    required int timeMs,
    required DateTime now,
  }) {
    final result = ProgressionEngine.applyStageCompletion(
      state: _state,
      allProgress: _stageProgress,
      structure: structure,
      stageId: stageId,
      bonusWordsFoundThisRun: bonusWordsFoundThisRun,
      hintsUsedThisRun: hintsUsedThisRun,
      timeMs: timeMs,
      now: now,
    );
    _state = result.state;
    _stageProgress = Map<int, StageProgress>.from(_stageProgress)
      ..[stageId] = result.stageProgress;
    _dirty = true;
    return result;
  }

  /// يستبدل الحالة كاملة (تُستخدم بعد دمج سحابي في
  /// progression_sync_repository.dart) — يُعلَّم قذرا كي يُكتب عند
  /// [save] التالية
  void replaceState(PlayerState state, Map<int, StageProgress> progress) {
    _state = state;
    _stageProgress = progress;
    _dirty = true;
  }

  // ─────────────────────── صندوق الفصل ───────────────────────

  /// يستلم صندوق فصل مؤهَّل بالفعل (كل مراحله مكتملة). لا يفعل شيئا
  /// بهدوء لو استُدعي على فصل غير مؤهَّل أو صندوق مُستلَم من قبل — لا
  /// استثناء لحالة يُفترض أن الواجهة لا تعرضها أصلا، لكن لا انهيار لو
  /// حدث خطأ استدعاء.
  Future<void> claimChapterChest(int chapterId) async {
    if (_state.claimedChapterChestIds.contains(chapterId)) return;
    final chapter = structure.chapterById(chapterId);
    final complete = chapter.stageIds.every(
      (id) => _stageProgress[id]?.completed ?? false,
    );
    if (!complete) return;

    _state = _state.copyWith(
      claimedChapterChestIds: {..._state.claimedChapterChestIds, chapterId},
    );
    _dirty = true;
    await save();
  }

  // ─────────────────────── مراسم فتح العالم ───────────────────────

  /// العوالم المفتوحة فعليا التي لم تُعرَض مراسمها بعد — عادة عنصر واحد
  /// أو لا شيء؛ أكثر من واحد ممكن نظريا (مثلا بعد دمج سحابي فتح عدة
  /// عوالم دفعة واحدة على جهاز لم يُشغَّل منذ فترة) وعلى الواجهة عرضها
  /// تباعا لا دفعة واحدة.
  Set<int> get worldsPendingCeremony =>
      _state.unlockedWorldIds.difference(_state.ceremonyShownForWorldIds);

  Future<void> markCeremonyShown(int worldId) async {
    if (_state.ceremonyShownForWorldIds.contains(worldId)) return;
    _state = _state.copyWith(
      ceremonyShownForWorldIds: {..._state.ceremonyShownForWorldIds, worldId},
    );
    _dirty = true;
    await save();
  }

  // ─────────────────────── جسر مؤقت من نظام اللعب القديم ───────────────────────

  /// جسر مؤقت بحت: شاشة اللعب الحالية (game_screen.dart) لا تزال تعمل
  /// على النظام القديم (GameLevel/levels.json) ولا تُبلِّغ هذا النظام
  /// الجديد بأي تفاصيل حقيقية عن المحاولة (كم تلميحا استُخدم فعلا، كم
  /// كلمة إضافية وُجدت). حين تكتشف شاشة الخريطة الجديدة أن مرحلة قديمة
  /// اكتملت (عبر تقدّم maxUnlocked القديم)، تستدعي هذه الدالة بدل
  /// recordStageCompletion مباشرة كي يبقى القرار المحافظ في مكان واحد
  /// موثَّق، لا متناثرا في كود الواجهة: تسجّل الإتمام وحده، صفر كلمات
  /// إضافية، وتفترض عمدا تلميحا واحدا على الأقل (غير صفر) فلا تُسجَّل
  /// «محاولة نظيفة» لم تُعرَف فعلا. لا تمسّ اقتصاد العملات إطلاقا.
  StageCompletionResult recordBasicCompletionFromLegacyBridge({
    required int stageId,
    required DateTime now,
  }) => recordStageCompletion(
    stageId: stageId,
    bonusWordsFoundThisRun: const {},
    hintsUsedThisRun: 1,
    timeMs: 0,
    now: now,
  );

  /// كتابة دفعة واحدة لكلا المفتاحين. لا تكتب شيئا إن لم يتغيّر شيء
  /// منذ آخر كتابة.
  Future<void> save() async {
    if (!_dirty) return;
    final stageJson = jsonEncode(
      _stageProgress.map((k, v) => MapEntry(k.toString(), v.toJson())),
    );
    await _prefs.setString(_kPlayerStateKey, jsonEncode(_state.toJson()));
    await _prefs.setString(_kStageProgressKey, stageJson);
    _dirty = false;
  }

  /// يعيد التقدّم (v2) إلى حالة أول تشغيل — في الذاكرة وعلى القرص معا.
  ///
  /// يُستدعى بعد [ProgressStore.resetProgress] مباشرة: تلك تمسح
  /// المفاتيح، وهذه تمسح النسخة المحمَّلة في الذاكرة ثم تكتب حالة
  /// بدئية نظيفة. علامة الهجرة تُضبط هنا كي لا تُعاد هجرة v1→v2 على
  /// بيانات ممسوحة أصلا.
  Future<void> resetToInitial() async {
    _state = PlayerState.initial();
    _stageProgress = {};
    _dirty = true;
    await _prefs.setBool(_kMigrationDoneFlag, true);
    await _prefs.setInt(_kPendingWelcomeChestKey, 0);
    await save();
  }
}
