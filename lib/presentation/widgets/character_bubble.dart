import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/world_models.dart';
import 'glass_card.dart';
import 'video_animation.dart';

String randomMessage(CharacterEmotion emotion) {
  final pool = characterMessages[emotion]!;
  return pool[Random().nextInt(pool.length)];
}

/// شخصية + فقاعة كلام زجاجية، تنزلق للداخل عند الظهور
class CharacterBubble extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final text = message ?? randomMessage(emotion);
    final name = characters[characterId]!.nameAr;
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
          animated
              ? CharacterAnimation(
                  characterId: characterId,
                  emotion: emotion,
                  size: characterSize,
                )
              : CharacterPortrait(
                  characterId: characterId, size: characterSize),
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
