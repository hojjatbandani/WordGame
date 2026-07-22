import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/world_models.dart';
import '../providers.dart';
import '../widgets/animated_background.dart';
import '../widgets/character_bubble.dart';
import '../widgets/glass_card.dart';
import '../widgets/video_animation.dart';
import 'level_map_screen.dart';
import 'shop_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(pointsProvider);
    final maxUnlocked = ref.watch(maxUnlockedProvider);
    final jar = ref.watch(bonusJarProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // التدرج يظهر فورا كبديل حتى جاهزية الفيديو
          const AnimatedBackground(child: SizedBox.expand()),
          const VideoAnimationWidget(
            assetPath: 'assets/video/mainmenu.mp4',
            loop: true,
          ),
          // طبقة تعتيم تضمن تباين النصوص والشخصيات فوق الفيديو
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  HurufTheme.bgTop.withValues(alpha: 0.72),
                  HurufTheme.bgTop.withValues(alpha: 0.35),
                  HurufTheme.bgBottom.withValues(alpha: 0.80),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(HurufTheme.s5),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatChip(
                      icon: '💎',
                      value: '$points',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ShopScreen()),
                      ),
                    ),
                    _StatChip(icon: '🫙', value: '$jar'),
                  ],
                ),
                const Spacer(flex: 2),
                // الشعار
                ShaderMask(
                  shaderCallback: (bounds) =>
                      HurufTheme.goldGradient.createShader(bounds),
                  child: const Text(
                    'حُروف',
                    style: TextStyle(
                      fontSize: 84,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
                const Text(
                  'رحلة الكلمات العربية',
                  style: TextStyle(
                    fontSize: 18,
                    color: HurufTheme.textSecondary,
                  ),
                ),
                const Spacer(flex: 2),
                // المرشد أبو الحروف يرحب باللاعب (فيديو متكرر)
                CharacterBubble(
                  characterId: mascot,
                  emotion: CharacterEmotion.idle,
                  animated: true,
                  characterSize: 96,
                ),
                const Spacer(flex: 1),
                _PlayButton(
                  label: maxUnlocked <= 1
                      ? 'ابدأ اللعب'
                      : 'تابع — المرحلة $maxUnlocked',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const LevelMapScreen()),
                  ),
                ),
                const SizedBox(height: HurufTheme.s4),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ShopScreen()),
                  ),
                  icon: const Icon(Icons.storefront_rounded,
                      color: HurufTheme.textSecondary, size: 20),
                  label: const Text(
                    'المتجر',
                    style: TextStyle(
                        color: HurufTheme.textSecondary, fontSize: 16),
                  ),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String value;
  final VoidCallback? onTap;

  const _StatChip({required this.icon, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final chip = GlassCard(
      radius: HurufTheme.rButton,
      padding: const EdgeInsets.symmetric(
        horizontal: HurufTheme.s4,
        vertical: HurufTheme.s2,
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: HurufTheme.s2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: HurufTheme.gold,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}

class _PlayButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _PlayButton({required this.label, required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: 1 + _pulse.value * 0.03,
        child: child,
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HurufTheme.s8,
            vertical: HurufTheme.s4,
          ),
          decoration: BoxDecoration(
            gradient: HurufTheme.goldGradient,
            borderRadius: BorderRadius.circular(HurufTheme.rCard),
            boxShadow: [
              BoxShadow(
                color: HurufTheme.gold.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: HurufTheme.bgTop,
            ),
          ),
        ),
      ),
    );
  }
}
