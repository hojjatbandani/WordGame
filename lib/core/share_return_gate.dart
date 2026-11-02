/// متى تُمنح مكافأة المشاركة. Dart صرف — بلا استيراد Flutter — كي
/// يُختبر القرار وحده بلا ورقة مشاركة ولا دورة حياة حقيقية.
///
/// القاعدة: تُمنح المكافأة حين *يعود* اللاعب إلى التطبيق بعد أن يغلق
/// ورقة المشاركة، لا حين تُفتح الورقة.
///
/// السبب مباشر: فتح الورقة حدث لا يكلّف شيئا ولا يخرج من التطبيق أصلا،
/// فمكافأته تعني ضغطة زر واحدة تُكرَّر إلى ما لا نهاية — «مشاركة» بلا
/// أي مشاركة. أما إغلاق الورقة بالإلغاء فيعني أن شيئا لم يُنشر، وهو ما
/// يقطعه [ShareSheetOutcome.dismissed] هنا نهائيا: لا تنتظر عودة، ولا
/// تُمنح مكافأة، مهما تكرّر.
library;

enum ShareSheetOutcome {
  /// اختار اللاعب تطبيقا فعلا (أو أبلغت المنصّة بنجاح)
  shared,

  /// أغلق الورقة دون اختيار — لا مكافأة
  dismissed,

  /// منصّة لا تُبلّغ بالنتيجة. نعطي الفائدة للاعب: تُعامَل كمشاركة،
  /// والسقف اليومي (مكافأتان) يبقى هو الحدّ الفعلي.
  unknown,
}

class ShareReturnGate {
  bool _awaitingReturn = false;

  /// شاركنا فعلا وننتظر عودة اللاعب إلى التطبيق
  bool get isAwaitingReturn => _awaitingReturn;

  /// تُستدعى فور إغلاق ورقة المشاركة. تعيد true إن استُحقّت المكافأة
  /// الآن — أي حين لم يغادر التطبيق أصلا (منصّة تشارك داخليا)، فلا عودة
  /// تُنتظر.
  bool onSheetClosed({
    required ShareSheetOutcome outcome,
    required bool appIsResumed,
  }) {
    if (outcome == ShareSheetOutcome.dismissed) {
      _awaitingReturn = false;
      return false;
    }
    _awaitingReturn = true;
    // التطبيق ما زال في المقدّمة: الورقة أُغلقت دون أن تنقلنا لتطبيق
    // آخر، فلا «عودة» ستقع لاحقا وننتظرها بلا نهاية
    return appIsResumed && _take();
  }

  /// تُستدعى عند كل عودة إلى المقدّمة. تعيد true مرة واحدة فقط لكل
  /// مشاركة: العلم يُطفأ قبل المنح، فتكرار حدث العودة لا يكرّر المكافأة.
  bool onAppResumed() => _take();

  bool _take() {
    if (!_awaitingReturn) return false;
    _awaitingReturn = false;
    return true;
  }

  /// إلغاء أي انتظار قائم (مغادرة الشاشة قبل العودة)
  void reset() => _awaitingReturn = false;
}
