// دفتر الإعلانات الجائزية: ميزانية يومية واحدة مشتركة، مكافأة متصاعدة،
// ومنح يقع *مرة واحدة بالضبط* لكل مشاهدة مهما تكرّر نداء الشبكة.
//
// Dart صرف — بلا Flutter وبلا تخزين. الحالة كائن قابل للتسلسل
// ([RewardedLedger]) يقرأه ويكتبه المستدعي، تماما كبقية منطق الصرف في
// المشروع (progression_engine، streak_engine).
//
// لماذا دفتر لا عدّاد: شبكات الإعلانات تنادي onUserEarnedReward أكثر من
// مرة للمشاهدة نفسها (إعادة محاولة، استئناف بعد تصغير التطبيق، تعارض
// نداءين)، وقد تتأخّر النداءة إلى ما بعد إغلاق التطبيق. عدّاد بسيط يمنح
// مرتين في الأولى ولا يمنح شيئا في الثانية. الدفتر يحلّ الحالتين بشيء
// واحد: معرّف لكل طلب، ومنح مقيَّد بذلك المعرّف.

import 'dart:convert';

import '../../config/balance_config.dart';

/// السطح الذي طُلب منه الإعلان — للتحليلات، ولاختيار طول الإعلان
/// ([AdFormats.forSurface] في ad_format.dart).
///
/// [levelReward] و[chapterChest] سطحان منفصلان لا `other` واحد: مضاعفة
/// جائزة المرحلة إعلان قصير ومضاعفة صندوق الفصل إعلان طويل، والفرق لا
/// يُقال إلا بسطحين.
///
/// إضافة قيمة هنا آمنة على المحفوظات: الدفتر يفكّ السطح المجهول إلى
/// [other] بدل أن يسقط ([PendingRewardGrant.fromJson]).
enum RewardedSurface {
  /// عجلة الحظ — دورة إضافية
  wheel,

  /// وضع الأمان (لم يُوصل بعد)
  safetyMode,

  /// شحن العملات: المتجر وورقة «ينقصك القليل»
  coinTopUp,

  /// مضاعفة جائزة إتمام مرحلة
  levelReward,

  /// مضاعفة صندوق نهاية الفصل
  chapterChest,

  other,
}

/// منحة اكتملت مشاهدتها ولم تُضَف بعد إلى المحفظة
class PendingRewardGrant {
  final String requestId;
  final int amount;
  final RewardedSurface surface;
  final DateTime completedAt;

  const PendingRewardGrant({
    required this.requestId,
    required this.amount,
    required this.surface,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': requestId,
    'amount': amount,
    'surface': surface.name,
    'at': completedAt.toIso8601String(),
  };

  factory PendingRewardGrant.fromJson(Map<String, dynamic> json) =>
      PendingRewardGrant(
        requestId: json['id'] as String,
        amount: json['amount'] as int,
        surface: _surfaceFromName(json['surface'] as String?),
        completedAt: DateTime.parse(json['at'] as String),
      );

  /// اسم سطح غير معروف يصير [RewardedSurface.other] لا استثناء.
  ///
  /// `byName` كانت ترمي على اسم مجهول، والاستثناء يُلتقط أعلى في
  /// [RewardedLedger.decode] فيُمسح الدفتر كلّه: منحة مستحقّة تضيع،
  /// وميزانية اليوم تُصفَّر معها. اسم مجهول يقع فعلا حين يُعاد اسم سطح
  /// أو يُحذف بين إصدارين والطابور محفوظ من الإصدار السابق. السطح بيان
  /// تحليلي؛ فقدانه أرخص من فقدان المنحة.
  static RewardedSurface _surfaceFromName(String? name) {
    if (name == null) return RewardedSurface.other;
    for (final surface in RewardedSurface.values) {
      if (surface.name == name) return surface;
    }
    return RewardedSurface.other;
  }
}

/// طلب مشاهدة: يحمل المبلغ *قبل* بدء الإعلان. عرض المبلغ مسبقا ليس
/// تجميلا — هو ما يجعل المشاهدة قرارا لا مقامرة، وهو شرط بقاء التصاعد
/// مفهوما (من يرى أن التالية 40 يعود إليها).
class RewardedAdRequest {
  final String id;
  final int quotedAmount;
  final RewardedSurface surface;
  final int viewNumber;

  const RewardedAdRequest({
    required this.id,
    required this.quotedAmount,
    required this.surface,
    required this.viewNumber,
  });
}

class RewardedLedger {
  /// اليوم التقويمي الذي تخصّه [viewsUsed] (yyyy-MM-dd)
  final String date;

  /// مشاهدات اكتملت اليوم — تُستهلك عند الاكتمال لا عند الطلب، فإعلان
  /// ألغاه اللاعب لا يحرق ميزانيته
  final int viewsUsed;

  /// معرّفات مُنح عنها فعلا، الأحدث آخرا. هذه هي الحارس الوحيد ضد
  /// النداء المكرّر.
  ///
  /// قائمة مرتّبة لا مجموعة، ومقصوصة بـ[maxGrantedHistory] لا مُصفّرة
  /// مع اليوم: نداء مكرّر متأخّر قد يصل بعد منتصف الليل (أو بعد إعادة
  /// تشغيل التطبيق)، ومسح السجلّ مع تغيّر اليوم كان سيمنح عنه مرة ثانية.
  /// القصّ يبقي الأحدث، وسعة 100 تغطّي أسابيع بميزانية أربع مشاهدات.
  final List<String> grantedRequestIds;

  /// اكتملت ولم تُضَف بعد (تُطبَّق عند أول فرصة، حتى بعد إعادة تشغيل)
  final List<PendingRewardGrant> queue;

  static const maxGrantedHistory = 100;

  const RewardedLedger({
    required this.date,
    required this.viewsUsed,
    required this.grantedRequestIds,
    required this.queue,
  });

  factory RewardedLedger.empty(String date) => RewardedLedger(
    date: date,
    viewsUsed: 0,
    grantedRequestIds: const [],
    queue: const [],
  );

  bool hasGranted(String requestId) => grantedRequestIds.contains(requestId);

  RewardedLedger copyWith({
    String? date,
    int? viewsUsed,
    List<String>? grantedRequestIds,
    List<PendingRewardGrant>? queue,
  }) => RewardedLedger(
    date: date ?? this.date,
    viewsUsed: viewsUsed ?? this.viewsUsed,
    grantedRequestIds: grantedRequestIds ?? this.grantedRequestIds,
    queue: queue ?? this.queue,
  );

  /// يضيف معرّفا مع الإبقاء على الأحدث فقط
  List<String> _withGranted(String id) {
    final next = [...grantedRequestIds, id];
    if (next.length <= maxGrantedHistory) return next;
    return next.sublist(next.length - maxGrantedHistory);
  }

  int get remaining => (BalanceConfig.rewardedDailyBudget - viewsUsed).clamp(
    0,
    BalanceConfig.rewardedDailyBudget,
  );

  bool get hasRemaining => remaining > 0;

  /// مكافأة المشاهدة التالية — تُعرض قبل بدء الإعلان
  int get nextReward => BalanceConfig.rewardedRewardForView(viewsUsed + 1);

  String encode() => jsonEncode({
    'date': date,
    'viewsUsed': viewsUsed,
    'granted': grantedRequestIds,
    'queue': [for (final g in queue) g.toJson()],
  });

  static RewardedLedger decode(String? raw, String todayKey) {
    if (raw == null || raw.isEmpty) return RewardedLedger.empty(todayKey);
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return RewardedLedger(
        date: json['date'] as String? ?? todayKey,
        viewsUsed: json['viewsUsed'] as int? ?? 0,
        grantedRequestIds: (json['granted'] as List? ?? const [])
            .cast<String>()
            .toList(),
        queue: [
          for (final g in (json['queue'] as List? ?? const []))
            PendingRewardGrant.fromJson(g as Map<String, dynamic>),
        ],
      );
    } catch (_) {
      // دفتر تالف لا يجوز أن يمنع اللعب — نبدأ يوما نظيفا
      return RewardedLedger.empty(todayKey);
    }
  }
}

/// نتيجة تطبيق طابور المنح: كم عملة تُضاف، وما الدفتر بعدها
class RewardedFlush {
  final int coins;
  final List<PendingRewardGrant> applied;
  final RewardedLedger ledger;

  const RewardedFlush({
    required this.coins,
    required this.applied,
    required this.ledger,
  });

  bool get isEmpty => coins <= 0;
}

class RewardedAds {
  const RewardedAds._();

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// يدوّر الدفتر إلى يوم جديد إن لزم: الميزانية وحدها تُصفَّر.
  ///
  /// لا الطابور ولا سجلّ المعرّفات يُمسحان مع اليوم. الطابور لأن مشاهدة
  /// اكتملت أمس ولم تُضَف بعد ما زالت مستحقّة، والسجلّ لأن نداء مكرّرا
  /// متأخّرا قد يصل بعد منتصف الليل فيُمنح عنه مرة ثانية — وحدّ السجلّ
  /// هو القصّ لا التاريخ ([RewardedLedger.maxGrantedHistory]).
  static RewardedLedger rollOver(RewardedLedger ledger, DateTime now) {
    final today = dateKey(now);
    if (ledger.date == today) return ledger;
    return ledger.copyWith(date: today, viewsUsed: 0);
  }

  /// يبدأ طلب مشاهدة. يعيد null إن نفدت الميزانية أو أُطفئ المفتاح —
  /// عندها لا يُعرض الزر أصلا في الواجهة.
  ///
  /// [amount] مبلغ ثابت بدل سلّم المكافأة (بطاقة المتجر).
  static RewardedAdRequest? beginRequest({
    required RewardedLedger ledger,
    required RewardedSurface surface,
    required String requestId,
    bool rewardedEnabled = true,
    int? amount,
  }) {
    if (!rewardedEnabled || !ledger.hasRemaining) return null;
    return RewardedAdRequest(
      id: requestId,
      quotedAmount: amount ?? ledger.nextReward,
      surface: surface,
      viewNumber: ledger.viewsUsed + 1,
    );
  }

  /// اكتملت المشاهدة. يُدخل المنحة الطابور *مرة واحدة* لهذا المعرّف
  /// مهما تكرّر النداء، ويستهلك وحدة من الميزانية معها.
  ///
  /// المبلغ المدفوع هو المبلغ المعروض وقت الطلب ([RewardedAdRequest.quotedAmount])
  /// لا ما يقوله السلّم لحظة الاكتمال: ما وُعد به اللاعب هو ما يُدفع.
  static RewardedLedger onAdCompleted({
    required RewardedLedger ledger,
    required RewardedAdRequest request,
    required DateTime now,
  }) {
    final rolled = rollOver(ledger, now);
    if (rolled.hasGranted(request.id)) {
      return rolled; // نداء مكرّر — لا منح ولا استهلاك ميزانية
    }
    return rolled.copyWith(
      viewsUsed: rolled.viewsUsed + 1,
      grantedRequestIds: rolled._withGranted(request.id),
      queue: [
        ...rolled.queue,
        PendingRewardGrant(
          requestId: request.id,
          amount: request.quotedAmount,
          surface: request.surface,
          completedAt: now,
        ),
      ],
    );
  }

  /// يفرّغ الطابور: يعيد مجموع ما يجب إضافته للمحفظة والدفتر بعد
  /// التفريغ. يُستدعى فور الاكتمال وأيضا عند كل إقلاع (المصالحة) —
  /// المنحة التي لم تصل نداءتها قبل إغلاق التطبيق تصل هنا.
  static RewardedFlush flushQueue(RewardedLedger ledger) {
    if (ledger.queue.isEmpty) {
      return RewardedFlush(coins: 0, applied: const [], ledger: ledger);
    }
    final total = ledger.queue.fold<int>(0, (sum, g) => sum + g.amount);
    return RewardedFlush(
      coins: total,
      applied: List.unmodifiable(ledger.queue),
      ledger: ledger.copyWith(queue: const []),
    );
  }
}
