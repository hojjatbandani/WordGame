import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../data/social_models.dart';
import '../providers.dart';
import '../widgets/glass_card.dart';
import '../widgets/pressable.dart';
import 'friends_screen.dart';

/// لوحة الأصدقاء بثلاثة معايير. صفّ اللاعب نفسه يبقى ظاهرا دائما أسفل
/// الشاشة حتى لو كان ترتيبه بعيدا في القائمة
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(leaderboardMetricProvider);
    final scope = ref.watch(leaderboardScopeProvider);
    final boardAsync = ref.watch(leaderboardProvider);
    final lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: HurufTheme.bgTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(lang.t('لوحة الترتيب', 'Leaderboard')),
        actions: [
          IconButton(
            tooltip: lang.t('الأصدقاء', 'Friends'),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FriendsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // مبدّل النطاق: بين ربعك أو بين كل اللاعبين
            Padding(
              padding: const EdgeInsets.fromLTRB(HurufTheme.s3, HurufTheme.s3,
                  HurufTheme.s3, 0),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: HurufTheme.tileEmpty,
                  borderRadius: BorderRadius.circular(HurufTheme.rButton),
                ),
                child: Row(
                  children: [
                    for (final s in LeaderboardScope.values)
                      Expanded(
                        child: Pressable(
                          onTap: () => ref
                              .read(leaderboardScopeProvider.notifier)
                              .select(s),
                          semanticLabel: lang.t('عرض ${s.titleAr}',
                              'Show ${s.titleEn}'),
                          child: AnimatedContainer(
                            duration: HurufTheme.durFast,
                            padding: const EdgeInsets.symmetric(
                                vertical: HurufTheme.s2),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: s == scope
                                  ? HurufTheme.surface
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(HurufTheme.rButton),
                            ),
                            child: Text(
                              lang.t(s.titleAr, s.titleEn),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: s == scope
                                    ? HurufTheme.gold
                                    : HurufTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(HurufTheme.s3),
              child: Row(
                children: [
                  for (final m in LeaderboardMetric.values)
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 2),
                        child: _MetricTab(
                          metric: m,
                          selected: m == metric,
                          lang: lang,
                          onTap: () => ref
                              .read(leaderboardMetricProvider.notifier)
                              .select(m),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: boardAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: Text(
                    lang.t('ما قدرنا نحمّل اللوحة، حاول لاحقا',
                        'Couldn\'t load the leaderboard, try again later'),
                    style: const TextStyle(color: HurufTheme.textSecondary),
                  ),
                ),
                data: (entries) {
                  // رسالة «ما عندك أصدقاء» تخصّ نطاق الأصدقاء فقط —
                  // اللوحة العالمية تعرض الجميع ولا معنى لها فيها
                  if (scope == LeaderboardScope.friends &&
                      entries.length <= 1) {
                    return _buildEmpty(context, lang);
                  }
                  if (entries.isEmpty) {
                    return Center(
                      child: Text(
                        lang.t('ما فيه نتائج بعد', 'No results yet'),
                        style: const TextStyle(color: HurufTheme.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: HurufTheme.s4),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => _EntryTile(
                        entry: entries[i], metric: metric, lang: lang),
                  );
                },
              ),
            ),
            // صفّ ثابت للاعب نفسه كي لا يحتاج للبحث عن مكانه
            boardAsync.maybeWhen(
              data: (entries) {
                final me = entries.where((e) => e.isMe).firstOrNull;
                if (me == null || entries.length <= 1) {
                  return const SizedBox.shrink();
                }
                return Container(
                  padding: const EdgeInsets.all(HurufTheme.s3),
                  decoration: const BoxDecoration(
                    color: HurufTheme.surface,
                    border: Border(
                      top: BorderSide(color: Colors.white12),
                    ),
                  ),
                  child: _EntryTile(
                      entry: me, metric: metric, lang: lang, pinned: true),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, AppLanguage lang) {
    return Padding(
      padding: const EdgeInsets.all(HurufTheme.s5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.groups_rounded,
              size: 56, color: HurufTheme.textSecondary),
          const SizedBox(height: HurufTheme.s3),
          Text(
            lang.t('ما عندك أصدقاء بعد', 'You don\'t have any friends yet'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: HurufTheme.s2),
          Text(
            lang.t('شارك رمزك مع ربعك وشوفوا مين الأقوى',
                'Share your code with friends and see who\'s the best'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: HurufTheme.textSecondary),
          ),
          const SizedBox(height: HurufTheme.s4),
          Pressable(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FriendsScreen()),
            ),
            semanticLabel: lang.t('إضافة أصدقاء', 'Add friends'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: HurufTheme.s6, vertical: HurufTheme.s3),
              decoration: BoxDecoration(
                gradient: HurufTheme.goldGradient,
                borderRadius: BorderRadius.circular(HurufTheme.rButton),
              ),
              child: Text(
                lang.t('أضف أصدقاء', 'Add Friends'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: HurufTheme.bgTop,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTab extends StatelessWidget {
  final LeaderboardMetric metric;
  final bool selected;
  final AppLanguage lang;
  final VoidCallback onTap;

  const _MetricTab({
    required this.metric,
    required this.selected,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: lang.t(
          'ترتيب حسب ${metric.titleAr}', 'Rank by ${metric.titleEn}'),
      child: AnimatedContainer(
        duration: HurufTheme.durFast,
        padding: const EdgeInsets.symmetric(vertical: HurufTheme.s3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected ? HurufTheme.goldGradient : null,
          color: selected ? null : HurufTheme.tileEmpty,
          borderRadius: BorderRadius.circular(HurufTheme.rButton),
        ),
        child: Text(
          lang.t(metric.titleAr, metric.titleEn),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: selected ? HurufTheme.bgTop : HurufTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final LeaderboardMetric metric;
  final AppLanguage lang;
  final bool pinned;

  const _EntryTile({
    required this.entry,
    required this.metric,
    required this.lang,
    this.pinned = false,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = entry.isMe;
    return Padding(
      padding: EdgeInsets.only(bottom: pinned ? 0 : HurufTheme.s2),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
            horizontal: HurufTheme.s4, vertical: HurufTheme.s3),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '${entry.position}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: entry.position <= 3
                      ? HurufTheme.gold
                      : HurufTheme.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                highlight
                    ? lang.t('${entry.displayName} (أنت)',
                        '${entry.displayName} (You)')
                    : entry.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color:
                      highlight ? HurufTheme.gold : HurufTheme.textPrimary,
                ),
              ),
            ),
            Text(
              '${entry.value} ${lang.t(metric.unitAr, metric.unitEn)}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: HurufTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
