import 'package:supabase_flutter/supabase_flutter.dart';

import 'social_models.dart';
import 'supabase_config.dart';

/// وصول بيانات الأصدقاء واللوحة. كل الاستعلامات تمر بدوال RPC في Postgres
/// كي تبقى سياسات RLS ضيّقة (لا قراءة عامة لملفات اللاعبين)
class SocialRepository {
  bool get isAvailable => SupabaseConfig.isConfigured;

  SupabaseClient get _client => Supabase.instance.client;

  Future<PlayerProfile?> myProfile() async {
    if (!isAvailable) return null;
    final row = await _client.rpc('get_or_create_my_profile');
    if (row == null) return null;
    return PlayerProfile.fromRow(row as Map<String, dynamic>);
  }

  Future<void> syncScore(int score) async {
    if (!isAvailable) return;
    await _client.rpc('sync_my_score', params: {'new_score': score});
  }

  Future<AddFriendOutcome> addFriendByCode(String code) async {
    if (!isAvailable) return AddFriendOutcome.failed;
    try {
      final result = await _client.rpc('add_friend_by_code',
          params: {'code': code.trim().toUpperCase()});
      return AddFriendOutcome.fromCode(result as String?);
    } catch (_) {
      return AddFriendOutcome.failed;
    }
  }

  Future<List<FriendRequest>> pendingRequests() async {
    if (!isAvailable) return const [];
    final rows = await _client.rpc('my_pending_requests');
    return [
      for (final r in (rows as List? ?? []))
        FriendRequest.fromRow(r as Map<String, dynamic>),
    ];
  }

  /// قائمة الأصدقاء المقبولين بكل ما يعرضه صفّهم — استدعاء واحد يجلب
  /// الاسم والصورة والمستوى والسلسلة وترتيب تحدي اليوم معا
  Future<List<Friend>> friends() async {
    if (!isAvailable) return const [];
    try {
      final rows = await _client.rpc('my_friends');
      return [
        for (final r in (rows as List? ?? []))
          Friend.fromRow(r as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<int> friendCount() async {
    if (!isAvailable) return 0;
    try {
      final result = await _client.rpc('my_friend_count');
      return (result as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<RequestDecision> acceptRequest(int requestId) async {
    if (!isAvailable) return RequestDecision.failed;
    try {
      final result = await _client
          .rpc('accept_friend_request', params: {'request_id': requestId});
      return RequestDecision.fromCode(result as String?);
    } catch (_) {
      return RequestDecision.failed;
    }
  }

  /// الرفض يحذف الطلب ولا يُبلَّغ به المرسِل — راجع تعليق
  /// decline_friend_request في supabase/schema_social_v2.sql
  Future<RequestDecision> declineRequest(int requestId) async {
    if (!isAvailable) return RequestDecision.failed;
    try {
      final result = await _client
          .rpc('decline_friend_request', params: {'request_id': requestId});
      return RequestDecision.fromCode(result as String?);
    } catch (_) {
      return RequestDecision.failed;
    }
  }

  Future<bool> removeFriend(String friendId) async {
    if (!isAvailable) return false;
    try {
      final result =
          await _client.rpc('remove_friend', params: {'friend': friendId});
      return result == 'removed';
    } catch (_) {
      return false;
    }
  }

  Future<List<LeaderboardEntry>> leaderboard(
    LeaderboardMetric metric, {
    LeaderboardScope scope = LeaderboardScope.friends,
  }) async {
    if (!isAvailable) return const [];
    // النطاق العالمي أُزيل — راجع تعليق LeaderboardScope في social_models.dart
    final rows = switch (scope) {
      LeaderboardScope.friends =>
        await _client.rpc('friends_leaderboard', params: {'metric': metric.key}),
    };
    return [
      for (final r in (rows as List? ?? []))
        LeaderboardEntry.fromRow(r as Map<String, dynamic>),
    ];
  }

  Future<String?> setDisplayName(String name) async {
    if (!isAvailable) return null;
    try {
      final result =
          await _client.rpc('set_display_name', params: {'new_name': name});
      final value = result as String?;
      return value == 'empty' ? null : value;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────── الدعوات والمكافآت ───────────────────────

  /// [installId] يفرض به الخادم «استبدال واحد لكل تثبيت» — الفرادة على
  /// الحساب وحدها لا تكفي: مسح بيانات التطبيق ينشئ حسابا مجهولا جديدا
  Future<ReferralResult> redeemReferral(
    String code, {
    required String installId,
  }) async {
    if (!isAvailable) {
      return const ReferralResult(ReferralOutcome.failed, 0);
    }
    try {
      final rows = await _client.rpc('redeem_referral', params: {
        'code': code.trim().toUpperCase(),
        'p_install_id': installId,
      });
      final row = (rows as List?)?.firstOrNull as Map<String, dynamic>?;
      if (row == null) return const ReferralResult(ReferralOutcome.failed, 0);
      return ReferralResult(
        ReferralOutcome.fromCode(row['outcome'] as String?),
        (row['reward'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return const ReferralResult(ReferralOutcome.failed, 0);
    }
  }

  /// يستلم مكافآت الدعوات التي تراكمت أثناء غياب اللاعب
  Future<ClaimedRewards> claimPendingRewards() async {
    if (!isAvailable) return const ClaimedRewards(total: 0, count: 0);
    try {
      final rows = await _client.rpc('claim_pending_rewards');
      final row = (rows as List?)?.firstOrNull as Map<String, dynamic>?;
      if (row == null) return const ClaimedRewards(total: 0, count: 0);
      return ClaimedRewards(
        total: (row['total'] as num?)?.toInt() ?? 0,
        count: (row['count'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return const ClaimedRewards(total: 0, count: 0);
    }
  }

  /// عدد الدعوات *الناجحة* (التي بلغ مدعوّوها مستوى التأهيل ودُفع عنها)
  Future<int> referralCount() async {
    if (!isAvailable) return 0;
    try {
      final result = await _client.rpc('my_referral_count');
      return (result as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// حالة الدعوات كاملة: كم انضمّ، كم تأهّل، كم دُفع، وما السقف
  Future<ReferralStatus> referralStatus() async {
    if (!isAvailable) return const ReferralStatus.empty();
    try {
      final rows = await _client.rpc('my_referral_status');
      final row = (rows as List?)?.firstOrNull as Map<String, dynamic>?;
      if (row == null) return const ReferralStatus.empty();
      return ReferralStatus.fromRow(row);
    } catch (_) {
      return const ReferralStatus.empty();
    }
  }

  /// يستلم الزينات التي مُنحت لمراحل الدعوة (3 و5 و10) ويعيد معرّفاتها.
  /// تُعلَّم مستلَمة في الخادم فلا تُمنح مرتين.
  Future<List<String>> claimPendingCosmetics() async {
    if (!isAvailable) return const [];
    try {
      final rows = await _client.rpc('claim_pending_cosmetics');
      return [
        for (final r in (rows as List? ?? []))
          (r as Map<String, dynamic>)['cosmetic_id'] as String,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// يرفع XP التراكمية إلى الخادم. هذا هو المسار الذي يُشتق منه مستوى
  /// اللاعب في الخادم، وبالتالي المسار الذي يؤهّل دعوة *من دعاه* حين
  /// يبلغ المستوى الثالث (try_qualify_referral في schema_social_v2.sql).
  ///
  /// يُستدعى من مسار اللاعب نفسه فقط. الداعي لا يملك أي دالة تدفع له،
  /// ولا معاملا يمرّره — لذلك لا يجدي إنشاء حسابات وهمية: كل حساب يجب
  /// أن يلعب فعلا حتى المستوى الثالث قبل أن يُدفع عنه شيء.
  Future<void> syncXp(int xp) async {
    if (!isAvailable) return;
    try {
      await _client.rpc('sync_my_xp', params: {'new_xp': xp});
    } catch (_) {
      // مزامنة فاشلة تُعاد في الفتحة التالية — لا شيء يضيع
    }
  }
}
