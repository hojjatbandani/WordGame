import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/progression/map_view_model.dart';
import '../progression_text.dart';
import '../providers.dart';

/// شريط أقرب مكافأة — ثابت أعلى المستويات الثلاثة كلها. يُعاد حسابه من
/// [progressionProvider] مباشرة (اختبار قبول: "يُعاد حسابه بعد كل إتمام
/// مرحلة") — أي تحديث لحالة اللاعب يعيد بناء هذا الشريط فورا لأنه يراقب
/// نفس المزوّد الذي يتغيّر بعد recordStageCompletion.
///
/// يعرض دوما موضع اللاعب الفعلي الحالي (currentStageId)، لا العالم/الفصل
/// الذي يتصفّحه — هو معلم شخصي عن "أين أنت"، لا معاينة لما تتصفّحه.
class NearRewardBanner extends ConsumerWidget {
  const NearRewardBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final snapshot = ref.watch(progressionProvider);
    final structure = ref.watch(progressionStructureProvider);

    final banner = MapViewModel.computeNearRewardBanner(
      state: snapshot.state,
      progress: snapshot.stageProgress,
      structure: structure,
    );
    final isPercent = banner.kind == NearRewardKind.worldCompletionPercent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: HurufTheme.s4, vertical: HurufTheme.s3),
      decoration: BoxDecoration(
        color: HurufTheme.gold.withValues(alpha: 0.12),
        border: const Border(
          bottom: BorderSide(color: HurufTheme.gold, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(isPercent ? '📊' : '✨', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: HurufTheme.s2),
          Expanded(
            child: Text(
              nearRewardBannerText(banner, lang),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: HurufTheme.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
