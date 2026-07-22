import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huruf/data/models.dart';
import 'package:huruf/data/world_models.dart';

void main() {
  test('500 levels map onto 8 worlds of at least 50', () {
    expect(worlds.length, 8);
    expect(worldSizes.reduce((a, b) => a + b), 500);
    for (final size in worldSizes) {
      expect(size, greaterThanOrEqualTo(50));
    }
    // حدود العالم الأول (62 مرحلة)
    expect(worldForLevel(1).id, 1);
    expect(worldForLevel(62).id, 1);
    expect(worldForLevel(63).id, 2);
    expect(worldForLevel(500).id, 8);
    expect(worlds.last.lastLevelId, 500);

    final level = GameLevel(
        id: 63, letters: const [], words: const [], bonusWords: const [], difficulty: 1);
    expect(level.worldId, 2);
    expect(level.indexInWorld, 1);

    // تسلسل الحدود بين كل العوالم
    for (final world in worlds) {
      expect(world.lastLevelId - world.firstLevelId + 1, world.levelCount);
      if (world.id > 1) {
        expect(world.firstLevelId, worlds[world.id - 2].lastLevelId + 1);
      }
    }
  });

  test('every world has a valid guide and background file', () {
    for (final world in worlds) {
      expect(characters.containsKey(world.guideId), isTrue,
          reason: 'world ${world.slug} guide ${world.guideId} missing');
      expect(File(world.background).existsSync(), isTrue,
          reason: '${world.background} not found');
    }
  });

  test('every character has portrait and mp4 animation on disk', () {
    for (final c in characters.values) {
      expect(File(c.portrait).existsSync(), isTrue,
          reason: '${c.portrait} not found');
      expect(File(c.animation).existsSync(), isTrue,
          reason: '${c.animation} not found');
    }
  });

  test('all emotions have at least one message', () {
    for (final emotion in CharacterEmotion.values) {
      expect(characterMessages[emotion], isNotEmpty,
          reason: 'no messages for $emotion');
    }
  });
}
