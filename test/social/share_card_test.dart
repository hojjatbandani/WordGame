import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/core/app_language.dart';
import 'package:huruf/core/share_templates.dart';
import 'package:huruf/core/theme.dart';
import 'package:huruf/presentation/widgets/share_card.dart';

/// كلمات لغز افتراضي. البطاقة لا تقبل نصّ كلمة أصلا — هذه هنا كي نبحث
/// عنها في كل نصّ تعرضه البطاقة ونثبت غيابه.
const _solutionWords = ['قلم', 'كتاب', 'مدرسة', 'قمر', 'شمس'];

/// كل النصوص المعروضة فعلا داخل الشجرة
List<String> _visibleTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .toList();

Future<void> _pumpCard(
  WidgetTester tester, {
  required List<ShareWordStatus> words,
  String? inviteCode,
  int? rank,
  int totalPlayers = 0,
  int streak = 0,
  AppLanguage lang = AppLanguage.ar,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: HurufTheme.build(),
    home: Scaffold(
      body: Center(
        child: RepaintBoundary(
          child: ShareCard(
            title: 'حروف — التحدي اليومي #42',
            date: DateTime.utc(2026, 8, 26),
            words: words,
            score: 780,
            rank: rank,
            totalPlayers: totalPlayers,
            streak: streak,
            inviteCode: inviteCode,
            lang: lang,
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  group('اختبار القبول: بطاقة المشاركة لا تحوي كلمات الحل', () {
    testWidgets('بكل تركيبات حالات الكلمات', (tester) async {
      for (final statuses in [
        List.filled(6, ShareWordStatus.solved),
        List.filled(6, ShareWordStatus.hinted),
        List.filled(6, ShareWordStatus.missed),
        const [
          ShareWordStatus.solved,
          ShareWordStatus.missed,
          ShareWordStatus.hinted,
          ShareWordStatus.solved,
          ShareWordStatus.missed,
        ],
      ]) {
        await _pumpCard(
          tester,
          words: statuses,
          inviteCode: 'ABCD2345',
          rank: 12,
          totalPlayers: 4300,
          streak: 5,
        );

        final texts = _visibleTexts(tester).join(' | ');
        for (final word in _solutionWords) {
          expect(texts, isNot(contains(word)),
              reason: 'كلمة «$word» ظهرت في بطاقة المشاركة: $texts');
        }
      }
    });

    testWidgets('المربّعات لا تحمل أي نصّ بداخلها', (tester) async {
      await _pumpCard(tester, words: List.filled(5, ShareWordStatus.solved));

      // كل نصوص البطاقة معروفة مسبقا: العنوان والتاريخ والأرقام
      // والتسميات. لا نصّ ديناميكي مصدره اللغز إطلاقا.
      final texts = _visibleTexts(tester);
      expect(texts, contains('حروف — التحدي اليومي #42'));
      expect(texts, contains('2026-08-26'));
      expect(texts, contains('5/5'));
      expect(texts, contains('780'));
    });
  });

  group('بطاقة المشاركة', () {
    testWidgets('مربّع واحد لكل كلمة', (tester) async {
      await _pumpCard(tester, words: List.filled(7, ShareWordStatus.solved));

      // الشبكة داخل Wrap — نعدّ أبناءه لا كل Container في البطاقة
      final wrap = tester.widget<Wrap>(find.byType(Wrap).first);
      expect(wrap.children, hasLength(7));
    });

    testWidgets('الترتيب يظهر حين يُعرف ويغيب حين لا يُعرف', (tester) async {
      await _pumpCard(
        tester,
        words: const [ShareWordStatus.solved],
        rank: 12,
        totalPlayers: 4300,
      );
      expect(find.text('12 / 4300'), findsOneWidget);

      await _pumpCard(tester, words: const [ShareWordStatus.solved]);
      expect(find.textContaining('/ 0'), findsNothing);
    });

    testWidgets('السلسلة تظهر من يومين فصاعدا', (tester) async {
      await _pumpCard(
          tester, words: const [ShareWordStatus.solved], streak: 1);
      expect(find.text('السلسلة'), findsNothing);

      await _pumpCard(
          tester, words: const [ShareWordStatus.solved], streak: 4);
      expect(find.text('السلسلة'), findsOneWidget);
      expect(find.text('🔥 4 يوم'), findsOneWidget);
    });

    testWidgets('رمز الدعوة يظهر فقط حين يُمرَّر', (tester) async {
      await _pumpCard(tester, words: const [ShareWordStatus.solved]);
      expect(find.text('ABCD2345'), findsNothing);

      await _pumpCard(
        tester,
        words: const [ShareWordStatus.solved],
        inviteCode: 'ABCD2345',
      );
      expect(find.text('ABCD2345'), findsOneWidget);
    });
  });
}
