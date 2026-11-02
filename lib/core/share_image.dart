import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// تحويل ودجة معروضة فعلا إلى PNG.
///
/// نلتقط حدّ إعادة الرسم (RepaintBoundary) لبطاقة *مرئية على الشاشة* لا
/// بطاقة تُبنى خارج الشجرة. سببان:
///
///  1) الالتقاط خارج الشجرة (PipelineOwner/BuildOwner يدويا) يعتمد على
///     تفاصيل داخلية في محرّك Flutter تتغيّر بين الإصدارات، ويفشل بصمت
///     حين تتغيّر — فتخرج صورة سوداء لا خطأ.
///  2) الأهم: اللاعب يرى بالضبط ما سيُنشر قبل أن ينشره. الشرط الحاسم في
///     هذه الميزة أن لا تكشف الصورة أي كلمة، ومعاينة مرئية تجعل ذلك
///     قابلا للفحص بالعين لا مجرد وعد في الكود.
///
/// البطاقة تُعرض مصغَّرة داخل FittedBox بينما يبقى حدّ إعادة الرسم بحجمه
/// المنطقي الكامل، فيخرج PNG بدقّة كاملة مهما صغر العرض على الشاشة.
class ShareImage {
  const ShareImage._();

  /// دقّة الالتقاط: ثلاثة أضعاف الحجم المنطقي — يكفي لعرض حادّ في
  /// إنستغرام وواتساب دون أن يتضخّم الملف فوق حدود المشاركة
  static const pixelRatio = 3.0;

  /// يعيد بايتات PNG، أو null إن تعذّر الالتقاط (البطاقة لم تُرسم بعد،
  /// أو المفتاح لا يشير إلى حدّ إعادة رسم). لا يرمي أبدا: فشل الصورة
  /// يجب أن يسقط على مشاركة نصّية، لا أن يُفشل المشاركة كلها.
  static Future<Uint8List?> capture(GlobalKey boundaryKey) async {
    try {
      final object = boundaryKey.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary) return null;

      // إطار لم يكتمل رسمه بعد يعطي صورة قديمة أو فارغة
      if (object.debugNeedsPaint) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      final image = await object.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (e) {
      debugPrint('صورة المشاركة: تعذّر الالتقاط — $e');
      return null;
    }
  }

  /// يكتب الصورة في ملف مؤقّت ويعيد مساره. ورقة المشاركة على أندرويد
  /// تحتاج ملفا حقيقيا لا بايتات في الذاكرة.
  static Future<String?> writeTempPng(Uint8List bytes, String name) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$name.png');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('صورة المشاركة: تعذّرت الكتابة — $e');
      return null;
    }
  }
}
