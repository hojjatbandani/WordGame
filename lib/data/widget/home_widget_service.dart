import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'widget_data.dart';

/// غلاف رقيق فوق حزمة `home_widget` — لا قرار هنا، فقط نقل لقطة جاهزة
/// إلى التخزين المشترك ثم إيقاظ الودجة كي تعيد رسم نفسها.
///
/// القرار كله في [WidgetDataBuilder] (منطق صرف مختبَر)، والمطالبة
/// بالجوائز تبقى في التطبيق وحده — الودجة لا تكتب شيئا يقرأه التطبيق
/// عن الاقتصاد، والمفتاح الوحيد الذي تكتبه هي [installedKey] وهو إشارة
/// وجود لا حالة لعب.
///
/// كل استدعاء محروس: منصّة بلا ودجات (سطح المكتب، بيئة الاختبار) أو
/// إضافة لم تُسجَّل تجعل الدالة تفشل بصمت بدل أن تُسقط الإقلاع — نفس نمط
/// games_services_sync.dart وsyncNotifications.
class HomeWidgetService {
  /// مجموعة التطبيقات على iOS: الطريق الوحيد لمشاركة `UserDefaults` بين
  /// التطبيق والإضافة. يجب أن تطابق حرفيا ما في
  /// `ios/Runner/Runner.entitlements` و`ios/HurufWidget/HurufWidget.entitlements`.
  static const appGroupId = 'group.com.huruf.huruf.widget';

  /// اسم مزوّد الودجة على أندرويد (الصنف الكامل) واسم النوع على iOS
  static const androidProvider = 'com.huruf.huruf.HurufWidgetProvider';
  static const iOSWidgetName = 'HurufWidget';

  /// مفتاح اللقطة الكاملة (JSON) — راجع [HomeWidgetData.encode]
  static const dataKey = 'huruf_widget_data';

  /// يكتبه الجانب الأصلي وحده: `true` ما دامت هناك نسخة ودجة واحدة على
  /// الأقل على الشاشة. مصدر «هل فُعِّلت الودجة؟» لمكافأة التفعيل.
  static const installedKey = 'huruf_widget_installed';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      _initialized = true;
    } catch (e) {
      debugPrint('الودجة: تعذّر ضبط مجموعة التطبيقات — $e');
    }
  }

  /// يكتب اللقطة ثم يوقظ الودجة. لا يرمي أبدا.
  Future<void> push(HomeWidgetData data) async {
    try {
      await init();
      await HomeWidget.saveWidgetData<String>(dataKey, data.encode());
      await HomeWidget.updateWidget(
        qualifiedAndroidName: androidProvider,
        iOSName: iOSWidgetName,
      );
    } catch (e) {
      debugPrint('الودجة: تعذّر تحديثها — $e');
    }
  }

  /// هل توجد نسخة ودجة واحدة على الأقل على شاشة اللاعب الآن؟
  Future<bool> isInstalled() async {
    try {
      await init();
      return await HomeWidget.getWidgetData<bool>(
            installedKey,
            defaultValue: false,
          ) ??
          false;
    } catch (e) {
      debugPrint('الودجة: تعذّرت قراءة حالة التثبيت — $e');
      return false;
    }
  }

  /// الرابط الذي أُطلق منه التطبيق إن كان الإطلاق من الودجة (بدء بارد)
  Future<Uri?> initialLaunchUri() async {
    try {
      await init();
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      debugPrint('الودجة: تعذّرت قراءة رابط الإطلاق — $e');
      return null;
    }
  }

  /// نقرات الودجة بينما التطبيق يعمل (بدء دافئ)
  Stream<Uri?> get clicks {
    try {
      return HomeWidget.widgetClicked;
    } catch (e) {
      debugPrint('الودجة: تعذّر الاشتراك في النقرات — $e');
      return const Stream.empty();
    }
  }
}
