import 'package:flutter/widgets.dart';

/// مسارات أيقونات الواجهة ثلاثية الأبعاد (مجهّزة بـ tool/process_icons.dart)
class AppIcons {
  static const String _base = 'assets/icons';

  static const String coin = '$_base/coin.png';
  static const String gems = '$_base/gems.png';
  static const String shopChest = '$_base/shop_chest.png';
  static const String dice = '$_base/dice.png';
  static const String challengeProverb = '$_base/challenge_proverb.png';
  static const String challengeVerse = '$_base/challenge_verse.png';
  static const String challengeWord = '$_base/challenge_word.png';
  static const String challengeGulf = '$_base/challenge_gulf.png';
  static const String appIcon = '$_base/app_icon.png';

  /// شعار اللعبة — خارج $_base لأنه ليس أيقونة واجهة بل هوية
  static const String logo = 'assets/logo/portrait.png';

  /// خلفية شاشة البدء خلف الشعار — اسم الملف كما ورد من المصمّم،
  /// ويُشار إليه من هنا فقط كي لا يتكرّر في الشيفرة
  static const String splashBackground =
      'assets/main/u8558185671_Premium_Arabic_word_puzzle_game_home_screen_backg_476ff759-8bb7-4c31-be2c-acace17afbec_1.png';

  /// كل صورة مصدرية تترك هامشا شفافا مختلفا حول الشكل (بعضها يحيط
  /// بالشكل عن قرب كالعملة، وبعضها يترك مساحة فارغة واسعة كالألماسة
  /// المائلة أو النرد المحاط برذاذ)، فيبدو حجمها الظاهر متفاوتا رغم
  /// تساوي مقاس الطلب. هذا المعامل يعوّض ذلك ليتساوى الحجم البصري
  /// الفعلي لكل الأيقونات عند تمرير نفس [AppIcon.size].
  static const Map<String, double> _visualScale = {
    coin: 1.0, // العملة تملأ إطارها تقريبا — المرجع الأساسي
    shopChest: 1.12,
    gems: 1.38,
    dice: 1.55, // أوسعها هامشا بسبب رذاذ الماء المتناثر حول المكعّب
  };

  static double visualScale(String asset) => _visualScale[asset] ?? 1.0;
}

/// أيقونة صورية بحجم بصري موحّد بين كل الأيقونات (بعد تعويض تفاوت
/// الهامش الشفاف في كل ملف)، تُفكّ بدقّة العرض فقط توفيرا للذاكرة.
/// زخرفية دائما: الوصف الدلالي يأتي من الزر الحاوي لها.
class AppIcon extends StatelessWidget {
  final String asset;

  /// المساحة المحجوزة في التخطيط (لا تتأثر بالتعويض، فلا ينكسر تباعد
  /// العناصر المجاورة)
  final double size;

  const AppIcon(this.asset, {super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final visualSize = size * AppIcons.visualScale(asset);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Image.asset(
            asset,
            width: visualSize,
            height: visualSize,
            fit: BoxFit.contain,
            // فكّ الترميز بحجم العرض الفعلي بدل 256px كاملة
            cacheWidth: (visualSize * dpr).round(),
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
