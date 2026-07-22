/// طبقة الشراء داخل التطبيق.
/// في النموذج الأولي نستخدم [MockIapService]؛ عند النشر تستبدل
/// بتطبيق حقيقي فوق حزمة in_app_purchase مع تحقق الإيصال في السيرفر.
library;

class PointsPackage {
  final String id;
  final String name;
  final int points;
  final int bonusPercent;
  final String priceLabel;
  final String? badge;

  const PointsPackage({
    required this.id,
    required this.name,
    required this.points,
    required this.bonusPercent,
    required this.priceLabel,
    this.badge,
  });

  int get totalPoints => points + (points * bonusPercent ~/ 100);
}

const pointsPackages = [
  PointsPackage(
    id: 'points_small',
    name: 'حزمة صغيرة',
    points: 500,
    bonusPercent: 0,
    priceLabel: r'$1.99',
  ),
  PointsPackage(
    id: 'points_medium',
    name: 'حزمة متوسطة',
    points: 1500,
    bonusPercent: 20,
    priceLabel: r'$4.99',
    badge: 'الأكثر مبيعا',
  ),
  PointsPackage(
    id: 'points_large',
    name: 'حزمة كبيرة',
    points: 4000,
    bonusPercent: 30,
    priceLabel: r'$9.99',
  ),
  PointsPackage(
    id: 'points_legend',
    name: 'الحزمة الأسطورية',
    points: 10000,
    bonusPercent: 50,
    priceLabel: r'$19.99',
    badge: 'الأفضل قيمة',
  ),
];

enum PurchaseStatus { success, cancelled, failed }

class PurchaseResult {
  final PurchaseStatus status;
  final String? error;

  const PurchaseResult(this.status, [this.error]);
}

abstract class IapService {
  Future<PurchaseResult> buy(PointsPackage package);
}

/// شراء محاكى للنموذج الأولي — ينجح دائما بعد مهلة قصيرة
class MockIapService implements IapService {
  @override
  Future<PurchaseResult> buy(PointsPackage package) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return const PurchaseResult(PurchaseStatus.success);
  }
}
