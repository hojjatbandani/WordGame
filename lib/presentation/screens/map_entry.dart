import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'world_select_screen.dart';
import 'world_unlock_ceremony_screen.dart';

/// نقطة الدخول الوحيدة إلى الخريطة من أي مكان في التطبيق. تتحقّق أولا
/// من مراسم فتح عالم معلّقة (اختبار قبول 5: تُعرض مرة واحدة فقط) — إن
/// وُجدت تُعرض المراسم أولا (أقدم عالم معلّق)، وإلا تُفتح شاشة اختيار
/// العوالم مباشرة.
void openMap(BuildContext context, WidgetRef ref) {
  final pending = ref.read(progressionRepositoryProvider).worldsPendingCeremony;
  if (pending.isNotEmpty) {
    final worldId = pending.reduce((a, b) => a < b ? a : b);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorldUnlockCeremonyScreen(worldId: worldId),
    ));
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const WorldSelectScreen()),
  );
}
