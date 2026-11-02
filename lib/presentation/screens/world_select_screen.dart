import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_language.dart';
import '../../core/theme.dart';
import '../../data/analytics/analytics_event.dart';
import '../../data/progression/map_view_model.dart';
import '../../data/world_models.dart';
import '../progression_text.dart';
import '../providers.dart';
import '../widgets/near_reward_banner.dart';
import '../widgets/pressable.dart';
import '../widgets/video_animation.dart';
import 'chapter_select_screen.dart';

/// اشتقاق لون مميّز لكل عالم من colorSeed وحده — لا فنّ فعليا مرسوما لهذه
/// الهويات الجديدة بعد (bidaya/waha/..)، فبدل الإشارة لملفات صور غير
/// موجودة (وتعطّل التطبيق) نستخدم تدرّج لوني حتمي كبديل مؤقت واضح.
Color worldSeedColor(int colorSeed) {
  final hue = (colorSeed * 47) % 360;
  return HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.45).toColor();
}

/// L1: اختيار العالم — المستوى الأول من ثلاثة. الثمانية عوالم كلها ظاهرة
/// دوما من أول تشغيل (اختبار قبول 1)، المقفلة منها معتّمة لكن مقروءة
/// بالكامل: الاسم، ظل الفنّ، ظل الشخصية، معاينة المكافأة، وشرط الفتح
/// الدقيق — لا لوح فارغ أبدا.
class WorldSelectScreen extends ConsumerWidget {
  const WorldSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final snapshot = ref.watch(progressionProvider);
    final structure = ref.watch(progressionStructureProvider);

    final cards = MapViewModel.buildWorldCards(
      state: snapshot.state,
      progress: snapshot.stageProgress,
      structure: structure,
    );

    return Scaffold(
      backgroundColor: HurufTheme.bgTop,
      body: SafeArea(
        child: Column(
          children: [
            _Header(lang: lang),
            const NearRewardBanner(),
            // عمود واحد لا عمودان: البطاقة العريضة تحمل صورة مرشد أكبر
            // ونصّا أكبر، وثمانية عوالم في عمود تبدو رحلة أطول مما تبدو
            // في شبكة تحشرها في أربعة صفوف. وارتفاع البطاقة مضبوط عمدا
            // (_kWorldCardHeight) كي يظهر جزء واضح من العالم التالي أسفل
            // الطيّة، فيُعرف أن القائمة تكمل بلا تجربة.
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(HurufTheme.s4),
                itemCount: cards.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: HurufTheme.s3),
                itemBuilder: (context, i) =>
                    _WorldCard(card: cards[i], lang: lang),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppLanguage lang;
  const _Header({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HurufTheme.s3,
        HurufTheme.s3,
        HurufTheme.s3,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: lang.t('رجوع', 'Back'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: HurufTheme.textSecondary,
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              lang.t('العوالم', 'Worlds'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

/// ارتفاع بطاقة العالم. الرقم مقصود لا اعتباطي: على أقصر شاشة ندعمها
/// (~640 نقطة منطقية) يبقى بعد الترويسة ولافتة المكافأة ~530 نقطة، أي
/// ثلاث بطاقات ونصف — فالرابعة تُقتطع ظاهرة، وهي الإشارة الوحيدة التي
/// تخبر اللاعب أن تحته المزيد. لو كبر الرقم حتى تدخل ثلاث بالضبط بدت
/// القائمة منتهية.
const double _kWorldCardHeight = 144;

/// صورة المرشد داخل البطاقة — أكبر مما كانت في الشبكة (88 حدّا أقصى)
/// لأن العمود الواحد أعطى عرضا لم يكن موجودا
const double _kGuidePortraitSize = 104;

class _WorldCard extends ConsumerWidget {
  final WorldCardViewData card;
  final AppLanguage lang;

  const _WorldCard({required this.card, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = worldSeedColor(card.colorSeed);
    final name = worldName(card.nameKey, lang);
    // الهوية البصرية للعالم: صورة الخلفية وشخصية المرشد
    final visuals = worldVisualsById(card.worldId);

    return Pressable(
      onTap: () {
        if (card.isUnlocked) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChapterSelectScreen(worldId: card.worldId),
            ),
          );
        } else {
          // «ما الذي يحجز اللاعبين» سؤال يُجاب بحقيقة لا بانطباع:
          // البوّابة الوحيدة الآن هي إتمام العالم السابق
          final c = card.unlockCondition;
          ref.logEvent(Ev.worldGateBlocked, {
            'world_id': card.worldId,
            'previous_world_incomplete':
                c != null && !c.requiredWorldLastChapterComplete,
          });
          _showLockedSheet(context, card, lang);
        }
      },
      semanticLabel: card.isUnlocked
          ? name
          : lang.t('$name، مقفل', '$name, locked'),
      child: Opacity(
        opacity: card.isUnlocked ? 1 : 0.55,
        child: Container(
          height: _kWorldCardHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HurufTheme.rCard),
            color: HurufTheme.surface,
          ),
          // الحدّ في foregroundDecoration لا في decoration: الأخيرة
          // تُرسم *تحت* الطفل، وصورة العالم تملأ البطاقة حتى حافة
          // القصّ فتبتلع الحدّ عند الزوايا المستديرة تحديدا. هنا
          // يُرسم فوق كل شيء فيظهر خطا واحدا متصلا على الدوران كله.
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HurufTheme.rCard),
            border: Border.all(
              color: card.isUnlocked ? color : HurufTheme.textSecondary,
              width: 1.5,
            ),
          ),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              // صورة العالم الحقيقية خلف البطاقة — العوالم المقفلة
              // بتدرّج رمادي كي يبقى «ما وراء القفل» ملمَّحا لا مكشوفا
              // cacheWidth: البطاقة صارت بعرض الشاشة كاملة (~360 نقطة) بعد
              // التحوّل لعمود واحد، فرفعناها من 540. وفكّ ثماني صور 1024×1024
              // كاملة لشبكة العوالم كان يعني ~32 ميغابايت من الصور النقطية
              Positioned.fill(
                child: card.isUnlocked
                    ? Image.asset(
                        visuals.background,
                        fit: BoxFit.cover,
                        cacheWidth: 720,
                      )
                    : ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
                        child: Image.asset(
                          visuals.background,
                          fit: BoxFit.cover,
                          cacheWidth: 720,
                        ),
                      ),
              ),
              // تعتيم يضمن قراءة الاسم والوصف فوق الصورة.
              //
              // أفقي لا رأسي بعد التحوّل إلى عمود واحد: النص صار بجانب
              // الصورة لا تحتها. وبالاتجاه المنطقي (start/end) لا
              // (left/right) كي ينقلب مع اللغة — الجهة الشفّافة تلاحق
              // صورة المرشد والجهة المعتمة تلاحق النص في العربية
              // والإنجليزية معا.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        color.withValues(alpha: card.isUnlocked ? 0.30 : 0.12),
                        HurufTheme.surface.withValues(alpha: 0.80),
                        HurufTheme.surface.withValues(alpha: 0.95),
                      ],
                      stops: const [0, 0.46, 1],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(HurufTheme.s3),
                child: Row(
                  children: [
                    // شخصية مرشد العالم — صورتها الحقيقية من
                    // assets/characters/. قياس ثابت الآن لا نسبة من عرض
                    // البطاقة: البطاقة تملأ عرض الشاشة، فنسبةٌ منها تعني
                    // صورة عملاقة على اللوحيّ وصغيرة على الهاتف.
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CharacterPortrait(
                          characterId: visuals.guideId,
                          size: _kGuidePortraitSize,
                        ),
                        if (!card.isUnlocked)
                          PositionedDirectional(
                            bottom: 2,
                            end: 2,
                            child: Icon(
                              Icons.lock_rounded,
                              size: _kGuidePortraitSize * .24,
                              color: HurufTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: HurufTheme.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            worldSubtitle(card.themeId, lang),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.25,
                              color: HurufTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: HurufTheme.s2),
                          Row(
                            children: [
                              const Text('🏆', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 4),
                              Text(
                                '+${card.completionRewardCoins}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: HurufTheme.gold,
                                ),
                              ),
                            ],
                          ),
                          if (!card.isUnlocked) ...[
                            const SizedBox(height: 3),
                            Text(
                              worldUnlockConditionText(
                                card.unlockCondition!,
                                _nameKeyForWorldId(
                                  card.unlockCondition!.requiredWorldId,
                                ),
                                lang,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: HurufTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: HurufTheme.textSecondary.withValues(alpha: 0.7),
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

/// يُستخدم فقط لتركيب نص شرط الفتح ("أكمل عالم «X»") من
/// [WorldUnlockConditionData.requiredWorldId] (معرّف عالم حقيقي 1-based
/// دوما) — قصير العمر، لا يستحق تمرير ProgressionStructure كاملة عبر
/// الودجة لأجل اسم واحد. نفس ترتيب الهوية الثابت في
/// world_defs.dart._identities بالضبط.
const _worldNameKeys = [
  'bidaya',
  'waha',
  'souq',
  'madina',
  'diwan',
  'khaleej',
  'hikma',
  'ustura',
];
String _nameKeyForWorldId(int worldId) => _worldNameKeys[worldId - 1];

void _showLockedSheet(
  BuildContext context,
  WorldCardViewData card,
  AppLanguage lang,
) {
  final condition = card.unlockCondition!;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: HurufTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(HurufTheme.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 40, color: HurufTheme.gold),
            const SizedBox(height: HurufTheme.s3),
            Text(
              lang.t(
                '${worldName(card.nameKey, lang)} مقفل بعد',
                '${worldName(card.nameKey, lang)} is still locked',
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: HurufTheme.s3),
            // الشرط الدقيق — لا "مقفل" عامة مبهمة (اختبار قبول 3)
            _ConditionRow(
              done: condition.requiredWorldLastChapterComplete,
              text: lang.t(
                'أكمل عالم «${worldName(_nameKeyForWorldId(condition.requiredWorldId), lang)}»',
                'Finish "${worldName(_nameKeyForWorldId(condition.requiredWorldId), lang)}"',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ConditionRow extends StatelessWidget {
  final bool done;
  final String text;
  const _ConditionRow({required this.done, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: done ? HurufTheme.success : HurufTheme.textSecondary,
          size: 20,
        ),
        const SizedBox(width: HurufTheme.s2),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: done ? HurufTheme.success : HurufTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
