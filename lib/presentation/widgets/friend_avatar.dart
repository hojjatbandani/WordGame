import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// صورة الصديق الرمزية.
///
/// حرف واحد على دائرة ملوّنة، لا صورة مرفوعة: رفع الصور يفتح بابا
/// (محتوى غير لائق، تخزين، إبلاغ، حجب) لا يستحقه صفّ في قائمة أصدقاء.
/// اللون مشتقّ من [avatarId] لا من الاسم، كي يبقى ثابتا للاعب حتى لو
/// غيّر اسمه — الثبات هو ما يجعل الصورة قابلة للتعرّف أصلا.
class FriendAvatar extends StatelessWidget {
  final String name;
  final String avatarId;
  final double size;

  /// شارة صغيرة أسفل الدائرة (المستوى عادة). null يخفيها.
  final int? level;

  const FriendAvatar({
    super.key,
    required this.name,
    required this.avatarId,
    this.size = 44,
    this.level,
  });

  static const _palette = [
    Color(0xFFF4C430),
    Color(0xFF34E89E),
    Color(0xFF6C8CFF),
    Color(0xFFFF8A5B),
    Color(0xFFB57BFF),
    Color(0xFF3FC5C9),
  ];

  Color get _color {
    if (avatarId.isEmpty) return _palette.first;
    final sum = avatarId.codeUnits.fold<int>(0, (a, b) => a + b);
    return _palette[sum % _palette.length];
  }

  String get _initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '؟' : trimmed.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return SizedBox(
      width: size,
      height: size + (level == null ? 0 : 8),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
              border: Border.all(color: color.withValues(alpha: 0.55), width: 2),
            ),
            child: Text(
              _initial,
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          if (level != null)
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: HurufTheme.bgTop,
                  borderRadius: BorderRadius.circular(HurufTheme.rTile),
                  border: Border.all(color: color.withValues(alpha: 0.55)),
                ),
                child: Text(
                  '$level',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
