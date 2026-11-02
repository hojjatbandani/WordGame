import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/balance_config.dart';
import '../../core/app_language.dart';
import '../../core/referral_link.dart';
import '../../core/share_templates.dart';
import '../../core/theme.dart';
import '../../data/achievement_models.dart';
import '../../data/analytics/analytics_event.dart';
import '../../data/social_models.dart';
import '../providers.dart';
import '../widgets/achievement_toast.dart';
import '../widgets/friend_avatar.dart';
import '../widgets/glass_card.dart';
import '../widgets/pressable.dart';
import 'leaderboard_screen.dart';

/// ملف اللاعب ودائرته: رمزه الدائم، أصدقاؤه، الطلبات الواردة، ودعوة
/// الأصدقاء حين يستحقّها.
///
/// «حين يستحقّها» حرفيّ: قسم الدعوة غير موجود في الشجرة أصلا قبل
/// المستوى [BalanceConfig.levelGateReferral] — لا معطَّل ولا خلف قفل.
/// راجع referralUnlockedProvider في providers.dart لسبب ذلك.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _codeController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        backgroundColor: HurufTheme.surface,
      ));
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _busy) return;
    setState(() => _busy = true);
    final outcome =
        await ref.read(socialRepositoryProvider).addFriendByCode(code);
    if (!mounted) return;
    setState(() => _busy = false);
    _codeController.clear();
    ref.invalidate(pendingRequestsProvider);
    ref.invalidate(friendsProvider);
    ref.invalidate(friendCountProvider);
    ref.invalidate(leaderboardProvider);

    // تُحتسب الصداقة فقط عند اكتمالها فعلا، لا عند مجرد إرسال الطلب
    if (outcome.isNewFriendship) {
      final achievements = ref.read(achievementsProvider.notifier);
      achievements.bump(StatKey.friendsAdded);
      showAchievementUnlocked(context, achievements.takeJustUnlocked());
    }
    final lang = ref.read(languageProvider);
    _toast(lang.t(outcome.messageAr, outcome.messageEn));
  }

  Future<void> _decide(FriendRequest request, {required bool accept}) async {
    final repo = ref.read(socialRepositoryProvider);
    // حاوية المزوّدات لا ref الودجة: القوائم يجب أن تُحدَّث حتى لو غادر
    // اللاعب الشاشة أثناء الطلب — وref الودجة يرمي StateError بعد التخلّص
    final container = ProviderScope.containerOf(context);
    final result = accept
        ? await repo.acceptRequest(request.id)
        : await repo.declineRequest(request.id);
    container.invalidate(pendingRequestsProvider);
    container.invalidate(friendsProvider);
    container.invalidate(friendCountProvider);
    container.invalidate(leaderboardProvider);
    if (!mounted) return;

    if (result == RequestDecision.accepted) {
      final achievements = ref.read(achievementsProvider.notifier);
      achievements.bump(StatKey.friendsAdded);
      showAchievementUnlocked(context, achievements.takeJustUnlocked());
    }
    final lang = ref.read(languageProvider);
    _toast(lang.t(result.messageAr, result.messageEn));
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final requestsAsync = ref.watch(pendingRequestsProvider);
    final friendsAsync = ref.watch(friendsProvider);
    final referralUnlocked = ref.watch(referralUnlockedProvider);
    final lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: HurufTheme.bgTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(lang.t('الأصدقاء', 'Friends')),
        actions: [
          IconButton(
            tooltip: lang.t('لوحة الأصدقاء', 'Friends board'),
            icon: const Icon(Icons.leaderboard_rounded),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(friendsProvider);
            ref.invalidate(pendingRequestsProvider);
            ref.invalidate(referralStatusProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(HurufTheme.s4),
            children: [
              profileAsync.when(
                data: (p) => p == null
                    ? _OfflineNotice(lang: lang)
                    : _MyProfileCard(profile: p),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _OfflineNotice(lang: lang),
              ),
              const SizedBox(height: HurufTheme.s5),

              // إدخال رمز دعوة: غير مقيّد بمستوى — المدعوّ لاعب جديد
              // بحكم التعريف، وتأخير مدخله يلغي الدعوة التي أحضرته
              const _RedeemInviteSection(),

              // ← بوّابة المستوى: القسم كله خارج الشجرة قبل المستوى 5
              if (referralUnlocked) ...[
                const SizedBox(height: HurufTheme.s5),
                const ReferralCard(key: ReferralCard.entryPointKey),
              ],

              const SizedBox(height: HurufTheme.s5),
              _SectionTitle(lang.t('أضف صديقا برمزه', 'Add a friend by code')),
              const SizedBox(height: HurufTheme.s3),
              _AddFriendRow(
                controller: _codeController,
                busy: _busy,
                lang: lang,
                onSubmit: _submitCode,
              ),

              const SizedBox(height: HurufTheme.s5),
              requestsAsync.when(
                data: (list) => list.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionTitle(lang.t(
                              'طلبات واردة (${list.length})',
                              'Incoming requests (${list.length})')),
                          const SizedBox(height: HurufTheme.s3),
                          for (final r in list)
                            _RequestTile(
                              request: r,
                              lang: lang,
                              onAccept: () => _decide(r, accept: true),
                              onDecline: () => _decide(r, accept: false),
                            ),
                          const SizedBox(height: HurufTheme.s5),
                        ],
                      ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),

              friendsAsync.when(
                data: (friends) => _FriendsSection(friends: friends, lang: lang),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      );
}

class _OfflineNotice extends StatelessWidget {
  final AppLanguage lang;
  const _OfflineNotice({required this.lang});

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(HurufTheme.s4),
        child: Text(
          lang.t('الأصدقاء يحتاجون اتصالا — بقية اللعبة تعمل بدونه',
              'Friends need a connection — the rest of the game works offline'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 12, color: HurufTheme.textSecondary),
        ),
      );
}

// ─────────────────────── بطاقة ملفّي ───────────────────────

/// رمز الصديق الدائم (ثمانية محارف) + الصورة والمستوى. لا تحمل أي نصّ
/// عن الدعوة أو مكافآتها: تلك مسؤولية [ReferralCard] المحجوبة بالمستوى.
class _MyProfileCard extends ConsumerWidget {
  final PlayerProfile profile;

  const _MyProfileCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final level = ref.watch(playerLevelProvider);

    return GlassCard(
      padding: const EdgeInsets.all(HurufTheme.s5),
      child: Column(
        children: [
          FriendAvatar(
            name: profile.displayName,
            avatarId: profile.avatarId,
            size: 64,
            level: level,
          ),
          const SizedBox(height: HurufTheme.s3),
          Text(
            profile.displayName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: HurufTheme.s3),
          Text(
            lang.t('رمزك', 'Your code'),
            style: const TextStyle(
                fontSize: 12, color: HurufTheme.textSecondary),
          ),
          const SizedBox(height: HurufTheme.s1),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                profile.friendCode,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: HurufTheme.gold,
                ),
              ),
              const SizedBox(width: HurufTheme.s2),
              Pressable(
                onTap: () async {
                  await Clipboard.setData(
                      ClipboardData(text: profile.friendCode));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(SnackBar(
                      content: Text(lang.t('تم نسخ الرمز', 'Code copied'),
                          textAlign: TextAlign.center),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: HurufTheme.surface,
                    ));
                },
                semanticLabel: lang.t('نسخ الرمز', 'Copy code'),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HurufTheme.tileEmpty,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Icon(Icons.copy_rounded,
                      size: 16, color: HurufTheme.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── قسم الدعوة (محجوب بالمستوى) ───────────────────────

/// عرض دعوة الأصدقاء: الرابط والرمز والمكافأتان وحالة الدعوات.
///
/// يُبنى فقط حين referralUnlockedProvider يعيد true. لا فحص مستوى
/// بداخله عمدا: البوّابة مسؤولية من يركّبه، فيستحيل عرضه «معطَّلا» سهوا.
class ReferralCard extends ConsumerWidget {
  /// مفتاح ثابت كي يتحقق اختبار القبول من غيابه عند المستوى 4 وحضوره
  /// عند المستوى 5
  static const entryPointKey = Key('referral-entry');

  const ReferralCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final profile = ref.watch(myProfileProvider).asData?.value;
    final status = ref.watch(referralStatusProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const ReferralStatus.empty(),
        );
    if (profile == null) return const SizedBox.shrink();

    final code = profile.friendCode;
    final milestones = BalanceConfig.referralMilestoneCosmetics;
    final next = status.nextMilestone(milestones.keys);

    return GlassCard(
      padding: const EdgeInsets.all(HurufTheme.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lang.t('ادعُ أصدقاءك', 'Invite your friends'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: HurufTheme.s2),
          Container(
            padding: const EdgeInsets.all(HurufTheme.s3),
            decoration: BoxDecoration(
              color: HurufTheme.success.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(HurufTheme.rButton),
            ),
            child: Column(
              children: [
                Text(
                  lang.t(
                      'صديقك يأخذ ${BalanceConfig.referralRewardInvitee} عملة فور إدخال رمزك',
                      'Your friend gets ${BalanceConfig.referralRewardInvitee} coins the moment they enter your code'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: HurufTheme.success,
                  ),
                ),
                const SizedBox(height: HurufTheme.s1),
                // الشرط معروض صراحة لا مخبّأ في الشروط: التأخير الذي لا
                // يُشرح يُقرأ عطلا في المكافأة، والمشروح يُقرأ شرطا
                Text(
                  lang.t(
                      'وأنت تأخذ ${BalanceConfig.referralRewardInviter} عملة حين يوصل المستوى ${status.qualifyLevel}',
                      'You get ${BalanceConfig.referralRewardInviter} coins once they reach level ${status.qualifyLevel}'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: HurufTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: HurufTheme.s4),
          if (status.invited > 0) ...[
            _ReferralProgress(status: status, lang: lang),
            const SizedBox(height: HurufTheme.s3),
          ],
          if (next != null)
            Text(
              lang.t('عند $next دعوات ناجحة: زينة حصرية 🎁',
                  'At $next successful invites: an exclusive cosmetic 🎁'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11, color: HurufTheme.textSecondary),
            ),
          if (status.atCap)
            Text(
              lang.t('وصلت سقف ${status.cap} دعوة ناجحة 🏆',
                  'You\'ve hit the ${status.cap} successful invite cap 🏆'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11, color: HurufTheme.gold),
            ),
          const SizedBox(height: HurufTheme.s4),
          Pressable(
            onTap: () {
              ref.logEvent(Ev.referralSent, {'channel': 'share_sheet'});
              SharePlus.instance.share(ShareParams(
              text: ShareTemplates.invite(
                code: code,
                lang: lang,
                joinerReward: BalanceConfig.referralRewardInvitee,
              ),
            ));
            },
            semanticLabel:
                lang.t('مشاركة رمز دعوتك', 'Share your invite code'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: HurufTheme.s3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: HurufTheme.goldGradient,
                borderRadius: BorderRadius.circular(HurufTheme.rButton),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.share_rounded,
                      size: 18, color: HurufTheme.bgTop),
                  const SizedBox(width: HurufTheme.s2),
                  Text(
                    lang.t('ادعُ صديقك', 'Invite a friend'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: HurufTheme.bgTop,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: HurufTheme.s2),
          Text(
            ReferralLink.forCode(code),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 10, color: HurufTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// «٣ انضموا · ١ وصل المستوى ٣» — الفرق بين الرقمين معروض لا مخفيّ
class _ReferralProgress extends StatelessWidget {
  final ReferralStatus status;
  final AppLanguage lang;

  const _ReferralProgress({required this.status, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Stat(
          value: '${status.invited}',
          label: lang.t('انضموا برمزك', 'joined'),
        ),
        _Stat(
          value: '${status.paid}',
          label: lang.t('دُفع لك عنهم', 'paid out'),
          highlight: true,
        ),
        if (status.pending > 0)
          _Stat(
            value: '${status.pending}',
            label: lang.t('ينتظرون المستوى ${status.qualifyLevel}',
                'reaching level ${status.qualifyLevel}'),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final bool highlight;

  const _Stat({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: highlight ? HurufTheme.gold : HurufTheme.textPrimary,
            ),
          ),
          SizedBox(
            width: 92,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10, color: HurufTheme.textSecondary),
            ),
          ),
        ],
      );
}

// ─────────────────────── إدخال رمز دعوة ───────────────────────

/// مرة واحدة فقط في حياة الحساب *وفي حياة التثبيت*، فيختفي القسم بعدها.
/// يُملأ تلقائيا من رابط دعوة عميق إن وصل (راجع DeepLinkService).
class _RedeemInviteSection extends ConsumerStatefulWidget {
  const _RedeemInviteSection();

  @override
  ConsumerState<_RedeemInviteSection> createState() =>
      _RedeemInviteSectionState();
}

class _RedeemInviteSectionState extends ConsumerState<_RedeemInviteSection> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _done = false;

  /// وصل الرمز من رابط لا من كتابة يدوية — نبرز ذلك للاعب كي يفهم من
  /// أين جاء النصّ في حقله
  bool _fromLink = false;

  @override
  void initState() {
    super.initState();
    final store = ref.read(progressStoreProvider);
    _done = store.referralRedeemed;
    final pending = store.pendingInviteCode;
    if (!_done && pending != null && ReferralLink.isWellFormed(pending)) {
      _controller.text = pending;
      _fromLink = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _controller.text.trim();
    if (code.isEmpty || _busy) return;
    setState(() => _busy = true);

    final store = ref.read(progressStoreProvider);
    final result = await ref
        .read(socialRepositoryProvider)
        .redeemReferral(code, installId: store.installId);
    if (!mounted) return;
    setState(() => _busy = false);
    final lang = ref.read(languageProvider);

    ref.logEvent(Ev.referralRedeemed, {
      'outcome': result.outcome.name,
      'reward': result.reward,
      'from_link': _fromLink,
    });

    if (result.outcome == ReferralOutcome.ok) {
      await store.setReferralRedeemed(true);
      await store.setPendingInviteCode(null);
      ref.earnPoints(result.reward);
      ref.invalidate(friendsProvider);
      ref.invalidate(leaderboardProvider);
      if (!mounted) return;
      setState(() => _done = true);
      _toast(lang.t('أهلا فيك! أخذت ${result.reward} عملة هدية 🎁',
          'Welcome! You got ${result.reward} bonus coins 🎁'));
      return;
    }

    // الخادم يعرف ما لا يعرفه الجهاز (تثبيت جديد لنفس الحساب، أو رمز
    // استُخدم على هذا الجهاز من قبل) — نخفي القسم بدل تركه يحاول بلا فائدة
    if (result.outcome == ReferralOutcome.alreadyRedeemed ||
        result.outcome == ReferralOutcome.installUsed) {
      await store.setReferralRedeemed(true);
      await store.setPendingInviteCode(null);
      if (!mounted) return;
      setState(() => _done = true);
    }
    _toast(lang.t(result.outcome.messageAr, result.outcome.messageEn));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        backgroundColor: HurufTheme.surface,
      ));
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();
    final lang = ref.watch(languageProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(lang.t('عندك رمز دعوة؟', 'Have an invite code?')),
        const SizedBox(height: HurufTheme.s1),
        Text(
          _fromLink
              ? lang.t('جاك رمز من رابط صديقك — اضغط استلم',
                  'A code came from your friend\'s link — tap redeem')
              : lang.t(
                  'أدخل رمز من دعاك وخذ ${BalanceConfig.referralRewardInvitee} عملة هدية — مرة واحدة فقط',
                  'Enter the code from whoever invited you and get ${BalanceConfig.referralRewardInvitee} bonus coins — one time only'),
          style: TextStyle(
            fontSize: 12,
            color: _fromLink ? HurufTheme.success : HurufTheme.textSecondary,
          ),
        ),
        const SizedBox(height: HurufTheme.s3),
        Row(
          children: [
            Expanded(
              child: _CodeField(
                controller: _controller,
                onSubmitted: (_) => _redeem(),
              ),
            ),
            const SizedBox(width: HurufTheme.s3),
            Pressable(
              onTap: _redeem,
              semanticLabel: lang.t('استخدام رمز الدعوة', 'Redeem invite code'),
              child: Container(
                height: 56,
                padding:
                    const EdgeInsets.symmetric(horizontal: HurufTheme.s5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HurufTheme.success.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(HurufTheme.rButton),
                  border: Border.all(
                      color: HurufTheme.success.withValues(alpha: 0.5)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: HurufTheme.success),
                      )
                    : Text(
                        lang.t('استلم', 'Redeem'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: HurufTheme.success,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────── إضافة صديق ───────────────────────

class _AddFriendRow extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final AppLanguage lang;
  final VoidCallback onSubmit;

  const _AddFriendRow({
    required this.controller,
    required this.busy,
    required this.lang,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CodeField(
            controller: controller,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(width: HurufTheme.s3),
        Pressable(
          onTap: onSubmit,
          semanticLabel: lang.t('إضافة الصديق', 'Add friend'),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: HurufTheme.s5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: HurufTheme.goldGradient,
              borderRadius: BorderRadius.circular(HurufTheme.rButton),
            ),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: HurufTheme.bgTop),
                  )
                : Text(
                    lang.t('إضافة', 'Add'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: HurufTheme.bgTop,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// حقل رمز موحّد — طوله وأبجديته من مكان واحد فلا ينحرف حقل عن آخر
class _CodeField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  const _CodeField({required this.controller, required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      textAlign: TextAlign.center,
      maxLength: BalanceConfig.friendCodeLength,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
        _UpperCaseFormatter(),
      ],
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: 'ABCD2345',
        filled: true,
        fillColor: HurufTheme.tileEmpty,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HurufTheme.rButton),
          borderSide: BorderSide.none,
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

// ─────────────────────── الطلبات الواردة ───────────────────────

class _RequestTile extends StatelessWidget {
  final FriendRequest request;
  final AppLanguage lang;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _RequestTile({
    required this.request,
    required this.lang,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HurufTheme.s2),
      child: GlassCard(
        padding: const EdgeInsets.all(HurufTheme.s3),
        child: Row(
          children: [
            FriendAvatar(
              name: request.fromName,
              avatarId: request.fromAvatarId,
              size: 40,
              level: request.fromLevel,
            ),
            const SizedBox(width: HurufTheme.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.fromName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    request.fromCode,
                    style: const TextStyle(
                        color: HurufTheme.textSecondary,
                        fontSize: 11,
                        letterSpacing: 2),
                  ),
                ],
              ),
            ),
            // الرفض أولا وبلا لون: القبول هو الفعل المقصود، والرفض
            // موجود كي لا يكون تجاهل الطلب هو الخيار الوحيد
            Pressable(
              onTap: onDecline,
              semanticLabel: lang.t('رفض طلب ${request.fromName}',
                  'Decline ${request.fromName}\'s request'),
              child: Container(
                width: 40,
                height: 36,
                alignment: Alignment.center,
                child: const Icon(Icons.close_rounded,
                    size: 20, color: HurufTheme.textSecondary),
              ),
            ),
            Pressable(
              onTap: onAccept,
              semanticLabel: lang.t('قبول طلب ${request.fromName}',
                  'Accept ${request.fromName}\'s request'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: HurufTheme.s4, vertical: HurufTheme.s2),
                decoration: BoxDecoration(
                  color: HurufTheme.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(HurufTheme.rButton),
                ),
                child: Text(
                  lang.t('قبول', 'Accept'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: HurufTheme.success),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── قائمة الأصدقاء ───────────────────────

class _FriendsSection extends ConsumerWidget {
  final List<Friend> friends;
  final AppLanguage lang;

  const _FriendsSection({required this.friends, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (friends.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(lang.t('أصدقائي', 'My friends')),
          const SizedBox(height: HurufTheme.s3),
          Text(
            lang.t('ما عندك أصدقاء بعد — أرسل رمزك لأحدهم',
                'No friends yet — send your code to someone'),
            style: const TextStyle(
                fontSize: 12, color: HurufTheme.textSecondary),
          ),
        ],
      );
    }

    final full = friends.length >= BalanceConfig.maxFriends;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionTitle(lang.t('أصدقائي', 'My friends')),
            Text(
              '${friends.length} / ${BalanceConfig.maxFriends}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: full ? HurufTheme.error : HurufTheme.textSecondary,
              ),
            ),
          ],
        ),
        if (full) ...[
          const SizedBox(height: HurufTheme.s1),
          Text(
            lang.t('قائمتك ممتلئة — احذف صديقا لتضيف غيره',
                'Your list is full — remove someone to add another'),
            style: const TextStyle(fontSize: 11, color: HurufTheme.error),
          ),
        ],
        const SizedBox(height: HurufTheme.s3),
        for (final f in friends) _FriendTile(friend: f, lang: lang),
      ],
    );
  }
}

class _FriendTile extends ConsumerWidget {
  final Friend friend;
  final AppLanguage lang;

  const _FriendTile({required this.friend, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return Padding(
      padding: const EdgeInsets.only(bottom: HurufTheme.s2),
      child: GlassCard(
        padding: const EdgeInsets.all(HurufTheme.s3),
        child: Row(
          children: [
            FriendAvatar(
              name: friend.displayName,
              avatarId: friend.avatarId,
              size: 44,
              level: friend.level,
            ),
            const SizedBox(width: HurufTheme.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: HurufTheme.s2,
                    runSpacing: 2,
                    children: [
                      _Chip(
                        icon: Icons.local_fire_department_rounded,
                        text: '${friend.streak}',
                        color: friend.streak > 0
                            ? HurufTheme.error
                            : HurufTheme.textSecondary,
                        semantic: lang.t(
                            'سلسلة ${friend.streak} يوم', '${friend.streak} day streak'),
                      ),
                      // ترتيب اليوم داخل دائرة الأصدقاء — «الثالث بين
                      // أصدقائك» رقم يعني شيئا، بخلاف رتبة عالمية
                      _Chip(
                        icon: Icons.emoji_events_rounded,
                        text: friend.playedToday
                            ? '#${friend.todayRank}'
                            : lang.t('ما لعب', 'not yet'),
                        color: friend.playedToday
                            ? HurufTheme.gold
                            : HurufTheme.textSecondary,
                        semantic: friend.playedToday
                            ? lang.t(
                                'ترتيب اليوم ${friend.todayRank} من ${friend.circleSize}',
                                'today\'s rank ${friend.todayRank} of ${friend.circleSize}')
                            : lang.t('ما لعب تحدي اليوم',
                                'hasn\'t played today\'s challenge'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final String semantic;

  const _Chip({
    required this.icon,
    required this.text,
    required this.color,
    required this.semantic,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        label: semantic,
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 2),
              Text(
                text,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      );
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
