// ورقة «ينقصك القليل». Dart صرف — بلا Flutter — فالقرار (تظهر أم لا)
// أهم من شكلها ويجب أن يُختبر وحده.
//
// لماذا هذه هي واجهة التحويل الأولى: اللاعب هنا لم يُعرض عليه شيء، بل
// قرّر هو شراء تلميح/زينة وعجز عن إتمامه بعشرين عملة. الفرق بين
// «ينقصك 20 عملة» و«افتح المتجر» هو الفرق بين إتمام قرار قائم وبين
// إعلان يقاطع اللعب.
//
// وحدّ الـ25% ليس ذوقا: على بعد ربع السعر يبقى الشيء في متناول اللاعب،
// وأبعد من ذلك تتحوّل الورقة نفسها إلى جدار يُعلن أن ما أراده بعيد —
// وهي أسوأ لحظة ممكنة لعرض شراء.

import '../../config/balance_config.dart';
import 'store_catalog.dart';

/// ما يُشترى بالعملات — لتسمية الورقة بما يفهمه اللاعب («ينقصك للتلميح»)
enum NearMissTarget { hint, cosmetic, skip, retry, other }

class NearMissOffer {
  /// سعر ما حاول شراءه
  final int price;

  /// رصيده لحظة المحاولة
  final int balance;

  /// الفارق بالضبط — هذا ما يُعرض، لا الكتالوج
  final int deficit;

  final NearMissTarget target;

  /// مشاهدة إعلان متاحة الآن (ميزانية اليوم لم تنفد والمفتاح مُشغَّل)
  final bool canWatchAd;

  /// مكافأة الإعلان *المعروضة* — القيمة المتصاعدة الفعلية للمشاهدة
  /// التالية، لا رقما ثابتا: الوعد المعروض هو ما يُدفع
  final int adReward;

  /// أصغر حزمة تكفي — لا الكتالوج كاملا
  final CoinPack? pack;

  const NearMissOffer({
    required this.price,
    required this.balance,
    required this.deficit,
    required this.target,
    required this.canWatchAd,
    required this.adReward,
    required this.pack,
  });

  /// هل يكفي إعلان واحد لإغلاق الفجوة؟ يغيّر نصّ الزر لا وجوده
  bool get adClosesGap => canWatchAd && adReward >= deficit;
}

class NearMiss {
  const NearMiss._();

  /// يعيد العرض، أو null إن كان يجب ألّا تظهر الورقة إطلاقا:
  ///  • الرصيد يكفي أصلا (لا نقص).
  ///  • النقص يتجاوز [BalanceConfig.nearMissMaxDeficitRatio] من السعر.
  ///  • سعر غير موجب (لا شيء يُشترى).
  static NearMissOffer? evaluate({
    required int price,
    required int balance,
    required NearMissTarget target,
    required bool canWatchAd,
    required int adReward,
  }) {
    if (price <= 0) return null;
    final deficit = price - balance;
    if (deficit <= 0) return null;
    if (deficit > price * BalanceConfig.nearMissMaxDeficitRatio) return null;

    return NearMissOffer(
      price: price,
      balance: balance,
      deficit: deficit,
      target: target,
      canWatchAd: canWatchAd,
      adReward: adReward,
      pack: StoreCatalog.smallestSufficient(balance: balance, target: price),
    );
  }
}
