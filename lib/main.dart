import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'data/progress_store.dart';
import 'presentation/providers.dart';
import 'presentation/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // الواجهة مصممة للوضع الرأسي فقط (عجلة الحروف، الشبكة، الخريطة)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final store = await ProgressStore.create();
  runApp(
    ProviderScope(
      overrides: [progressStoreProvider.overrideWithValue(store)],
      child: const HurufApp(),
    ),
  );
}

class HurufApp extends StatelessWidget {
  const HurufApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حروف',
      debugShowCheckedModeBanner: false,
      theme: HurufTheme.build(),
      // RTL في جذر التطبيق
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const SplashScreen(),
    );
  }
}
