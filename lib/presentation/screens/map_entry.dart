import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/analytics/analytics_event.dart';
import '../../data/analytics/analytics_service.dart';
import '../../data/models.dart';
import '../providers.dart';
import 'game_screen.dart';
import 'world_select_screen.dart';
import 'world_unlock_ceremony_screen.dart';

/// مراقب المسارات: يعرف به [HomeScreen] أنه صار ظاهرا (عند الإقلاع أو
/// بعد العودة إليه) فيُسجّل home_viewed. يُمرَّر إلى MaterialApp.
///
/// صفحات فقط: النوافذ والأوراق مسارات أيضا، وإغلاق إحداها فوق الرئيسية
/// كان يُعدّ «عودة» فيُضخّم home_viewed ويسلسل الأسئلة واحدا بعد آخر.
final hurufRouteObserver = RouteObserver<PageRoute<dynamic>>();

/// نقطة الدخول الوحيدة إلى الخريطة من أي مكان في التطبيق. تتحقّق أولا
/// من مراسم فتح عالم معلّقة (اختبار قبول 5: تُعرض مرة واحدة فقط) — إن
/// وُجدت تُعرض المراسم أولا (أقدم عالم معلّق)، وإلا تُفتح شاشة اختيار
/// العوالم مباشرة.
void openMap(BuildContext context, WidgetRef ref) {
  final pending = ref.read(progressionRepositoryProvider).worldsPendingCeremony;
  if (pending.isNotEmpty) {
    final worldId = pending.reduce((a, b) => a < b ? a : b);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorldUnlockCeremonyScreen(worldId: worldId),
      ),
    );
    return;
  }
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const WorldSelectScreen()));
}

/// يفتح المرحلة الحالية مباشرة — بلا عوالم ولا فصول ولا مسار بينها
/// (المواصفة §5.1). كان «تابع اللعب» يفتح الخريطة فيمرّ اللاعب الجديد
/// بأربع لمسات قبل أي حرف. من أنهى كل المراحل يذهب إلى الخريطة.
///
/// كل ما يلزم يُقرأ قبل انتظار المراحل: الشاشة المستدعية قد تُستبدل
/// (شاشة البدء) قبل أن تصل.
Future<void> openCurrentStage(
  BuildContext context,
  WidgetRef ref, {
  required String source,
}) async {
  final navigator = Navigator.of(context);
  final analytics = ref.read(analyticsProvider);
  final current = ref.read(maxUnlockedProvider);
  final levels = await ref.read(levelsProvider.future);
  if (current > levels.length) {
    if (context.mounted) openMap(context, ref);
    return;
  }
  pushStage(
    navigator,
    level: levels[current - 1],
    levels: levels,
    source: source,
    analytics: analytics,
  );
}

/// يدفع شاشة المرحلة ويسجّل stage_selected — متزامن، كي تُدفع فوق
/// الرئيسية في الإطار نفسه حين يلزم (الإقلاع الأول)
void pushStage(
  NavigatorState navigator, {
  required GameLevel level,
  required List<GameLevel> levels,
  required String source,
  AnalyticsService? analytics,
}) {
  analytics?.log(Ev.stageSelected, {'stage_id': level.id, 'source': source});
  navigator.push(
    MaterialPageRoute(
      builder: (_) =>
          GameScreen(level: level, allLevels: levels, source: source),
    ),
  );
}
