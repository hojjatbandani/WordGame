import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/world_models.dart';
import '../providers.dart';
import 'glass_card.dart';
import 'video_animation.dart';

String randomMessage(CharacterEmotion emotion) {
  final pool = characterMessages[emotion]!;
  return pool[Random().nextInt(pool.length)];
}

/// شخصية + فقاعة كلام زجاجية، تنزلق للداخل عند الظهور، وتُسمع بصمة
/// الشخصية الصوتية مع ظهورها
class CharacterBubble extends ConsumerStatefulWidget {
  final String characterId;
  final CharacterEmotion emotion;
  final String? message;
  final bool animated;
  final double characterSize;

  const CharacterBubble({
    super.key,
    required this.characterId,
    this.emotion = CharacterEmotion.idle,
    this.message,
    this.animated = false,
    this.characterSize = 84,
  });

  @override
  ConsumerState<CharacterBubble> createState() => _CharacterBubbleState();
}

class _CharacterBubbleState extends ConsumerState<CharacterBubble> {
  @override
  void initState() {
    super.initState();
    // بصمة الشخصية تُسمع مرة عند ظهور الفقاعة لا مع كل إعادة رسم
    ref.read(audioServiceProvider).playCharacter(widget.characterId);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.message ?? randomMessage(widget.emotion);
    final name = characters[widget.characterId]!.nameAr;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, (1 - t) * 24),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          widget.animated
              ? CharacterAnimation(
                  characterId: widget.characterId,
                  emotion: widget.emotion,
                  size: widget.characterSize,
                )
              : CharacterPortrait(
                  characterId: widget.characterId,
                  size: widget.characterSize),
          const SizedBox(width: HurufTheme.s3),
          Expanded(
            child: GlassCard(
              radius: HurufTheme.rButton,
              padding: const EdgeInsets.symmetric(
                horizontal: HurufTheme.s4,
                vertical: HurufTheme.s3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: HurufTheme.gold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
