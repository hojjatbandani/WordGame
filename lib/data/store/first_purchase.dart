// محفّز الشراء الأول ومكافأته. Dart صرف — بلا Flutter وبلا ساعة داخلية:
// [now] معامل صريح كبقية منطق الصرف في المشروع.
//
// المحفّز سلوكي لا تقويمي. «اليوم الثالث» يصادف لاعبا سعيدا فيقرأ العرض
// إزعاجا، ولاعبا محبطا فيقرأه استغلالا. أما اللحظة التي اجتمع فيها:
// لم يشترِ قط + رصيده تحت الثلاثين + فشل في مرحلته مرتين + أنهى عشرين
// مرحلة — فهي لحظة واحدة بعينها يعرف فيها اللاعب ما ينقصه ولماذا،
// والعرض فيها إجابة لا مقاطعة.
//
// كل الشروط مطلوبة معا (AND). إسقاط أي واحد منها يحوّل العرض إلى نافذة
// عامة تُغلَق بلا قراءة، ويحرق العرض الوحيد المتاح في العمر.

import '../../config/balance_config.dart';
import 'store_catalog.dart';

/// لماذا لم يظهر العرض — للتحليلات ولتشخيص «لماذا لا يظهر عندي»
enum FirstPurchaseBlock {
  alreadyPurchased,
  alreadyOffered,
  balanceTooHigh,
  notFailingEnough,
  tooEarlyInGame,
  shownRecently,
  storeDisabled,
}

class FirstPurchaseDecision {
  final bool show;
  final FirstPurchaseBlock? block;

  const FirstPurchaseDecision._(this.show, this.block);

  static const _show = FirstPurchaseDecision._(true, null);
  const FirstPurchaseDecision.blocked(this.block) : show = false;
}

/// عرض الشراء الأول القائم الآن: خصم ومهلة
class FirstPurchaseOffer {
  final DateTime startedAt;
  final DateTime endsAt;
  final int discountPercent;
  final double referenceUsd;

  const FirstPurchaseOffer({
    required this.startedAt,
    required this.endsAt,
    required this.discountPercent,
    required this.referenceUsd,
  });

  /// السعر بعد الخصم، **محدودا بأدنى شريحة سعر حقيقية في المتجرين**.
  ///
  /// بلا هذا الحدّ تعرض البطاقة 0.30$ ثم تفتح ورقة الدفع على 0.99$:
  /// لا توجد شريحة تحت 0.99$ لتُسجَّل أصلا. الرقم المعروض يجب أن يكون
  /// الرقم المدفوع، وإلا فهو إعلان كاذب لا خصم.
  double get discountedUsd {
    final raw = referenceUsd * (100 - discountPercent) / 100;
    final floor = StoreCatalog.minimumStorePriceUsd;
    if (referenceUsd <= floor) return referenceUsd;
    return raw < floor ? floor : raw;
  }

  /// هل خفّض العرض السعر فعلا؟
  ///
  /// false حين يكون المنتج أصلا على أدنى شريحة (حزمة البداية بعد
  /// تسعيرها بـ0.99$): عندها لا تُشطب سعرٌ ولا تُعرض شارة «-٧٠٪» —
  /// يبقى العدّاد التنازلي وحده، فالإلحاح صادق والخصم لا.
  bool get loweredPrice => discountedUsd < referenceUsd - 0.001;

  Duration remaining(DateTime now) {
    final left = endsAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isActive(DateTime now) => now.isBefore(endsAt);
}

/// مكافأة الشراء الأول: مضاعف عملات مؤقّت + زينة حصرية. تُمنح مع أي
/// شراء أول مهما صغر — «أخذت أكثر مما دفعت» هو ما يرفع احتمال الشراء
/// الثاني، وهو الرقم الذي يهمّ فعلا.
class FirstPurchaseBonus {
  final DateTime until;
  final double coinMultiplier;
  final String avatarId;

  const FirstPurchaseBonus({
    required this.until,
    required this.coinMultiplier,
    required this.avatarId,
  });

  bool isActive(DateTime now) => now.isBefore(until);
}

class FirstPurchase {
  const FirstPurchase._();

  /// هل يُعرض عرض الشراء الأول الآن؟ كل الشروط مطلوبة معا.
  ///
  /// [alreadyOfferedThisInstall] هو الحارس القاطع: العرض مرة واحدة لكل
  /// تثبيت. [lastShownAt] فحص ثان يبقى ساريا لو رُخّي الأول يوما إلى
  /// «مرة كل موسم» — الحارسان لا يتعارضان، والأضيق هو الحاكم.
  static FirstPurchaseDecision shouldOffer({
    required bool hasEverPurchased,
    required bool alreadyOfferedThisInstall,
    required int coinBalance,
    required int failedAttemptsCurrentStage,
    required int stagesCompleted,
    required DateTime? lastShownAt,
    required DateTime now,
    bool storeEnabled = true,
  }) {
    if (!storeEnabled) {
      return const FirstPurchaseDecision.blocked(
        FirstPurchaseBlock.storeDisabled,
      );
    }
    if (hasEverPurchased) {
      return const FirstPurchaseDecision.blocked(
        FirstPurchaseBlock.alreadyPurchased,
      );
    }
    if (alreadyOfferedThisInstall) {
      return const FirstPurchaseDecision.blocked(
        FirstPurchaseBlock.alreadyOffered,
      );
    }
    if (coinBalance >= BalanceConfig.firstPurchaseMaxCoinBalance) {
      return const FirstPurchaseDecision.blocked(
        FirstPurchaseBlock.balanceTooHigh,
      );
    }
    if (failedAttemptsCurrentStage <
        BalanceConfig.firstPurchaseMinStageFailures) {
      return const FirstPurchaseDecision.blocked(
        FirstPurchaseBlock.notFailingEnough,
      );
    }
    if (stagesCompleted < BalanceConfig.firstPurchaseMinStagesCompleted) {
      return const FirstPurchaseDecision.blocked(
        FirstPurchaseBlock.tooEarlyInGame,
      );
    }
    if (lastShownAt != null &&
        now.difference(lastShownAt) <
            BalanceConfig.firstPurchaseMinGapBetweenShows) {
      return const FirstPurchaseDecision.blocked(
        FirstPurchaseBlock.shownRecently,
      );
    }
    return FirstPurchaseDecision._show;
  }

  static FirstPurchaseOffer startOffer({
    required DateTime now,
    required double referenceUsd,
  }) => FirstPurchaseOffer(
    startedAt: now,
    endsAt: now.add(BalanceConfig.firstPurchaseOfferDuration),
    discountPercent: BalanceConfig.firstPurchaseOfferDiscountPercent,
    referenceUsd: referenceUsd,
  );

  static FirstPurchaseBonus grantBonus(DateTime now) => FirstPurchaseBonus(
    until: now.add(BalanceConfig.firstPurchaseBonusDuration),
    coinMultiplier: BalanceConfig.firstPurchaseCoinMultiplier,
    avatarId: BalanceConfig.firstPurchaseAvatarId,
  );

  /// يطبّق مضاعف الشراء الأول على مكافأة عملات مكتسبة من اللعب.
  /// التقريب لأعلى عمدا: مضاعف 20% على 3 عملات يجب أن يعطي 4 لا 3،
  /// وإلا صار المضاعف بلا أثر في المكافآت الصغيرة وهي أكثرها عددا.
  static int applyMultiplier(int amount, {required double multiplier}) {
    if (amount <= 0 || multiplier <= 1) return amount;
    return (amount * multiplier).ceil();
  }
}
