import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../data/rewards/reward_track.dart';
import '../home_widget_launch.dart';
import '../providers.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/pressable.dart';
import '../widgets/reward_burst_overlay.dart';

/// شاشة مسار الجوائز: ثلاث بطاقات (يومية/أسبوعية/شهرية) لكل واحدة عدد
/// مطالبات محدود، فينتهي المسار كله بعد ستة أشهر. حلّت محلّ شاشة التحدي
/// اليومي في نفس موضع الشريط السفلي.
///
/// كل القرار في lib/data/rewards/reward_track.dart — هذه الشاشة تعرض
/// [RewardTierStatus] كما هي ولا تحسب أهلية ولا تاريخا بنفسها.
class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  /// المبلغ الذي مُنح للتوّ — يقود احتفال [RewardBurstOverlay]
  int? _justClaimed;
  RewardTier? _justClaimedTier;

  @override
  void initState() {
    super.initState();
    // تُسجّل نفسها كي لا تُكدَّس نسخة ثانية عند نقرة ودجة تالية —
    // راجع HomeWidgetLaunch.openRewards
    HomeWidgetLaunch.setRewardsOpen(true);
  }

  @override
  void dispose() {
    HomeWidgetLaunch.setRewardsOpen(false);
    HomeWidgetLaunch.focusTier.value = null;
    super.dispose();
  }

  void _claim(RewardTier tier) {
    final coins = ref.read(rewardTrackProvider.notifier).claim(tier);
    // null = لم تعد جاهزة (منتصف ليل مرّ، أو ضغطتان متلاحقتان). الزر
    // نفسه يعيد رسم حالته من الحالة الجديدة، فلا رسالة خطأ هنا.
    if (coins == null) return;

    HapticFeedback.mediumImpact();
    ref.read(rewardTrackPendingProvider.notifier).refresh();
    // الودجة تعرض الرصيد والتقدّم معا، فتتقادم لحظة المطالبة
    unawaited(syncHomeWidget(ref));
    setState(() {
      _justClaimed = coins;
      _justClaimedTier = tier;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final track = ref.watch(rewardTrackProvider);
    final points = ref.watch(pointsProvider);
    final all = RewardTrackEngine.statuses(track, DateTime.now());
    final trackComplete = RewardTrackEngine.isTrackComplete(track);
    // الطبقة المنتهية تختفي بدل أن تعلن انتهاءها. راجع [_TrackSummary]:
    // لا شيء في هذه الشاشة يقول للاعب كم بقي من مسار محدود.
    final statuses = [for (final s in all) if (!s.isComplete) s];

    return Scaffold(
      backgroundColor: HurufTheme.bgTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(lang.t('مسار الجوائز', 'Reward Track')),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: HurufTheme.s4),
            child: Row(
              children: [
                const AppIcon(AppIcons.gems, size: 24),
                const SizedBox(width: HurufTheme.s1),
                Text(
                  '$points',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: HurufTheme.gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(HurufTheme.s4),
                children: [
                  _TrackSummary(
                    statuses: all,
                    lang: lang,
                    complete: trackComplete,
                  ),
                  const SizedBox(height: HurufTheme.s4),
                  // الطبقة القادمة من نقرة الودجة تُبرَز بإطار ذهبي، كي
                  // يجد اللاعب فورا ما نقر عليه بالضبط
                  ValueListenableBuilder<RewardTier?>(
                    valueListenable: HomeWidgetLaunch.focusTier,
                    builder: (context, focus, _) => Column(
                      children: [
                        for (final status in statuses) ...[
                          _TierCard(
                            status: status,
                            lang: lang,
                            highlighted: status.tier == focus,
                            onClaim: () => _claim(status.tier),
                          ),
                          const SizedBox(height: HurufTheme.s3),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: HurufTheme.s6),
                ],
              ),
              if (_justClaimed != null)
                RewardBurstOverlay(
                  points: _justClaimed!,
                  lang: lang,
                  caption: _claimCaption(_justClaimedTier!, lang),
                  onDismiss: () => setState(() {
                    _justClaimed = null;
                    _justClaimedTier = null;
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _claimCaption(RewardTier tier, AppLanguage lang) => switch (tier) {
    RewardTier.daily => lang.t('جائزة اليوم — أضيفت إلى رصيدك',
        "Today's reward — added to your balance"),
    RewardTier.weekly => lang.t('جائزة الأسبوع — أضيفت إلى رصيدك',
        "This week's reward — added to your balance"),
    RewardTier.monthly => lang.t('جائزة الشهر — أضيفت إلى رصيدك',
        "This month's reward — added to your balance"),
  };
}

// ─────────────────────── نصوص الطبقات ───────────────────────

String tierTitle(RewardTier tier, AppLanguage lang) => switch (tier) {
  RewardTier.daily => lang.t('الجائزة اليومية', 'Daily reward'),
  RewardTier.weekly => lang.t('الجائزة الأسبوعية', 'Weekly reward'),
  RewardTier.monthly => lang.t('الجائزة الشهرية', 'Monthly reward'),
};

String _tierEmoji(RewardTier tier) => switch (tier) {
  RewardTier.daily => '🎁',
  RewardTier.weekly => '🎖️',
  RewardTier.monthly => '👑',
};

/// «كل يوم» / «كل أسبوع» / «كل شهر» — إيقاع الطبقة بكلمة واحدة
String _tierCadence(RewardTier tier, AppLanguage lang) => switch (tier) {
  RewardTier.daily => lang.t('كل يوم', 'every day'),
  RewardTier.weekly => lang.t('كل أسبوع', 'every week'),
  RewardTier.monthly => lang.t('كل شهر', 'every month'),
};

/// «بعد N يوما» بصيغة عربية سليمة: اليوم الواحد والاثنان لهما لفظهما
String _inDays(int days, AppLanguage lang) => switch (days) {
  1 => lang.t('غدا', 'tomorrow'),
  2 => lang.t('بعد يومين', 'in 2 days'),
  _ => lang.t('بعد $days أيام', 'in $days days'),
};

// ─────────────────────── ملخّص المسار ───────────────────────

class _TrackSummary extends StatelessWidget {
  final List<RewardTierStatus> statuses;
  final AppLanguage lang;
  final bool complete;

  const _TrackSummary({
    required this.statuses,
    required this.lang,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    // ما جمعه اللاعب من المسار حتى الآن — رقم *يكبر* بكل مطالبة.
    //
    // كان هنا «بقي لك N ألماسة» وشريطُ تقدّم و«$claimed من $total
    // جائزة»: ثلاثة أرقام كلّها تقيس مسافة إلى نهاية. عدّاد نازل يعلّم
    // اللاعب أن الخزّان يفرغ، فيقلّ معنى العودة غدا كلّما اقترب من
    // الصفر — وهو عكس ما يُبنى مسارُ جوائز من أجله. الرقم الصاعد يقيس
    // ما ربحه لا ما تبقّى، ولا يعِد بنهاية أصلا.
    final earned = statuses.fold<int>(0, (sum, s) => sum + s.claimed * s.coins);

    return GlassCard(
      padding: const EdgeInsets.all(HurufTheme.s5),
      child: Column(
        children: [
          const Text('💎', style: TextStyle(fontSize: 38)),
          const SizedBox(height: HurufTheme.s2),
          Text(
            earned == 0
                ? lang.t('جوائزك بانتظارك', 'Your rewards are waiting')
                : lang.t(
                    'جمعت $earned ألماسة',
                    "You've collected $earned gems",
                  ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: HurufTheme.gold,
            ),
          ),
          const SizedBox(height: HurufTheme.s1),
          Text(
            complete
                ? lang.t(
                    'استلمت كل الجوائز المتاحة — شكرا لوفائك',
                    "You've claimed every reward available — thank you",
                  )
                : lang.t(
                    'كل يوم تفتح فيه اللعبة يقرّبك من الجائزة التالية',
                    'Every day you open the game brings the next reward closer',
                  ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HurufTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── بطاقة طبقة ───────────────────────

class _TierCard extends StatelessWidget {
  final RewardTierStatus status;
  final AppLanguage lang;
  final VoidCallback onClaim;

  /// وصل إليها اللاعب من نقرة ودجة على هذه الطبقة بعينها
  final bool highlighted;

  const _TierCard({
    required this.status,
    required this.lang,
    required this.onClaim,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final ready = status.isReady;
    final card = GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _tierEmoji(status.tier),
                style: TextStyle(
                  fontSize: 26,
                  // المنتهية باهتة لا مخفيّة: رؤية ما استُكمل جزء من
                  // الإحساس بالتقدّم
                  color: Colors.white.withValues(alpha: ready ? 1 : .7),
                ),
              ),
              const SizedBox(width: HurufTheme.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tierTitle(status.tier, lang),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const AppIcon(AppIcons.gems, size: 18),
                        const SizedBox(width: 4),
                        // مرنة: «200 كل شهر» بجانب زرّ يحمل «بعد 29 يوما»
                        // كان يفيض على هواتف 360 نقطة
                        Flexible(
                          child: Text(
                            '${status.coins} '
                            '${_tierCadence(status.tier, lang)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HurufTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _ClaimButton(status: status, lang: lang, onClaim: onClaim),
            ],
          ),
          const SizedBox(height: HurufTheme.s3),
          Text(
            _subtitle(),
            style: const TextStyle(
              color: HurufTheme.textSecondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );

    if (!highlighted) return card;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HurufTheme.rCard),
        border: Border.all(color: HurufTheme.gold, width: 1.6),
      ),
      child: card,
    );
  }

  /// حالة الطبقة وحدها، بلا «$claimed من $total».
  ///
  /// العدّ كان يكشف أن للطبقة عددا نهائيا من المطالبات، ولاعبٌ يقرأ
  /// «3 من 30» يعرف أنه يمشي إلى حائط. ما يحتاجه هنا سؤال واحد: هل
  /// هناك شيء لي الآن، ومتى التالي.
  String _subtitle() {
    if (status.isReady) {
      return lang.t('جاهزة الآن — استلمها', 'Ready now — claim it');
    }
    final when = _inDays(status.daysUntilReady!, lang);
    return lang.t('الجائزة التالية $when', 'Next reward $when');
  }
}

/// زرّ المطالبة بحالاته الثلاث: جاهزة، تنتظر، انتهت
class _ClaimButton extends StatelessWidget {
  final RewardTierStatus status;
  final AppLanguage lang;
  final VoidCallback onClaim;

  const _ClaimButton({
    required this.status,
    required this.lang,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final ready = status.isReady;
    final label = status.isComplete
        ? lang.t('اكتملت', 'Done')
        : ready
        ? '+${status.coins}'
        : _inDays(status.daysUntilReady!, lang);

    return Pressable(
      onTap: ready ? onClaim : null,
      semanticLabel: ready
          ? lang.t(
              'استلم ${status.coins} ألماسة من ${tierTitle(status.tier, lang)}',
              'Claim ${status.coins} gems from ${tierTitle(status.tier, lang)}',
            )
          : label,
      child: Container(
        // سقف للعرض: «بعد 29 يوما» بلا حدّ كان يبتلع نصف البطاقة على
        // هواتف 360 نقطة فيفيض ما بجانبه. سطران مسموحان بدل القصّ.
        constraints: const BoxConstraints(
          minWidth: 78,
          maxWidth: 96,
          minHeight: 40,
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: HurufTheme.s2,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HurufTheme.rButton),
          color: ready ? HurufTheme.gold : HurufTheme.tileEmpty,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          // «+20» نصّ لاتيني في سياق عربي: باتجاه الفقرة تنقلب علامة
          // الزائد إلى آخر السطر فيُقرأ «20+»
          textDirection: ready ? TextDirection.ltr : null,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13.5,
            height: 1.25,
            color: ready ? HurufTheme.bgTop : HurufTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
