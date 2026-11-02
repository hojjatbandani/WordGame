import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/theme.dart';
import '../providers.dart';
import '../widgets/animated_background.dart';
import 'home_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, animation, _) =>
              FadeTransition(opacity: animation, child: const HomeScreen()),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // التدرّج والنجوم تبقى تحت الصورة: إن تأخّر فكّ ترميزها
          // إطارا أو إطارين لا تومض الشاشة بياضا
          const AnimatedBackground(child: SizedBox.expand()),
          Image.asset(
            AppIcons.splashBackground,
            fit: BoxFit.cover,
            cacheWidth: 1080,
          ),
          // طبقة تعتيم: المشهد فاتح ودافئ، وعليه قرص
          // أبيض واسم ذهبي لا يقرآان عليه بلا تعتيم
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  HurufTheme.bgTop.withValues(alpha: 0.90),
                  HurufTheme.bgTop.withValues(alpha: 0.62),
                  HurufTheme.bgTop.withValues(alpha: 0.90),
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
          Center(
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _controller,
                curve: Curves.elasticOut,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    clipBehavior: Clip.antiAlias,
                    // نفس هوية الشعار في الرئيسية: قرص أبيض بحلقة ذهبية
                    foregroundDecoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: HurufTheme.gold, width: 4),
                    ),
                    child: Image.asset(
                      AppIcons.logo,
                      fit: BoxFit.cover,
                      // فكّ الترميز بحجم العرض لا بـ640px كاملة
                      cacheHeight: 600,
                    ),
                  ),
                  const SizedBox(height: HurufTheme.s3),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        HurufTheme.goldGradient.createShader(bounds),
                    child: Text(
                      ref.watch(languageProvider).t('حُروف', 'Huruf'),
                      style: const TextStyle(
                        fontSize: 58,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
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
