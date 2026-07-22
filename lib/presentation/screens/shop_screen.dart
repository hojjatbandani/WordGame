import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/iap_service.dart';
import '../providers.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';

/// المتجر: باقات النقاط، المكافأة اليومية، وإعلانات المكافأة
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  bool _purchasing = false;
  int? _successPoints;

  static const _packageGradients = <String, List<Color>>{
    'points_small': [Color(0xFF0F3443), Color(0xFF34E89E)],
    'points_medium': [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
    'points_large': [Color(0xFFB24592), Color(0xFFFF9F1C)],
    'points_legend': [Color(0xFF1A1F3A), Color(0xFFC99A10)],
  };

  Future<void> _buy(PointsPackage package) async {
    final confirmed = await _showConfirmSheet(package);
    if (confirmed != true || !mounted) return;

    setState(() => _purchasing = true);
    final result = await ref.read(iapServiceProvider).buy(package);
    if (!mounted) return;
    setState(() => _purchasing = false);

    if (result.status == PurchaseStatus.success) {
      ref.read(pointsProvider.notifier).add(package.totalPoints);
      HapticFeedback.mediumImpact();
      setState(() => _successPoints = package.totalPoints);
    } else if (result.status == PurchaseStatus.failed) {
      _toast('تعذر إتمام الشراء، حاول مجددا');
    }
  }

  Future<bool?> _showConfirmSheet(PointsPackage package) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          margin: const EdgeInsets.all(HurufTheme.s4),
          padding: const EdgeInsets.all(HurufTheme.s5),
          decoration: BoxDecoration(
            color: HurufTheme.surface,
            borderRadius: BorderRadius.circular(HurufTheme.rCard),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                package.name,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: HurufTheme.s2),
              Text(
                '💎 ${package.totalPoints} نقطة'
                '${package.bonusPercent > 0 ? '  (تشمل ${package.bonusPercent}٪ هدية)' : ''}',
                style: const TextStyle(
                    fontSize: 16, color: HurufTheme.textSecondary),
              ),
              const SizedBox(height: HurufTheme.s5),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: HurufTheme.gold,
                        foregroundColor: HurufTheme.bgTop,
                        padding: const EdgeInsets.symmetric(
                            vertical: HurufTheme.s3),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(HurufTheme.rButton),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(
                        'شراء ${package.priceLabel}',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: HurufTheme.s3),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('إلغاء',
                        style:
                            TextStyle(color: HurufTheme.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: HurufTheme.s2),
              const Text(
                'الشراء محاكى في هذه النسخة التجريبية',
                style: TextStyle(
                    fontSize: 11, color: HurufTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _claimDaily() {
    final reward = ref.read(dailyRewardProvider.notifier).claim();
    if (reward != null) {
      HapticFeedback.mediumImpact();
      setState(() => _successPoints = reward);
    }
  }

  Future<void> _watchAd() async {
    final notifier = ref.read(adRewardProvider.notifier);
    if (notifier.remaining <= 0) {
      _toast('استنفدت إعلانات اليوم، عد غدا!');
      return;
    }
    // محاكاة مشاهدة إعلان مكافأة
    setState(() => _purchasing = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _purchasing = false);
    final reward = notifier.grantReward();
    if (reward != null) {
      HapticFeedback.mediumImpact();
      setState(() => _successPoints = reward);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        backgroundColor: HurufTheme.surface,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final points = ref.watch(pointsProvider);
    final daily = ref.watch(dailyRewardProvider);
    final adsWatched = ref.watch(adRewardProvider);

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(HurufTheme.s4),
                children: [
                  _buildHeader(points),
                  const SizedBox(height: HurufTheme.s4),
                  _buildDailyCard(daily),
                  const SizedBox(height: HurufTheme.s4),
                  const _SectionTitle('باقات النقاط'),
                  const SizedBox(height: HurufTheme.s3),
                  for (final p in pointsPackages) ...[
                    _PackageCard(
                      package: p,
                      gradient: _packageGradients[p.id]!,
                      onTap: () => _buy(p),
                    ),
                    const SizedBox(height: HurufTheme.s3),
                  ],
                  const _SectionTitle('نقاط مجانية'),
                  const SizedBox(height: HurufTheme.s3),
                  _buildAdCard(adsWatched),
                  const SizedBox(height: HurufTheme.s6),
                ],
              ),
              if (_purchasing)
                Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: const Center(
                    child:
                        CircularProgressIndicator(color: HurufTheme.gold),
                  ),
                ),
              if (_successPoints != null)
                _RewardOverlay(
                  points: _successPoints!,
                  onDismiss: () => setState(() => _successPoints = null),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int points) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_forward_ios_rounded,
              color: HurufTheme.textSecondary, size: 20),
        ),
        const Expanded(
          child: Text(
            'المتجر',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
        GlassCard(
          radius: HurufTheme.rButton,
          padding: const EdgeInsets.symmetric(
              horizontal: HurufTheme.s3, vertical: HurufTheme.s1),
          child: Row(
            children: [
              const Text('💎', style: TextStyle(fontSize: 16)),
              const SizedBox(width: HurufTheme.s1),
              Text(
                '$points',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: HurufTheme.gold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyCard(DailyRewardState daily) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 22)),
              const SizedBox(width: HurufTheme.s2),
              const Expanded(
                child: Text(
                  'المكافأة اليومية',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      daily.canClaim ? HurufTheme.gold : HurufTheme.tileEmpty,
                  foregroundColor: daily.canClaim
                      ? HurufTheme.bgTop
                      : HurufTheme.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HurufTheme.rButton),
                  ),
                ),
                onPressed: daily.canClaim ? _claimDaily : null,
                child: Text(
                  daily.canClaim ? '+${daily.nextReward}' : 'غدا',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: HurufTheme.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var day = 1; day <= 7; day++)
                _DayChip(
                  day: day,
                  reward: dailyRewards[day - 1],
                  // الأيام السابقة في الدورة الحالية تعتبر مأخوذة
                  state: daily.canClaim
                      ? (day < daily.nextDay
                          ? _DayState.claimed
                          : day == daily.nextDay
                              ? _DayState.today
                              : _DayState.future)
                      : (day <= ((daily.nextDay - 2) % 7) + 1
                          ? _DayState.claimed
                          : _DayState.future),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdCard(int adsWatched) {
    final remaining = AdRewardNotifier.maxPerDay - adsWatched;
    return GlassCard(
      child: Row(
        children: [
          const Text('🎬', style: TextStyle(fontSize: 22)),
          const SizedBox(width: HurufTheme.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'شاهد إعلانا',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  '+${AdRewardNotifier.reward} نقطة — متبق $remaining اليوم',
                  style: const TextStyle(
                      fontSize: 12, color: HurufTheme.textSecondary),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  remaining > 0 ? HurufTheme.success : HurufTheme.tileEmpty,
              foregroundColor: HurufTheme.bgTop,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(HurufTheme.rButton),
              ),
            ),
            onPressed: remaining > 0 ? _watchAd : null,
            child: const Text('مشاهدة',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

enum _DayState { claimed, today, future }

class _DayChip extends StatelessWidget {
  final int day;
  final int reward;
  final _DayState state;

  const _DayChip({
    required this.day,
    required this.reward,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = state == _DayState.today;
    final claimed = state == _DayState.claimed;
    return Column(
      children: [
        Container(
          width: 38,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isToday ? HurufTheme.goldGradient : null,
            color: isToday
                ? null
                : claimed
                    ? HurufTheme.gold.withValues(alpha: 0.18)
                    : HurufTheme.tileEmpty,
            borderRadius: BorderRadius.circular(HurufTheme.rTile),
            border: Border.all(
              color: isToday
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: claimed
              ? const Icon(Icons.check_rounded,
                  size: 18, color: HurufTheme.gold)
              : Text(
                  '$reward',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isToday
                        ? HurufTheme.bgTop
                        : HurufTheme.textSecondary,
                  ),
                ),
        ),
        const SizedBox(height: 2),
        Text(
          '$day',
          style: const TextStyle(
              fontSize: 10, color: HurufTheme.textSecondary),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: HurufTheme.textSecondary,
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final PointsPackage package;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _PackageCard({
    required this.package,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(HurufTheme.s4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  gradient[0].withValues(alpha: 0.55),
                  gradient[1].withValues(alpha: 0.35),
                ],
              ),
              borderRadius: BorderRadius.circular(HurufTheme.rCard),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: gradient[1].withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  package.id == 'points_legend' ? '👑' : '💎',
                  style: const TextStyle(fontSize: 30),
                ),
                const SizedBox(width: HurufTheme.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        package.bonusPercent > 0
                            ? '${package.points} + ${package.bonusPercent}٪ هدية = ${package.totalPoints} نقطة'
                            : '${package.points} نقطة',
                        style: const TextStyle(
                            fontSize: 12,
                            color: HurufTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: HurufTheme.s3, vertical: HurufTheme.s2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(HurufTheme.rButton),
                  ),
                  child: Text(
                    package.priceLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
          if (package.badge != null)
            Positioned(
              top: -9,
              right: HurufTheme.s4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: HurufTheme.s3, vertical: 3),
                decoration: BoxDecoration(
                  gradient: HurufTheme.goldGradient,
                  borderRadius: BorderRadius.circular(HurufTheme.rButton),
                  boxShadow: [
                    BoxShadow(
                      color: HurufTheme.gold.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  package.badge!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: HurufTheme.bgTop,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// نجاح الشراء أو المكافأة: انفجار جواهر + عد تصاعدي
class _RewardOverlay extends StatefulWidget {
  final int points;
  final VoidCallback onDismiss;

  const _RewardOverlay({required this.points, required this.onDismiss});

  @override
  State<_RewardOverlay> createState() => _RewardOverlayState();
}

class _RewardOverlayState extends State<_RewardOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _burst;
  late final AnimationController _card;
  late final List<_Gem> _gems;

  @override
  void initState() {
    super.initState();
    _burst = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..forward();
    _card = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    final rng = Random();
    _gems = List.generate(24, (_) => _Gem.random(rng));
  }

  @override
  void dispose() {
    _burst.dispose();
    _card.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _burst,
              builder: (context, _) => Stack(
                children: [
                  for (final gem in _gems)
                    _buildGem(gem, MediaQuery.sizeOf(context)),
                ],
              ),
            ),
            Center(
              child: ScaleTransition(
                scale:
                    CurvedAnimation(parent: _card, curve: Curves.elasticOut),
                child: GlassCard(
                  padding: const EdgeInsets.all(HurufTheme.s6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: HurufTheme.s3),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: widget.points),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => Text(
                          '+$value',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: HurufTheme.gold,
                          ),
                        ),
                      ),
                      const SizedBox(height: HurufTheme.s2),
                      const Text(
                        'أضيفت إلى رصيدك',
                        style:
                            TextStyle(color: HurufTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGem(_Gem gem, Size size) {
    final local = ((_burst.value - gem.delay) / (1 - gem.delay))
        .clamp(0.0, 1.0);
    if (local == 0) return const SizedBox.shrink();
    final eased = Curves.easeOutCubic.transform(local);
    final origin = Offset(size.width / 2, size.height / 2);
    final pos = origin +
        Offset(
          cos(gem.angle) * eased * gem.distance * size.width,
          sin(gem.angle) * eased * gem.distance * size.height +
              local * local * 120,
        );
    return Positioned(
      left: pos.dx - 10,
      top: pos.dy - 10,
      child: Opacity(
        opacity: (1 - local).clamp(0.0, 1.0),
        child: Text('💎', style: TextStyle(fontSize: 12 + gem.size)),
      ),
    );
  }
}

class _Gem {
  final double angle;
  final double distance;
  final double size;
  final double delay;

  _Gem(this.angle, this.distance, this.size, this.delay);

  factory _Gem.random(Random rng) => _Gem(
        rng.nextDouble() * 2 * pi,
        0.15 + rng.nextDouble() * 0.3,
        rng.nextDouble() * 10,
        rng.nextDouble() * 0.2,
      );
}
