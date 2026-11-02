import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// غلاف قياسي لكل عنصر قابل للنقر في التطبيق.
///
/// يعالج ثلاث قواعد أساسية دفعة واحدة:
///  • بازخورد لمسي مرئي: تصغير 0.96 + خفض شفافية خلال 150ms (لا يزيح التخطيط)
///  • الوصولية: تسمية دلالية للقارئ الصوتي وزر دلالي صحيح
///  • حد أدنى لمساحة اللمس 48dp حتى لو كان المحتوى أصغر
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// وصف للقارئ الصوتي — إلزامي عمليا للأزرار الأيقونية
  final String? semanticLabel;

  /// اهتزاز خفيف عند النقر (مناسب لأزرار اللعب)
  final bool haptic;

  /// شدّة التصغير عند الضغط
  final double pressedScale;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.haptic = true,
    this.pressedScale = 0.96,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _setDown(bool value) {
    if (!_enabled || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    final scale = _down && !reduce ? widget.pressedScale : 1.0;

    return Semantics(
      button: _enabled,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: _enabled
            ? () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap?.call();
              }
            : null,
        onLongPress: widget.onLongPress,
        child: ConstrainedBox(
          // يضمن مساحة لمس كافية دون تغيير شكل المحتوى
          constraints: const BoxConstraints(
            minWidth: HurufTheme.minTouch,
            minHeight: HurufTheme.minTouch,
          ),
          child: AnimatedScale(
            scale: scale,
            duration: HurufTheme.durFast,
            curve: HurufTheme.curveEnter,
            child: AnimatedOpacity(
              opacity: _down && _enabled ? 0.82 : 1,
              duration: HurufTheme.durFast,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
