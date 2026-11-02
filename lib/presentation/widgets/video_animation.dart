import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/world_models.dart';

/// مشغل MP4 قابل لإعادة الاستخدام لرسوم الشخصيات والخلفيات.
///
/// - تشغيل سلس مع وضعي loop أو مرة واحدة
/// - إيقاف تلقائي عند خروج التطبيق للخلفية
/// - إن منع المتصفح التشغيل التلقائي: يعرض أول إطار ويعيد المحاولة
///   تلقائيا وعند أول لمسة
/// - تحرير المتحكم عند الإزالة
class VideoAnimationWidget extends StatefulWidget {
  final String assetPath;
  final bool loop;
  final String? placeholderImage;
  final BoxFit fit;
  final VoidCallback? onFinished;

  const VideoAnimationWidget({
    super.key,
    required this.assetPath,
    this.loop = true,
    this.placeholderImage,
    this.fit = BoxFit.cover,
    this.onFinished,
  });

  @override
  State<VideoAnimationWidget> createState() => _VideoAnimationWidgetState();
}

class _VideoAnimationWidgetState extends State<VideoAnimationWidget>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _playing = false;
  bool _finishedNotified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.asset(widget.assetPath);
    _controller = controller;
    try {
      await controller.initialize();
    } catch (e) {
      debugPrint('VideoAnimation: init failed for ${widget.assetPath}: $e');
      return; // نبقي الصورة البديلة
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    await controller.setLooping(widget.loop);
    await controller.setVolume(0); // كتم الصوت شرط التشغيل التلقائي في الويب
    if (!widget.loop) controller.addListener(_watchCompletion);
    // نعرض أول إطار فورا حتى لو تأخر التشغيل أو منع
    setState(() => _ready = true);
    await _tryPlay();
    // محاولة ثانية بعد لحظة — بعض المتصفحات تمنع أول نداء فقط
    if (!_playing) {
      Future.delayed(const Duration(milliseconds: 800), _tryPlay);
    }
  }

  Future<void> _tryPlay() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _playing) return;
    try {
      await c.play();
      if (mounted) setState(() => _playing = c.value.isPlaying);
    } catch (e) {
      debugPrint('VideoAnimation: autoplay blocked: $e');
    }
  }

  void _watchCompletion() {
    final c = _controller;
    if (c == null || _finishedNotified) return;
    final value = c.value;
    if (value.isInitialized &&
        !value.isPlaying &&
        value.position >= value.duration - const Duration(milliseconds: 80)) {
      _finishedNotified = true;
      widget.onFinished?.call();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.resumed) {
      _playing = false;
      _tryPlay();
    } else {
      c.pause();
      _playing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_watchCompletion);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (!_ready || c == null || !c.value.isInitialized) {
      // شفاف افتراضيا كي تظهر الطبقة الخلفية فورا دون انتظار الفيديو
      return widget.placeholderImage != null
          ? Image.asset(widget.placeholderImage!, fit: widget.fit)
          : const SizedBox.expand();
    }
    // Listener لا يزاحم الأزرار — يلتقط أول لمسة لاستئناف التشغيل الممنوع
    return Listener(
      onPointerDown: (_) => _tryPlay(),
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          builder: (context, opacity, child) =>
              Opacity(opacity: opacity, child: child),
          child: FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
        ),
      ),
    );
  }
}

/// رسم شخصية بحالة عاطفية — واجهة عالية المستوى فوق [VideoAnimationWidget]
///
/// ```dart
/// CharacterAnimation(characterId: 'puzzle_master',
///     emotion: CharacterEmotion.happy, loop: false)
/// ```
class CharacterAnimation extends StatelessWidget {
  final String characterId;
  final CharacterEmotion emotion;
  final bool loop;
  final double size;
  final VoidCallback? onFinished;

  const CharacterAnimation({
    super.key,
    required this.characterId,
    this.emotion = CharacterEmotion.idle,
    this.loop = true,
    this.size = 120,
    this.onFinished,
  });

  @override
  Widget build(BuildContext context) {
    final character = characters[characterId]!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      // الحلقة فوق الفيديو لا تحته: decoration تُرسم قبل الطفل، والفيديو
      // يملأ الدائرة حتى حافة القصّ فيخفيها تماما
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: VideoAnimationWidget(
        assetPath: character.animation,
        loop: loop,
        placeholderImage: character.portrait,
        onFinished: onFinished,
      ),
    );
  }
}

/// صورة الشخصية الثابتة في إطار دائري (أخف من الفيديو للقوائم)
class CharacterPortrait extends StatelessWidget {
  final String characterId;
  final double size;

  const CharacterPortrait({
    super.key,
    required this.characterId,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final character = characters[characterId]!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      // الحلقة فوق الصورة لا تحتها: decoration تُرسم قبل الطفل،
      // والصورة تملأ الدائرة حتى حافة القصّ فتخفي الحلقة تماما
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        character.portrait,
        fit: BoxFit.cover,
        // تصغير فك الترميز لتوفير الذاكرة
        cacheWidth: (size * 3).round(),
      ),
    );
  }
}
