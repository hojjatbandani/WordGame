import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/config/balance_config.dart';
import 'package:huruf/core/referral_link.dart';
import 'package:huruf/data/progress_store.dart';
import 'package:huruf/data/progression/player_level_curve.dart';
import 'package:huruf/data/progression/player_state.dart';
import 'package:huruf/data/progression_repository.dart';
import 'package:huruf/data/social_models.dart';
import 'package:huruf/presentation/providers.dart';
import 'package:huruf/presentation/screens/friends_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// أقلّ XP تضع اللاعب في [level] بالضبط
int _xpForLevel(int level) => PlayerLevelCurve.cumulativeXpToReach(level);

/// حاوية بحالة لاعب محفوظة مسبقا عند [level] بالضبط — نزرع الحالة في
/// SharedPreferences لا نعدّلها بعد التحميل، كي يمرّ المسار نفسه الذي
/// يمرّ به التطبيق عند الإقلاع
Future<ProviderContainer> _containerAtLevel(int level) async {
  final state = PlayerState.initial().copyWith(
    wallet: PlayerWallet.initial().copyWith(xp: _xpForLevel(level)),
  );
  SharedPreferences.setMockInitialValues({
    'khroof_player_state_v2': jsonEncode(state.toJson()),
    'migration_v2_done': true,
  });
  final prefs = await SharedPreferences.getInstance();
  final store = ProgressStore(prefs);
  final repo = await ProgressionRepository.load(prefs: prefs, legacy: store);

  return ProviderContainer(overrides: [
    progressStoreProvider.overrideWithValue(store),
    progressionRepositoryProvider.overrideWithValue(repo),
  ]);
}

void main() {
  group('منحنى المستوى', () {
    test('عتبات المستويات الثلاثة المعنيّة بالدعوة', () {
      // مستوى التأهيل (3) ومستوى ظهور الدعوة (5) — الرقمان اللذان
      // يعتمد عليهما النظام كله
      expect(PlayerLevelCurve.currentLevel(_xpForLevel(3)), 3);
      expect(PlayerLevelCurve.currentLevel(_xpForLevel(3) - 1), 2);
      expect(PlayerLevelCurve.currentLevel(_xpForLevel(5)), 5);
      expect(PlayerLevelCurve.currentLevel(_xpForLevel(5) - 1), 4);
    });

    test('صيغة الخادم تطابق منحنى العميل عند كل عتبة',
        () {
      // مرآة player_level_from_xp في supabase/schema_social_v2.sql:
      //   floor((-125 + sqrt(15625 + 100*xp)) / 50) + 1
      int serverLevel(int xp) {
        final k = (-125 + (15625 + 100 * xp).toDouble().sqrtOrZero()) / 50.0;
        return k.floor() + 1;
      }

      for (var xp = 0; xp <= 20000; xp += 7) {
        expect(serverLevel(xp), PlayerLevelCurve.currentLevel(xp),
            reason: 'اختلف المستوى بين الخادم والعميل عند xp=$xp');
      }
    });
  });

  group('بوّابة مستوى الدعوة', () {
    test('مقفلة عند المستوى 4 ومفتوحة عند 5', () async {
      final atFour = await _containerAtLevel(4);
      addTearDown(atFour.dispose);
      expect(atFour.read(playerLevelProvider), 4);
      expect(atFour.read(referralUnlockedProvider), isFalse);

      final atFive = await _containerAtLevel(5);
      addTearDown(atFive.dispose);
      expect(atFive.read(playerLevelProvider), 5);
      expect(atFive.read(referralUnlockedProvider), isTrue);
    });

    test('البوّابة تتبع BalanceConfig لا رقما مكتوبا في الشيفرة', () async {
      final original = BalanceConfig.levelGateReferral;
      addTearDown(() => BalanceConfig.levelGateReferral = original);

      final c = await _containerAtLevel(4);
      addTearDown(c.dispose);
      expect(c.read(referralUnlockedProvider), isFalse);

      BalanceConfig.levelGateReferral = 4;
      final c2 = await _containerAtLevel(4);
      addTearDown(c2.dispose);
      expect(c2.read(referralUnlockedProvider), isTrue);
    });
  });

  group('اختبار القبول: مدخل الدعوة في الواجهة', () {
    Future<void> pumpFriends(WidgetTester tester, ProviderContainer c) async {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: FriendsScreen()),
      ));
      await tester.pump();
    }

    testWidgets('غير موجود عند المستوى 4', (tester) async {
      final c = await _containerAtLevel(4);
      addTearDown(c.dispose);
      await pumpFriends(tester, c);

      expect(find.byKey(ReferralCard.entryPointKey), findsNothing);
      // ليس مخفيّا ولا معطَّلا — غير مبني إطلاقا
      expect(find.byType(ReferralCard), findsNothing);
    });

    testWidgets('موجود عند المستوى 5', (tester) async {
      final c = await _containerAtLevel(5);
      addTearDown(c.dispose);
      c.read(myProfileProvider); // يبقى loading بلا Supabase — لا يهم
      await pumpFriends(tester, c);

      expect(find.byKey(ReferralCard.entryPointKey), findsOneWidget);
    });
  });

  group('روابط الدعوة', () {
    test('تستخرج الرمز من كل شكل قد يصل به', () {
      const code = 'ABCD2345';
      for (final input in [
        code,
        '  abcd2345 ',
        'https://huruf.site/i/$code',
        'http://www.huruf.site/i/$code',
        'huruf://i/$code',
        'https://huruf.site/get?code=$code',
        'https://huruf.site/x/y/i/$code',
      ]) {
        expect(ReferralLink.extractCode(input), code, reason: input);
      }
    });

    test('لا ترمي ولا تخترع رمزا من مدخل غير صالح', () {
      for (final input in [
        null,
        '',
        '   ',
        'ABC',
        'ABCD23451',
        'ABCD2340', // صفر ليس في الأبجدية (ملتبس مع O)
        'https://huruf.site/i/',
        'مرحبا',
        '::::',
      ]) {
        expect(ReferralLink.extractCode(input), isNull, reason: '$input');
      }
    });

    test('الرابط المبني يعود لنفس الرمز', () {
      const code = 'JKLM6789';
      expect(ReferralLink.extractCode(ReferralLink.forCode(code)), code);
      expect(ReferralLink.forCode('jklm6789'), contains(code));
    });

    test('طول الرمز ثمانية — يطابق الخادم وBalanceConfig', () {
      expect(ReferralLink.codeLength, BalanceConfig.friendCodeLength);
      expect(ReferralLink.isWellFormed('ABCDEFGH'), isTrue);
      expect(ReferralLink.isWellFormed('ABCDEF'), isFalse);
    });
  });

  group('حالة الدعوات', () {
    test('المعلَّق هو من انضم ولم يبلغ مستوى التأهيل', () {
      const status = ReferralStatus(
          invited: 5, qualified: 2, paid: 2, cap: 20, qualifyLevel: 3);

      expect(status.pending, 3);
      expect(status.atCap, isFalse);
    });

    test('العتبة التالية تتخطّى ما نيل منها', () {
      const milestones = [3, 5, 10];
      expect(
          const ReferralStatus(
                  invited: 0, qualified: 0, paid: 0, cap: 20, qualifyLevel: 3)
              .nextMilestone(milestones),
          3);
      expect(
          const ReferralStatus(
                  invited: 9, qualified: 4, paid: 4, cap: 20, qualifyLevel: 3)
              .nextMilestone(milestones),
          5);
      expect(
          const ReferralStatus(
                  invited: 30, qualified: 12, paid: 12, cap: 20, qualifyLevel: 3)
              .nextMilestone(milestones),
          isNull);
    });

    test('السقف يُقاس بالمدفوع لا بمن أدخل الرمز', () {
      const status = ReferralStatus(
          invited: 40, qualified: 20, paid: 20, cap: 20, qualifyLevel: 3);
      expect(status.atCap, isTrue);
    });
  });

  group('معرّف التثبيت', () {
    test('يُولَّد مرة ويثبت بعدها', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ProgressStore(await SharedPreferences.getInstance());

      final first = store.installId;
      expect(first, hasLength(32));
      expect(store.installId, first);
      expect(store.installId, first);
    });

    test('تثبيتان مختلفان يعطيان معرّفين مختلفين', () async {
      SharedPreferences.setMockInitialValues({});
      final a = ProgressStore(await SharedPreferences.getInstance()).installId;
      SharedPreferences.setMockInitialValues({});
      final b = ProgressStore(await SharedPreferences.getInstance()).installId;

      expect(a, isNot(b));
    });
  });
}

extension on double {
  /// جذر تربيعي بلا استيراد dart:math في ملف اختبار — للمقارنة مع
  /// الصيغة المغلقة في الخادم فقط
  double sqrtOrZero() {
    if (this <= 0) return 0;
    var x = this;
    for (var i = 0; i < 60; i++) {
      x = 0.5 * (x + this / x);
    }
    return x;
  }
}
