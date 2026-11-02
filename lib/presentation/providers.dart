import 'dart:async';

import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/balance_config.dart';
import '../core/app_language.dart';
import '../core/store_review.dart';
import '../data/achievement_models.dart';
import '../data/ad_service.dart';
import '../data/analytics/analytics_event.dart';
import '../data/analytics/analytics_service.dart';
import '../data/ads/ad_format.dart';
import '../data/ads/ad_pacing.dart';
import '../data/ads/ad_policy.dart';
import '../data/ads/policy_gated_ad_service.dart';
import '../data/ads/rewarded_ads.dart';
import '../data/audio_service.dart';
import '../data/challenge_models.dart';
import '../data/challenge_progress.dart';
import '../data/config/feature_flags.dart';
import '../data/economy/chapter_chest.dart';
import '../data/economy/economy_models.dart';
import '../data/economy/economy_service.dart';
import '../data/economy/stage_reward.dart';
import '../data/games_services_sync.dart';
import '../data/iap_service.dart';
import '../data/level_repository.dart';
import '../data/literature_models.dart';
import '../data/login_calendar.dart';
import '../data/missions/mission_engine.dart';
import '../data/missions/mission_models.dart';
import '../data/models.dart';
import '../data/notifications/notification_engine.dart';
import '../data/notifications/notification_models.dart';
import '../data/notifications/notification_service.dart';
import '../data/progress_store.dart';
import '../data/progression/player_level_curve.dart';
import '../data/progression/player_state.dart';
import '../data/progression/progression_engine.dart';
import '../data/progression/progression_rules.dart';
import 'widgets/mock_ad_service.dart';
import '../data/progression/stage_progress.dart';
import '../data/progression/world_defs.dart';
import '../data/progression_repository.dart';
import '../data/rewards/reward_track.dart';
import '../data/widget/home_widget_service.dart';
import '../data/widget/widget_activation.dart';
import '../data/widget/widget_data.dart';
import '../data/widget/widget_data_builder.dart';
import '../data/social_models.dart';
import '../data/store/first_purchase.dart';
import '../data/store/starter_pack.dart';
import '../data/store/store_catalog.dart';
import '../data/social_repository.dart';
import '../data/streak/streak_engine.dart';
import '../data/streak/streak_models.dart';
import '../data/wheel/wheel_models.dart';

/// يُستبدل بقيمة حقيقية في main قبل تشغيل التطبيق
final progressStoreProvider = Provider<ProgressStore>(
  (ref) => throw UnimplementedError('overridden in main'),
);

// ─────────────────────── التحليلات والإعداد عن بعد ───────────────────────

/// ناقل الأحداث. يُستبدل في main بناقل حقيقي؛ الافتراضي هنا ناقل صامت
/// كي لا يحتاج أي اختبار ودجة إلى تجاوزه، ولا يحاول أي شاشة الوصول
/// لتخزين غير موجود.
final analyticsProvider = Provider<AnalyticsService?>((ref) => null);

/// تسجيل حدث من أي مكان. آمن حين لا ناقل (الاختبارات): لا يفعل شيئا.
extension LogEvent on WidgetRef {
  void logEvent(String name, [Map<String, Object?> props = const {}]) =>
      read(analyticsProvider)?.log(name, props);
}

/// مفاتيح الإيقاف عن بعد. الافتراضي «كل شيء مُشغَّل» — لاعب بلا اتصال
/// يرى اللعبة كاملة، والمفتاح أداة إطفاء عند عطل لا شرط تشغيل.
final featureFlagsProvider = Provider<FeatureFlags>(
  (ref) => const FeatureFlags.allOn(),
);

/// مستودع التقدّم — ومحفظة اللاعب معه: العملات وشحنات التلميح وXP كلها
/// تعيش في [PlayerState.wallet] هنا، ولا يمسّها شيء إلا عبر
/// [ProgressionRepository.runEconomy] (أي عبر EconomyService).
///
/// يبني نفسه من [progressStoreProvider] بدل أن يرمي `UnimplementedError`
/// بانتظار تجاوز من `main`: مزوّد لا يعمل إلا بتجاوز يدوي يعني أن كل
/// اختبار وكل مزوّد آخر يحتاج معرفة سرّ تركيبه — وهو سبب بقاء دفترين
/// للعملات جنبا إلى جنب طوال هذا الوقت. `main` لا يزال يتجاوزه بنسخة
/// حمّلها وحفظها بانتظار فعلي، فيبقى الإقلاع الحقيقي كما هو.
final progressionRepositoryProvider = Provider<ProgressionRepository>((ref) {
  final store = ref.watch(progressStoreProvider);
  return ProgressionRepository.loadSync(prefs: store.prefs, legacy: store);
});

final progressionStructureProvider = Provider<ProgressionStructure>(
  (ref) => ref.watch(progressionRepositoryProvider).structure,
);

/// لقطة واحدة تجمع حالة اللاعب وتقدّم كل مراحله معا — عمدا كائن واحد
/// (لا مزوّدان منفصلان) كي تُعاد بناء أي واجهة تراقب أيّا منهما بدقّة في
/// نفس اللحظة، لا بحالة عابرة يتوافق فيها أحدهما مع القديم والآخر مع
/// الجديد
class ProgressionSnapshot {
  final PlayerState state;
  final Map<int, StageProgress> stageProgress;

  const ProgressionSnapshot({required this.state, required this.stageProgress});
}

class ProgressionNotifier extends Notifier<ProgressionSnapshot> {
  @override
  ProgressionSnapshot build() =>
      _snapshotOf(ref.read(progressionRepositoryProvider));

  ProgressionSnapshot _snapshotOf(ProgressionRepository repo) =>
      ProgressionSnapshot(state: repo.state, stageProgress: repo.stageProgress);

  /// يثبّت كلمة إضافية لحظة اكتشافها ويعيد هل تستحقّ عملاتها.
  ///
  /// شاشة اللعب تدفع عند الاكتشاف، فيجب أن يُكتب الدفتر عند الاكتشاف
  /// أيضا — راجع [ProgressionRepository.recordBonusWordFound]. الحفظ
  /// فوري هنا لا مؤجَّل: المغادرة قبل الإتمام هي بالضبط الحالة التي
  /// نحمي منها، فلا يصحّ أن تنتظر الكتابةُ إتماما قد لا يقع.
  Future<bool> recordBonusWordFound(int stageId, String word) async {
    final repo = ref.read(progressionRepositoryProvider);
    final isNew = repo.recordBonusWordFound(stageId, word);
    if (!isNew) return false;
    await repo.save();
    state = _snapshotOf(repo);
    return true;
  }

  void _refresh() {
    state = _snapshotOf(ref.read(progressionRepositoryProvider));
  }

  /// يسجّل إتمام مرحلة عبر المحرّك الصرف، يمنح مكافأة العملات عبر
  /// [EconomyService]، يحفظ فورا، ويحدّث كل من يراقب.
  ///
  /// [coinsAwarded] في النتيجة المعادة هو ما دخل المحفظة فعلا — تعرضه
  /// شاشة الإتمام بدل رقم تحسبه بنفسها.
  Future<StageCompletionResult> recordStageCompletion({
    required int stageId,
    required Set<String> bonusWordsFoundThisRun,
    required int hintsUsedThisRun,
    required int timeMs,
    int coreWordsFound = 0,
  }) async {
    final repo = ref.read(progressionRepositoryProvider);
    final before = repo.state;
    final result = repo.recordStageCompletion(
      stageId: stageId,
      bonusWordsFoundThisRun: bonusWordsFoundThisRun,
      hintsUsedThisRun: hintsUsedThisRun,
      timeMs: timeMs,
      now: DateTime.now(),
    );
    _awardStageCoins(
      repo: repo,
      result: result,
      stageId: stageId,
      coreWordsFound: coreWordsFound,
      hintsUsedThisRun: hintsUsedThisRun,
    );
    await repo.save();

    // فتح الفصل/العالم يُكتشف بمقارنة ما قبل وما بعد لا بادّعاء الشاشة:
    // الفتح نتيجة قاعدة في المحرّك، وأي شاشة تدّعيه ستخطئ يوما.
    final analytics = ref.read(analyticsProvider);
    final newChapters = result.state.unlockedChapterIds.difference(
      before.unlockedChapterIds,
    );
    final newWorlds = result.state.unlockedWorldIds.difference(
      before.unlockedWorldIds,
    );
    for (final id in newChapters) {
      analytics?.log(Ev.chapterUnlocked, {'chapter_id': id});
    }
    for (final id in newWorlds) {
      analytics?.log(Ev.worldUnlocked, {'world_id': id});
    }
    for (final tier in result.jarRewardsGained) {
      analytics?.log(Ev.jarFilled, {
        'tier': tier.tier,
        'coins': tier.coins,
        'cosmetic': tier.cosmeticRewardId,
      });
    }
    analytics?.updateContext(
      playerLevel: PlayerLevelCurve.currentLevel(result.state.wallet.xp),
    );

    _refresh();
    return result;
  }

  /// يمنح عملات إتمام المرحلة من [EconomyService] — وهو المكان الوحيد
  /// الذي تتحوّل فيه أرقام `BalanceConfig.coins*` إلى رصيد فعلي.
  ///
  /// كل سطر من التفصيل يُمنح على حدة كي يبقى لكل مصدر حدثه التحليلي
  /// الخاص (لا مبلغ إجمالي مبهم)، ثم يُضاف فرق مضاعف الشراء الأول مرة
  /// واحدة على المجموع — لا على كل سطر، وإلا ضخّم التقريب لأعلى المكافأة
  /// بحسب عدد سطورها لا بحسب قيمتها.
  void _awardStageCoins({
    required ProgressionRepository repo,
    required StageCompletionResult result,
    required int stageId,
    required int coreWordsFound,
    required int hintsUsedThisRun,
  }) {
    final stageDef = repo.structure.stageById(stageId);
    final breakdown = repo.runEconomy(
      (economy) => economy.computeStageReward(
        StageResult(
          worldId: stageDef.worldId,
          isBossStage: stageDef.isBoss,
          isReplay: result.wasAlreadyCompleted,
          coreWordsFound: coreWordsFound,
          // صفر عمدا: شاشة اللعب تمنح عملات الكلمة الإضافية لحظة
          // اكتشافها (quoteBonusWordCoins)، فاحتسابها هنا ثانية دفعتان
          // لكلمة واحدة
          newBonusWordsFoundThisRun: 0,
          isPerfect: hintsUsedThisRun == 0,
          chapterJustCompleted: result.chapterCompletedThisRun,
          worldJustCompleted: result.worldCompletedThisRun,
          // صندوق الفصل يفتحه اللاعب بنقرة (claimChapterChest) لا آليا
          chapterChestAlreadyRolled: 0,
        ),
      ),
    );

    final points = ref.read(pointsProvider.notifier);
    final lines = <(int, String)>[
      (breakdown.stageClearCoins, 'stage_clear'),
      (breakdown.coreWordCoins, 'core_words'),
      (breakdown.perfectBonusCoins, 'perfect_stage'),
      (breakdown.bossBonusCoins, 'boss_stage'),
      (breakdown.chapterCompleteCoins, 'chapter_complete'),
      (breakdown.worldCompleteCoins, 'world_complete'),
    ];
    for (final (amount, reason) in lines) {
      points.add(amount, reason: reason);
    }

    final base = breakdown.total;
    final granted = FirstPurchase.applyMultiplier(
      base,
      multiplier: ref.read(coinMultiplierProvider),
    );
    if (granted > base) {
      points.add(granted - base, reason: 'first_purchase_bonus');
    }
    if (granted > 0) {
      ref
          .read(achievementsProvider.notifier)
          .bump(StatKey.pointsEarned, granted);
    }
    _lastStageCoinsAwarded = granted;
  }

  /// ما مُنح فعلا في آخر [recordStageCompletion] — تقرؤه شاشة الإتمام
  int _lastStageCoinsAwarded = 0;
  int get lastStageCoinsAwarded => _lastStageCoinsAwarded;

  /// جسر مؤقت من شاشة اللعب القديمة — راجع الشرح في
  /// progression_repository.dart:recordBasicCompletionFromLegacyBridge.
  /// يعيد النتيجة (خلافا للسابق) كي يستطيع المستدعي منح مكافآت جرّة
  /// بلغت عتبتها هذه المحاولة — راجع stage_path_screen.dart
  Future<StageCompletionResult> recordBasicCompletionFromLegacyBridge(
    int stageId,
  ) async {
    final repo = ref.read(progressionRepositoryProvider);
    final result = repo.recordBasicCompletionFromLegacyBridge(
      stageId: stageId,
      now: DateTime.now(),
    );
    await repo.save();
    _refresh();
    return result;
  }

  /// يستلم صندوق الفصل ويمنح عملاته، ويعيد ما مُنح فعلا (0 إن كان
  /// مُستلَما أصلا أو الفصل غير مكتمل).
  ///
  /// المبلغ يُسحب من التوزيع المثلثي في economy/chapter_chest.dart —
  /// وهو ما كان ينقص: المستودع كان يعلّم الصندوق «مُستلَما» بلا أن
  /// يضيف عملة واحدة إلى المحفظة، فيفتحه اللاعب ولا يرى شيئا.
  Future<int> claimChapterChest(int chapterId) async {
    final repo = ref.read(progressionRepositoryProvider);
    if (repo.state.claimedChapterChestIds.contains(chapterId)) return 0;

    await repo.claimChapterChest(chapterId);
    _refresh();
    // لم يُستلَم فعلا (فصل غير مكتمل مثلا) — لا عملات
    if (!repo.state.claimedChapterChestIds.contains(chapterId)) return 0;

    // مبلغ ثابت لهذا الفصل لا قرعة عند الفتح: البطاقة تعرض الرقم نفسه
    // قبل الفتح (راجع ChapterChest.amountFor)، فما وُعد به هو ما يُقبَض
    final coins = ChapterChest.amountFor(chapterId);
    ref.read(pointsProvider.notifier).add(coins, reason: 'chapter_chest');
    ref.read(achievementsProvider.notifier).bump(StatKey.pointsEarned, coins);
    return coins;
  }

  Future<void> markCeremonyShown(int worldId) async {
    await ref.read(progressionRepositoryProvider).markCeremonyShown(worldId);
    _refresh();
  }
}

final progressionProvider =
    NotifierProvider<ProgressionNotifier, ProgressionSnapshot>(
      ProgressionNotifier.new,
    );

final levelRepositoryProvider = Provider((ref) => LevelRepository());

/// مشغّل الصوت — يعيش طوال عمر التطبيق ويوقف نفسه عند التخفّي
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService(ref.watch(progressStoreProvider));
  ref.onDispose(service.dispose);
  return service;
});

final levelsProvider = FutureProvider<List<GameLevel>>(
  (ref) => ref.watch(levelRepositoryProvider).loadLevels(),
);

/// تصنيف الاقتصاد لسبب الكسب النصّي. النصّ يبقى هو ما يُرسَل في
/// التحليلات (أدقّ وأوسع)، والتعداد هو ما يفهمه محرّك الاقتصاد.
EarnReason _earnReasonFor(String reason) => switch (reason) {
  'stage_clear' => EarnReason.stageClear,
  'core_words' => EarnReason.coreWord,
  'bonus_word' => EarnReason.bonusWord,
  'perfect_stage' => EarnReason.perfectStageBonus,
  'boss_stage' => EarnReason.bossStageBonus,
  'chapter_complete' => EarnReason.chapterComplete,
  'chapter_chest' => EarnReason.chapterChest,
  'world_complete' => EarnReason.worldComplete,
  _ => EarnReason.other,
};

SpendReason _spendReasonFor(String reason) => switch (reason) {
  'hint' => SpendReason.hint,
  'reveal_entire_word' => SpendReason.revealEntireWord,
  'skip_stage' => SpendReason.skipStage,
  'streak_freeze' => SpendReason.streakFreeze,
  'jar_booster' => SpendReason.jarBooster,
  'cosmetic' => SpendReason.cosmetic,
  _ => SpendReason.other,
};

/// كل حركة عملات تمرّ من هنا، فهذه هي النقطة الوحيدة التي تُصدَّر منها
/// أحداث coins_earned/coins_spent. حدث في كل نقطة نداء كان سيعني حركة
/// غير مسجّلة عند أول نداء جديد يُضاف بعد شهور.
///
/// الرصيد نفسه يعيش في [PlayerState.wallet] لا في `ProgressStore.points`:
/// هذا المزوّد واجهة Riverpod فوق [EconomyService]، والمحرّك هو من
/// يجمع ويطرح فعلا. كان هنا دفتر ثانٍ مستقل تماما، فبقيت كل أرقام
/// `BalanceConfig.coins*` معطّلة بلا أثر على اللعب.
class PointsNotifier extends Notifier<int> {
  @override
  int build() => ref.read(progressionRepositoryProvider).state.wallet.coins;

  ProgressionRepository get _repo => ref.read(progressionRepositoryProvider);

  /// يعيد قراءة الرصيد من المحفظة بعد أي عملية غيّرتها
  void _commit(ProgressionRepository repo) {
    state = repo.state.wallet.coins;
    ref.read(analyticsProvider)?.updateContext(coinBalance: state);
    // الكتابة غير منتظَرة: القيمة صارت في الذاكرة فورا، والقرص يلحق —
    // نفس نمط بقية الكتابات في هذا الملف
    unawaited(repo.save());
  }

  void add(int amount, {String reason = 'unspecified'}) {
    if (amount <= 0) return; // المحرّك يرمي على السالب، ولا معنى للصفر
    final repo = _repo;
    repo.runEconomy((economy) => economy.award(amount, _earnReasonFor(reason)));
    _commit(repo);
    ref.read(analyticsProvider)?.log(Ev.coinsEarned, {
      'amount': amount,
      'reason': reason,
      'balance': state,
    });
  }

  /// يخصم النقاط إن كان الرصيد كافيا، ويعيد نجاح العملية.
  ///
  /// المحاولة الفاشلة تُسجَّل أيضا: «حاول ولم يستطع» هي بالضبط الإشارة
  /// التي تقول أين يخنق الاقتصاد اللاعب.
  bool spend(int amount, {String reason = 'unspecified'}) {
    final repo = _repo;
    final result = repo.runEconomy(
      (economy) => economy.spend(amount, _spendReasonFor(reason)),
    );
    if (result.isFailure) {
      ref.read(analyticsProvider)?.log(Ev.coinsSpent, {
        'amount': amount,
        'reason': reason,
        'balance': state,
        'failed': true,
      });
      return false;
    }
    _commit(repo);
    ref.read(analyticsProvider)?.log(Ev.coinsSpent, {
      'amount': amount,
      'reason': reason,
      'balance': state,
    });
    return true;
  }
}

final pointsProvider = NotifierProvider<PointsNotifier, int>(
  PointsNotifier.new,
);

class MaxUnlockedNotifier extends Notifier<int> {
  @override
  int build() => ref.read(progressStoreProvider).maxUnlocked;

  void unlockUpTo(int levelId) {
    if (levelId <= state) return;
    state = levelId;
    ref.read(progressStoreProvider).setMaxUnlocked(state);
  }
}

final maxUnlockedProvider = NotifierProvider<MaxUnlockedNotifier, int>(
  MaxUnlockedNotifier.new,
);

class BonusJarNotifier extends Notifier<int> {
  @override
  int build() => ref.read(progressStoreProvider).bonusJar;

  void add(int count) {
    state += count;
    ref.read(progressStoreProvider).setBonusJar(state);
  }
}

final bonusJarProvider = NotifierProvider<BonusJarNotifier, int>(
  BonusJarNotifier.new,
);

/// شحنات التلميح المجانية المملوكة: تُكسب من عجلة الحظ وصندوق المهمات
/// وحزمة البداية وكل خمس مراحل، وتُستهلك قبل العملات عند كل تلميح.
///
/// تعيش في [PlayerWallet.hintCharges] كالعملات تماما، وتمرّ بنفس
/// المحرّك — لا في مفتاح `banked_hint_charges` منفصل كما كانت.
class HintChargesNotifier extends Notifier<int> {
  @override
  int build() =>
      ref.read(progressionRepositoryProvider).state.wallet.hintCharges;

  /// تُستدعى بعد أي مسار آخر غيّر شحنات المحفظة (منحة كل خمس مراحل)
  void refresh() =>
      state = ref.read(progressionRepositoryProvider).state.wallet.hintCharges;

  void add(int count) {
    if (count <= 0) return;
    final repo = ref.read(progressionRepositoryProvider);
    repo.runEconomy((economy) => economy.grantHintCharges(count));
    state = repo.state.wallet.hintCharges;
    unawaited(repo.save());
  }

  /// يستهلك شحنة واحدة. يعيد false إن لا رصيد — عندها يدفع اللاعب عملات.
  bool consume() {
    final repo = ref.read(progressionRepositoryProvider);
    final consumed = repo.runEconomy((economy) => economy.consumeHintCharge());
    if (!consumed) return false;
    state = repo.state.wallet.hintCharges;
    unawaited(repo.save());
    return true;
  }
}

final hintChargesProvider = NotifierProvider<HintChargesNotifier, int>(
  HintChargesNotifier.new,
);

/// هل قيّم اللاعب التطبيق؟ true يعني لا تُعرض عليه نافذة التقييم بعد
/// اليوم إطلاقا. لا نملك تأكيدا من المتجر بأنه قيّم فعلا (لا واجهة
/// تعطيه)، فالمقصود حرفيا: «ضغط قيّم وذهب إلى المتجر» — وهو أقصى ما
/// يمكن معرفته، وتكرار السؤال بعده إزعاج بلا فائدة.
class AppRatedNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(progressStoreProvider).appRated;

  /// يفتح صفحة التقييم في متجر المنصّة ويعلّم أن اللاعب قيّم.
  ///
  /// يجرّب الروابط بالترتيب: تطبيق المتجر أولا ثم الويب — جهاز بلا
  /// تطبيق متجر (أو محاكي) يجب أن يصل للصفحة لا أن يبتلع الضغطة.
  Future<bool> openStoreAndMark() async {
    final urls = StoreReview.urlsFor(
      isIOS: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
    );
    var opened = false;
    for (final url in urls) {
      try {
        opened = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (opened) break;
      } catch (_) {
        // رابط لا يفتح على هذا الجهاز — نجرّب التالي بهدوء
      }
    }
    // يُعلَّم حتى لو تعذّر الفتح: اللاعب أبدى موقفه بالضغط، وإعادة
    // السؤال عليه بعد فشل تقني ليست خطأه
    state = true;
    await ref.read(progressStoreProvider).setAppRated(true);
    return opened;
  }
}

final appRatedProvider = NotifierProvider<AppRatedNotifier, bool>(
  AppRatedNotifier.new,
);

/// اسم اللاعب المحلّي — يُسأل عنه مرة عند أول تشغيل (راجع
/// askPlayerNameIfNeeded في home_screen.dart). null يعني لم يُدخِل اسما.
class PlayerNameNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(progressStoreProvider).playerName;

  Future<void> set(String name) async {
    final trimmed = name.trim();
    state = trimmed.isEmpty ? null : trimmed;
    final store = ref.read(progressStoreProvider);
    await store.setPlayerName(trimmed);
    await store.setPlayerNameAsked(true);
    // إن كان الحساب الاجتماعي متاحا فليحمل نفس الاسم — بلا هذا يرى
    // أصدقاؤه اسما مختلفا عمّا يراه هو في رئيسيته
    if (trimmed.isNotEmpty) {
      unawaited(ref.read(socialRepositoryProvider).setDisplayName(trimmed));
    }
  }

  Future<void> skip() async {
    await ref.read(progressStoreProvider).setPlayerNameAsked(true);
  }
}

final playerNameProvider = NotifierProvider<PlayerNameNotifier, String?>(
  PlayerNameNotifier.new,
);

/// عدد الفصول المكتملة بالكامل عبر كل العوالم — شارة الرئيسية.
///
/// يُحسب من تقدّم المراحل مباشرة لا من عدّاد محفوظ: العدّاد المحفوظ
/// يمكن أن ينحرف عن الحقيقة (هجرة، مزامنة، إصلاح فجوة)، والحساب هنا
/// رخيص (40 فصلا) ويستحيل أن يكذب.
final chaptersCompletedProvider = Provider<int>((ref) {
  final snapshot = ref.watch(progressionProvider);
  final structure = ref.watch(progressionStructureProvider);
  var count = 0;
  for (final chapter in structure.chapters) {
    if (ProgressionRules.isChapterComplete(chapter, snapshot.stageProgress)) {
      count++;
    }
  }
  return count;
});

/// عدد العوالم المكتملة بالكامل — بوّابة فتح الأنماط اللغوية في
/// الرئيسية. يُحسب من تقدّم المراحل لا من `unlockedWorldIds`: فتح العالم
/// التالي يعني «بدأتَه»، والفتح هنا يكافئ «أتممتَه».
final worldsCompletedProvider = Provider<int>((ref) {
  final snapshot = ref.watch(progressionProvider);
  final structure = ref.watch(progressionStructureProvider);
  var count = 0;
  for (final world in structure.worlds) {
    if (ProgressionRules.isWorldComplete(
      world,
      structure,
      snapshot.stageProgress,
    )) {
      count++;
    }
  }
  return count;
});

/// عدّاد الكلمات الإضافية الجديدة عبر كل المراحل، ومكافأة كل خمس منها.
///
/// الحالة هي المجموع التراكمي (لا يُصفَّر)، والمكافأة تقع كلما عبر
/// المجموع مضاعفا لـ[BalanceConfig.bonusWordMilestoneEvery]. لا يُستدعى
/// [register] إلا لكلمة لم يسبق اكتشافها في مرحلتها — التكرار لا يُحتسب.
class BonusWordCounterNotifier extends Notifier<int> {
  @override
  int build() => ref.read(progressStoreProvider).bonusWordsCounted;

  /// يسجّل كلمة إضافية جديدة واحدة. يعيد عدد الكلمات عند بلوغ مكافأة
  /// (5، 10، 15..) أو null إن لم تكتمل الخمس بعد.
  int? register() {
    final total = state + 1;
    state = total;
    ref.read(progressStoreProvider).setBonusWordsCounted(total);
    final every = BalanceConfig.bonusWordMilestoneEvery;
    if (every > 0 && total % every == 0) return total;
    return null;
  }
}

final bonusWordCounterProvider =
    NotifierProvider<BonusWordCounterNotifier, int>(
      BonusWordCounterNotifier.new,
    );

/// خدمة الدفع. الافتراضي محاكاة (للاختبارات، ولا تبيع شيئا في الإصدار)؛
/// main.dart يتجاوزه بـRevenueCat على الهاتف.
final iapServiceProvider = Provider<IapService>((ref) {
  final service = MockIapService();
  ref.onDispose(service.dispose);
  return service;
});

/// ما يُباع الآن بأسعار Google Play — بعملة اللاعب وبالرقم الذي سيدفعه.
class StoreState {
  final Map<String, String> prices;

  const StoreState(this.prices);

  /// null = لا يُعرض للبيع (المنتج غير متاح الآن أو لا متجر أصلا)
  String? priceOf(String sku) => prices[sku];

  bool get anyForSale => prices.isNotEmpty;
}

/// المتجر: الأسعار، والتسليم.
///
/// التسليم هنا لا في الشاشة: الشراء الحقيقي قد يكتمل والمتجر مغلق (دفع
/// نقدي يُعتمد لاحقا، تطبيق أُغلق وسط الدفع، تثبيت جديد يستعيد ما اشتُري)،
/// فتسلّمه خدمة الدفع عبر [_fulfill] الموصول ما دام المزوّد حيّا — وجذر
/// التطبيق يبقيه حيّا من الإقلاع (HurufApp).
class StoreNotifier extends Notifier<StoreState> {
  @override
  StoreState build() {
    final iap = ref.watch(iapServiceProvider);
    iap.attachFulfiller(_fulfill);
    void onChange() => state = _read(iap);
    iap.changes.addListener(onChange);
    ref.onDispose(() {
      iap.changes.removeListener(onChange);
      iap.detachFulfiller(_fulfill);
    });
    return _read(iap);
  }

  StoreState _read(IapService iap) =>
      StoreState({for (final sku in SkuIds.forSale) sku: ?iap.priceOf(sku)});

  Future<PurchaseResult> buy(String sku) =>
      ref.read(iapServiceProvider).buy(sku);

  /// يعيد سؤال Google Play عمّا لم يصل عند الإقلاع — الأسعار تصل عبر
  /// [IapService.changes] كالعادة
  Future<void> refresh() => ref.read(iapServiceProvider).refresh();

  /// يمنح ما اشتُري. يُستدعى من خدمة الدفع مرة واحدة لكل شراء موثَّق.
  Future<Delivery> _fulfill(String sku, {required bool fullDelivery}) async {
    if (!fullDelivery) {
      await _restoreOwnership(sku);
      return Delivery.none;
    }
    final store = ref.read(progressStoreProvider);
    final purchase = ref.read(purchaseStateProvider.notifier);
    var coins = 0;
    switch (sku) {
      case SkuIds.removeAds:
        ref.read(adsRemovedProvider.notifier).setPurchased();
        coins = StoreCatalog.removeAdsGiftCoins;
        ref.read(pointsProvider.notifier).add(coins, reason: 'iap_$sku');
      case SkuIds.starterPack:
        // الزيّ والإطار «معلَّقان» حتى يُبنى مخزون الأزياء (راجع
        // pendingCosmeticUnlocks في progress_store.dart)
        await store.addPendingCosmeticUnlock(StoreCatalog.starterPackAvatarId);
        await store.addPendingCosmeticUnlock(StoreCatalog.starterPackFrameId);
        await purchase.markStarterPackOwned();
        // القسط الأول بلا مطالبة: من دفع للتوّ لا يُطلب منه نقرة أخرى
        coins =
            (await ref.read(starterPackProvider.notifier).claim())?.coins ?? 0;
      default:
        final pack = StoreCatalog.packById(sku);
        if (pack == null) return Delivery.none;
        coins = pack.coins;
        ref.read(pointsProvider.notifier).add(coins, reason: 'iap_$sku');
    }
    final first = await purchase.recordPurchase();
    return Delivery(coins: coins, firstPurchase: first);
  }

  /// شراء سُلِّم على تثبيت سابق يعود على هذا التثبيت: الملكية الدائمة
  /// وحدها. لا عملات ولا هدايا ولا مكافأة شراء أول — وإلا صارت إعادة
  /// التثبيت ماكينة عملات.
  Future<void> _restoreOwnership(String sku) async {
    final store = ref.read(progressStoreProvider);
    switch (sku) {
      case SkuIds.removeAds:
        if (!ref.read(adsRemovedProvider)) {
          ref.read(adsRemovedProvider.notifier).setPurchased();
        }
      case SkuIds.starterPack:
        if (store.starterPackOwned) break;
        // الأقساط تُعدّ مستلَمة قبل إعلان الملكية: مزوّد الأقساط يُعاد
        // بناؤه لحظة الملكية، ويجب أن يراها مكتملة
        await store.setStarterPackClaimedDays(StoreCatalog.starterPackDays);
        await store.addPendingCosmeticUnlock(StoreCatalog.starterPackAvatarId);
        await store.addPendingCosmeticUnlock(StoreCatalog.starterPackFrameId);
        await ref.read(purchaseStateProvider.notifier).markStarterPackOwned();
    }
    await ref.read(purchaseStateProvider.notifier).markHasPurchased();
  }
}

final storeProvider = NotifierProvider<StoreNotifier, StoreState>(
  StoreNotifier.new,
);

// ─────────────────────── لغة الواجهة ───────────────────────

/// لغة القوائم وما حولها — شاشة اللعب (عجلة الحروف وشبكة الكلمات) تبقى
/// عربية دوما بصرف النظر عن هذا الاختيار
class LanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => ref.read(progressStoreProvider).language == 'en'
      ? AppLanguage.en
      : AppLanguage.ar;

  void select(AppLanguage lang) {
    state = lang;
    ref.read(progressStoreProvider).setLanguage(lang.name);
  }

  void toggle() =>
      select(state == AppLanguage.ar ? AppLanguage.en : AppLanguage.ar);
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(
  LanguageNotifier.new,
);

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// حالة تقويم الدخول اليومي. [currentPosition] هو آخر موضع طُولِب به
/// *فعلا* (0 يعني لم يُطالَب قط) — بصرف النظر عن [canClaim]، فلا معنى
/// مزدوجا لحقل واحد كما كان سابقا.
class DailyRewardState {
  final bool canClaim;
  final int currentPosition;

  const DailyRewardState({
    required this.canClaim,
    required this.currentPosition,
  });

  int get nextPosition => currentPosition + 1;
  LoginCalendarReward get nextReward =>
      LoginCalendar.rewardForPosition(nextPosition);

  /// الموضع المعروض كـ"اليوم" في شريط الأيام — القادم إن لم يُطالَب به
  /// اليوم بعد، أو الحالي إن سبقت المطالبة
  int get todayPosition => canClaim ? nextPosition : currentPosition;
}

class DailyRewardNotifier extends Notifier<DailyRewardState> {
  @override
  DailyRewardState build() {
    final store = ref.read(progressStoreProvider);
    final today = _dateKey(DateTime.now());
    final last = store.dailyLastClaim;
    return DailyRewardState(
      canClaim: last != today,
      currentPosition: _migratedPosition(store),
    );
  }

  /// أول قراءة بعد إدخال الموضع المتصاعد الجديد: إن لم يُخزَّن بعد لكن
  /// وُجدت قيمة dailyStreakDay القديمة (لاعب عائد)، تُهاجَر كنقطة بداية
  /// كي لا يعود اللاعب للصفر — راجع تعليق المفتاح في progress_store.dart
  int _migratedPosition(ProgressStore store) =>
      store.dailyCalendarPosition ?? store.dailyStreakDay;

  /// يعيد المكافأة الممنوحة، أو null إن لم تكن متاحة
  LoginCalendarReward? claim() {
    if (!state.canClaim) return null;
    final store = ref.read(progressStoreProvider);
    final newPosition = state.nextPosition;
    final reward = state.nextReward;

    store.setDailyLastClaim(_dateKey(DateTime.now()));
    store.setDailyCalendarPosition(newPosition);
    ref.read(pointsProvider.notifier).add(reward.coins, reason: 'daily_reward');
    ref.read(analyticsProvider)?.log(Ev.dailyRewardClaimed, {
      'position': newPosition,
      'coins': reward.coins,
      'shards': reward.cosmeticShards,
    });
    if (reward.cosmeticShards > 0) {
      store.setCosmeticShards(store.cosmeticShards + reward.cosmeticShards);
    }

    state = DailyRewardState(canClaim: false, currentPosition: newPosition);
    return reward;
  }
}

final dailyRewardProvider =
    NotifierProvider<DailyRewardNotifier, DailyRewardState>(
      DailyRewardNotifier.new,
    );

// ─────────────────────── مسار الجوائز ───────────────────────
//
// ثلاث طبقات محدودة العدد تنتهي بعد ستة أشهر — راجع
// lib/data/rewards/reward_track.dart للجدول الزمني وقواعد الأهلية
// كاملة. هنا الربط وحده: قراءة/كتابة التخزين، ومنح الألماس، والتسجيل.

class RewardTrackNotifier extends Notifier<RewardTrackState> {
  @override
  RewardTrackState build() {
    final store = ref.read(progressStoreProvider);
    final saved = RewardTrackState.decode(store.rewardTrackJson);
    if (saved != null) return saved;

    // أول لقاء بالمسار — يبدأ من *اليوم* لا من يوم تثبيت اللعبة: لاعب
    // قديم يبدأ مساره كاملا الآن، لا وقد انقضت مواعيده كلها بلا أن يرى
    // منها شيئا. تُكتب البداية فورا كي لا يتزحزح اليوم صفر مع كل تشغيل.
    final fresh = RewardTrackState.fresh(DateTime.now());
    unawaited(store.setRewardTrackJson(fresh.encode()));
    return fresh;
  }

  /// حالة الطبقات الثلاث الآن — الواجهة تعرضها كما هي بلا حساب
  List<RewardTierStatus> statusesNow() =>
      RewardTrackEngine.statuses(state, DateTime.now());

  /// يعيد عدد الألماسات الممنوحة، أو null إن لم تكن الطبقة جاهزة (يوم
  /// تغيّر تحت اللاعب، أو ضغطتان متلاحقتان على نفس الزر)
  int? claim(RewardTier tier) {
    final now = DateTime.now();
    final status = RewardTrackEngine.statusOf(tier, state, now);
    if (!status.isReady) return null;

    final coins = tier.coins;
    state = RewardTrackEngine.claim(tier, state, now);
    ref.read(progressStoreProvider).setRewardTrackJson(state.encode());
    ref
        .read(pointsProvider.notifier)
        .add(coins, reason: 'reward_track_${tier.name}');
    ref.read(analyticsProvider)?.log(Ev.rewardTrackClaimed, {
      'tier': tier.name,
      'claim_number': status.claimed + 1,
      'coins': coins,
    });
    return coins;
  }
}

final rewardTrackProvider =
    NotifierProvider<RewardTrackNotifier, RewardTrackState>(
      RewardTrackNotifier.new,
    );

/// النقطة الحمراء على تبويب الجوائز: طبقة واحدة جاهزة على الأقل.
///
/// يُعاد بناؤها تلقائيا مع كل مطالبة (`watch` لا `read`)، و[refresh]
/// لحالة واحدة لا تلتقطها: منتصف الليل يمرّ والتطبيق مفتوح، فتصير جائزة
/// اليوم التالي جاهزة بلا أن يتغيّر شيء في الحالة المخزَّنة.
class RewardTrackPendingNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(rewardTrackProvider);
    return _anyReady();
  }

  bool _anyReady() => RewardTrackEngine.statuses(
    ref.read(rewardTrackProvider),
    DateTime.now(),
  ).any((s) => s.isReady);

  void refresh() => state = _anyReady();
}

final rewardTrackPendingProvider =
    NotifierProvider<RewardTrackPendingNotifier, bool>(
      RewardTrackPendingNotifier.new,
    );

/// سياسة قوالب الإعلان (data/ads/ad_policy.dart). ثابتة طوال التشغيل: لا
/// الإعداد عن بعد ولا التخزين يغيّرانها. main.dart يتجاوزها بالسياسة الفعلية
/// ([AdFormatPolicy.effective]) — «لا شيء» لنسخة إصدار بلا معرّفات AdMob —
/// وهي نفسها التي تحرس خدمة الإعلانات، فلا يظهر زرّ لإعلان لن يأتي.
final adFormatPolicyProvider = Provider<AdFormatPolicy>(
  (ref) => AdFormatPolicy.currentBuild,
);

/// طبقة الإعلانات، خلف بوّابة السياسة دوما. الافتراضي محاكاة كي تعمل
/// الاختبارات بلا تجاوز؛ main.dart يتجاوزه بـAdMobAdService (مغلّفة بالبوّابة
/// نفسها) على الهاتف.
final adServiceProvider = Provider<AdService>(
  (ref) => PolicyGatedAdService(
    MockAdService(),
    policy: ref.watch(adFormatPolicyProvider),
  ),
);

/// هل يُعرض أي مدخل لإعلان جائزي الآن؟ السياسة *و* مفتاح الإيقاف عن بعد
/// معا: المفتاح يضيّق ما تسمح به السياسة ولا يوسّعه. كل زرّ «شاهد إعلانا»
/// وكل طلب مشاهدة يسأل هنا — لا يقرأ أحد المفتاح وحده.
final rewardedAdsAvailableProvider = Provider<bool>(
  (ref) =>
      ref.watch(adFormatPolicyProvider).allowsRewardAds &&
      ref.watch(featureFlagsProvider).rewardedAds,
);

/// هل يجوز طلب إعلان بيني أصلا؟ (السياسة + مفتاح الإيقاف). الإيقاع وإزالة
/// الإعلانات يقرّرهما [AdPacing] بعد ذلك.
final interstitialAdsAvailableProvider = Provider<bool>(
  (ref) =>
      ref.watch(adFormatPolicyProvider).allows(AdFormat.interstitial) &&
      ref.watch(featureFlagsProvider).interstitialAds,
);

/// اشتراك إزالة الإعلانات — مرة واحدة تشمل هدية نقاط
class AdsRemovedNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(progressStoreProvider).adsRemoved;

  void setPurchased() {
    state = true;
    ref.read(progressStoreProvider).setAdsRemoved(true);
  }
}

final adsRemovedProvider = NotifierProvider<AdsRemovedNotifier, bool>(
  AdsRemovedNotifier.new,
);

/// نوع الإعلان الذي يُعرض بعد إتمام مرحلة
enum AdCue {
  /// لا إعلان
  none,

  /// إعلان بيني
  interstitial,
}

/// هل وقع لعب فعلي في هذه الجلسة؟
///
/// «الجلسة» هنا عمر عملية التطبيق: المزوّد يُبنى بـfalse عند كل إقلاع
/// بارد ولا يُخزَّن إطلاقا — هذا بالضبط ما يمنع إعلانا على شاشة أول
/// افتتاح قبل أن يلعب اللاعب شيئا.
class SessionGameplayNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markGameplayStarted() {
    if (!state) state = true;
  }
}

final sessionGameplayProvider = NotifierProvider<SessionGameplayNotifier, bool>(
  SessionGameplayNotifier.new,
);

/// لحظة محميّة قائمة الآن (مكافأة يومية، عجلة، صندوق، ترقية مستوى).
/// الشاشة التي تعرض إحداها ترفع العلم وتخفضه، فيرى قرار الإعلان الحالة
/// الحقيقية بدل أن يخمّنها من رقم شاشة.
class ProtectedMomentNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// عدّاد لا bool: قد تتداخل لحظتان (صندوق فوقه ترقية مستوى)
  void begin() => state = state + 1;
  void end() => state = (state - 1).clamp(0, 1 << 30);
}

final protectedMomentProvider = NotifierProvider<ProtectedMomentNotifier, int>(
  ProtectedMomentNotifier.new,
);

/// بوّابة الإعلانات البينية — كل مسار في التطبيق يمرّ من هنا.
///
/// لا شاشة تقرّر بنفسها عرض إعلان: القرار كله في
/// [AdPacing.decideInterstitial]، وهذا المزوّد يجمع له مدخلاته من
/// التخزين والحالة الحيّة ثم يسجّل أثر القرار.
class InterstitialGateNotifier extends Notifier<int> {
  /// الحالة = عدد الإتمامات منذ آخر إعلان (تُعرض في التشخيص)
  @override
  int build() => ref.read(progressStoreProvider).completionsSinceInterstitial;

  /// يقدّم عدّاد الإيقاع بإتمام مرحلة واحد.
  ///
  /// يُستدعى عند الإتمام *فقط*. الفشل والمغادرة لا يُسجَّلان إطلاقا:
  /// القاعدة «لا إعلان بعد فشل» يجب ألّا تتحوّل إلى «الإعلان مؤجَّل
  /// للمرحلة التالية» — الفشل لا يقرّب الإعلان بشيء.
  void recordStageCleared() {
    state = state + 1;
    ref.read(progressStoreProvider).setCompletionsSinceInterstitial(state);
  }

  /// يطلب إعلانا بينيا الآن. يعيد [AdCue.interstitial] إن سمحت كل
  /// القواعد، بعد تسجيل وقت الإعلان وتصفير عدّاد الإيقاع.
  ///
  /// اللحظة الصحيحة للطلب هي بعد اكتمال تسلسل المكافأة ومغادرة اللاعب
  /// للمرحلة بنفسه — لا لحظة الإتمام.
  AdCue requestInterstitial({
    required int stageNumber,
    required bool stageCleared,
    required bool rewardSequenceComplete,
    DateTime? nowOverride,
  }) {
    final store = ref.read(progressStoreProvider);
    final now = nowOverride ?? DateTime.now();

    final decision = AdPacing.decideInterstitial(
      InterstitialRequest(
        stageNumber: stageNumber,
        completionsSinceLastInterstitial: state,
        formatAllowed: ref
            .read(adFormatPolicyProvider)
            .allows(AdFormat.interstitial),
        adsRemoved: ref.read(adsRemovedProvider),
        interstitialsEnabled: ref.read(featureFlagsProvider).interstitialAds,
        stageCleared: stageCleared,
        rewardSequenceComplete: rewardSequenceComplete,
        protectedMomentPending: ref.read(protectedMomentProvider) > 0,
        hadGameplayThisSession: ref.read(sessionGameplayProvider),
        now: now,
        lastAdShownAt: store.lastAdShownAt,
        lastPurchaseAt: store.lastPurchaseAt,
      ),
    );

    if (!decision.allowed) {
      if (kDebugMode) {
        debugPrint('إعلان بيني: مُنع — ${decision.reason?.name}');
      }
      // سبب المنع نفسه معلومة تحليلية: «لماذا لا تظهر إعلانات في اليوم
      // الأول» يُجاب برقم لا بتخمين
      ref.read(analyticsProvider)?.log(Ev.adFailed, {
        'kind': 'interstitial',
        'reason': decision.reason?.name,
        'stage': stageNumber,
      });
      return AdCue.none;
    }

    // العدّاد يُصفَّر ووقت الإعلان يُسجَّل هنا لا في الودجة: المهلة
    // العامة يجب أن تبدأ من لحظة القرار حتى لو أُغلق التطبيق فورا
    state = 0;
    store.setCompletionsSinceInterstitial(0);
    store.setLastAdShownAt(now);
    final analytics = ref.read(analyticsProvider);
    analytics?.log(Ev.adRequested, {
      'kind': 'interstitial',
      'stage': stageNumber,
    });
    analytics?.log(Ev.adShown, {'kind': 'interstitial', 'stage': stageNumber});
    return AdCue.interstitial;
  }

  /// يسجّل عرض إعلان من *أي* مصدر آخر (جائزي مثلا) كي تسري عليه المهلة
  /// العامة نفسها — «تسعين ثانية من أي إعلان آخر»، لا من البينية فقط
  void recordAdShown({DateTime? nowOverride}) => ref
      .read(progressStoreProvider)
      .setLastAdShownAt(nowOverride ?? DateTime.now());
}

final interstitialGateProvider =
    NotifierProvider<InterstitialGateNotifier, int>(
      InterstitialGateNotifier.new,
    );

// ─────────────────────── الإعلانات الجائزية ───────────────────────

/// دفتر الإعلانات الجائزية: ميزانية يومية مشتركة (4 مشاهدات) بمكافأة
/// متصاعدة، ومنح مرة واحدة بالضبط لكل مشاهدة.
class RewardedAdsNotifier extends Notifier<RewardedLedger> {
  @override
  RewardedLedger build() {
    final store = ref.read(progressStoreProvider);
    return RewardedAds.rollOver(
      RewardedLedger.decode(
        store.rewardedLedgerJson,
        RewardedAds.dateKey(DateTime.now()),
      ),
      DateTime.now(),
    );
  }

  void _persist(RewardedLedger ledger) {
    state = ledger;
    ref.read(progressStoreProvider).setRewardedLedgerJson(ledger.encode());
  }

  /// مكافأة المشاهدة التالية — تُعرض على الزر *قبل* بدء الإعلان
  int get nextReward => state.nextReward;
  bool get hasBudget => state.hasRemaining;

  /// يبدأ مشاهدة. null يعني «لا تعرض الزر»: القالب مطفأ في هذا البناء، أو
  /// أُطفئ المفتاح، أو نفدت الميزانية.
  ///
  /// الإتاحة تُقرأ هنا من [rewardedAdsAvailableProvider] لكل السطوح، لا
  /// يمرّرها المستدعي: كانت معاملا اختياريا افتراضه «مسموح»، فتجاوز المتجر
  /// والعجلة وورقة «ينقصك القليل» مفتاح الإيقاف بصمت.
  ///
  /// [amount] يتجاوز سلّم المكافأة لسطح بمبلغ ثابت (بطاقة المتجر).
  RewardedAdRequest? begin(RewardedSurface surface, {int? amount}) {
    final formatAllowed = ref.read(adFormatPolicyProvider).allowsRewardAds;
    final available = ref.read(rewardedAdsAvailableProvider);
    final ledger = RewardedAds.rollOver(state, DateTime.now());
    if (ledger != state) _persist(ledger);
    final request = RewardedAds.beginRequest(
      ledger: ledger,
      surface: surface,
      requestId: _newRequestId(),
      rewardedEnabled: available,
      amount: amount,
    );
    ref
        .read(analyticsProvider)
        ?.log(request == null ? Ev.adFailed : Ev.adRequested, {
          'surface': surface.name,
          'kind': 'rewarded',
          if (request != null) 'reward': request.quotedAmount,
          if (request != null) 'view_number': request.viewNumber,
          if (request == null)
            'reason': !formatAllowed
                ? 'format_disabled'
                : !available
                ? 'kill_switch'
                : 'budget_exhausted',
        });
    return request;
  }

  /// اكتملت المشاهدة. آمنة للنداء المكرّر: النداء الثاني لنفس الطلب لا
  /// يمنح شيئا ولا يستهلك ميزانية.
  ///
  /// تعيد ما أُضيف فعلا إلى المحفظة (0 عند النداء المكرّر).
  int complete(RewardedAdRequest request, {DateTime? nowOverride}) {
    final now = nowOverride ?? DateTime.now();
    // الفحص قبل الاستدعاء لا بعده: مقارنة الدفترين بعده تخلط النداء
    // المكرّر بتدوير اليوم (كلاهما يغيّر viewsUsed)
    final isDuplicate = state.hasGranted(request.id);

    _persist(
      RewardedAds.onAdCompleted(ledger: state, request: request, now: now),
    );
    if (isDuplicate) return 0;

    ref.read(analyticsProvider)?.log(Ev.adShown, {
      'surface': request.surface.name,
      'kind': 'rewarded',
      'view_number': request.viewNumber,
    });

    // الإعلان الجائزي يدخل مهلة التسعين ثانية العامة أيضا
    ref.read(interstitialGateProvider.notifier).recordAdShown(nowOverride: now);
    return flush();
  }

  /// يستهلك مشاهدة من الميزانية بلا منح عملات — للسطوح التي مكافأتها
  /// شيء آخر (دورة عجلة). يستهلك الميزانية ويتقدّم بسلّم المكافأة
  /// كأي مشاهدة، فالميزانية واحدة فعلا لا اسما.
  void consumeViewWithoutCoins(
    RewardedAdRequest request, {
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();
    if (state.hasGranted(request.id)) return;
    final after = RewardedAds.onAdCompleted(
      ledger: state,
      request: request,
      now: now,
    );
    // نزيل منحة هذا الطلب من الطابور: الميزانية استُهلكت، ولا عملات
    _persist(
      after.copyWith(
        queue: [
          for (final g in after.queue)
            if (g.requestId != request.id) g,
        ],
      ),
    );
    ref.read(interstitialGateProvider.notifier).recordAdShown(nowOverride: now);
  }

  /// يعرض إعلانا جائزيا ثم يمنح [amount] عملة إضافية — أي يضاعف جائزة
  /// ربحها اللاعب للتوّ (مرحلة أو صندوق فصل). يعيد ما مُنح فعلا، و0 إن
  /// تعذّر العرض (ميزانية اليوم نفدت، أو المفتاح مطفأ، أو المبلغ صفر).
  ///
  /// المشاهدة تُستهلك بلا عملات السلّم المعتاد
  /// ([consumeViewWithoutCoins]) لأن مكافأتها هنا شيء آخر: ضعف الجائزة.
  /// بلا ذلك يأخذ اللاعب مكافأتين عن مشاهدة واحدة.
  ///
  /// [amount] هو ما **دخل المحفظة فعلا** لا الجائزة الخام: الواجهة
  /// تمرّر الرقم المعروض على الشاشة نفسه (راجع
  /// GameScreen._earnedCoins و_ChestRewardDialog). ولهذا لا يُعاد
  /// تمريره على مضاعف الشراء الأول هنا — كان يُعاد، فيقبض صاحب مضاعف
  /// ساري أكثر من الضعف (16 معروضة → 24 زيادة → 40 مجموعا). المضاعف
  /// طُبّق مرة واحدة على الجائزة الأصلية، وهذا يضاعف نتيجتها.
  ///
  /// [playAd] هو العرض نفسه: تمرّره الواجهة، ويأتيه الطول من الخريطة
  /// ([AdFormats.forSurface]) لا من المستدعي — فمضاعفة جائزة المرحلة
  /// إعلان قصير ومضاعفة صندوق الفصل إعلان طويل بحكم السطح وحده. إلزامي:
  /// لا منح إلا بـtrue صريح منه، أي بمشاهدة اكتملت واستُحقّت مكافأتها
  /// (كان تركه null يعني «امنح بلا عرض»). يعيد false إن لم يُعرض الإعلان
  /// فعلا (غادر اللاعب الشاشة قبل بدئه) — عندها لا منح ولا استهلاك من
  /// الميزانية: مكافأة بلا إعلان هي ما يمنعه هذا كله.
  Future<int> doubleReward(
    int amount, {
    RewardedSurface surface = RewardedSurface.other,
    required Future<bool> Function(AdLength length) playAd,
  }) async {
    if (amount <= 0) return 0;
    // null حين يكون القالب مطفأ أو المفتاح مطفأ أو الميزانية نافدة — ولا
    // يُستدعى [playAd] أصلا
    final request = begin(surface);
    if (request == null) return 0;

    // العرض نفسه عند الواجهة (adServiceProvider.showRewarded) — هي من
    // تملك السياق، وهي من تعيد false إن لم يُعرض أو لم تكتمل المشاهدة
    final watched = await playAd(AdFormats.forSurface(surface));
    if (!watched) return 0;
    consumeViewWithoutCoins(request);

    // مضاعفة حرفية: [amount] ثانية بالضبط، فيرى اللاعب الرقم الذي وُعد
    // به. راجع BalanceConfig.adDoubleBonusFor لسبب إسقاط النسبة والسقف.
    final granted = BalanceConfig.adDoubleBonusFor(amount);
    ref.read(pointsProvider.notifier).add(granted, reason: 'reward_doubled');
    ref.read(achievementsProvider.notifier).bump(StatKey.pointsEarned, granted);
    ref.read(analyticsProvider)?.log(Ev.adRewardGranted, {
      'coins': granted,
      'surface': surface.name,
      'kind': 'double_reward',
    });
    return granted;
  }

  /// يفرّغ ما اكتمل ولم يُضَف بعد ويضيفه إلى المحفظة. يُستدعى فور
  /// الاكتمال وعند كل إقلاع — منحة لم تصل نداءتها قبل الإغلاق تصل هنا.
  int flush() {
    final result = RewardedAds.flushQueue(state);
    if (result.isEmpty) return 0;
    _persist(result.ledger);
    ref.read(pointsProvider.notifier).add(result.coins, reason: 'rewarded_ad');
    ref
        .read(achievementsProvider.notifier)
        .bump(StatKey.pointsEarned, result.coins);
    ref.read(analyticsProvider)?.log(Ev.adRewardGranted, {
      'coins': result.coins,
      'grants': result.applied.length,
    });
    return result.coins;
  }

  static int _requestCounter = 0;
  String _newRequestId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_requestCounter++}';
}

final rewardedAdsProvider =
    NotifierProvider<RewardedAdsNotifier, RewardedLedger>(
      RewardedAdsNotifier.new,
    );

// ─────────────────────── المكتبة الأدبية ───────────────────────

final literatureRepositoryProvider = Provider((ref) => LiteratureRepository());

final literatureProvider = FutureProvider<LiteratureLibrary>(
  (ref) => ref.watch(literatureRepositoryProvider).load(),
);

final challengeRepositoryProvider = Provider((ref) => ChallengeRepository());

/// تقدّم التحدّيات اللغوية: ما حُلّ من عناصر، وما استُلم من صناديق.
///
/// القرارات كلها في ChallengeProgressRules (منطق صرف مختبَر)؛ هذا
/// المزوّد يحمل الحالة ويثبّتها في التخزين لا أكثر.
class ChallengeProgressState {
  final Set<String> solvedIds;
  final Set<String> claimedChestIds;

  const ChallengeProgressState({
    required this.solvedIds,
    required this.claimedChestIds,
  });
}

class ChallengeProgressNotifier extends Notifier<ChallengeProgressState> {
  @override
  ChallengeProgressState build() {
    final store = ref.read(progressStoreProvider);
    return ChallengeProgressState(
      solvedIds: store.solvedChallenges,
      claimedChestIds: store.claimedChallengeChests,
    );
  }

  /// يسجّل حلّ عنصر. لا يمنح عملات — تلك تُمنح في شاشة التحدّي نفسها
  /// عند الحلّ، ومنحها هنا أيضا يعني دفعتين لعمل واحد.
  void markSolved(ChallengeCategory category, int index) {
    final id = ChallengeProgressRules.idFor(category, index);
    if (state.solvedIds.contains(id)) return;
    final solved = {...state.solvedIds, id};
    state = ChallengeProgressState(
      solvedIds: solved,
      claimedChestIds: state.claimedChestIds,
    );
    ref.read(progressStoreProvider).setSolvedChallenges(solved);
  }

  /// يستلم صندوق فئة اكتملت — مرة واحدة، ويعيد العملات الممنوحة (0 إن
  /// لم يكن مستحقّا)
  int claimChest(ChallengeCategory category, {required int total}) {
    if (!ChallengeProgressRules.isChestClaimable(
      category: category,
      total: total,
      solvedIds: state.solvedIds,
      claimedChestIds: state.claimedChestIds,
    )) {
      return 0;
    }
    final claimed = {
      ...state.claimedChestIds,
      ChallengeProgressRules.chestIdFor(category),
    };
    state = ChallengeProgressState(
      solvedIds: state.solvedIds,
      claimedChestIds: claimed,
    );
    ref.read(progressStoreProvider).setClaimedChallengeChests(claimed);

    final coins = BalanceConfig.challengeCategoryChestCoins;
    ref
        .read(pointsProvider.notifier)
        .add(coins, reason: 'challenge_category_chest');
    return coins;
  }
}

final challengeProgressProvider =
    NotifierProvider<ChallengeProgressNotifier, ChallengeProgressState>(
      ChallengeProgressNotifier.new,
    );

final challengesProvider = FutureProvider<ChallengeSet>(
  (ref) => ref.watch(challengeRepositoryProvider).load(),
);

// ─────────────────────── ميزانية الإعلانات اليومية العامة ───────────────────────
//
// راجع BalanceConfig.globalDailyAdBudget: مشتركة بين كل ميزة تمنح عملات
// بمشاهدة إعلان. عجلة الحظ خارجها بعدّادها الخاص
// (BalanceConfig.wheelAdSpinsPerDay). إن أُضيفت ميزة أخرى لاحقا (مثلا
// شاشة وضع الأمان economy/safety_mode.dart، التي لديها فعلا معامل
// adBudgetRemaining بانتظار مصدر حقيقي) فستقرأ من هنا أيضا بدل ميزانية
// خاصة بها منفصلة.
class GlobalAdBudgetState {
  final int usedToday;
  const GlobalAdBudgetState(this.usedToday);

  int get remaining => (BalanceConfig.rewardedDailyBudget - usedToday).clamp(
    0,
    BalanceConfig.rewardedDailyBudget,
  );
  bool get hasRemaining => remaining > 0;
}

/// واجهة قراءة/استهلاك للميزانية المشتركة، *فوق دفتر الإعلانات
/// الجائزية* لا بجانبه.
///
/// كان هذا عدّادا مستقلا بتخزين خاص، فصارت هناك ميزانيتان: واحدة للعجلة
/// وأخرى لبقية السطوح — وهذا بالضبط ما تمنعه قاعدة «أربع مشاهدات في
/// اليوم مشتركة بين كل السطوح». الآن العدّاد واحد
/// ([RewardedLedger.viewsUsed])، فدورة عجلة بإعلان تتقدّم بسلّم المكافأة
/// تماما كمشاهدة من المتجر: ما استُهلك استُهلك أيا كان بابه.
class GlobalAdBudgetNotifier extends Notifier<GlobalAdBudgetState> {
  @override
  GlobalAdBudgetState build() =>
      GlobalAdBudgetState(ref.watch(rewardedAdsProvider).viewsUsed);

  /// يستهلك مشاهدة من الميزانية المشتركة *بلا منح عملات* — لسطح مكافأته
  /// ليست عملات. يعيد true إن نجح.
  bool consume() {
    final rewarded = ref.read(rewardedAdsProvider.notifier);
    final request = rewarded.begin(RewardedSurface.wheel);
    if (request == null) return false;
    // نستهلك المشاهدة ثم نتجاهل ما نتج من عملات: مكافأة هذا السطح هي
    // الدورة نفسها. لا نمرّ بـcomplete كي لا تُضاف عملات مزدوجة.
    rewarded.consumeViewWithoutCoins(request);
    return true;
  }
}

final globalAdBudgetProvider =
    NotifierProvider<GlobalAdBudgetNotifier, GlobalAdBudgetState>(
      GlobalAdBudgetNotifier.new,
    );

// ─────────────────────── عجلة الحظ ───────────────────────

class WheelState {
  final bool freeSpinAvailable;
  final int adSpinsRemaining;

  const WheelState({
    required this.freeSpinAvailable,
    required this.adSpinsRemaining,
  });

  static int get maxAdSpinsPerDay => BalanceConfig.wheelAdSpinsPerDay;

  bool get canSpinNow => freeSpinAvailable || adSpinsRemaining > 0;
}

class WheelNotifier extends Notifier<WheelState> {
  @override
  WheelState build() {
    final freeAvailable = _freeSpinAvailableNow();
    // لا دورات بإعلان حين لا يُتاح الإعلان الجائزي: الواجهة تعرض «عد غدا»
    // بدل زرّ ميّت، والدورة المجانية اليومية باقية كما هي
    final adRemaining = ref.watch(rewardedAdsAvailableProvider)
        ? WheelState.maxAdSpinsPerDay - _adSpinsUsedToday()
        : 0;
    return WheelState(
      freeSpinAvailable: freeAvailable,
      adSpinsRemaining: adRemaining.clamp(0, WheelState.maxAdSpinsPerDay),
    );
  }

  /// دورات الإعلان المستهلكة اليوم — من التخزين مباشرة، كالدورة المجانية
  int _adSpinsUsedToday() {
    final store = ref.read(progressStoreProvider);
    return store.wheelAdDate == _dateKey(DateTime.now())
        ? store.wheelAdSpinsUsed
        : 0;
  }

  /// يُقرَأ من التخزين مباشرة في كل استدعاء (لا من state المخبّأة) كي لا
  /// تتقادم القيمة لو تغيّر اليوم التقويمي والتطبيق لا يزال مفتوحا
  bool _freeSpinAvailableNow() {
    final store = ref.read(progressStoreProvider);
    final today = _dateKey(DateTime.now());
    return store.wheelDate == today ? !store.wheelFreeUsed : true;
  }

  /// يستهلك الدورة المجانية (إن وُجدت) وإلا دورة إعلان من عدّاد العجلة.
  /// يعيد true إن سُمح بالدوران.
  bool consumeSpin({required bool viaAd}) {
    final freeAvailableNow = _freeSpinAvailableNow();

    if (!viaAd && freeAvailableNow) {
      final store = ref.read(progressStoreProvider);
      store.setWheelDate(_dateKey(DateTime.now()));
      store.setWheelFreeUsed(true);
      state = WheelState(
        freeSpinAvailable: false,
        adSpinsRemaining: state.adSpinsRemaining,
      );
      return true;
    }
    if (viaAd) {
      // القالب مطفأ أو المفتاح مطفأ: لا دورة بإعلان مهما بقي في العدّاد
      if (!ref.read(rewardedAdsAvailableProvider)) return false;
      final used = _adSpinsUsedToday();
      if (used >= WheelState.maxAdSpinsPerDay) return false;
      final store = ref.read(progressStoreProvider);
      store.setWheelAdDate(_dateKey(DateTime.now()));
      store.setWheelAdSpinsUsed(used + 1);
      ref.read(analyticsProvider)?.log(Ev.adShown, {
        'surface': RewardedSurface.wheel.name,
        'kind': 'rewarded',
        'view_number': used + 1,
      });
      // الإعلان الجائزي يدخل مهلة التسعين ثانية العامة أيضا
      ref.read(interstitialGateProvider.notifier).recordAdShown();
      state = WheelState(
        freeSpinAvailable: freeAvailableNow,
        adSpinsRemaining: WheelState.maxAdSpinsPerDay - used - 1,
      );
      return true;
    }
    return false;
  }

  /// يمنح جائزة القطاع المحدد بعد توقّف العجلة
  void grantPrize(int segmentIndex) {
    final segment = BalanceConfig.wheelSegments[segmentIndex];
    final store = ref.read(progressStoreProvider);
    ref.read(analyticsProvider)?.log(Ev.wheelSpun, {
      'segment': segmentIndex,
      'type': segment.type.name,
      'value': segment.value,
    });
    switch (segment.type) {
      case WheelPrizeType.coins:
        ref.read(pointsProvider.notifier).add(segment.value, reason: 'wheel');
      case WheelPrizeType.hintCharge:
        ref.read(hintChargesProvider.notifier).add(segment.value);
      case WheelPrizeType.jarBooster:
        final until = DateTime.now().add(BalanceConfig.jarBoosterDuration);
        store.setJarBoosterActiveUntil(until.toIso8601String());
    }
  }
}

final wheelProvider = NotifierProvider<WheelNotifier, WheelState>(
  WheelNotifier.new,
);

// ─────────────────────── المهمات اليومية والأسبوعية ───────────────────────
//
// مسندة بالأحداث (event-sourced) لا مشتقّة من فارق عدّاد StatKey: كل
// حدث (مرحلة اكتملت، كلمة وُجدت..) يُبلَّغ صراحة من نفس نقطة وقوعه في
// game_screen.dart عبر MissionsNotifier.reportX، تماما بجانب استدعاءات
// achievements.bump
// الموجودة هناك فعلا. هذا يتفادى تعقيد "أي مصدر بيانات يغذّي أي هدف"
// في منطق صرف عام. راجع lib/data/missions/mission_engine.dart للاختيار
// والسحب، ولا واجهة مخصّصة هنا عمدا — "صف ملخّص المهمات اليومية" مذكور
// صراحة كعنصر واجهة في مهمة إعادة بناء الرئيسية المنفصلة، لا هذه.

class DailyMissionsState {
  final String dateKey;
  final List<MissionInstance> missions;
  final bool chestClaimed;

  const DailyMissionsState({
    required this.dateKey,
    required this.missions,
    required this.chestClaimed,
  });

  bool get allComplete => missions.every((m) => m.isComplete);
  int get completedCount => missions.where((m) => m.isComplete).length;
}

class WeeklyMissionsState {
  final String weekStartKey;
  final List<MissionInstance> missions;
  final bool badgeClaimed;
  final Set<String> daysPlayed;

  const WeeklyMissionsState({
    required this.weekStartKey,
    required this.missions,
    required this.badgeClaimed,
    required this.daysPlayed,
  });

  bool get allComplete => missions.every((m) => m.isComplete);
}

class MissionsState {
  final DailyMissionsState daily;
  final WeeklyMissionsState weekly;
  const MissionsState({required this.daily, required this.weekly});
}

/// 300 عملة + شارة أسبوعية واحدة — مكافأة مجمَّعة عند إكمال الثلاث معا،
/// لا لكل مهمة على حدة (راجع تعليق coinsReward في mission_models.dart)
const int weeklyMissionsBadgeCoins = 300;

class MissionsNotifier extends Notifier<MissionsState> {
  @override
  MissionsState build() {
    final store = ref.read(progressStoreProvider);
    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final weekKey = _dateKey(MissionEngine.mostRecentMonday(now));

    var daily = _decodeDaily(store.dailyMissionsJson);
    if (daily == null ||
        daily.dateKey != todayKey ||
        daily.missions.length != 3) {
      final xp = ref.read(progressionRepositoryProvider).state.wallet.xp;
      final playerLevel = PlayerLevelCurve.currentLevel(xp);
      final defs = MissionEngine.selectDaily(
        playerLevel: playerLevel,
        rng: Random(),
      );
      daily = DailyMissionsState(
        dateKey: todayKey,
        missions: [for (final d in defs) MissionInstance.fresh(d)],
        chestClaimed: false,
      );
      store.setDailyMissionsJson(_encodeDaily(daily));
    }

    var weekly = _decodeWeekly(store.weeklyMissionsJson);
    if (weekly == null ||
        weekly.weekStartKey != weekKey ||
        weekly.missions.length != 3) {
      final defs = MissionEngine.selectWeekly(rng: Random());
      weekly = WeeklyMissionsState(
        weekStartKey: weekKey,
        missions: [for (final d in defs) MissionInstance.fresh(d)],
        badgeClaimed: false,
        daysPlayed: const {},
      );
      store.setWeeklyMissionsJson(_encodeWeekly(weekly));
    }

    return MissionsState(daily: daily, weekly: weekly);
  }

  void _persist() {
    final store = ref.read(progressStoreProvider);
    store.setDailyMissionsJson(_encodeDaily(state.daily));
    store.setWeeklyMissionsJson(_encodeWeekly(state.weekly));
  }

  void _reportToAll(MissionObjectiveType type, int amount) {
    final beforeDaily = state.daily;
    final beforeWeekly = state.weekly;

    var newlyCompletedCoins = 0;
    final newDailyMissions = <MissionInstance>[];
    for (final m in beforeDaily.missions) {
      final updated = m.reportEvent(type, amount);
      if (!m.isComplete && updated.isComplete) {
        newlyCompletedCoins += updated.def.coinsReward;
      }
      newDailyMissions.add(updated);
    }

    var chestClaimed = beforeDaily.chestClaimed;
    DailyChestReward? chestReward;
    if (!chestClaimed && newDailyMissions.every((m) => m.isComplete)) {
      chestClaimed = true;
      chestReward = MissionEngine.rollDailyChest(Random());
    }

    final newWeeklyMissions = [
      for (final m in beforeWeekly.missions) m.reportEvent(type, amount),
    ];
    var badgeClaimed = beforeWeekly.badgeClaimed;
    var weeklyJustCompleted = false;
    if (!badgeClaimed && newWeeklyMissions.every((m) => m.isComplete)) {
      badgeClaimed = true;
      weeklyJustCompleted = true;
    }

    state = MissionsState(
      daily: DailyMissionsState(
        dateKey: beforeDaily.dateKey,
        missions: newDailyMissions,
        chestClaimed: chestClaimed,
      ),
      weekly: WeeklyMissionsState(
        weekStartKey: beforeWeekly.weekStartKey,
        missions: newWeeklyMissions,
        badgeClaimed: badgeClaimed,
        daysPlayed: beforeWeekly.daysPlayed,
      ),
    );
    _persist();

    if (newlyCompletedCoins > 0) {
      ref
          .read(pointsProvider.notifier)
          .add(newlyCompletedCoins, reason: 'mission');
      ref.read(analyticsProvider)?.log(Ev.missionCompleted, {
        'scope': 'daily',
        'coins': newlyCompletedCoins,
      });
    }
    if (chestReward != null) {
      ref
          .read(pointsProvider.notifier)
          .add(chestReward.coins, reason: 'daily_mission_chest');
      if (chestReward.hintCharge) {
        ref.read(hintChargesProvider.notifier).add(1);
      }
    }
    if (weeklyJustCompleted) {
      ref
          .read(pointsProvider.notifier)
          .add(weeklyMissionsBadgeCoins, reason: 'weekly_mission_badge');
      ref.read(analyticsProvider)?.log(Ev.missionCompleted, {
        'scope': 'weekly',
        'coins': weeklyMissionsBadgeCoins,
      });
    }
  }

  void reportStageCompleted() =>
      _reportToAll(MissionObjectiveType.completeStages, 1);
  void reportWordsFound(int count) {
    if (count > 0) _reportToAll(MissionObjectiveType.findWords, count);
  }

  void reportBonusWordFound([int count = 1]) {
    if (count > 0) _reportToAll(MissionObjectiveType.findBonusWords, count);
  }

  void reportStageCompletedNoHints() =>
      _reportToAll(MissionObjectiveType.completeStageNoHints, 1);

  /// نشاط اليوم (نفس حدث streakProvider.recordActivityToday) — يغذّي
  /// هدف "العب 5 أيام مختلفة" الأسبوعي حصرا، مرة واحدة لكل يوم تقويمي
  void reportActivityToday() {
    final todayKey = _dateKey(DateTime.now());
    if (state.weekly.daysPlayed.contains(todayKey)) return;
    state = MissionsState(
      daily: state.daily,
      weekly: WeeklyMissionsState(
        weekStartKey: state.weekly.weekStartKey,
        missions: state.weekly.missions,
        badgeClaimed: state.weekly.badgeClaimed,
        daysPlayed: {...state.weekly.daysPlayed, todayKey},
      ),
    );
    _reportToAll(MissionObjectiveType.playDifferentDays, 1);
  }
}

final missionsProvider = NotifierProvider<MissionsNotifier, MissionsState>(
  MissionsNotifier.new,
);

String _encodeDaily(DailyMissionsState s) => jsonEncode({
  'dateKey': s.dateKey,
  'missions': [for (final m in s.missions) m.toJson()],
  'chestClaimed': s.chestClaimed,
});

/// null عند التلف أيضا لا عند الغياب فقط: قيمة محفوظة بشكل قديم أو
/// تالف كانت تُسقط المزوّد كله فتنهار كل شاشة تراقبه بلا مخرج. المهمات
/// تُختار من جديد كأنها يوم جديد — خسارة مهمة يوم واحد أهون من شاشة
/// رئيسية لا تفتح.
DailyMissionsState? _decodeDaily(String? raw) {
  if (raw == null) return null;
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final missions = <MissionInstance>[];
    for (final entry in json['missions'] as List) {
      final map = entry as Map<String, dynamic>;
      final def = allMissionDefsById[map['id'] as String];
      if (def == null) continue; // معرّف مهمة لم يعد موجودا — يُتجاوَز بأمان
      missions.add(MissionInstance.fromJson(map, def));
    }
    return DailyMissionsState(
      dateKey: json['dateKey'] as String,
      missions: missions,
      chestClaimed: json['chestClaimed'] as bool,
    );
  } catch (e) {
    debugPrint('missions: مهمات اليوم المحفوظة تالفة، تُختار من جديد: $e');
    return null;
  }
}

String _encodeWeekly(WeeklyMissionsState s) => jsonEncode({
  'weekStartKey': s.weekStartKey,
  'missions': [for (final m in s.missions) m.toJson()],
  'badgeClaimed': s.badgeClaimed,
  'daysPlayed': s.daysPlayed.toList(),
});

WeeklyMissionsState? _decodeWeekly(String? raw) {
  if (raw == null) return null;
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final missions = <MissionInstance>[];
    for (final entry in json['missions'] as List) {
      final map = entry as Map<String, dynamic>;
      final def = allMissionDefsById[map['id'] as String];
      if (def == null) continue;
      missions.add(MissionInstance.fromJson(map, def));
    }
    return WeeklyMissionsState(
      weekStartKey: json['weekStartKey'] as String,
      missions: missions,
      badgeClaimed: json['badgeClaimed'] as bool,
      daysPlayed: (json['daysPlayed'] as List).cast<String>().toSet(),
    );
  } catch (e) {
    debugPrint('missions: مهمات الأسبوع المحفوظة تالفة، تُختار من جديد: $e');
    return null;
  }
}

// ─────────────────────── سلسلة الأيام المتتالية (محلية) ───────────────────────
//
// راجع lib/data/streak/streak_engine.dart للتوثيق الكامل. هذا يحلّ محلّ
// streakProvider القديم (FutureProvider معتمد على Supabase، يعود صفرا
// بلا اتصال) بمزوّد محلي متزامن يعمل بلا إنترنت إطلاقا ويحتسب أيضا
// إتمام المراحل. جدول streaks في Supabase يبقى دون تغيير — يُستخدَم
// فقط لمقياس "streak" في لوحة الترتيب، وهو رقم قد يختلف عن هذا.
class StreakNotifier extends Notifier<StreakState> {
  @override
  StreakState build() {
    final store = ref.read(progressStoreProvider);
    final loaded = StreakState(
      currentStreak: store.streakCurrent,
      longestStreak: store.streakLongest,
      freezesHeld: store.streakFreezesHeld,
      freezeMilestonesGranted: store.streakFreezeMilestonesGranted,
      securedThroughDateKey: store.streakSecuredThrough,
      pendingFreezeNoticeCount: store.streakPendingFreezeNotice,
    );
    // يسوّي أي فجوة مضت منذ آخر فتح للتطبيق فورا (تجميد تلقائي أو كسر)
    final reconciled = StreakEngine.reconcile(
      state: loaded,
      now: DateTime.now(),
    );
    if (!identical(reconciled, loaded)) _persist(reconciled);
    return reconciled;
  }

  void _persist(StreakState s) {
    ref
        .read(progressStoreProvider)
        .saveStreak(
          current: s.currentStreak,
          longest: s.longestStreak,
          freezesHeld: s.freezesHeld,
          freezeMilestonesGranted: s.freezeMilestonesGranted,
          securedThrough: s.securedThroughDateKey,
          pendingFreezeNotice: s.pendingFreezeNoticeCount,
        );
  }

  /// يسجّل نشاط اليوم (إتمام مرحلة) — آمن الاستدعاء
  /// عدة مرات في نفس اليوم. يحدّث أيضا إنجاز أطول سلسلة وتجميدات معالم
  /// يوم-7 تلقائيا، فلا يحتاج المستدعي معرفة أيّهما.
  void recordActivityToday() {
    final before = state;
    var next = StreakEngine.recordActivityToday(
      state: state,
      now: DateTime.now(),
    );
    // الانكسار يُكتشف هنا لا في الشاشة: السلسلة تنكسر بمرور الوقت لا
    // بفعل اللاعب، فلا شاشة تعرف بها لحظة وقوعها
    if (before.currentStreak > 1 && next.currentStreak <= 1) {
      ref.read(analyticsProvider)?.log(Ev.streakBroken, {
        'lost_streak': before.currentStreak,
      });
    }
    next = StreakEngine.grantMilestoneFreezes(
      state: next,
      grantEveryDays: BalanceConfig.streakFreezeGrantEveryDays,
      maxHeld: BalanceConfig.maxStreakFreezesHeld,
    );
    // يوم لعب جديد يُحتسب مرّة واحدة مهما تكرّر النشاط فيه: المحرّك يعيد
    // نفس الحالة حين يكون اليوم مؤمَّنا فعلا، فتغيّر «اليوم المؤمَّن» هو
    // إشارة «يوم جديد» الوحيدة الصادقة هنا
    final newDay = before.securedThroughDateKey != next.securedThroughDateKey;
    state = next;
    _persist(next);
    final achievements = ref.read(achievementsProvider.notifier);
    if (newDay) achievements.bump(StatKey.daysPlayed, 1);
    achievements.reportBest(StatKey.bestStreak, next.longestStreak);
  }

  /// يشتري تجميدا بالعملات — يعيد true إن نجح (رصيد كافٍ ولم يُبلَغ الحد
  /// الأقصى المحمول بعد)
  bool purchaseFreeze() {
    if (!StreakEngine.canPurchaseFreeze(
      state: state,
      maxHeld: BalanceConfig.maxStreakFreezesHeld,
    )) {
      return false;
    }
    if (!ref
        .read(pointsProvider.notifier)
        .spend(BalanceConfig.coinsStreakFreeze, reason: 'streak_freeze')) {
      return false;
    }
    state = StreakEngine.addPurchasedFreeze(state: state);
    _persist(state);
    return true;
  }

  /// يأخذ عدد التجميدات المستهلكة تلقائيا منذ آخر مرة (ويصفّره) — تعرضه
  /// الواجهة كرسالة صباحية واحدة ثم تستهلكه، فلا يُعرض مرتين لنفس الحدث
  int takePendingFreezeNotice() {
    final (next, count) = StreakEngine.takePendingFreezeNotice(state);
    if (count > 0) {
      state = next;
      _persist(next);
      ref.read(analyticsProvider)?.log(Ev.streakFreezeUsed, {'count': count});
    }
    return count;
  }
}

final streakProvider = NotifierProvider<StreakNotifier, StreakState>(
  StreakNotifier.new,
);

// ─────────────────────── الإنجازات ───────────────────────

class AchievementsState {
  final Map<StatKey, int> stats;
  final Set<String> unlocked;

  const AchievementsState({required this.stats, required this.unlocked});

  int valueOf(StatKey key) => stats[key] ?? 0;

  bool isUnlocked(String id) => unlocked.contains(id);

  /// نسبة تقدّم اللاعب في إنجاز بعينه (0..1)
  double progressOf(Achievement a) => a.progressFor(valueOf(a.stat));

  /// يُحسب من [visibleAchievements] لا من حجم [unlocked]: المجموعة
  /// المخزّنة قد تحمل معرّفات لإنجازات حُذفت أو لفئة عُطّلت لاحقا، فطولها
  /// وحده يعطي «103 من 91».
  int get unlockedCount =>
      visibleAchievements.where((a) => unlocked.contains(a.id)).length;

  int get totalCount => visibleAchievements.length;
}

/// يدير عدّادات الإنجازات وفتحها.
///
/// كل تحديث للعدّاد يمرّ من هنا فيُفحص فورا: أي إنجاز بلغ هدفه يُفتح،
/// وتُمنح مكافأته، ويُرفع إلى Google Play Games إن كان اللاعب مسجّلا.
class AchievementsNotifier extends Notifier<AchievementsState> {
  @override
  AchievementsState build() {
    final store = ref.read(progressStoreProvider);
    return AchievementsState(
      stats: {for (final k in StatKey.values) k: store.stat(k)},
      unlocked: store.unlockedAchievements,
    );
  }

  /// الإنجازات التي فُتحت للتوّ — تعرضها الواجهة ثم تستهلكها
  final List<Achievement> _justUnlocked = [];

  List<Achievement> takeJustUnlocked() {
    final list = List<Achievement>.from(_justUnlocked);
    _justUnlocked.clear();
    return list;
  }

  /// يزيد عدّادا تراكميا (مثل عدد الكلمات)
  void bump(StatKey key, [int by = 1]) => _apply(key, state.valueOf(key) + by);

  /// يضبط عدّادا يمثّل «أفضل قيمة» (مثل أطول كلمة أو أطول سلسلة)
  void reportBest(StatKey key, int value) {
    if (value <= state.valueOf(key)) return;
    _apply(key, value);
  }

  void _apply(StatKey key, int value) {
    final store = ref.read(progressStoreProvider);
    store.setStat(key, value);

    final stats = Map<StatKey, int>.from(state.stats)..[key] = value;
    final unlocked = Set<String>.from(state.unlocked);

    var rewardTotal = 0;
    for (final a in achievements) {
      // فئة معطّلة لا تُفتح ولا تدفع: عرض إنجاز اجتماعي أو منح عملاته
      // في نسخة لا ميزات اجتماعية فيها يربك اللاعب بلا فائدة. تُلتقط
      // إنجازاتها المستحقّة عند أول تغيّر في عدّادها بعد إعادة تفعيلها.
      if (!a.category.isEnabled) continue;
      if (a.stat != key || unlocked.contains(a.id)) continue;
      if (!a.isEarnedAt(value)) continue;
      unlocked.add(a.id);
      rewardTotal += a.reward;
      _justUnlocked.add(a);
      // صدى إلى حساب اللاعب — يفشل بصمت إن لم يكن مسجّلا
      GamesServicesSync.unlock(a.id);
      // مكافأة زخرفية حصرية (طبقة أسطورية فقط) — راجع تعليق
      // cosmeticRewardId في achievement_models.dart وpendingCosmeticUnlocks
      // في progress_store.dart لسبب عدم منحها في مخزون فعلي بعد
      if (a.cosmeticRewardId != null) {
        store.addPendingCosmeticUnlock(a.cosmeticRewardId!);
      }
    }

    if (unlocked.length != state.unlocked.length) {
      store.setUnlockedAchievements(unlocked);
    }
    state = AchievementsState(stats: stats, unlocked: unlocked);

    if (rewardTotal > 0) {
      ref.read(pointsProvider.notifier).add(rewardTotal, reason: 'achievement');
    }
  }
}

final achievementsProvider =
    NotifierProvider<AchievementsNotifier, AchievementsState>(
      AchievementsNotifier.new,
    );

/// يمنح نقاطا مكتسبة من اللعب ويحتسبها في إنجاز «النقاط المكتسبة».
///
/// نقاط مكافآت الإنجازات نفسها تُمنح عبر [PointsNotifier.add] مباشرة، كي
/// لا تُحتسب مرتين ولا ينشأ اعتماد دائري بين المزوّدين.
extension EarnPoints on WidgetRef {
  /// يمرّ من هنا كل كسب عملات من *اللعب*، فهو المكان الوحيد الذي يُطبَّق
  /// فيه مضاعف الشراء الأول. المكافآت غير المرتبطة باللعب (استلام دعوة،
  /// تفريغ طابور إعلان جائزي) تستخدم pointsProvider.add مباشرة عمدا:
  /// المضاعف مكافأة على اللعب لا على استلام حوالة.
  void earnPoints(int amount) {
    final granted = FirstPurchase.applyMultiplier(
      amount,
      multiplier: read(coinMultiplierProvider),
    );
    read(pointsProvider.notifier).add(granted);
    read(achievementsProvider.notifier).bump(StatKey.pointsEarned, granted);
  }
}

// ─────────────────────── المتجر والعروض ───────────────────────

/// حالة الشراء: هل اشترى من قبل، وما العروض/المكافآت السارية.
///
/// كل ما يخصّ «متى يظهر عرض» يعيش هنا لا في شاشة المتجر: العرض يُقرَّر
/// من سلوك اللاعب أثناء اللعب، والمتجر يعرض ما قُرِّر فقط.
class PurchaseState {
  final bool hasEverPurchased;
  final bool starterPackOwned;
  final bool adsRemoved;
  final DateTime? lastPurchaseAt;
  final DateTime? firstPurchaseOfferShownAt;
  final DateTime? firstPurchaseBonusUntil;

  const PurchaseState({
    required this.hasEverPurchased,
    required this.starterPackOwned,
    required this.adsRemoved,
    required this.lastPurchaseAt,
    required this.firstPurchaseOfferShownAt,
    required this.firstPurchaseBonusUntil,
  });

  /// عُرض عرض الشراء الأول في هذا التثبيت (مرة واحدة فقط في العمر)
  bool get offerAlreadyShown => firstPurchaseOfferShownAt != null;

  FirstPurchaseOffer? activeOffer(DateTime now) {
    final shown = firstPurchaseOfferShownAt;
    if (shown == null) return null;
    final offer = FirstPurchase.startOffer(
      now: shown,
      referenceUsd: StoreCatalog.starterPackReferenceUsd,
    );
    return offer.isActive(now) ? offer : null;
  }

  double coinMultiplierAt(DateTime now) {
    final until = firstPurchaseBonusUntil;
    if (until == null || !now.isBefore(until)) return 1;
    return BalanceConfig.firstPurchaseCoinMultiplier;
  }
}

class PurchaseStateNotifier extends Notifier<PurchaseState> {
  @override
  PurchaseState build() {
    final store = ref.read(progressStoreProvider);
    return PurchaseState(
      hasEverPurchased: store.hasEverPurchased,
      starterPackOwned: store.starterPackOwned,
      adsRemoved: store.adsRemoved,
      lastPurchaseAt: store.lastPurchaseAt,
      firstPurchaseOfferShownAt: store.firstPurchaseOfferShownAt,
      firstPurchaseBonusUntil: store.firstPurchaseBonusUntil,
    );
  }

  void _reload() => state = build();

  /// يُستدعى بعد *أي* عملية شراء ناجحة.
  ///
  /// يفعل ثلاثة أشياء معا لأنها تقع معا دوما: يكتم الإعلانات 24 ساعة،
  /// ويعلّم «اشترى»، ويمنح مكافأة الشراء الأول إن كان أول شراء —
  /// مضاعف عملات وزينة حصرية، كي يشعر اللاعب أنه أخذ أكثر من المنتج.
  Future<bool> recordPurchase({DateTime? nowOverride}) async {
    final now = nowOverride ?? DateTime.now();
    final store = ref.read(progressStoreProvider);
    final isFirst = !store.hasEverPurchased;

    await store.setLastPurchaseAt(now);
    await store.setHasEverPurchased(true);

    if (isFirst) {
      final bonus = FirstPurchase.grantBonus(now);
      await store.setFirstPurchaseBonusUntil(bonus.until);
      await store.addPendingCosmeticUnlock(bonus.avatarId);
    }
    _reload();
    ref.read(analyticsProvider)?.log(Ev.purchaseCompleted, {
      'is_first': isFirst,
    });
    return isFirst;
  }

  Future<void> markStarterPackOwned() async {
    await ref.read(progressStoreProvider).setStarterPackOwned(true);
    _reload();
  }

  /// «اشترى من قبل» بلا أثر شراء جديد (لا كتم إعلانات ولا مكافأة أول
  /// شراء) — لما يُستعاد على تثبيت جديد: عرض الشراء الأول لا يُعرض على من
  /// اشترى فعلا
  Future<void> markHasPurchased() async {
    final store = ref.read(progressStoreProvider);
    if (store.hasEverPurchased) return;
    await store.setHasEverPurchased(true);
    _reload();
  }

  /// يفحص محفّز الشراء الأول ويبدأ العرض إن تحقّقت كل شروطه.
  /// يعيد العرض إن بدأ الآن، أو null.
  Future<FirstPurchaseOffer?> maybeStartFirstPurchaseOffer({
    required int failedAttemptsCurrentStage,
    required int stagesCompleted,
    DateTime? nowOverride,
    bool storeEnabled = true,
  }) async {
    final now = nowOverride ?? DateTime.now();
    final decision = FirstPurchase.shouldOffer(
      hasEverPurchased: state.hasEverPurchased,
      alreadyOfferedThisInstall: state.offerAlreadyShown,
      coinBalance: ref.read(pointsProvider),
      failedAttemptsCurrentStage: failedAttemptsCurrentStage,
      stagesCompleted: stagesCompleted,
      lastShownAt: state.firstPurchaseOfferShownAt,
      now: now,
      storeEnabled: storeEnabled,
    );
    if (!decision.show) return null;

    await ref.read(progressStoreProvider).setFirstPurchaseOfferShownAt(now);
    _reload();
    ref.read(analyticsProvider)?.log(Ev.offerShown, {
      'offer_id': 'first_purchase_starter_pack',
      'discount': BalanceConfig.firstPurchaseOfferDiscountPercent,
      'stages_completed': stagesCompleted,
      'failed_attempts': failedAttemptsCurrentStage,
    });
    return FirstPurchase.startOffer(
      now: now,
      referenceUsd: StoreCatalog.starterPackReferenceUsd,
    );
  }
}

final purchaseStateProvider =
    NotifierProvider<PurchaseStateNotifier, PurchaseState>(
      PurchaseStateNotifier.new,
    );

// ─────────────────────── أقساط حزمة البداية ───────────────────────

/// تسليم حزمة البداية على ثلاثة أيام. القرارات كلها في
/// [StarterPackDelivery] (منطق صرف مختبَر)؛ هذا المزوّد يحمل الحالة
/// ويثبّتها ويمنح، لا أكثر.
class StarterPackNotifier extends Notifier<StarterPackStatus> {
  @override
  StarterPackStatus build() {
    // يُعاد بناؤه مع كل تغيّر في حالة الشراء: لحظة تملّك الحزمة هي
    // بالضبط لحظة استحقاق قسطها الأول
    ref.watch(purchaseStateProvider);
    return _statusAt(DateTime.now());
  }

  /// يعيد حساب الحالة من التخزين عند [now].
  ///
  /// يُحسب من التخزين لا من [state]: الحالة المحفوظة في المزوّد بُنيت
  /// بلحظة ماضية، والقبض يقع بلحظته هو.
  StarterPackStatus _statusAt(DateTime now) {
    final store = ref.read(progressStoreProvider);
    return StarterPackDelivery.status(
      owned: ref.read(purchaseStateProvider).starterPackOwned,
      claimedCount: store.starterPackClaimedDays,
      lastClaimDate: store.starterPackLastClaimDate,
      now: now,
    );
  }

  /// يقبض قسط اليوم ويمنحه. يعيد القسط الممنوح، أو null إن لا قسط الآن.
  ///
  /// العملات هنا **لا تمرّ بمضاعف الشراء الأول**: المضاعف يخصّ ما
  /// يكسبه اللاعب من اللعب (راجع earnPoints)، ومضاعفة سلعة اشتُريت
  /// بمالها تعني أن ثمن الحزمة يختلف باختلاف ساعة قبض القسط.
  Future<StarterPackInstallment?> claim({DateTime? nowOverride}) async {
    final now = nowOverride ?? DateTime.now();
    // القرار يُتّخذ عند [now] لا من الحالة المعروضة: بين بناء الحالة
    // والنقر قد يعبر منتصف الليل، وقد يكون هذا أول قبض بعد الشراء
    // مباشرة قبل أن تُعاد الحالة أصلا
    final installment = _statusAt(now).claimable;
    if (installment == null) return null;

    final store = ref.read(progressStoreProvider);
    await store.setStarterPackClaimedDays(installment.number);
    await store.setStarterPackLastClaimDate(StarterPackDelivery.dateKey(now));

    ref
        .read(pointsProvider.notifier)
        .add(
          installment.coins,
          reason: 'starter_pack_day_${installment.number}',
        );
    if (installment.hintCharges > 0) {
      ref.read(hintChargesProvider.notifier).add(installment.hintCharges);
    }
    ref.read(analyticsProvider)?.log(Ev.offerShown, {
      'offer_id': 'starter_pack_installment',
      'installment': installment.number,
      'coins': installment.coins,
      'hints': installment.hintCharges,
    });

    state = _statusAt(now);
    return installment;
  }
}

final starterPackProvider =
    NotifierProvider<StarterPackNotifier, StarterPackStatus>(
      StarterPackNotifier.new,
    );

/// هل ينتظر اللاعبَ شيء *مجاني أو مدفوع ثمنه* داخل المتجر الآن؟
///
/// النقطة الحمراء على تبويب المتجر تتبع هذا وحده — لا العروض ولا
/// الخصومات. الفرق ليس تفصيلا: نقطة تعني «هناك ما تستلمه» تختفي فور
/// استلامه، ونقطة تعني «هناك ما تشتريه» لا تختفي أبدا، فيتعلّم اللاعب
/// تجاهل النقطة كلها — وتموت معها نقطتا الجوائز والعجلة.
///
/// المصدران كلاهما استلام لا بيع: جائزة الدخول اليومية، وقسط حزمة
/// بداية دُفع ثمنه بمال حقيقي.
final shopPendingProvider = Provider<bool>((ref) {
  if (!ref.watch(featureFlagsProvider).store) return false;
  return ref.watch(dailyRewardProvider).canClaim ||
      ref.watch(starterPackProvider).hasClaimable;
});

/// مضاعف العملات الساري الآن (1.0 حين لا مكافأة)
final coinMultiplierProvider = Provider<double>(
  (ref) => ref.watch(purchaseStateProvider).coinMultiplierAt(DateTime.now()),
);

/// هل يُسمح بأي ترويج في المتجر (شارة، نافذة، عرض)؟
///
/// لا شيء قبل إتمام الفصل الأول. اللاعب في فصله الأول لم يقرّر بعد أن
/// اللعبة تستحق وقته، وعرض الشراء عليه يسبق ذلك القرار بكثير.
final storePromoAllowedProvider = Provider<bool>((ref) {
  final snapshot = ref.watch(progressionProvider);
  final structure = ref.watch(progressionStructureProvider);
  var completed = 0;
  for (final chapter in structure.chapters) {
    if (ProgressionRules.isChapterComplete(chapter, snapshot.stageProgress)) {
      completed++;
    }
  }
  return completed >= BalanceConfig.storePromoMinChaptersCompleted;
});

// ─────────────────────── الأصدقاء واللوحة ───────────────────────

final socialRepositoryProvider = Provider((ref) => SocialRepository());

final myProfileProvider = FutureProvider<PlayerProfile?>(
  (ref) => ref.watch(socialRepositoryProvider).myProfile(),
);

final pendingRequestsProvider = FutureProvider.autoDispose<List<FriendRequest>>(
  (ref) => ref.watch(socialRepositoryProvider).pendingRequests(),
);

/// قائمة الأصدقاء المقبولين. تُزامن XP قبل القراءة كي يظهر مستوى اللاعب
/// نفسه محدَّثا لأصدقائه — ولأن نفس المزامنة هي ما يؤهّل دعوته إن كان
/// مدعوّا (راجع SocialRepository.syncXp)
final friendsProvider = FutureProvider.autoDispose<List<Friend>>((ref) async {
  final repo = ref.watch(socialRepositoryProvider);
  await repo.syncXp(ref.read(progressionProvider).state.wallet.xp);
  return repo.friends();
});

final friendCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(socialRepositoryProvider).friendCount(),
);

/// المعيار المختار حاليا في لوحة الأصدقاء
class LeaderboardMetricNotifier extends Notifier<LeaderboardMetric> {
  @override
  LeaderboardMetric build() => LeaderboardMetric.streak;

  void select(LeaderboardMetric metric) => state = metric;
}

final leaderboardMetricProvider =
    NotifierProvider<LeaderboardMetricNotifier, LeaderboardMetric>(
      LeaderboardMetricNotifier.new,
    );

/// نطاق اللوحة المختار: أصدقائي أم عالمي
class LeaderboardScopeNotifier extends Notifier<LeaderboardScope> {
  @override
  LeaderboardScope build() => LeaderboardScope.friends;

  void select(LeaderboardScope scope) => state = scope;
}

final leaderboardScopeProvider =
    NotifierProvider<LeaderboardScopeNotifier, LeaderboardScope>(
      LeaderboardScopeNotifier.new,
    );

final leaderboardProvider = FutureProvider.autoDispose<List<LeaderboardEntry>>((
  ref,
) async {
  final repo = ref.watch(socialRepositoryProvider);
  // نزامن نقاط الجهاز قبل القراءة كي يظهر "المجموع" محدّثا
  await repo.syncScore(ref.read(pointsProvider));
  return repo.leaderboard(
    ref.watch(leaderboardMetricProvider),
    scope: ref.watch(leaderboardScopeProvider),
  );
});

/// مستوى اللاعب الحالي، مشتقّا من XP التراكمية
final playerLevelProvider = Provider<int>(
  (ref) => PlayerLevelCurve.currentLevel(
    ref.watch(progressionProvider).state.wallet.xp,
  ),
);

/// هل يظهر عرض «ادعُ أصدقاءك» أصلا؟
///
/// طلب الدعوة قبل أن يعيش اللاعب اللعبة يحرق الطلب: لا يدعو أحدا لأنه
/// لا يعرف بعد ما يدعوهم إليه، ولا يعود الطلب مرة ثانية بنفس الوقع.
/// لذلك يبقى المدخل *غير موجود* حتى المستوى [BalanceConfig.levelGateReferral]
/// — لا معطَّلا ولا مقفلا بقفل ذهبي، بل غير معروض إطلاقا.
///
/// ملاحظة: هذا يخصّ *إرسال* الدعوات فقط. إدخال رمز وصلك من صديق يبقى
/// متاحا من المستوى الأول — المدعوّ لاعب جديد بحكم التعريف، وتأخير
/// مدخله يعني إلغاء الدعوة التي أحضرته أصلا.
final referralUnlockedProvider = Provider<bool>(
  (ref) =>
      ref.watch(featureFlagsProvider).referral &&
      ref.watch(playerLevelProvider) >= BalanceConfig.levelGateReferral,
);

/// عدد الدعوات الناجحة (المدفوعة) — للعرض وللإنجاز
final referralCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(socialRepositoryProvider).referralCount(),
);

/// حالة الدعوات الكاملة: كم انضمّ، كم تأهّل، كم دُفع، وما السقف
final referralStatusProvider = FutureProvider.autoDispose<ReferralStatus>(
  (ref) => ref.watch(socialRepositoryProvider).referralStatus(),
);

/// يستلم مكافآت الدعوات المتراكمة ويضيفها إلى رصيد الجهاز.
///
/// يُستدعى مرة عند فتح التطبيق: الداعي قد يكون مغلقا تطبيقه لحظة *تأهّل*
/// مدعوّه (بلوغه المستوى الثالث)، فتنتظره المكافأة في السيرفر حتى يعود.
/// السيرفر يعلّمها مستلمة في نفس الاستعلام، فلا تُمنح مرتين.
Future<ClaimedRewards> claimPendingReferralRewards(WidgetRef ref) async {
  final repo = ref.read(socialRepositoryProvider);

  // الزينات أولا: مكافآت مراحل الدعوة (3/5/10) زخرفية بحتة ولا تدخل
  // في مجموع العملات المعروض في البشارة
  final cosmetics = await repo.claimPendingCosmetics();
  if (cosmetics.isNotEmpty) {
    final store = ref.read(progressStoreProvider);
    for (final id in cosmetics) {
      await store.addPendingCosmeticUnlock(id);
    }
  }

  final claimed = await repo.claimPendingRewards();
  if (claimed.isEmpty) return claimed;

  ref.read(pointsProvider.notifier).add(claimed.total, reason: 'referral');
  final achievements = ref.read(achievementsProvider.notifier);
  achievements.bump(StatKey.pointsEarned, claimed.total);
  achievements.bump(StatKey.friendsInvited, claimed.count);
  ref.read(analyticsProvider)?.log(Ev.referralSent, {
    'qualified': claimed.count,
    'coins': claimed.total,
  });
  ref.invalidate(referralCountProvider);
  ref.invalidate(referralStatusProvider);
  return claimed;
}

/// يرفع XP إلى الخادم عند فتح التطبيق.
///
/// وظيفته الحقيقية ليست العرض: هي المسار الذي يؤهّل *دعوتي أنا* حين
/// أبلغ مستوى التأهيل، فيُدفع لمن دعاني. بلا هذه الرفعة يبقى الداعي بلا
/// مكافأة حتى أفتح شاشة الدوري صدفة.
Future<void> syncReferralQualification(WidgetRef ref) => ref
    .read(socialRepositoryProvider)
    .syncXp(ref.read(progressionProvider).state.wallet.xp);

// ─────────────────────── مكافأة المشاركة ───────────────────────

class ShareRewardState {
  /// كم مكافأة مشاركة قُبضت طوال عمر الحساب
  final int used;

  const ShareRewardState(this.used);

  bool get canEarn => used < ShareRewardNotifier.maxTotal;
  int get remaining => ShareRewardNotifier.maxTotal - used;
}

/// مكافأة على مشاركة النتيجة، بسقف **مدى الحياة** لا يومي.
///
/// لا يمكن التحقق فعليا من وصول المنشور لأحد، فالسقف هو الحدّ الفعلي
/// الذي يمنع تحويلها إلى مصدر عملات لا نهائي. كان يوميا (مرّتان كل يوم)
/// فكان ذلك صنبورا دائما بلا سقف حقيقي: من يشارك كل يوم يقبض بلا نهاية
/// على فعل لا يُتحقَّق منه أصلا. الغرض من المكافأة إثبات أن الزرّ يعطي
/// شيئا، وهذا يتمّ في أول مرّتين. الحدّ الثاني — الأهم — زمني لا عددي:
/// المكافأة لا تُطلب إلا بعد *عودة* اللاعب من ورقة المشاركة، فلا تنفع
/// ضغطة تفتح الورقة ثم تلغيها. راجع lib/core/share_return_gate.dart
///
/// وبعد نفاد السقف يبقى زرّ المشاركة كما هو، بلا رسالة «نفدت مكافأتك»:
/// اللاعب لا يُذكَّر بشيء انتهى، والمشاركة نفسها هي المقصودة.
class ShareRewardNotifier extends Notifier<ShareRewardState> {
  static int get reward => BalanceConfig.shareRewardCoins;
  static int get maxTotal => BalanceConfig.shareRewardMaxTotal;

  @override
  ShareRewardState build() =>
      ShareRewardState(ref.read(progressStoreProvider).shareRewardCount);

  /// يمنح المكافأة إن بقي من السقف شيء، ويعيد ما مُنح فعلا (0 إن نفد)
  int claim() {
    if (!state.canEarn) return 0;
    final store = ref.read(progressStoreProvider);
    final used = state.used + 1;
    store.setShareRewardCount(used);
    state = ShareRewardState(used);
    ref.read(pointsProvider.notifier).add(reward, reason: 'share');
    ref.read(achievementsProvider.notifier).bump(StatKey.pointsEarned, reward);
    ref.read(analyticsProvider)?.log(Ev.shareCompleted, {
      'reward': reward,
      'used_total': used,
    });
    return reward;
  }
}

final shareRewardProvider =
    NotifierProvider<ShareRewardNotifier, ShareRewardState>(
      ShareRewardNotifier.new,
    );

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

class NotificationSettingsState {
  final bool dailyRewardEnabled;
  final bool rewardTrackEnabled;
  final bool streakEnabled;

  const NotificationSettingsState({
    required this.dailyRewardEnabled,
    required this.rewardTrackEnabled,
    required this.streakEnabled,
  });
}

class NotificationSettingsNotifier extends Notifier<NotificationSettingsState> {
  @override
  NotificationSettingsState build() {
    final store = ref.read(progressStoreProvider);
    return NotificationSettingsState(
      dailyRewardEnabled: store.notifDailyRewardEnabled,
      rewardTrackEnabled: store.notifRewardTrackEnabled,
      streakEnabled: store.notifStreakEnabled,
    );
  }

  void setDailyRewardEnabled(bool value) {
    ref.read(progressStoreProvider).setNotifDailyRewardEnabled(value);
    state = NotificationSettingsState(
      dailyRewardEnabled: value,
      rewardTrackEnabled: state.rewardTrackEnabled,
      streakEnabled: state.streakEnabled,
    );
  }

  void setRewardTrackEnabled(bool value) {
    ref.read(progressStoreProvider).setNotifRewardTrackEnabled(value);
    state = NotificationSettingsState(
      dailyRewardEnabled: state.dailyRewardEnabled,
      rewardTrackEnabled: value,
      streakEnabled: state.streakEnabled,
    );
  }

  void setStreakEnabled(bool value) {
    ref.read(progressStoreProvider).setNotifStreakEnabled(value);
    state = NotificationSettingsState(
      dailyRewardEnabled: state.dailyRewardEnabled,
      rewardTrackEnabled: state.rewardTrackEnabled,
      streakEnabled: value,
    );
  }
}

/// مرشد الخريطة: مفعّل أم لا. تفضيل جهاز لا تقدّم لعب، فينجو من
/// «البدء من جديد» (راجع ProgressStore._preservedOnReset).
class AssistantEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(progressStoreProvider).assistantEnabled;

  void set(bool value) {
    state = value;
    ref.read(progressStoreProvider).setAssistantEnabled(value);
  }
}

final assistantEnabledProvider =
    NotifierProvider<AssistantEnabledNotifier, bool>(
      AssistantEnabledNotifier.new,
    );

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
      NotificationSettingsNotifier.new,
    );

bool _notificationTypeEnabled(
  AppNotificationType type,
  NotificationSettingsState settings,
) => switch (type) {
  AppNotificationType.dailyRewardReady => settings.dailyRewardEnabled,
  // مفتاح واحد للطبقات الثلاث: هي شاشة واحدة وميزة واحدة، وثلاثة
  // مفاتيح لثلاثة صفوف من نفس البطاقة إغراق للإعدادات بلا مقابل
  AppNotificationType.rewardTrackDailyReady ||
  AppNotificationType.rewardTrackWeeklyReady ||
  AppNotificationType.rewardTrackMonthlyReady => settings.rewardTrackEnabled,
  AppNotificationType.streakEndingTonight => settings.streakEnabled,
  // يتبع مفتاح المكافأة اليومية: نصّه عنها، ومفتاح رابع في
  // الإعدادات لأجل تذكير واحد كل يومين مبالغة
  AppNotificationType.comebackReminder => settings.dailyRewardEnabled,
};

/// مفتاح الإيقاف يمنع إشعار ميزته أيضا. إشعار عن ميزة مطفأة يفتح
/// التطبيق على مدخل غير موجود — وهذا أسوأ من عدم الإشعار.
bool _notificationTypeAllowedByFlags(
  AppNotificationType type,
  FeatureFlags flags,
) => switch (type) {
  AppNotificationType.rewardTrackDailyReady ||
  AppNotificationType.rewardTrackWeeklyReady ||
  AppNotificationType.rewardTrackMonthlyReady => flags.rewardTrack,
  AppNotificationType.dailyRewardReady => true,
  AppNotificationType.streakEndingTonight => true,
  AppNotificationType.comebackReminder => true,
};

/// يُستدعى مرة عند كل فتح/استئناف للتطبيق (راجع _NotificationSync في
/// home_screen.dart، بنفس نمط _PendingRewardsClaimer). يسجّل الجلسة
/// ووقت الفتح، يطلب صلاحية الإشعارات إن حان وقتها، ثم يعيد تقييم
/// وجدولة إشعارات اليوم بالكامل من الصفر — راجع الشرح الكامل لسبب
/// "إلغاء ثم إعادة جدولة" في notification_engine.dart
///
/// أي فشل غير متوقّع (منصّة لا تدعم الإشعارات، بيئة اختبار بلا قناة
/// منصّة حقيقية..) يُبتلَع هنا بصمت مع تسجيله فقط — تماما كنمط
/// games_services_sync.dart: ميزة ثانوية لا يجوز أن تُعطِّل بقية التطبيق
Future<void> syncNotifications(WidgetRef ref) async {
  try {
    await _syncNotificationsImpl(ref);
  } catch (e) {
    debugPrint('syncNotifications: تعذّرت المزامنة: $e');
  }
}

Future<void> _syncNotificationsImpl(WidgetRef ref) async {
  final store = ref.read(progressStoreProvider);
  final service = ref.read(notificationServiceProvider);
  await service.init();

  final now = DateTime.now();
  final previousOpenedAt = store.lastAppOpenedAt == null
      ? null
      : DateTime.tryParse(store.lastAppOpenedAt!);
  await store.setLastAppOpenedAt(now.toIso8601String());

  final sessionCount = store.sessionCount + 1;
  await store.setSessionCount(sessionCount);
  if (NotificationEngine.shouldRequestPermission(
    sessionCount: sessionCount,
    alreadyRequested: store.notificationPermissionRequested,
  )) {
    await service.requestPermission();
    await store.setNotificationPermissionRequested(true);
  }

  final todayKey = _dateKey(now);
  // أنواع استُهلكت فعلا اليوم (جُدولت مرة، حتى لو أُلغيت لاحقا) — لا
  // تُعاد جدولتها ولا تحرّر حصّتها من السقف اليومي إطلاقا
  final alreadyUsedToday = store.notificationsSentDate == todayKey
      ? store.notificationsSentTypes
      : <String>{};

  final settings = ref.read(notificationSettingsProvider);
  final flags = ref.read(featureFlagsProvider);
  final enabledTypes = {
    for (final t in AppNotificationType.values)
      if (_notificationTypeEnabled(t, settings) &&
          _notificationTypeAllowedByFlags(t, flags) &&
          !alreadyUsedToday.contains(t.name))
        t,
  };

  // ميزة مطفأة عن بعد لا تُذكِّر بنفسها. لا معنى لإشعار «جائزة اليوم
  // جاهزة» بينما تبويب الجوائز نفسه مخفيّ من الرئيسية — الإشعار يفتح
  // التطبيق على لا شيء.
  final readyRewardTiers = flags.rewardTrack
      ? _readyRewardTierTypes(ref, now)
      : const <AppNotificationType>{};
  final streakState = ref.read(streakProvider);

  final eligible = NotificationEngine.eligibleNow(
    NotificationDecisionInput(
      dailyRewardUnclaimed: ref.read(dailyRewardProvider).canClaim,
      readyRewardTiers: readyRewardTiers,
      streakNotYetSecuredToday: streakState.securedThroughDateKey != todayKey,
      enabledTypes: enabledTypes,
      lastAppOpenedAt: previousOpenedAt,
      now: now,
      sentCountToday: alreadyUsedToday.length,
    ),
  );

  await service.cancelAll();

  // سلّم العودة قبل أي شيء ومستقل عن جدول اليوم: يُجدول حتى حين لا
  // يستحق اليوم تذكيرا أصلا — وهي الحالة الشائعة للاعب يفتح اللعبة
  // الآن، وهو بالضبط من نريد أن نذكّره لو انقطع بعد اليوم
  await _scheduleComebackChain(ref, service);
  // وتذكيرات مسار الجوائز لأيام قادمة: بلاها لا يصل التذكير إلا لمن فتح
  // اللعبة قبل ساعة النوع من نفس اليوم
  await _scheduleRewardTrackChain(ref, service, now);

  if (eligible.isEmpty) return;

  final lang = ref.read(languageProvider);
  for (final type in eligible) {
    final plan = ScheduledNotification(
      type: type,
      daysAhead: 0,
      hour: NotificationEngine.scheduledHourOf(type),
    );
    final (title, body) = notificationTitleBody(
      type: type,
      lang: lang,
      streakDays: streakState.currentStreak,
    );
    await service.schedule(plan: plan, title: title, body: body);
  }

  await store.setNotificationsSentDate(todayKey);
  await store.setNotificationsSentTypes({
    ...alreadyUsedToday,
    for (final t in eligible) t.name,
  });
}

/// نصّ إشعار واحد بلغة الواجهة الحالية. مفصول في دالة واحدة لأن نفس
/// النصّ يُطلب من مسارين: الجدولة اليومية، وإعادة الصياغة عند تبديل
/// لغة الواجهة (نصّ الإشعار يُثبَّت لحظة الجدولة، فلا يتبع اللغة وحده).
(String, String) notificationTitleBody({
  required AppNotificationType type,
  required AppLanguage lang,
  required int streakDays,
}) => switch (type) {
  AppNotificationType.dailyRewardReady => (
    lang.t('مكافأتك اليومية جاهزة', 'Your daily reward is ready'),
    lang.t('افتح حروف واستلمها الآن', 'Open Huruf and claim it now'),
  ),
  // المبلغ في النصّ لا خارجه: «جائزة بانتظارك» بلا رقم لا تُقارن بشيء،
  // و«200 ألماسة» تُقارن بثمن تلميح فورا
  AppNotificationType.rewardTrackDailyReady => (
    lang.t('جائزة اليوم جاهزة', "Today's reward is ready"),
    lang.t(
      '${BalanceConfig.rewardTrackDailyCoins} ألماسة بانتظارك في مسار الجوائز',
      '${BalanceConfig.rewardTrackDailyCoins} gems waiting on your reward track',
    ),
  ),
  AppNotificationType.rewardTrackWeeklyReady => (
    lang.t('جائزة هذا الأسبوع جاهزة', "This week's reward is ready"),
    lang.t(
      '${BalanceConfig.rewardTrackWeeklyCoins} ألماسة بانتظارك في مسار الجوائز',
      '${BalanceConfig.rewardTrackWeeklyCoins} gems waiting on your reward track',
    ),
  ),
  AppNotificationType.rewardTrackMonthlyReady => (
    lang.t('جائزة هذا الشهر جاهزة', "This month's reward is ready"),
    lang.t(
      '${BalanceConfig.rewardTrackMonthlyCoins} ألماسة بانتظارك في مسار الجوائز',
      '${BalanceConfig.rewardTrackMonthlyCoins} gems waiting on your reward track',
    ),
  ),
  AppNotificationType.streakEndingTonight => (
    lang.t('سلسلتك على المحك', 'Your streak is on the line'),
    lang.t(
      'سلسلة $streakDays أيام تنتهي منتصف الليل',
      'Your $streakDays-day streak ends at midnight',
    ),
  ),
  // لا يُجدول ضمن جدول اليوم إطلاقا — راجع سلّم العودة أدناه
  AppNotificationType.comebackReminder => ('', ''),
};

/// يعيد جدولة ما هو مجدول *الآن* بلغة الواجهة الحالية، بلا إعادة تقييم
/// الأهلية وبلا استهلاك حصّة اليوم.
///
/// لماذا مسار منفصل عن [syncNotifications]: نصّ الإشعار يُثبَّت لحظة
/// الجدولة في نظام التشغيل، فتبديل اللغة بعد الجدولة يترك تذكير المساء
/// باللغة المتروكة. ولا يصحّ استدعاء المزامنة الكاملة بدلا منها: تلك
/// تعامل الفتح كنشاط يُسقط تذكيرات اليوم (أنواع اليوم مستهلَكة فلا
/// تُعاد جدولتها)، فتبديل اللغة كان سيُلغي تذكير اليوم بدل ترجمته.
Future<void> relocalizeScheduledNotifications(WidgetRef ref) async {
  try {
    final store = ref.read(progressStoreProvider);
    final service = ref.read(notificationServiceProvider);
    await service.init();

    final todayKey = _dateKey(DateTime.now());
    final scheduledToday = store.notificationsSentDate == todayKey
        ? store.notificationsSentTypes
        : <String>{};
    final types = [
      for (final type in AppNotificationType.values)
        if (type != AppNotificationType.comebackReminder &&
            scheduledToday.contains(type.name))
          type,
    ];

    await service.cancelAll();
    await _scheduleComebackChain(ref, service);
    await _scheduleRewardTrackChain(ref, service, DateTime.now());

    if (types.isEmpty) return;

    final lang = ref.read(languageProvider);
    final streakState = ref.read(streakProvider);

    for (final type in types) {
      final (title, body) = notificationTitleBody(
        type: type,
        lang: lang,
        streakDays: streakState.currentStreak,
      );
      // ما فات موعده اليوم تتجاهله NotificationService.schedule نفسها
      await service.schedule(
        plan: ScheduledNotification(
          type: type,
          daysAhead: 0,
          hour: NotificationEngine.scheduledHourOf(type),
        ),
        title: title,
        body: body,
      );
    }
  } catch (e) {
    debugPrint('relocalizeScheduledNotifications: تعذّرت إعادة الصياغة: $e');
  }
}

/// تذكيرات «عُد إلينا» للأيام القادمة. تُجدول كاملة عند كل فتح وتُلغى
/// كاملة عند الفتح التالي (cancelAll أعلاه)، فاللاعب المنتظم لا يرى
/// منها شيئا: تذكير اليوم الثاني يموت قبل موعده كلما فتح اللعبة.
Future<void> _scheduleComebackChain(
  WidgetRef ref,
  NotificationService service,
) async {
  final settings = ref.read(notificationSettingsProvider);
  final plans = NotificationEngine.comebackPlan(
    enabled: _notificationTypeEnabled(
      AppNotificationType.comebackReminder,
      settings,
    ),
  );
  if (plans.isEmpty) return;

  final lang = ref.read(languageProvider);
  for (final plan in plans) {
    // النص يتدرّج مع طول الغياب: «مكافأتك جاهزة» في اليوم الثاني نداء
    // مباشر، وفي اليوم السابع تذكير بأن هناك ما يُستأنف
    final (title, body) = switch (plan.daysAhead) {
      <= 2 => (
        lang.t('مكافأتك اليومية بانتظارك', 'Your daily reward is waiting'),
        lang.t('عد إلى حروف واستلمها', 'Come back to Huruf and claim it'),
      ),
      <= 4 => (
        lang.t('اشتقنا إليك', 'We miss you'),
        lang.t(
          'مكافآت يومية تراكمت في انتظارك',
          'Daily rewards have piled up for you',
        ),
      ),
      _ => (
        lang.t('أسبوع بلا حروف', 'A week without Huruf'),
        lang.t(
          'مرحلتك التالية ومكافأتك اليومية بانتظارك',
          'Your next level and daily reward are waiting',
        ),
      ),
    };
    await service.schedule(plan: plan, title: title, body: body);
  }
}

/// أنواع إشعارات طبقات مسار الجوائز الجاهزة للمطالبة الآن
Set<AppNotificationType> _readyRewardTierTypes(WidgetRef ref, DateTime now) {
  final track = ref.read(rewardTrackProvider);
  return {
    for (final status in RewardTrackEngine.statuses(track, now))
      if (status.isReady) _rewardTierNotificationType(status.tier),
  };
}

AppNotificationType _rewardTierNotificationType(RewardTier tier) =>
    switch (tier) {
      RewardTier.daily => AppNotificationType.rewardTrackDailyReady,
      RewardTier.weekly => AppNotificationType.rewardTrackWeeklyReady,
      RewardTier.monthly => AppNotificationType.rewardTrackMonthlyReady,
    };

/// تذكيرات مسار الجوائز للأيام القادمة.
///
/// جدول اليوم وحده كان يعني تذكيرا لمن يفتح اللعبة قبل ساعة النوع فقط.
/// هذه السلسلة تجعله يصل فعلا حتى لمن لا يفتحها إطلاقا، وتُلغى وتُعاد
/// جدولتها عند كل فتح فلا يصل تذكير عن جائزة استُلمت بالفعل.
///
/// أي يوم تنتهي عنده الطبقة (استُنفدت مطالباتها) لا يُجدول له شيء —
/// `RewardTrackEngine.readyDaysAhead` تعيد قائمة فارغة عندها، فلا يصل
/// «جائزة اليوم جاهزة» بعد انقضاء المسار.
Future<void> _scheduleRewardTrackChain(
  WidgetRef ref,
  NotificationService service,
  DateTime now,
) async {
  final settings = ref.read(notificationSettingsProvider);
  final flags = ref.read(featureFlagsProvider);
  final track = ref.read(rewardTrackProvider);

  final plans = NotificationEngine.rewardTrackPlan(
    enabled:
        _notificationTypeEnabled(
          AppNotificationType.rewardTrackDailyReady,
          settings,
        ) &&
        _notificationTypeAllowedByFlags(
          AppNotificationType.rewardTrackDailyReady,
          flags,
        ),
    readyDaysAhead: {
      for (final tier in RewardTier.values)
        _rewardTierNotificationType(tier): RewardTrackEngine.readyDaysAhead(
          tier,
          track,
          now,
          horizonDays: NotificationEngine.rewardTrackDaysAhead,
        ),
    },
  );
  if (plans.isEmpty) return;

  final lang = ref.read(languageProvider);
  for (final plan in plans) {
    final (title, body) = notificationTitleBody(
      type: plan.type,
      lang: lang,
      streakDays: 0,
    );
    await service.schedule(plan: plan, title: title, body: body);
  }
}

// ─────────────────────── ودجة الشاشة الرئيسية ───────────────────────
//
// الودجة **طبقة عرض فقط**: تقرأ لقطة جاهزة يكتبها التطبيق، ولا تحسب
// مكافأة ولا تُطالب بها ولا تمسّ الألماس أو السلسلة أو التقدّم. كل قرار
// اقتصادي يبقى هنا وفي rewardTrackProvider — راجع الشرح الكامل أعلى
// lib/data/widget/widget_data.dart.

final homeWidgetServiceProvider = Provider<HomeWidgetService>(
  (ref) => HomeWidgetService(),
);

/// يبني لقطة الودجة من الحالة الحيّة. مفصولة عن [syncHomeWidget] كي
/// تُختبر بلا منصّة ولا قناة أصلية.
HomeWidgetData buildHomeWidgetSnapshot(WidgetRef ref, {DateTime? now}) {
  final stats = ref.read(achievementsProvider);
  return WidgetDataBuilder.build(
    track: ref.read(rewardTrackProvider),
    now: now ?? DateTime.now(),
    diamonds: ref.read(pointsProvider),
    streakDays: ref.read(streakProvider).currentStreak,
    stagesCompleted: stats.valueOf(StatKey.levelsCompleted),
    chaptersCompleted: stats.valueOf(StatKey.chaptersCompleted),
    worldsCompleted: stats.valueOf(StatKey.worldsCompleted),
    languageCode: ref.read(languageProvider).name,
  );
}

/// يدفع اللقطة الحالية إلى الودجة. يُستدعى عند كل فتح/استئناف للتطبيق،
/// وبعد كل حدث يغيّر ما تعرضه (مطالبة بجائزة، إتمام مرحلة، تبديل لغة).
///
/// لا يوقظ التطبيق ولا يجدول شيئا: الكتابة محلية والنظام هو من يعيد
/// رسم الودجة. راجع كذلك التحديث الدوري في huruf_widget_info.xml
/// (`updatePeriodMillis`) الذي يلتقط تغيّر اليوم بلا أي عمل خلفي منّا.
Future<void> syncHomeWidget(WidgetRef ref) async {
  try {
    await ref
        .read(homeWidgetServiceProvider)
        .push(buildHomeWidgetSnapshot(ref));
  } catch (e) {
    debugPrint('الودجة: تعذّرت المزامنة: $e');
  }
}

/// يمنح مكافأة تفعيل الودجة مرة واحدة فقط، ويعيد المبلغ الممنوح (أو
/// null إن لم يكن هناك ما يُمنح).
///
/// يُستدعى عند كل فتح/استئناف: اللاعب قد يضيف الودجة والتطبيق مغلق،
/// فلا لحظة أخرى نعرف فيها أنها أُضيفت.
Future<int?> grantWidgetActivationRewardIfDue(WidgetRef ref) async {
  try {
    final store = ref.read(progressStoreProvider);
    if (store.widgetActivationRewarded) return null;

    final installed = await ref.read(homeWidgetServiceProvider).isInstalled();
    if (!WidgetActivation.shouldGrant(
      widgetInstalled: installed,
      alreadyRewarded: store.widgetActivationRewarded,
    )) {
      return null;
    }

    // العلَم أولا ثم المنح: لو قُتلت العملية بين السطرين، الأسوأ أن
    // تضيع المكافأة مرة — لا أن تُمنح مرتين
    await store.setWidgetActivationRewarded(true);
    final coins = BalanceConfig.widgetActivationRewardCoins;
    ref
        .read(pointsProvider.notifier)
        .add(coins, reason: WidgetActivation.earnReason);
    return coins;
  } catch (e) {
    debugPrint('الودجة: تعذّر منح مكافأة التفعيل: $e');
    return null;
  }
}
