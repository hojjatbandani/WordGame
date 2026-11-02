import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_language.dart';
import '../../core/share_image.dart';
import '../../core/share_return_gate.dart';
import '../../core/theme.dart';
import '../../data/achievement_models.dart';
import '../providers.dart';
import 'achievement_toast.dart';
import 'pressable.dart';

/// أزرار مشاركة النتيجة: صورة، نصّ، ونسخ — تُستخدم بعد إتمام مرحلة
/// والمراحل العادية على حد سواء.
///
/// المكافأة تُمنح عند *عودة* اللاعب إلى التطبيق بعد إغلاق الورقة، لا عند
/// فتحها. راجع [ShareReturnGate] لسبب ذلك بالتفصيل.
class ShareResultRow extends ConsumerStatefulWidget {
  /// نصّ المشاركة — مبنيّ في ShareTemplates، وخال من أي كلمة من الحل
  final String text;

  /// مفتاح حدّ إعادة الرسم المحيط ببطاقة المشاركة المعروضة على الشاشة.
  /// null يخفي زر مشاركة الصورة ويبقي النصّ وحده (شاشة بلا بطاقة).
  final GlobalKey? cardKey;

  /// اسم ملف الصورة المؤقّت — يظهر في بعض تطبيقات المراسلة
  final String imageName;

  const ShareResultRow({
    super.key,
    required this.text,
    this.cardKey,
    this.imageName = 'huruf',
  });

  @override
  ConsumerState<ShareResultRow> createState() => _ShareResultRowState();
}

class _ShareResultRowState extends ConsumerState<ShareResultRow>
    with WidgetsBindingObserver {
  bool _sharing = false;
  final _gate = ShareReturnGate();

  AppLanguage get _lang => ref.read(languageProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _gate.onAppResumed()) {
      _grantReward();
    }
  }

  bool get _appIsResumed =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  static ShareSheetOutcome _outcomeOf(ShareResult result) =>
      switch (result.status) {
        ShareResultStatus.dismissed => ShareSheetOutcome.dismissed,
        ShareResultStatus.success => ShareSheetOutcome.shared,
        ShareResultStatus.unavailable => ShareSheetOutcome.unknown,
      };

  Future<void> _shareText() => _run(() async {
    final result = await SharePlus.instance.share(
      ShareParams(text: widget.text),
    );
    return _outcomeOf(result);
  });

  Future<void> _shareImage() => _run(() async {
    final key = widget.cardKey;
    if (key == null) {
      final result = await SharePlus.instance.share(
        ShareParams(text: widget.text),
      );
      return _outcomeOf(result);
    }

    final bytes = await ShareImage.capture(key);
    final path = bytes == null
        ? null
        : await ShareImage.writeTempPng(bytes, widget.imageName);

    // فشل الالتقاط لا يُفشل المشاركة: نسقط على النصّ بهدوء، فاللاعب
    // ينشر شيئا في كل الأحوال بدل أن تُبتلع ضغطته
    if (path == null) {
      final result = await SharePlus.instance.share(
        ShareParams(text: widget.text),
      );
      return _outcomeOf(result);
    }

    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'image/png')],
        text: widget.text,
      ),
    );
    return _outcomeOf(result);
  });

  /// يغلّف أي مشاركة بحارس «لا مشاركتين معا» وببوّابة العودة
  Future<void> _run(Future<ShareSheetOutcome> Function() share) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final outcome = await share();
      if (!mounted) return;
      final earnedNow = _gate.onSheetClosed(
        outcome: outcome,
        appIsResumed: _appIsResumed,
      );
      if (earnedNow) _grantReward();
    } catch (e) {
      // ورقة المشاركة قد ترمي على منصّات لا تدعمها — لا مكافأة ولا انهيار
      _gate.reset();
      debugPrint('المشاركة: تعذّرت — $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _grantReward() {
    if (!mounted) return;
    final reward = ref.read(shareRewardProvider.notifier).claim();
    final achievements = ref.read(achievementsProvider.notifier);
    achievements.bump(StatKey.resultsShared);
    showAchievementUnlocked(context, achievements.takeJustUnlocked());
    if (reward > 0) {
      _toast(
        _lang.t(
          'شكرا للمشاركة! +$reward عملة',
          'Thanks for sharing! +$reward coins',
        ),
      );
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
          backgroundColor: HurufTheme.surface,
          duration: const Duration(milliseconds: 1800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HurufTheme.rButton),
          ),
        ),
      );
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    _toast(_lang.t('تم نسخ النتيجة', 'Result copied'));
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final hasCard = widget.cardKey != null;

    // لا مبلغ على الزرّ ولا عدّاد تحته. المكافأة سقفها مرّتان في عمر
    // الحساب (BalanceConfig.shareRewardMaxTotal)، ووعدٌ معلن ينتهي بعد
    // مرّتين يُقرأ خُلفا للوعد لا كرما. تُمنح بصمت في مرّتيها الأوليين،
    // ويبقى الزرّ للمشاركة نفسها — وهي المقصودة أصلا.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // مرن لا ثابت: النصّ الإنجليزي أعرض من العربي بما يكفي
            // ليفيض البطاقة على الشاشات الضيّقة
            Flexible(
              child: Pressable(
                onTap: hasCard ? _shareImage : _shareText,
                semanticLabel: lang.t('مشاركة النتيجة', 'Share result'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HurufTheme.s5,
                    vertical: HurufTheme.s3,
                  ),
                  decoration: BoxDecoration(
                    gradient: HurufTheme.goldGradient,
                    borderRadius: BorderRadius.circular(HurufTheme.rButton),
                    boxShadow: [
                      BoxShadow(
                        color: HurufTheme.gold.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sharing
                            ? Icons.hourglass_top_rounded
                            : (hasCard
                                  ? Icons.image_rounded
                                  : Icons.share_rounded),
                        color: HurufTheme.bgTop,
                        size: 20,
                      ),
                      const SizedBox(width: HurufTheme.s2),
                      Flexible(
                        child: Text(
                          lang.t('مشاركة النتيجة', 'Share result'),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: HurufTheme.bgTop,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (hasCard) ...[
              const SizedBox(width: HurufTheme.s2),
              _CircleButton(
                icon: Icons.notes_rounded,
                semanticLabel: lang.t('مشاركة كنص', 'Share as text'),
                onTap: _shareText,
              ),
            ],
            const SizedBox(width: HurufTheme.s2),
            _CircleButton(
              icon: Icons.copy_rounded,
              semanticLabel: lang.t('نسخ النتيجة', 'Copy result'),
              onTap: _copy,
            ),
          ],
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HurufTheme.tileEmpty,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Icon(icon, color: HurufTheme.textSecondary, size: 18),
      ),
    );
  }
}
