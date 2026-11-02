// مكافأة تفعيل الودجة — منطق صرف.
//
// تُمنح **مرة واحدة لكل تثبيت للتطبيق**، ولا تُمنح ثانية بأي من هذه:
// إزالة الودجة وإعادتها، إضافة أكثر من نسخة، تغيير الحجم، إعادة تشغيل
// الجهاز، أو إعادة إضافة الودجة بعد حذفها.
//
// كيف يُضمن ذلك: القرار لا يقرأ «كم ودجة موجودة» ولا «متى أُضيفت»، بل
// علَما واحدا في تخزين *التطبيق* ([alreadyRewarded]) يُرفع عند أول منح
// ولا يُخفَض أبدا — ولا حتى عند «البدء من جديد» (راجع
// ProgressStore._preservedOnReset). الجانب الأصلي لا يستطيع خفضه لأنه
// لا يكتب إلا مفتاح «توجد ودجة الآن».
//
// الحالة الوحيدة التي تُعيد المنح هي مسح بيانات التطبيق أو إعادة
// تثبيته — وهي حالة تمسح الرصيد والتقدّم كلّه معها، فلا ربح فيها.

class WidgetActivation {
  const WidgetActivation._();

  /// [widgetInstalled] يأتي من الجانب الأصلي (`huruf_widget_installed`)،
  /// و[alreadyRewarded] من تخزين التطبيق.
  static bool shouldGrant({
    required bool widgetInstalled,
    required bool alreadyRewarded,
  }) => widgetInstalled && !alreadyRewarded;

  /// سبب الكسب كما يُسجَّل في التحليلات والاقتصاد
  static const earnReason = 'widget_activation';
}
