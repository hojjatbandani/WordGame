/// حالة سلسلة الأيام المتتالية — محلية بالكامل، بلا أي اعتماد على
/// الشبكة. راجع streak_engine.dart للمنطق الذي يبني/يحدّث هذه الحالة.
class StreakState {
  final int currentStreak;

  /// أطول سلسلة بلغها اللاعب على الإطلاق — لا تنقص أبدا حتى لو انكسرت
  /// السلسلة الحالية. هذا ما يُغذّي StatKey.bestStreak والإنجازات.
  final int longestStreak;

  final int freezesHeld;

  /// كم "معلَم يوم-7" (7، 14، 21..) مُنح تجميدا تلقائيا بالفعل — يُقاس من
  /// [longestStreak] لا [currentStreak] كي لا يُعاد نفس المنح بعد كسر
  /// السلسلة ثم بنائها من جديد حتى نفس الطول
  final int freezeMilestonesGranted;

  /// آخر يوم تقويمي محلي (yyyy-MM-dd) "مؤمَّن" فعلا — بنشاط حقيقي أو
  /// بتجميد تلقائي. null يعني لم تبدأ أي سلسلة بعد.
  final String? securedThroughDateKey;

  /// عدد التجميدات المستهلكة تلقائيا منذ آخر مرة عُرضت فيها رسالة "استُهلك
  /// تجميد" وأُخذت (takePendingFreezeNotice) — راجع الشرح في streak_engine.dart
  final int pendingFreezeNoticeCount;

  const StreakState({
    required this.currentStreak,
    required this.longestStreak,
    required this.freezesHeld,
    required this.freezeMilestonesGranted,
    required this.securedThroughDateKey,
    required this.pendingFreezeNoticeCount,
  });

  factory StreakState.initial() => const StreakState(
        currentStreak: 0,
        longestStreak: 0,
        freezesHeld: 0,
        freezeMilestonesGranted: 0,
        securedThroughDateKey: null,
        pendingFreezeNoticeCount: 0,
      );

  StreakState copyWith({
    int? currentStreak,
    int? longestStreak,
    int? freezesHeld,
    int? freezeMilestonesGranted,
    String? securedThroughDateKey,
    bool clearSecuredThroughDateKey = false,
    int? pendingFreezeNoticeCount,
  }) =>
      StreakState(
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        freezesHeld: freezesHeld ?? this.freezesHeld,
        freezeMilestonesGranted:
            freezeMilestonesGranted ?? this.freezeMilestonesGranted,
        securedThroughDateKey: clearSecuredThroughDateKey
            ? null
            : (securedThroughDateKey ?? this.securedThroughDateKey),
        pendingFreezeNoticeCount:
            pendingFreezeNoticeCount ?? this.pendingFreezeNoticeCount,
      );

  Map<String, dynamic> toJson() => {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'freezesHeld': freezesHeld,
        'freezeMilestonesGranted': freezeMilestonesGranted,
        'securedThroughDateKey': securedThroughDateKey,
        'pendingFreezeNoticeCount': pendingFreezeNoticeCount,
      };

  factory StreakState.fromJson(Map<String, dynamic> json) => StreakState(
        currentStreak: json['currentStreak'] as int,
        longestStreak: json['longestStreak'] as int,
        freezesHeld: json['freezesHeld'] as int,
        freezeMilestonesGranted: json['freezeMilestonesGranted'] as int? ?? 0,
        securedThroughDateKey: json['securedThroughDateKey'] as String?,
        pendingFreezeNoticeCount: json['pendingFreezeNoticeCount'] as int? ?? 0,
      );
}
