import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart' as gs;

import 'achievement_models.dart';

/// مزامنة الإنجازات مع Google Play Games (وGame Center على iOS).
///
/// المصدر الحقيقي للإنجازات يبقى محليا دائما، وهذه الطبقة مجرد «صدى»
/// يرفع الإنجاز إلى حساب اللاعب كي يبقى محفوظا عند تغيير الجهاز. لذلك
/// كل استدعاء هنا يفشل بصمت: إن لم يسجّل اللاعب دخوله، أو لم تُضبط
/// الخدمة في Play Console بعد، تكمل اللعبة عملها كالمعتاد.
///
/// ── الإعداد المطلوب منك في Google Play Console ──
/// 1. Play Games Services → Setup and management → Configuration
/// 2. أنشئ كل إنجاز يدويا هناك بنفس العناوين العربية في
///    [achievements]، وانسخ معرّف كل واحد (يشبه CgkI...).
/// 3. ضع المعرّفات في [_playGamesIds] أدناه مقابل المعرّف الداخلي.
/// 4. أضف رقم المشروع في android/app/src/main/AndroidManifest.xml:
///    <meta-data android:name="com.google.android.gms.games.APP_ID"
///               android:value="@string/game_services_app_id"/>
///
/// ما دامت الخريطة فارغة، تعمل الإنجازات محليا فقط دون أي خطأ.
class GamesServicesSync {
  /// المعرّف الداخلي → معرّف الإنجاز في Google Play Games.
  /// اتركه فارغا حتى تنشئ الإنجازات في Play Console — 34 إنجازا بالضبط
  /// حاليا (راجع achievements في achievement_models.dart للعناوين
  /// والأوصاف الدقيقة اللازمة عند إنشائها هناك). القائمة الكاملة
  /// للمعرّفات الداخلية الـ34 التي تحتاج معرّف Play Games مقابلا:
  /// first_step, levels_50, levels_200, levels_500, world_1, world_4,
  /// world_8, words_50, words_500, words_2000, words_5000, bonus_1,
  /// bonus_100, bonus_500, perfect_1, perfect_50, perfect_150,
  /// perfect_400, chapters_1, chapters_10, chapters_40, streak_3, streak_7,
  /// streak_30, streak_100, daily_1, daily_30, daily_100, friend_1,
  /// wheel_10, wheel_100, invite_1, invite_25, share_1
  static const Map<String, String> _playGamesIds = {
    // 'first_step': 'CgkIxxxxxxxxEAIQAQ',
    // 'levels_50' : 'CgkIxxxxxxxxEAIQAg',
  };

  /// المعرّف الداخلي → معرّف Game Center على iOS
  static const Map<String, String> _gameCenterIds = {};

  static bool _signedIn = false;
  static bool get isSignedIn => _signedIn;

  static bool get _supportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  /// تسجيل دخول صامت عند إقلاع التطبيق. لا يعرض أي واجهة إن فشل.
  static Future<void> signInSilently() async {
    if (!_supportedPlatform) return;
    try {
      if (await gs.GamesServices.isSignedIn) {
        _signedIn = true;
        return;
      }
      await gs.GamesServices.signIn();
      _signedIn = await gs.GamesServices.isSignedIn;
    } catch (e) {
      debugPrint('GamesServices: تعذّر تسجيل الدخول — $e');
      _signedIn = false;
    }
  }

  /// يرفع إنجازا مفتوحا إلى حساب اللاعب
  static Future<void> unlock(String achievementId) async {
    if (!_supportedPlatform || !_signedIn) return;
    final androidId = _playGamesIds[achievementId];
    final iosId = _gameCenterIds[achievementId];
    if (androidId == null && iosId == null) return; // لم يُربط بعد
    try {
      await gs.Achievements.unlock(
        achievement: gs.Achievement(
          // الحقلان غير قابلين للإفلات في الحزمة، وقيمتهما الافتراضية ""
          androidID: androidId ?? '',
          iOSID: iosId ?? '',
          percentComplete: 100,
        ),
      );
    } catch (e) {
      debugPrint('GamesServices: تعذّر رفع الإنجاز $achievementId — $e');
    }
  }

  /// يفتح واجهة الإنجازات الرسمية للمنصّة. يعيد false إن لم تكن متاحة
  /// كي تعرض الشاشة قائمتنا الداخلية بدلا منها.
  static Future<bool> showNativeAchievements() async {
    if (!_supportedPlatform || !_signedIn) return false;
    try {
      await gs.Achievements.showAchievements();
      return true;
    } catch (e) {
      debugPrint('GamesServices: تعذّر فتح واجهة الإنجازات — $e');
      return false;
    }
  }
}
