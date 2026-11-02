// محرّك اقتصاد العملات. Dart صرف — بلا أي استيراد Flutter — يُنشأ حول
// PlayerWallet الحالية (من lib/data/progression/player_state.dart، الحقل
// الوحيد المشترك فعليا بين المهمتين) ويُحدّثها في الذاكرة فقط؛ الكتابة
// الفعلية إلى SharedPreferences تبقى مسؤولية ProgressionRepository (لا
// علاقة لهذا الملف بها، ولا يستورد shared_preferences إطلاقا).
//
// "quote"/"compute" = حساب صرف بلا أي أثر جانبي (لا يُغيّر المحفظة ولا
// يصدر حدثا). "spend"/"award"/"apply*" = تُغيّر المحفظة فعليا وتصدر
// [EconomyEvent] واحدا على الأقل دوما — بلا استثناء، حتى محاولة إنفاق
// فاشلة تصدر حدثا (فشل الإنفاق نفسه معلومة تحليلية، لا يجوز إخفاؤها).

import '../../config/balance_config.dart';
import '../progression/player_state.dart';
import 'chapter_chest.dart';
import 'economy_events.dart';
import 'economy_models.dart';
import 'stage_reward.dart';

class EconomyService {
  PlayerWallet _wallet;
  final EconomyEventSink _emit;

  EconomyService({
    required this._wallet,
    EconomyEventSink onEvent = noopEconomyEventSink,
  }) : _emit = onEvent;

  PlayerWallet get wallet => _wallet;

  // ─────────────────────── التلميحات ───────────────────────

  static int _roundToNearest(double value, int unit) =>
      (value / unit).round() * unit;

  /// سعر تلميح واحد بالعملات — حساب صرف، لا يُنفق شيئا. [hintsUsedThisStage]
  /// هو كم تلميحا استُخدم في هذه المرحلة *قبل* هذا التلميح (0 = هذا الأول).
  /// يبقى 15 دوما بعد مغادرة المرحلة والعودة إليها لأن هذه الدالة لا
  /// تتذكر شيئا بين استدعاءاتها — الصفر يأتي من المستدعي دوما في تلك
  /// الحالة، لا من حالة داخلية هنا.
  int quoteHintCost(
    HintType type, {
    required int hintsUsedThisStage,
    required int worldId,
  }) {
    if (type == HintType.revealEntireWord &&
        hintsUsedThisStage <
            BalanceConfig.revealEntireWordMinHintsUsedThisStage) {
      throw StateError(
        'كشف الكلمة كاملة غير متاح إلا من التلميح رقم '
        '${BalanceConfig.revealEntireWordMinHintsUsedThisStage + 1} فصاعدا '
        '— hintsUsedThisStage=$hintsUsedThisStage',
      );
    }
    final baseCost = type == HintType.revealEntireWord
        ? BalanceConfig.coinsRevealEntireWord
        : BalanceConfig.hintBaseCostForPosition(hintsUsedThisStage);
    final mult = BalanceConfig.hintCostMultiplierForWorld(worldId);
    return _roundToNearest(baseCost * mult, BalanceConfig.hintCostRoundingUnit);
  }

  /// يستهلك شحنة تلميح مجانية إن وُجدت (تغطّي أول تلميح في المرحلة
  /// فقط — على المستدعي عدم استدعائها إلا لأول تلميح في المرحلة). يعيد
  /// true إن استُهلكت شحنة فعلا. لا تُنفق عملات هنا مطلقا — الشحنات
  /// تُستهلك *قبل* العملات دوما، فعلى المستدعي تجربة هذه أولا.
  bool consumeHintCharge() {
    if (_wallet.hintCharges <= 0) return false;
    _wallet = _wallet.copyWith(hintCharges: _wallet.hintCharges - 1);
    return true;
  }

  /// يضيف شحنات تلميح *مملوكة* (اشتُريت أو رُبحت من العجلة/صندوق
  /// المهمات). لا سقف هنا عمدا، بخلاف [grantFreeHintChargeIfEarned]:
  /// [BalanceConfig.maxHintCharges] سقف على ما تمنحه اللعبة مجانا، لا
  /// على ما دفع اللاعب ثمنه — حزمة البداية وحدها تمنح خمسا.
  void grantHintCharges(int count) {
    if (count <= 0) return;
    _wallet = _wallet.copyWith(hintCharges: _wallet.hintCharges + count);
  }

  /// شحنة تلميح واحدة كل [BalanceConfig.stagesPerFreeHintCharge] مراحل
  /// مكتملة، بحد أقصى [BalanceConfig.maxHintCharges]. تُستدعى بعد كل
  /// إتمام مرحلة أول مرة (ليس إعادة لعب) بعدد المراحل المكتملة الكلي.
  void grantFreeHintChargeIfEarned(int totalStagesClearedNow) {
    if (totalStagesClearedNow <= 0 ||
        totalStagesClearedNow % BalanceConfig.stagesPerFreeHintCharge != 0) {
      return;
    }
    if (_wallet.hintCharges >= BalanceConfig.maxHintCharges) return;
    _wallet = _wallet.copyWith(hintCharges: _wallet.hintCharges + 1);
  }

  // ─────────────────────── الإنفاق العام ───────────────────────

  Result<void> spend(int amount, SpendReason reason) {
    if (amount < 0) {
      throw ArgumentError('لا يمكن إنفاق مبلغ سالب: $amount');
    }
    if (_wallet.coins < amount) {
      final message = 'رصيد غير كاف: يملك ${_wallet.coins}، يحتاج $amount';
      _emit(
        EconomyEvent.spendFailed(
          amount: amount,
          reason: reason,
          balanceBefore: _wallet.coins,
          message: message,
        ),
      );
      return Result.fail(message);
    }
    _wallet = _wallet.copyWith(coins: _wallet.coins - amount);
    _emit(
      EconomyEvent.spendSucceeded(
        amount: amount,
        reason: reason,
        balanceAfter: _wallet.coins,
      ),
    );
    return Result.ok();
  }

  void award(int amount, EarnReason reason) {
    if (amount < 0) {
      throw ArgumentError('لا يمكن منح مبلغ سالب: $amount');
    }
    _wallet = _wallet.copyWith(coins: _wallet.coins + amount);
    _emit(
      EconomyEvent.earned(
        amount: amount,
        reason: reason,
        balanceAfter: _wallet.coins,
      ),
    );
  }

  // ─────────────────────── مكافأة إتمام المرحلة ───────────────────────

  /// حساب صرف بحت — لا يُغيّر المحفظة ولا يصدر حدثا. إعادة لعب مرحلة
  /// مكتملة تعيد صفرا في كل حقل دوما، بصرف النظر عن بقية مدخلات
  /// [result] (كلمات إضافية جديدة ما زالت تُحتسب لصالح الجرّة في طبقة
  /// التقدّم المنفصلة، لا لصالح العملات هنا مطلقا).
  StageRewardBreakdown computeStageReward(StageResult result) {
    if (result.isReplay) return StageRewardBreakdown.zero;

    final mult = BalanceConfig.coinEarningMultiplierForWorld(result.worldId);
    int scaled(int base) => _roundToNearest(base * mult, 1);

    final raw = StageRewardBreakdown(
      stageClearCoins: scaled(BalanceConfig.coinsStageClear),
      coreWordCoins: scaled(
        BalanceConfig.coinsPerCoreWord * result.coreWordsFound,
      ),
      bonusWordCoins: scaled(
        BalanceConfig.coinsPerBonusWord * result.newBonusWordsFoundThisRun,
      ),
      perfectBonusCoins: result.isPerfect
          ? scaled(BalanceConfig.coinsPerfectStageBonus)
          : 0,
      // الأربعة التالية عمدا بلا مضاعف عالم — راجع التعليق في BalanceConfig
      bossBonusCoins: result.isBossStage
          ? BalanceConfig.coinsBossStageBonus
          : 0,
      chapterCompleteCoins: result.chapterJustCompleted
          ? BalanceConfig.coinsChapterComplete
          : 0,
      chapterChestCoins: result.chapterChestAlreadyRolled,
      worldCompleteCoins: result.worldJustCompleted
          ? BalanceConfig.coinsWorldComplete
          : 0,
    );
    return _clampPlayCoins(raw);
  }

  /// يحصر أجر لعب المرحلة بين [BalanceConfig.minCoinsPerStage] و
  /// [BalanceConfig.maxCoinsPerStage].
  ///
  /// العمل على الأسطر لا على المجموع: `applyStageReward` يمنح كل سطر
  /// على حدة ويصدر له حدثا تحليليا مستقلا، فلو حصرنا المجموع وحده صار
  /// ما تعرضه الواجهة وما تسجّله التحليلات مخالفا لما دخل المحفظة فعلا.
  ///
  /// ترتيب الاقتطاع مقصود — من الأقل دلالة أولا: الكلمات الإضافية
  /// اختيارية أصلا، ثم كلمات الأساس (عددها يتبع حجم المرحلة لا مهارة
  /// اللاعب)، ثم الكمال، ثم الزعيم. أجر الإتمام آخر ما يُمسّ: مرحلة
  /// أُنهيت يجب أن تدفع شيئا مهما بلغ السقف.
  ///
  /// والتكميل إلى الأرضية يذهب كله إلى أجر الإتمام: هو السطر الذي
  /// معناه «أنهيتَ المرحلة»، فزيادته لا تكذب على اللاعب — بخلاف نفخ
  /// سطر الكلمات بما لا يقابله كلمة.
  ///
  /// صندوق الفصل وإتمام العالم خارج الحصر: ليسا أجر لعب مرحلة.
  static StageRewardBreakdown _clampPlayCoins(StageRewardBreakdown b) {
    final play =
        b.stageClearCoins +
        b.coreWordCoins +
        b.bonusWordCoins +
        b.perfectBonusCoins +
        b.bossBonusCoins;

    // مرحلة بلا أجر لعب أصلا (إعادة لعب) لا تُرفع إلى الأرضية — الصفر
    // هنا قرار لا نقص، ودالة الحساب تعيده قبل الوصول إلى هنا
    if (play <= 0) return b;

    if (play < BalanceConfig.minCoinsPerStage) {
      return _withStageClear(
        b,
        b.stageClearCoins + (BalanceConfig.minCoinsPerStage - play),
      );
    }

    var excess = play - BalanceConfig.maxCoinsPerStage;
    if (excess <= 0) return b;

    int trim(int line) {
      final cut = excess < line ? excess : line;
      excess -= cut;
      return line - cut;
    }

    final bonusWord = trim(b.bonusWordCoins);
    final coreWord = trim(b.coreWordCoins);
    final perfect = trim(b.perfectBonusCoins);
    final boss = trim(b.bossBonusCoins);
    final stageClear = trim(b.stageClearCoins);

    return StageRewardBreakdown(
      stageClearCoins: stageClear,
      coreWordCoins: coreWord,
      bonusWordCoins: bonusWord,
      perfectBonusCoins: perfect,
      bossBonusCoins: boss,
      chapterCompleteCoins: b.chapterCompleteCoins,
      chapterChestCoins: b.chapterChestCoins,
      worldCompleteCoins: b.worldCompleteCoins,
    );
  }

  static StageRewardBreakdown _withStageClear(
    StageRewardBreakdown b,
    int stageClearCoins,
  ) => StageRewardBreakdown(
    stageClearCoins: stageClearCoins,
    coreWordCoins: b.coreWordCoins,
    bonusWordCoins: b.bonusWordCoins,
    perfectBonusCoins: b.perfectBonusCoins,
    bossBonusCoins: b.bossBonusCoins,
    chapterCompleteCoins: b.chapterCompleteCoins,
    chapterChestCoins: b.chapterChestCoins,
    worldCompleteCoins: b.worldCompleteCoins,
  );

  /// يحسب المكافأة ثم يطبّقها فعليا (award لكل مكوّن على حدة، فيصدر حدثا
  /// مستقلا لكل مصدر — لا مبلغا إجماليا واحدا مبهما). يعيد التفصيل نفسه
  /// كي تعرضه الواجهة لاحقا.
  StageRewardBreakdown applyStageReward(StageResult result) {
    final breakdown = computeStageReward(result);
    if (breakdown.stageClearCoins > 0) {
      award(breakdown.stageClearCoins, EarnReason.stageClear);
    }
    if (breakdown.coreWordCoins > 0) {
      award(breakdown.coreWordCoins, EarnReason.coreWord);
    }
    if (breakdown.bonusWordCoins > 0) {
      award(breakdown.bonusWordCoins, EarnReason.bonusWord);
    }
    if (breakdown.perfectBonusCoins > 0) {
      award(breakdown.perfectBonusCoins, EarnReason.perfectStageBonus);
    }
    if (breakdown.bossBonusCoins > 0) {
      award(breakdown.bossBonusCoins, EarnReason.bossStageBonus);
    }
    if (breakdown.chapterCompleteCoins > 0) {
      award(breakdown.chapterCompleteCoins, EarnReason.chapterComplete);
    }
    if (breakdown.chapterChestCoins > 0) {
      award(breakdown.chapterChestCoins, EarnReason.chapterChest);
    }
    if (breakdown.worldCompleteCoins > 0) {
      award(breakdown.worldCompleteCoins, EarnReason.worldComplete);
    }
    return breakdown;
  }

  /// كم عملة تمنحها كلمة إضافية *واحدة* في [worldId] — نفس حساب
  /// [computeStageReward] لسطر الكلمات الإضافية، مستخرَجا وحده لأن شاشة
  /// اللعب تمنحها لحظة اكتشاف الكلمة لا عند إتمام المرحلة (المكافأة
  /// الفورية هي نصف متعة الكلمة الإضافية). من يستدعي هذه يجب أن يمرّر
  /// `newBonusWordsFoundThisRun: 0` في [StageResult] وإلا دُفعت مرتين.
  int quoteBonusWordCoins(int worldId) => _roundToNearest(
    BalanceConfig.coinsPerBonusWord *
        BalanceConfig.coinEarningMultiplierForWorld(worldId),
    1,
  );

  /// مبلغ صندوق الفصل [chapterId] — يلفّ [ChapterChest.amountFor].
  ///
  /// كانت `rollChapterChest(Random)`: الاسم والمعامل كلاهما صار كذبا
  /// حين صار المبلغ ثابتا، فبقاؤهما يوحي بعشوائية لم تعد موجودة.
  static int chapterChestCoins(int chapterId) =>
      ChapterChest.amountFor(chapterId);
}
