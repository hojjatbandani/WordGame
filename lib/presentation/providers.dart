import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/iap_service.dart';
import '../data/level_repository.dart';
import '../data/models.dart';
import '../data/progress_store.dart';

/// يُستبدل بقيمة حقيقية في main قبل تشغيل التطبيق
final progressStoreProvider = Provider<ProgressStore>(
  (ref) => throw UnimplementedError('overridden in main'),
);

final levelRepositoryProvider = Provider((ref) => LevelRepository());

final levelsProvider = FutureProvider<List<GameLevel>>(
  (ref) => ref.watch(levelRepositoryProvider).loadLevels(),
);

class PointsNotifier extends Notifier<int> {
  @override
  int build() => ref.read(progressStoreProvider).points;

  void add(int amount) {
    state += amount;
    ref.read(progressStoreProvider).setPoints(state);
  }

  /// يخصم النقاط إن كان الرصيد كافيا، ويعيد نجاح العملية
  bool spend(int amount) {
    if (state < amount) return false;
    state -= amount;
    ref.read(progressStoreProvider).setPoints(state);
    return true;
  }
}

final pointsProvider = NotifierProvider<PointsNotifier, int>(PointsNotifier.new);

class MaxUnlockedNotifier extends Notifier<int> {
  @override
  int build() => ref.read(progressStoreProvider).maxUnlocked;

  void unlockUpTo(int levelId) {
    if (levelId <= state) return;
    state = levelId;
    ref.read(progressStoreProvider).setMaxUnlocked(state);
  }
}

final maxUnlockedProvider =
    NotifierProvider<MaxUnlockedNotifier, int>(MaxUnlockedNotifier.new);

class BonusJarNotifier extends Notifier<int> {
  @override
  int build() => ref.read(progressStoreProvider).bonusJar;

  void add(int count) {
    state += count;
    ref.read(progressStoreProvider).setBonusJar(state);
  }
}

final bonusJarProvider =
    NotifierProvider<BonusJarNotifier, int>(BonusJarNotifier.new);

final iapServiceProvider = Provider<IapService>((ref) => MockIapService());

/// مكافآت الأيام السبعة — اليوم السابع هو الكبرى
const dailyRewards = [20, 30, 40, 50, 60, 80, 200];

class DailyRewardState {
  final bool canClaim;

  /// اليوم الذي سيحصل عليه اللاعب عند المطالبة (1..7)
  final int nextDay;

  const DailyRewardState({required this.canClaim, required this.nextDay});

  int get nextReward => dailyRewards[nextDay - 1];
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class DailyRewardNotifier extends Notifier<DailyRewardState> {
  @override
  DailyRewardState build() {
    final store = ref.read(progressStoreProvider);
    final now = DateTime.now();
    final today = _dateKey(now);
    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
    final last = store.dailyLastClaim;

    if (last == today) {
      return DailyRewardState(
        canClaim: false,
        nextDay: (store.dailyStreakDay % 7) + 1,
      );
    }
    // استمرار السلسلة إن لعب أمس، وإلا تبدأ من اليوم الأول
    final nextDay = last == yesterday ? (store.dailyStreakDay % 7) + 1 : 1;
    return DailyRewardState(canClaim: true, nextDay: nextDay);
  }

  /// يعيد قيمة المكافأة الممنوحة، أو null إن لم تكن متاحة
  int? claim() {
    if (!state.canClaim) return null;
    final store = ref.read(progressStoreProvider);
    final reward = state.nextReward;
    store.setDailyLastClaim(_dateKey(DateTime.now()));
    store.setDailyStreakDay(state.nextDay);
    ref.read(pointsProvider.notifier).add(reward);
    state = DailyRewardState(
      canClaim: false,
      nextDay: (state.nextDay % 7) + 1,
    );
    return reward;
  }
}

final dailyRewardProvider =
    NotifierProvider<DailyRewardNotifier, DailyRewardState>(
        DailyRewardNotifier.new);

/// إعلانات المكافأة: 30 نقطة، بحد أقصى 5 مرات يوميا
class AdRewardNotifier extends Notifier<int> {
  static const maxPerDay = 5;
  static const reward = 30;

  @override
  int build() {
    final store = ref.read(progressStoreProvider);
    return store.adDate == _dateKey(DateTime.now()) ? store.adCount : 0;
  }

  int get remaining => maxPerDay - state;

  /// يستدعى بعد اكتمال مشاهدة الإعلان
  int? grantReward() {
    if (state >= maxPerDay) return null;
    final store = ref.read(progressStoreProvider);
    state = state + 1;
    store.setAdDate(_dateKey(DateTime.now()));
    store.setAdCount(state);
    ref.read(pointsProvider.notifier).add(reward);
    return reward;
  }
}

final adRewardProvider =
    NotifierProvider<AdRewardNotifier, int>(AdRewardNotifier.new);
