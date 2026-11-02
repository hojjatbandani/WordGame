// جمل المرشد على الخريطة — بيانات ومنطق اختيار صرف، بلا Flutter وبلا
// عشوائية داخلية: [Random] يُمرَّر من الخارج فيبقى الاختيار قابلا
// للاختبار الحتمي.

import 'dart:math';

/// نصيحة واحدة بلغتيها. لا تُترجَم وقت التشغيل — كل جملة مكتوبة بلغتها
/// لأن نصائح اللعب اصطلاحية، والترجمة الحرفية تفقدها معناها.
class AssistantTip {
  final String ar;
  final String en;

  const AssistantTip({required this.ar, required this.en});
}

/// كل نصيحة تصف قاعدة حقيقية في اللعبة لا كلاما عاما مشجّعا: «استمتع!»
/// لا يعلّم شيئا، ويُقرأ حشوا بعد المرة الثانية.
const assistantTips = <AssistantTip>[
  AssistantTip(
    ar: 'اسحب إصبعك على الحروف المتجاورة لتكوّن الكلمة — لا حاجة للنقر حرفا حرفا.',
    en: 'Drag across neighbouring letters to build a word — no need to tap each one.',
  ),
  AssistantTip(
    ar: 'الكلمات الإضافية لا تظهر في الشبكة، لكنها تملأ الجرّة وتفتح مكافآت العالم.',
    en: 'Bonus words are not on the grid, but they fill the jar and unlock world rewards.',
  ),
  AssistantTip(
    ar: 'التلميح يكلّف عملات. جرّب ترتيب الحروف من النهاية أحيانا قبل أن تشتريه.',
    en: 'Hints cost coins. Try reading the letters from the end before you buy one.',
  ),
  AssistantTip(
    ar: 'مرحلة بلا تلميح واحد تمنحك مكافأة إتقان — التأنّي أرخص من الشراء.',
    en: 'Finishing a stage with no hints pays a bonus — patience beats buying.',
  ),
  AssistantTip(
    ar: 'العودة كل يوم تبني سلسلتك، والسلسلة تفتح مكافآت لا تُشترى بعملة.',
    en: 'Coming back daily builds your streak, and streaks unlock rewards coins cannot buy.',
  ),
  AssistantTip(
    ar: 'مسار الجوائز يعطيك جائزة كل يوم، وأخرى كل أسبوع، وثالثة كل شهر.',
    en: 'The reward track gives you a reward daily, another weekly, and a third monthly.',
  ),
  AssistantTip(
    ar: 'عجلة الحظ تمنحك دورة مجانية كل يوم. لا تنسها قبل منتصف الليل.',
    en: 'The lucky wheel gives a free spin every day. Do not miss it before midnight.',
  ),
  AssistantTip(
    ar: 'الحرف الأول من كلمة عالقة غالبا حرف تجاهلته لأنه في طرف العجلة.',
    en: 'The first letter of a stuck word is often the one you skipped at the wheel edge.',
  ),
  AssistantTip(
    ar: 'إن ضاقت بك مرحلة، اخرج والعب غيرها ثم عد — العين تجد الكلمة بعد راحة.',
    en: 'Stuck on a stage? Leave, play another and come back — fresh eyes find the word.',
  ),
  AssistantTip(
    ar: 'كل فصل يُختم بصندوق. أكمل مراحله كلها قبل أن تمضي إلى الفصل التالي.',
    en: 'Every chapter ends with a chest. Clear all its stages before moving on.',
  ),
  AssistantTip(
    ar: 'الجرّة تُملأ لكل عالم على حدة، وامتلاؤها يمنحك مكافأة — لا تحبسك عن التقدّم.',
    en: 'The jar fills per world and pays a reward when it does — it never blocks your progress.',
  ),
  AssistantTip(
    ar: 'الكلمات المتقاطعة في الشبكة تشترك في حروف — حرف واحد يكشف كلمتين.',
    en: 'Crossing words share letters — one revealed letter can crack two words.',
  ),
];

/// نصيحة عشوائية غير [except] (كي لا تتكرّر الجملة نفسها مرّتين متتاليتين).
/// تعيد أي نصيحة إن كانت القائمة أقصر من أن تسمح بذلك.
AssistantTip randomAssistantTip(Random rng, {AssistantTip? except}) {
  if (assistantTips.length < 2 || except == null) {
    return assistantTips[rng.nextInt(assistantTips.length)];
  }
  final pool = [
    for (final tip in assistantTips)
      if (!identical(tip, except)) tip,
  ];
  return pool[rng.nextInt(pool.length)];
}
