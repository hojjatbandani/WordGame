// حدث اقتصادي واحد — كل تغيير في المحفظة عبر EconomyService يصدر واحدا
// من هذه، بلا استثناء ("لا تغييرات صامتة"). هذا الملف لا يبني ناقل
// التحليلات الفعلي (Prompt 11 — لم يُبنَ بعد)؛ [EconomyEventSink] هو
// نقطة الحقن التي تستدعيها EconomyService، ونقطة الربط الفعلية بناقل
// تحليلات حقيقي مهمة لاحقة. الافتراضي [noopEconomyEventSink] لا يفعل
// شيئا، فلا يفرض هذا الملف أي تبعية على شيء غير موجود بعد.

enum EconomyEventKind { earn, spendSucceeded, spendFailed }

class EconomyEvent {
  final EconomyEventKind kind;
  final int amount;
  final Object reason; // EarnReason أو SpendReason حسب kind
  final int balanceAfter;
  final String? failureMessage;

  const EconomyEvent._({
    required this.kind,
    required this.amount,
    required this.reason,
    required this.balanceAfter,
    this.failureMessage,
  });

  factory EconomyEvent.earned({
    required int amount,
    required Object reason,
    required int balanceAfter,
  }) =>
      EconomyEvent._(
        kind: EconomyEventKind.earn,
        amount: amount,
        reason: reason,
        balanceAfter: balanceAfter,
      );

  factory EconomyEvent.spendSucceeded({
    required int amount,
    required Object reason,
    required int balanceAfter,
  }) =>
      EconomyEvent._(
        kind: EconomyEventKind.spendSucceeded,
        amount: amount,
        reason: reason,
        balanceAfter: balanceAfter,
      );

  factory EconomyEvent.spendFailed({
    required int amount,
    required Object reason,
    required int balanceBefore,
    required String message,
  }) =>
      EconomyEvent._(
        kind: EconomyEventKind.spendFailed,
        amount: amount,
        reason: reason,
        balanceAfter: balanceBefore, // لم يتغيّر — الإنفاق فشل
        failureMessage: message,
      );
}

typedef EconomyEventSink = void Function(EconomyEvent event);

void noopEconomyEventSink(EconomyEvent event) {}
