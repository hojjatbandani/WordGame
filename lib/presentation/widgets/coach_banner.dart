import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// جملة توجيه قصيرة في خانة المعاينة فوق العجلة (مدرّب المرحلة الأولى
/// والمساعدة المتدرّجة). لا نافذة ولا زرّ: اللاعب يبقى يلعب.
class CoachBanner extends StatelessWidget {
  final String text;

  const CoachBanner({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(
          horizontal: HurufTheme.s4,
          vertical: HurufTheme.s1,
        ),
        decoration: BoxDecoration(
          color: HurufTheme.gold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(HurufTheme.rButton),
          border: Border.all(color: HurufTheme.gold.withValues(alpha: 0.35)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: HurufTheme.gold,
          ),
        ),
      ),
    );
  }
}
