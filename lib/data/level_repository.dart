import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

class LevelRepository {
  List<GameLevel>? _cache;

  Future<List<GameLevel>> loadLevels() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/levels.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _cache = (data['levels'] as List)
        .map((l) => GameLevel.fromJson(l as Map<String, dynamic>))
        .toList();
    return _cache!;
  }
}
