// شاشة الإنجازات كانت تقصّ النصوص الطويلة: العنوان والوصف سطر واحد
// لكلٍّ، وعمود التقدّم بلا عرض محدود. مع مئة إنجاز صارت العناوين أطول
// («فاتح المدينة الذهبية») والأهداف أكبر («12345/50000»)، فظهر القصّ.
//
// الاختبار يرسم الشاشة كاملة على أضيق جهاز ندعمه وبأطول نصوص في
// الكتالوج، ويفشل عند أي تجاوز تخطيط (flutter_test يعتبر تحذير
// RenderFlex overflow فشلا).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/data/achievement_models.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/achievements_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// لاعب في منتصف الطريق: أشرطة تقدّم جزئية وشارات مفتوحة معا — الحالة
/// التي تُظهر أطول نصّ في البطاقة (العنوان + الشارة + «قيمة/هدف»)
Future<Widget> _app() async {
  SharedPreferences.setMockInitialValues({
    'stat_levelsCompleted': 137,
    'stat_wordsFound': 1240,
    'stat_bonusWords': 312,
    'stat_perfectLevels': 96,
    'stat_worldsCompleted': 2,
    'stat_chaptersCompleted': 11,
    'stat_longestWord': 7,
    'stat_daysPlayed': 12,
    'stat_bestStreak': 7,
    'stat_challengesSolved': 24,
    'stat_pointsEarned': 12345,
    'stat_wheelSpins': 41,
  });
  final store = ProgressStore(await SharedPreferences.getInstance());
  return ProviderScope(
    overrides: [progressStoreProvider.overrideWithValue(store)],
    child: MaterialApp(
      theme: HurufTheme.build(),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const AchievementsScreen(),
    ),
  );
}

void main() {
  testWidgets('تمرير الشاشة كلها على أضيق جهاز بلا أي تجاوز تخطيط', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280); // 360×640 منطقية
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    // نمرّر حتى النهاية كي تُبنى كل البطاقات فعلا — القائمة كسولة،
    // وبطاقة لم تُبنَ لا تفيض
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 40; i++) {
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('لا فئة «اجتماعي» على الشاشة ما دامت معطّلة', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    // «مفتوح من أصل» يعدّ المرئيّ لا الكتالوج كله
    expect(find.textContaining('من ${visibleAchievements.length}'), findsOne);

    // القائمة كسولة، فعناوين الفئات لا تُبنى دفعة واحدة: نمرّر حتى
    // النهاية ونجمع ما ظهر فعلا
    final seen = <String>{};
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 40; i++) {
      for (final c in AchievementCategory.values) {
        if (find.text(c.titleAr).evaluate().isNotEmpty) seen.add(c.name);
      }
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
    }

    expect(
      seen,
      isNot(contains(AchievementCategory.social.name)),
      reason: 'فئة معطّلة لا تظهر ولو مرّة أثناء التمرير كله',
    );
    expect(
      seen,
      containsAll(
        AchievementCategory.values.where((c) => c.isEnabled).map((c) => c.name),
      ),
      reason: 'كل فئة مفعّلة يجب أن تظهر ترويستها',
    );
  });
}
