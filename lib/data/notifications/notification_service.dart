import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_models.dart';

/// غلاف رقيق فوق flutter_local_notifications — لا قرار هنا، فقط تنفيذ
/// ما يقرّره NotificationEngine (منطق صرف، مختبَر بالكامل في
/// notification_engine_test.dart). لا يمكن اختبار الجدولة/الإطلاق
/// الفعليين آليا في هذه البيئة (يحتاجان جهازا حقيقيا أو محاكيا) — راجع
/// خطوات الاختبار اليدوي في ملخّص التسليم.
class NotificationService {
  /// رمز الإشعار الأحادي (drawable-*dpi/ic_stat_huruf.png، يولّده
  /// tool/generate_notification_icon.dart). منذ Android 5 يتجاهل النظام
  /// ألوان أيقونة الإشعار ويستعمل قناة الشفافية قناعا — فتمرير أيقونة
  /// التطبيق المعتمة (@mipmap/ic_launcher) كان يعطي مربّعا أبيض مصمتا
  /// بلا شكل، أي «إشعار بلا أيقونة».
  static const androidSmallIcon = 'ic_stat_huruf';

  /// أيقونة التطبيق الكاملة تظهر بجانب النصّ (الأيقونة الكبيرة) — الرمز
  /// الأحادي وحده صغير ورمادي في الشريط، وهذه تعيد هوية اللعبة الملوّنة
  static const _largeIcon = DrawableResourceAndroidBitmap(
    '@mipmap/ic_launcher',
  );

  /// HurufTheme.gold — يصبغ به النظام الرمز الأحادي واسم التطبيق
  static const _accent = Color(0xFFF4C430);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const androidInit = AndroidInitializationSettings(androidSmallIcon);
    // false في الثلاثة: القيم الافتراضية true تطلب الصلاحية داخل
    // initialize() نفسها، أي عند أول فتح للرئيسية — فتُفرَغ بوّابة
    // «لا تطلبها قبل الجلسة الثالثة» من معناها. الطلب يقع في
    // [requestPermission] وحدها، حين يقرّره NotificationEngine.
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  /// يعيد true إن مُنحت الصلاحية (أو لم تكن مطلوبة على هذه المنصّة)
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    final androidGranted = await android?.requestNotificationsPermission();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// يجدول تذكيرا عند الساعة [plan.hour] من يوم يبعد [plan.daysAhead]
  /// يوما عن اليوم. إن كان الموعد قد فات (يوم اليوم بعد ساعته) لا يفعل
  /// شيئا — يُعاد تقييم كل شيء عند فتح التطبيق التالي (راجع
  /// notification_engine.dart)
  Future<void> schedule({
    required ScheduledNotification plan,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    final target = DateTime(
      now.year,
      now.month,
      now.day + plan.daysAhead,
      plan.hour,
    );
    if (!target.isAfter(now)) return;

    await _plugin.zonedSchedule(
      plan.id,
      title,
      body,
      // الموعد يُبنى بتوقيت الجهاز ثم يُحوَّل: TZDateTime.from تحفظ
      // اللحظة نفسها. البناء المباشر tz.TZDateTime(tz.local, ...) خطأ
      // هنا — tz.local تبقى UTC ما لم تُضبط منطقة الجهاز صراحة (وهو ما
      // يحتاج تبعية إضافية لمعرفة اسمها)، فتُطلق التذكيرات بفارق ساعات
      // عن الساعة المقصودة لكل من ليس على توقيت غرينتش.
      tz.TZDateTime.from(target, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'huruf_daily_systems',
          // اسم القناة يظهر في إعدادات النظام لا داخل التطبيق، ولا
          // يتبع لغة اللعبة (القنوات تُنشأ مرة واحدة ويملكها النظام)،
          // فيحمل اللغتين معا بدل أن يظهر بلغة لا يقرأها صاحب الجهاز
          'تذكيرات حروف اليومية · Huruf daily reminders',
          importance: Importance.defaultImportance,
          icon: androidSmallIcon,
          largeIcon: _largeIcon,
          color: _accent,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // غير دقيق عن قصد: تذكير لعبة لا يحتاج دقّة الثانية، والوضع
      // الدقيق يستلزم SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM وGoogle Play
      // تحصرهما في تطبيقات المنبّهات والتقويم. النظام يطلقه في نافذة
      // قريبة من الموعد، وهذا كل المطلوب.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
