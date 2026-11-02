import 'dart:async';

import 'package:flutter/material.dart';

import '../data/rewards/reward_track.dart';
import '../data/widget/widget_data.dart';
import 'screens/rewards_screen.dart';

/// فتح شاشة الجوائز من نقرة ودجة الشاشة الرئيسية.
///
/// يغطّي البدايتين معا:
///  • **بارد** — التطبيق مغلق والنقرة أطلقته: الرابط يُقرأ مرة واحدة
///    بعد أول إطار (`HomeWidgetService.initialLaunchUri`).
///  • **دافئ** — التطبيق يعمل: الروابط تصل عبر `HomeWidgetService.clicks`.
///
/// ولا تُكدَّس شاشتان: إن كانت شاشة الجوائز معروضة فعلا يُحدَّث إبرازها
/// موضعيا ([focusTier]) بدل دفع نسخة ثانية فوقها — راجع تسجيل الشاشة
/// لنفسها في [RewardsScreen].
class HomeWidgetLaunch {
  const HomeWidgetLaunch._();

  /// مفتاح المُلاح الجذري — النقرة تصل خارج شجرة الودجات، فلا سياق
  /// (`BuildContext`) بيدها تنطلق منه
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// الطبقة المطلوب إبرازها في شاشة الجوائز. تراقبها الشاشة المفتوحة
  /// فتُمرّر الإبراز بلا إعادة بناء المسار.
  static final focusTier = ValueNotifier<RewardTier?>(null);

  static bool _rewardsOpen = false;

  /// تستدعيها [RewardsScreen] في initState/dispose
  static void setRewardsOpen(bool open) => _rewardsOpen = open;

  /// اسم المسار — يجعل شاشة الجوائز مميَّزة في مكدّس المُلاح للتشخيص
  static const routeName = 'rewards';

  /// يعالج رابطا واردا. يتجاهل بهدوء أي رابط ليس رابط جوائز (روابط
  /// الدعوة لها مسارها في deep_link_service.dart).
  static Future<void> handle(Uri? uri) async {
    if (uri == null) return;
    final (isRewards, tier) = WidgetDeepLink.parse(uri);
    if (!isRewards) return;
    await openRewards(tier);
  }

  static Future<void> openRewards(RewardTier? tier) async {
    focusTier.value = tier;

    // معروضة أصلا: الإبراز أعلاه كافٍ، ودفع نسخة ثانية يعطي شاشتين
    // متطابقتين وزرّ رجوع يمرّ بهما معا
    if (_rewardsOpen) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      // الشجرة لم تُبنَ بعد (بدء بارد شديد السرعة) — الإبراز محفوظ
      // أعلاه، وسيلتقطه أول فتح للشاشة
      debugPrint('الودجة: المُلاح غير جاهز بعد، أُجّل الفتح');
      return;
    }
    await navigator.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: routeName),
        builder: (_) => const RewardsScreen(),
      ),
    );
  }

  /// يربط مصدري الروابط معا. يعيد اشتراكا يجب التخلّص منه.
  static StreamSubscription<Uri?> listen({
    required Stream<Uri?> clicks,
    required Future<Uri?> Function() initialUri,
  }) {
    // البدء البارد: بعد أول إطار كي يكون المُلاح جاهزا فعلا
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await handle(await initialUri());
    });
    return clicks.listen(
      handle,
      onError: (Object e) => debugPrint('الودجة: خطأ في مجرى النقرات — $e'),
    );
  }
}
