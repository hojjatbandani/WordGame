import 'package:shared_preferences/shared_preferences.dart';

/// تخزين التقدم محليا (يستبدل لاحقا بمزامنة سحابية)
class ProgressStore {
  static const _kPoints = 'points';
  static const _kMaxUnlocked = 'max_unlocked';
  static const _kBonusJar = 'bonus_jar';
  static const _kDailyLastClaim = 'daily_last_claim';
  static const _kDailyStreakDay = 'daily_streak_day';
  static const _kAdDate = 'ad_date';
  static const _kAdCount = 'ad_count';

  final SharedPreferences prefs;

  ProgressStore(this.prefs);

  static Future<ProgressStore> create() async =>
      ProgressStore(await SharedPreferences.getInstance());

  int get points => prefs.getInt(_kPoints) ?? 100;
  int get maxUnlocked => prefs.getInt(_kMaxUnlocked) ?? 1;
  int get bonusJar => prefs.getInt(_kBonusJar) ?? 0;
  String? get dailyLastClaim => prefs.getString(_kDailyLastClaim);
  int get dailyStreakDay => prefs.getInt(_kDailyStreakDay) ?? 0;
  String? get adDate => prefs.getString(_kAdDate);
  int get adCount => prefs.getInt(_kAdCount) ?? 0;

  Future<void> setPoints(int value) => prefs.setInt(_kPoints, value);
  Future<void> setMaxUnlocked(int value) => prefs.setInt(_kMaxUnlocked, value);
  Future<void> setBonusJar(int value) => prefs.setInt(_kBonusJar, value);
  Future<void> setDailyLastClaim(String value) =>
      prefs.setString(_kDailyLastClaim, value);
  Future<void> setDailyStreakDay(int value) =>
      prefs.setInt(_kDailyStreakDay, value);
  Future<void> setAdDate(String value) => prefs.setString(_kAdDate, value);
  Future<void> setAdCount(int value) => prefs.setInt(_kAdCount, value);
}
