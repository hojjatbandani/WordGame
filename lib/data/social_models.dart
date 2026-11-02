/// ملف اللاعب في السحابة. رمز الصديق (ثمانية محارف، دائم) هو العمود
/// الفقري للنظام كله: يعمل نصّا يُنسخ في أي محادثة، ويعمل رابطا عميقا
/// حين تسمح المنصّة — راجع lib/core/referral_link.dart
class PlayerProfile {
  final String userId;
  final String friendCode;
  final String displayName;
  final int totalScore;
  final String avatarId;

  const PlayerProfile({
    required this.userId,
    required this.friendCode,
    required this.displayName,
    required this.totalScore,
    this.avatarId = 'a1',
  });

  factory PlayerProfile.fromRow(Map<String, dynamic> row) => PlayerProfile(
        userId: row['user_id'] as String,
        friendCode: row['friend_code'] as String,
        displayName: row['display_name'] as String? ?? 'لاعب',
        totalScore: row['total_score'] as int? ?? 0,
        avatarId: row['avatar_id'] as String? ?? 'a1',
      );
}

/// صديق مقبول، بكل ما يعرضه صفّه في القائمة: الاسم والصورة والمستوى
/// والسلسلة وترتيب تحدي اليوم — استدعاء واحد لا خمسة.
class Friend {
  final String userId;
  final String displayName;
  final String friendCode;
  final String avatarId;
  final int level;
  final int streak;

  /// نتيجة تحدي اليوم؛ 0 إن لم يلعب بعد
  final int todayScore;

  /// ترتيبه في تحدي اليوم *داخل دائرة أصدقائي*، أو null إن لم يلعب اليوم
  final int? todayRank;

  /// حجم الدائرة التي حُسب فيها [todayRank] (أنا + أصدقائي)
  final int circleSize;

  const Friend({
    required this.userId,
    required this.displayName,
    required this.friendCode,
    required this.avatarId,
    required this.level,
    required this.streak,
    required this.todayScore,
    required this.todayRank,
    required this.circleSize,
  });

  bool get playedToday => todayRank != null;

  factory Friend.fromRow(Map<String, dynamic> row) => Friend(
        userId: row['friend_id'] as String,
        displayName: row['display_name'] as String? ?? 'لاعب',
        friendCode: row['friend_code'] as String? ?? '--------',
        avatarId: row['avatar_id'] as String? ?? 'a1',
        level: (row['player_level'] as num?)?.toInt() ?? 1,
        streak: (row['current_streak'] as num?)?.toInt() ?? 0,
        todayScore: (row['today_score'] as num?)?.toInt() ?? 0,
        todayRank: (row['today_rank'] as num?)?.toInt(),
        circleSize: (row['circle_size'] as num?)?.toInt() ?? 1,
      );
}

/// معيار ترتيب لوحة الأصدقاء
enum LeaderboardMetric {
  streak('streak', 'السلسلة', 'يوم', 'Streak', 'day'),
  weekly('weekly', 'كلمات الأسبوع', 'كلمة', 'Weekly Words', 'word'),
  score('score', 'المجموع', 'نقطة', 'Total', 'point');

  final String key;
  final String titleAr;
  final String unitAr;
  final String titleEn;
  final String unitEn;

  const LeaderboardMetric(
      this.key, this.titleAr, this.unitAr, this.titleEn, this.unitEn);
}

class LeaderboardEntry {
  final String playerId;
  final String displayName;
  final String friendCode;
  final int value;
  final int position;
  final bool isMe;

  const LeaderboardEntry({
    required this.playerId,
    required this.displayName,
    required this.friendCode,
    required this.value,
    required this.position,
    required this.isMe,
  });

  factory LeaderboardEntry.fromRow(Map<String, dynamic> row) =>
      LeaderboardEntry(
        playerId: row['player_id'] as String,
        displayName: row['display_name'] as String? ?? 'لاعب',
        friendCode: row['friend_code'] as String? ?? '------',
        value: (row['metric_value'] as num?)?.toInt() ?? 0,
        position: (row['place'] as num?)?.toInt() ?? 0,
        isMe: row['is_me'] as bool? ?? false,
      );
}

class FriendRequest {
  final int id;
  final String fromId;
  final String fromName;
  final String fromCode;
  final String fromAvatarId;
  final int fromLevel;

  const FriendRequest({
    required this.id,
    required this.fromId,
    required this.fromName,
    required this.fromCode,
    this.fromAvatarId = 'a1',
    this.fromLevel = 1,
  });

  factory FriendRequest.fromRow(Map<String, dynamic> row) => FriendRequest(
        id: (row['friendship_id'] as num).toInt(),
        fromId: row['from_id'] as String? ?? '',
        fromName: row['from_name'] as String? ?? 'لاعب',
        fromCode: row['from_code'] as String? ?? '--------',
        fromAvatarId: row['from_avatar'] as String? ?? 'a1',
        fromLevel: (row['from_level'] as num?)?.toInt() ?? 1,
      );
}

/// حصيلة قرار على طلب صداقة وارد
enum RequestDecision {
  accepted('صرتوا أصدقاء! 🎉', 'You\'re friends now! 🎉'),
  declined('', ''),
  full('قائمتك ممتلئة', 'Your friend list is full'),
  targetFull('قائمة صديقك ممتلئة', 'Their friend list is full'),
  gone('هذا الطلب ما عاد موجودا', 'That request is no longer there'),
  failed('ما ضبطت، حاول مرة ثانية', 'Something went wrong, try again');

  final String messageAr;
  final String messageEn;
  const RequestDecision(this.messageAr, this.messageEn);

  static RequestDecision fromCode(String? code) => switch (code) {
        'accepted' => RequestDecision.accepted,
        'declined' => RequestDecision.declined,
        'full' => RequestDecision.full,
        'target_full' => RequestDecision.targetFull,
        'not_found' => RequestDecision.gone,
        _ => RequestDecision.failed,
      };
}

/// نطاق لوحة الترتيب. النطاق العالمي أُزيل عمدا: لوحة عالمية تعني أن
/// 90% من اللاعبين لن يدخلوا المئة الأولى أبدا فيتوقفون عن النظر إليها،
/// وبقيت لوحة الأصدقاء وحدها: دائرة صغيرة ذات معنى شخصي، لا ترتيبا
/// بين مئة ألف غريب.
enum LeaderboardScope {
  friends('أصدقائي', 'Friends');

  final String titleAr;
  final String titleEn;
  const LeaderboardScope(this.titleAr, this.titleEn);
}

/// نتيجة استبدال رمز دعوة
enum ReferralOutcome {
  ok('', ''),
  alreadyRedeemed(
      'استخدمت رمز دعوة من قبل', 'You\'ve already used an invite code'),
  // «هذا الجهاز» لا «هذا الحساب»: الخادم يرفض بمعرّف التثبيت، فإعادة
  // التثبيت أو مسح البيانات لا تفتح استبدالا جديدا
  installUsed('استُخدم رمز دعوة على هذا الجهاز من قبل',
      'An invite code was already used on this device'),
  notFound('ما لقينا هذا الرمز، تأكد منه', 'Code not found, double-check it'),
  self('ما تقدر تدعو نفسك 🙂', 'You can\'t invite yourself 🙂'),
  tooLate('الدعوة للاعبين الجدد بس', 'Invites are for new players only'),
  capReached('صاحب الرمز وصل حدّ دعواته', 'That code has reached its limit'),
  failed('ما ضبطت، حاول مرة ثانية', 'Something went wrong, try again');

  final String messageAr;
  final String messageEn;
  const ReferralOutcome(this.messageAr, this.messageEn);

  static ReferralOutcome fromCode(String? code) => switch (code) {
        'ok' => ReferralOutcome.ok,
        'already_redeemed' => ReferralOutcome.alreadyRedeemed,
        'install_used' => ReferralOutcome.installUsed,
        'not_found' => ReferralOutcome.notFound,
        'self' => ReferralOutcome.self,
        'too_late' => ReferralOutcome.tooLate,
        'cap_reached' => ReferralOutcome.capReached,
        _ => ReferralOutcome.failed,
      };
}

class ReferralResult {
  final ReferralOutcome outcome;
  final int reward;

  const ReferralResult(this.outcome, this.reward);
}

/// حالة دعوات اللاعب كما يراها الخادم.
///
/// [invited] كل من أدخل رمزي، و[paid] من بلغ منهم مستوى التأهيل فدُفع
/// لي عنه فعلا. الفرق بينهما ليس تفصيلا تقنيا نخفيه: عرضه صراحة
/// («٣ انضموا، ١ منهم وصل المستوى ٣») هو ما يجعل التأخير مفهوما بدل أن
/// يبدو عطلا في المكافأة.
class ReferralStatus {
  final int invited;
  final int qualified;
  final int paid;
  final int cap;
  final int qualifyLevel;

  const ReferralStatus({
    required this.invited,
    required this.qualified,
    required this.paid,
    required this.cap,
    required this.qualifyLevel,
  });

  const ReferralStatus.empty()
      : invited = 0,
        qualified = 0,
        paid = 0,
        cap = 20,
        qualifyLevel = 3;

  /// من أدخل الرمز ولم يبلغ مستوى التأهيل بعد
  int get pending => (invited - qualified).clamp(0, invited);

  bool get atCap => paid >= cap;

  /// العتبة التالية لمكافأة زخرفية، أو null إن نالها كلها
  int? nextMilestone(Iterable<int> milestones) {
    for (final m in milestones.toList()..sort()) {
      if (paid < m) return m;
    }
    return null;
  }

  factory ReferralStatus.fromRow(Map<String, dynamic> row) => ReferralStatus(
        invited: (row['invited'] as num?)?.toInt() ?? 0,
        qualified: (row['qualified'] as num?)?.toInt() ?? 0,
        paid: (row['paid'] as num?)?.toInt() ?? 0,
        cap: (row['cap'] as num?)?.toInt() ?? 20,
        qualifyLevel: (row['qualify_level'] as num?)?.toInt() ?? 3,
      );
}

/// مكافآت جُمعت للاعب بينما كان التطبيق مغلقا (دعوات قبلها أصدقاؤه)
class ClaimedRewards {
  final int total;
  final int count;

  const ClaimedRewards({required this.total, required this.count});

  bool get isEmpty => total <= 0;
}

/// نتيجة محاولة إضافة صديق — نصوصها خليجية ودّية وتُعرض كما هي
enum AddFriendOutcome {
  sent('أرسلنا طلبك، بانتظار قبوله', 'Request sent, waiting for acceptance'),
  accepted('صرتوا أصدقاء! 🎉', 'You\'re friends now! 🎉'),
  exists('أنتم أصدقاء من قبل', 'You\'re already friends'),
  pending('طلبك عنده من قبل، ينتظر رده',
      'You already sent them a request, waiting on them'),
  notFound('ما لقينا هذا الرمز، تأكد منه', 'Code not found, double-check it'),
  self('هذا رمزك أنت 🙂', 'That\'s your own code 🙂'),
  full('قائمتك ممتلئة', 'Your friend list is full'),
  targetFull('قائمة صديقك ممتلئة', 'Their friend list is full'),
  failed('ما ضبطت، حاول مرة ثانية', 'Something went wrong, try again');

  final String messageAr;
  final String messageEn;
  const AddFriendOutcome(this.messageAr, this.messageEn);

  /// الصداقة اكتملت فعلا الآن — لا مجرد طلب أُرسل. الإنجازات والعدّادات
  /// لا تُحرَّك إلا على هذه.
  bool get isNewFriendship => this == AddFriendOutcome.accepted;

  static AddFriendOutcome fromCode(String? code) => switch (code) {
        'sent' => AddFriendOutcome.sent,
        'accepted' => AddFriendOutcome.accepted,
        'exists' => AddFriendOutcome.exists,
        'pending' => AddFriendOutcome.pending,
        'not_found' => AddFriendOutcome.notFound,
        'self' => AddFriendOutcome.self,
        'full' => AddFriendOutcome.full,
        'target_full' => AddFriendOutcome.targetFull,
        _ => AddFriendOutcome.failed,
      };
}
