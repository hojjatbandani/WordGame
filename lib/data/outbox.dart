// طابور معلَّقات عام صغير — أول تطبيق فعلي لقاعدة "عدم الاتصال أولا: أي
// كتابة تفشل بسبب انعدام الشبكة تدخل طابورا لإعادة المحاولة لاحقا، لا
// تُفقَد بصمت ولا تُعطِّل اللاعب" في هذا المشروع. لا يوجد أي تطبيق سابق
// لهذا النمط في الكود (تحقَّق منه بحث شامل قبل هذه المهمة) — كل الوحدات
// اللاسلكية الأخرى (multiplayer_repository.dart، social_repository.dart)
// إمّا لا تُعالج فشل الشبكة إطلاقا أو تكتفي بابتلاعه صامتا. هذا مصمَّم
// كأداة عامة قابلة لإعادة الاستخدام من أي ميزة لاحقا عبر [namespace]
// مختلف، لا حصرا للتحدي اليومي الذي يستخدمها اليوم فعلا.
//
// بسيط عمدا: قائمة سلاسل JSON في SharedPreferences، لا قاعدة بيانات
// محلية منفصلة — يكفي هذا الحجم من البيانات (نتيجة واحدة معلّقة في
// الغالب، نادرا أكثر).

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OutboxEntry {
  /// معرّف محلي فريد (uuid بسيط كافٍ — لا حاجة لتشفير حقيقي، فقط لمنع
  /// إعادة إدخال نفس العنصر مرتين لو استُدعي enqueue بالخطأ مرتين)
  final String id;
  final Map<String, dynamic> payload;
  final DateTime queuedAt;

  const OutboxEntry({
    required this.id,
    required this.payload,
    required this.queuedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'payload': payload,
        'queuedAt': queuedAt.toIso8601String(),
      };

  factory OutboxEntry.fromJson(Map<String, dynamic> json) => OutboxEntry(
        id: json['id'] as String,
        payload: json['payload'] as Map<String, dynamic>,
        queuedAt: DateTime.parse(json['queuedAt'] as String),
      );
}

class Outbox {
  final SharedPreferences prefs;
  final String namespace;

  const Outbox(this.prefs, this.namespace);

  String get _key => 'outbox_$namespace';

  List<OutboxEntry> get pending {
    final raw = prefs.getStringList(_key) ?? const [];
    return [
      for (final s in raw)
        OutboxEntry.fromJson(jsonDecode(s) as Map<String, dynamic>),
    ];
  }

  /// إن وُجد عنصر بنفس [OutboxEntry.id] يُستبدَل، لا يُكدَّس بجانبه — إعادة
  /// محاولة/إعادة لعب لاحقة لنفس العملية المنطقية تستبدل المعلَّق القديم
  Future<void> enqueue(OutboxEntry entry) async {
    final list = pending.where((e) => e.id != entry.id).toList()..add(entry);
    await prefs.setStringList(
        _key, [for (final e in list) jsonEncode(e.toJson())]);
  }

  Future<void> remove(String id) async {
    final list = pending.where((e) => e.id != id).toList();
    await prefs.setStringList(
        _key, [for (final e in list) jsonEncode(e.toJson())]);
  }
}
