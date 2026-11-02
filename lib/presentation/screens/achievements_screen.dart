import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../data/achievement_models.dart';
import '../../data/games_services_sync.dart';
import '../providers.dart';
import '../widgets/glass_card.dart';
import '../widgets/pressable.dart';

/// شاشة الإنجازات: كل الإنجازات مرتّبة بالفئات، مع شريط تقدّم لكل واحد
/// حتى غير المفتوح — كي يعرف اللاعب كم بقي له.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(achievementsProvider);
    final lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: HurufTheme.bgTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(lang.t('الإنجازات', 'Achievements')),
        actions: [
          if (GamesServicesSync.isSignedIn)
            IconButton(
              tooltip: lang.t('إنجازات Google Play', 'Google Play Achievements'),
              icon: const Icon(Icons.sports_esports_rounded),
              onPressed: () => GamesServicesSync.showNativeAchievements(),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HurufTheme.s4),
          children: [
            _SummaryCard(state: state, lang: lang),
            const SizedBox(height: HurufTheme.s5),
            // الفئات المعطّلة لا تُعرض — راجع AchievementCategory.isEnabled
            for (final category
                in AchievementCategory.values.where((c) => c.isEnabled)) ...[
              _CategoryHeader(category: category, state: state, lang: lang),
              const SizedBox(height: HurufTheme.s3),
              for (final a in achievementsIn(category))
                _AchievementTile(achievement: a, state: state, lang: lang),
              const SizedBox(height: HurufTheme.s5),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AchievementsState state;
  final AppLanguage lang;

  const _SummaryCard({required this.state, required this.lang});

  @override
  Widget build(BuildContext context) {
    final progress = state.totalCount == 0
        ? 0.0
        : state.unlockedCount / state.totalCount;
    return GlassCard(
      padding: const EdgeInsets.all(HurufTheme.s5),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 40)),
          const SizedBox(height: HurufTheme.s2),
          Text(
            lang.t('${state.unlockedCount} من ${state.totalCount}',
                '${state.unlockedCount} of ${state.totalCount}'),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: HurufTheme.gold,
            ),
          ),
          Text(
            lang.t('إنجازا مفتوحا', 'achievements unlocked'),
            style: const TextStyle(color: HurufTheme.textSecondary),
          ),
          const SizedBox(height: HurufTheme.s4),
          ClipRRect(
            borderRadius: BorderRadius.circular(HurufTheme.rButton),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: HurufTheme.tileEmpty,
              valueColor:
                  const AlwaysStoppedAnimation(HurufTheme.gold),
            ),
          ),
          if (!GamesServicesSync.isSignedIn) ...[
            const SizedBox(height: HurufTheme.s3),
            Text(
              lang.t('سجّل دخولك في Google Play كي تبقى إنجازاتك محفوظة',
                  'Sign in to Google Play to keep your achievements saved'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: HurufTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final AchievementCategory category;
  final AchievementsState state;
  final AppLanguage lang;

  const _CategoryHeader(
      {required this.category, required this.state, required this.lang});

  @override
  Widget build(BuildContext context) {
    final list = achievementsIn(category);
    final done = list.where((a) => state.isUnlocked(a.id)).length;
    return Row(
      children: [
        Text(category.emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: HurufTheme.s2),
        Expanded(
          child: Text(
            lang.t(category.titleAr, category.titleEn),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: HurufTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: HurufTheme.s2),
        // اتجاه صريح: الشرطة بين رقمين داخل فقرة عربية تقلب ترتيبهما
        // بصريا، فيقرأ اللاعب «9 / 5» بدل «5 / 9»
        Text(
          '$done / ${list.length}',
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: HurufTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  final AchievementsState state;
  final AppLanguage lang;

  const _AchievementTile(
      {required this.achievement, required this.state, required this.lang});

  @override
  Widget build(BuildContext context) {
    final unlocked = state.isUnlocked(achievement.id);
    final value = state.valueOf(achievement.stat);
    final progress = achievement.progressFor(value);
    final tierColor = Color(achievement.tier.color);
    final title = lang.t(achievement.titleAr, achievement.titleEn);

    return Padding(
      padding: const EdgeInsets.only(bottom: HurufTheme.s2),
      child: Semantics(
        label: unlocked
            ? lang.t('$title، مفتوح', '$title, unlocked')
            : lang.t('$title، $value من ${achievement.target}',
                '$title, $value of ${achievement.target}'),
        child: Container(
          padding: const EdgeInsets.all(HurufTheme.s3),
          decoration: BoxDecoration(
            color: HurufTheme.surface,
            borderRadius: BorderRadius.circular(HurufTheme.rCard),
            border: Border.all(
              color: unlocked
                  ? tierColor.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              // الشارة تبقى رمادية باهتة قبل الفتح كي يظهر الفرق فورا
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked
                      ? tierColor.withValues(alpha: 0.18)
                      : HurufTheme.tileEmpty,
                  border: Border.all(
                    color: unlocked
                        ? tierColor.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: unlocked
                    ? Text(achievement.emoji,
                        style: const TextStyle(fontSize: 24))
                    : const Icon(Icons.lock_rounded,
                        size: 20, color: HurufTheme.textSecondary),
              ),
              const SizedBox(width: HurufTheme.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      // سطران للعنوان: بعض العناوين طويلة («فاتح المدينة
                      // الذهبية»)، وسطر واحد كان يقصّها فلا تُقرأ. الشارة
                      // تُحاذى أعلى السطر الأول لا منتصف السطرين.
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: unlocked
                                  ? HurufTheme.textPrimary
                                  : HurufTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: HurufTheme.s2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            lang.t(achievement.tier.titleAr,
                                achievement.tier.titleEn),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: tierColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      lang.t(
                          achievement.descriptionAr, achievement.descriptionEn),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: HurufTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: HurufTheme.s2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: HurufTheme.tileEmpty,
                        valueColor: AlwaysStoppedAnimation(
                          unlocked ? tierColor : HurufTheme.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: HurufTheme.s3),
              // عرض ثابت وتصغير عند الحاجة: «12345/50000» أعرض بكثير من
              // «3/5»، وبلا حدّ كان يدفع العمود الأوسط خارج البطاقة
              SizedBox(
                width: 56,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        unlocked
                            ? '✓'
                            : '${value.clamp(0, achievement.target)}/${achievement.target}',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: unlocked ? 18 : 11,
                          fontWeight: FontWeight.w800,
                          color:
                              unlocked ? tierColor : HurufTheme.textSecondary,
                        ),
                      ),
                    ),
                    // الأسطوري بلا عملات — نعرض «زخرفي» بدل «+0»، وإلا
                    // بدا الإنجاز الأصعب في اللعبة أقلّها مكافأة
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        achievement.reward > 0
                            ? '+${achievement.reward}'
                            : lang.t('زخرفي', 'Cosmetic'),
                        style: TextStyle(
                          fontSize: 10,
                          color: achievement.reward > 0
                              ? HurufTheme.gold
                              : tierColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// زر مدمج يفتح شاشة الإنجازات — يُستخدم في الصفحة الرئيسية
class AchievementsEntryTile extends ConsumerWidget {
  const AchievementsEntryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(achievementsProvider);
    final lang = ref.watch(languageProvider);
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AchievementsScreen()),
      ),
      semanticLabel: lang.t(
          'الإنجازات، ${state.unlockedCount} من ${state.totalCount}',
          'Achievements, ${state.unlockedCount} of ${state.totalCount}'),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: HurufTheme.s3, vertical: HurufTheme.s3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color(0xFFF4C430), Color(0xFF8A6A10)],
          ),
          borderRadius: BorderRadius.circular(HurufTheme.rCard),
          boxShadow: [
            BoxShadow(
              color: HurufTheme.gold.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏅', style: TextStyle(fontSize: 20)),
              const SizedBox(width: HurufTheme.s2),
              Flexible(
                child: Text(
                  lang.t('الإنجازات ${state.unlockedCount}/${state.totalCount}',
                      'Achievements ${state.unlockedCount}/${state.totalCount}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: lang.textDirection,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: HurufTheme.bgTop,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
