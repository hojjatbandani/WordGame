import 'package:huruf/config/balance_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/economy/economy_events.dart';
import 'package:huruf/data/economy/economy_models.dart';
import 'package:huruf/data/economy/economy_service.dart';
import 'package:huruf/data/economy/stage_reward.dart';
import 'package:huruf/data/progression/player_state.dart';

void main() {
  group('مكافأة إتمام المرحلة', () {
    test('إعادة لعب مرحلة مكتملة تمنح صفر عملات (اختبار قبول)، بصرف '
        'النظر عن كلمات إضافية جديدة في هذه المحاولة — إضافتها للجرّة '
        'مسؤولية طبقة التقدّم المنفصلة، لا هذه الطبقة', () {
      final economy = EconomyService(wallet: PlayerWallet.initial());
      final breakdown = economy.computeStageReward(
        const StageResult(
          worldId: 1,
          isBossStage: false,
          isReplay: true,
          coreWordsFound: 5,
          newBonusWordsFoundThisRun: 2, // كلمة جديدة فعلا، لكن إعادة لعب
          isPerfect: true,
          chapterJustCompleted: false,
          worldJustCompleted: false,
        ),
      );
      expect(breakdown.total, 0);
      expect(breakdown.stageClearCoins, 0);
      expect(breakdown.coreWordCoins, 0);
      expect(breakdown.bonusWordCoins, 0);
      expect(breakdown.perfectBonusCoins, 0);
    });

    test('أول إكمال عادي في عالم1: 8(مرحلة) + 2×5(كلمات) + 2×1(إضافية) '
        '+ 4(إتقان) = 24، عند السقف تماما', () {
      final economy = EconomyService(wallet: PlayerWallet.initial());
      final breakdown = economy.computeStageReward(
        const StageResult(
          worldId: 1,
          isBossStage: false,
          isReplay: false,
          coreWordsFound: 5,
          newBonusWordsFoundThisRun: 1,
          isPerfect: true,
          chapterJustCompleted: false,
          worldJustCompleted: false,
        ),
      );
      expect(breakdown.stageClearCoins, 8);
      expect(breakdown.coreWordCoins, 10);
      expect(breakdown.bonusWordCoins, 2);
      expect(breakdown.perfectBonusCoins, 4);
      expect(breakdown.total, 24);
      expect(
        breakdown.total,
        lessThanOrEqualTo(BalanceConfig.maxCoinsPerStage),
        reason: 'الحالة العادية دون السقف، فالقصّ لا يشوّه الأسطر',
      );
    });

    test('مضاعف عالم 8 (2.00) يُطبَّق على المرحلة/الكلمات/الإتقان، لا على '
        'مكافأة الزعيم أو إتمام الفصل — تبقيان ثابتتين', () {
      // المكافأتان صفر في التوازن المشحون (مكافأة الفصل تعيش في صندوقه
      // وحده)، فنرفعهما هنا مؤقّتا وإلا لم يفحص الاختبار شيئا: 0 بلا
      // مضاعف تساوي 0 بمضاعف. المفحوص هو قاعدة «لا مضاعف عالم عليهما».
      // والسقف يُرفع كذلك: المفحوص هنا قاعدة المضاعف لا القصّ، ومجموع
      // هذه الحالة (41) يتجاوز 12 فيبتلع القصُّ ما نريد قياسه
      final cap = BalanceConfig.maxCoinsPerStage;
      BalanceConfig.coinsBossStageBonus = 25;
      BalanceConfig.coinsChapterComplete = 30;
      BalanceConfig.maxCoinsPerStage = 1000;
      addTearDown(() {
        BalanceConfig.coinsBossStageBonus = 0;
        BalanceConfig.coinsChapterComplete = 0;
        BalanceConfig.maxCoinsPerStage = cap;
      });

      final economy = EconomyService(wallet: PlayerWallet.initial());
      final breakdown = economy.computeStageReward(
        const StageResult(
          worldId: 8,
          isBossStage: true,
          isReplay: false,
          coreWordsFound: 5,
          newBonusWordsFoundThisRun: 0,
          isPerfect: false,
          chapterJustCompleted: true,
          worldJustCompleted: false,
        ),
      );
      expect(breakdown.stageClearCoins, 16, reason: '8 × 2.00');
      expect(breakdown.coreWordCoins, 20, reason: '2×5 × 2.00');
      expect(breakdown.bossBonusCoins, 25, reason: 'ثابتة، بلا مضاعف');
      expect(breakdown.chapterCompleteCoins, 30, reason: 'ثابتة، بلا مضاعف');
    });

    test(
      'applyStageReward تُحدّث المحفظة فعليا وتصدر حدثا لكل مكوّن على حدة',
      () {
        final events = <EconomyEvent>[];
        final economy = EconomyService(
          wallet: PlayerWallet.initial(),
          onEvent: events.add,
        );
        economy.applyStageReward(
          const StageResult(
            worldId: 1,
            isBossStage: false,
            isReplay: false,
            coreWordsFound: 3,
            newBonusWordsFoundThisRun: 0,
            isPerfect: false,
            chapterJustCompleted: false,
            worldJustCompleted: false,
          ),
        );
        // 8 (مرحلة) + 6 (3 كلمات × 2) = 14، وهو دون الأرضية فيُكمَّل
        // إلى 16 عبر سطر الإتمام وحده
        expect(economy.wallet.coins, BalanceConfig.minCoinsPerStage);
        expect(
          events.length,
          2,
          reason: 'حدث لمصدر المرحلة وحدث لمصدر الكلمات',
        );
        expect(events.every((e) => e.kind == EconomyEventKind.earn), isTrue);
      },
    );

    test('الإنفاق الفاشل (رصيد غير كافٍ) يصدر حدثا صريحا، لا صمتا', () {
      final events = <EconomyEvent>[];
      final economy = EconomyService(
        wallet: PlayerWallet.initial(),
        onEvent: events.add,
      );
      final result = economy.spend(50, SpendReason.hint);
      expect(result.isFailure, isTrue);
      expect(economy.wallet.coins, 0, reason: 'لا تغيير على فشل');
      expect(events.length, 1);
      expect(events.single.kind, EconomyEventKind.spendFailed);
    });

    test('إنفاق ناجح يخصم المبلغ ويصدر حدث نجاح', () {
      final economy = EconomyService(
        wallet: PlayerWallet.initial().copyWith(coins: 100),
      );
      final result = economy.spend(30, SpendReason.hint);
      expect(result.isSuccess, isTrue);
      expect(economy.wallet.coins, 70);
    });
  });
}
