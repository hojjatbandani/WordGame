import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/referral_link.dart';
import '../../core/share_templates.dart';
import '../../core/theme.dart';

/// البطاقة التي تُصوَّر وتُشارَك كـ PNG.
///
/// عقدها هو عقد ShareTemplates نفسه بالضبط: لا تقبل نصّ كلمة إطلاقا،
/// وأقرب ما تعرفه عن الكلمة هو [ShareWordStatus] — مربّع ملوّن بلا
/// محتوى. لا توجد هنا حالة ولا مزوّدون: كل ما تعرضه يصل عبر المعاملات،
/// كي تُبنى في اختبار ودجة وتُفحص صورتها بلا بيئة تشغيل كاملة.
///
/// حجمها منطقي ثابت ([width]×ارتفاع محسوب) لا يتبع حجم الشاشة: الصورة
/// المنشورة يجب أن تخرج بالمقاس نفسه من كل جهاز، وحدّ إعادة الرسم
/// يلتقط الحجم المنطقي مهما صُغِّر العرض في الواجهة.
class ShareCard extends StatelessWidget {
  static const double width = 340;

  final String title;
  final DateTime date;
  final List<ShareWordStatus> words;
  final int score;
  final int? rank;
  final int totalPlayers;
  final int streak;
  final String? inviteCode;
  final AppLanguage lang;

  const ShareCard({
    super.key,
    required this.title,
    required this.date,
    required this.words,
    required this.score,
    required this.streak,
    required this.lang,
    this.rank,
    this.totalPlayers = 0,
    this.inviteCode,
  });

  int get _solved => words.where((w) => w != ShareWordStatus.missed).length;

  @override
  Widget build(BuildContext context) {
    final rankText = ShareTemplates.rankLine(
        rank: rank, totalPlayers: totalPlayers, lang: lang);

    return Directionality(
      textDirection: lang.textDirection,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(HurufTheme.s5),
        decoration: const BoxDecoration(
          gradient: HurufTheme.bgGradient,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: HurufTheme.gold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: HurufTheme.s1),
            Text(
              ShareTemplates.formatDate(date),
              style: const TextStyle(
                fontSize: 12,
                color: HurufTheme.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: HurufTheme.s4),
            _Grid(words: words),
            const SizedBox(height: HurufTheme.s4),
            _StatRow(
              label: lang.t('الكلمات', 'Words'),
              value: '$_solved/${words.length}',
            ),
            _StatRow(
              label: lang.t('النتيجة', 'Score'),
              value: '$score',
              highlight: true,
            ),
            if (rankText != null)
              _StatRow(
                label: lang.t('الترتيب', 'Rank'),
                value: '$rank / $totalPlayers',
              ),
            if (streak >= 2)
              _StatRow(
                label: lang.t('السلسلة', 'Streak'),
                value: lang.t('🔥 $streak يوم', '🔥 $streak days'),
              ),
            const SizedBox(height: HurufTheme.s4),
            const Divider(color: HurufTheme.tileEmpty, height: 1),
            const SizedBox(height: HurufTheme.s3),
            _Footer(inviteCode: inviteCode, lang: lang),
          ],
        ),
      ),
    );
  }
}

/// شبكة المربّعات — السطر الوحيد الذي يقول شيئا عن اللغز، ولا يقول منه
/// إلا اللون. الالتفاف تلقائي كي تصلح لأي عدد كلمات.
class _Grid extends StatelessWidget {
  final List<ShareWordStatus> words;

  const _Grid({required this.words});

  static const _size = 34.0;

  Color _colorFor(ShareWordStatus s) => switch (s) {
        ShareWordStatus.solved => HurufTheme.success,
        ShareWordStatus.hinted => HurufTheme.gold,
        ShareWordStatus.missed => HurufTheme.tileEmpty,
      };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: HurufTheme.s2,
      runSpacing: HurufTheme.s2,
      children: [
        for (final w in words)
          Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: _colorFor(w),
              borderRadius: BorderRadius.circular(HurufTheme.rTile),
              border: w == ShareWordStatus.missed
                  ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                  : null,
            ),
          ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HurufTheme.s1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 13, color: HurufTheme.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 20 : 15,
              fontWeight: FontWeight.w900,
              color: highlight ? HurufTheme.gold : HurufTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// تذييل البطاقة: اسم اللعبة ورمز الدعوة إن كان اللاعب مؤهّلا له.
/// الرابط مكتوب نصّا لا رمز QR: الصورة تُعاد مشاركتها ولقطتها تُقصّ،
/// ونصّ قصير يبقى مقروءا في كل الحالات.
class _Footer extends StatelessWidget {
  final String? inviteCode;
  final AppLanguage lang;

  const _Footer({required this.inviteCode, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          lang.t(ShareTemplates.appName, ShareTemplates.appNameEn),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: HurufTheme.textPrimary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: HurufTheme.s1),
        Text(
          ReferralLink.domain,
          style: const TextStyle(
              fontSize: 11, color: HurufTheme.textSecondary, letterSpacing: 1),
        ),
        if (inviteCode != null) ...[
          const SizedBox(height: HurufTheme.s3),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: HurufTheme.s4, vertical: HurufTheme.s2),
            decoration: BoxDecoration(
              color: HurufTheme.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(HurufTheme.rButton),
              border: Border.all(color: HurufTheme.gold.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Text(
                  lang.t('رمز الدعوة', 'Invite code'),
                  style: const TextStyle(
                      fontSize: 10, color: HurufTheme.textSecondary),
                ),
                Text(
                  inviteCode!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: HurufTheme.gold,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
