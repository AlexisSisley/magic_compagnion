// test/models/game_format_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_format.dart';

void main() {
  group('GameFormat', () {
    test('creates a valid format with all fields', () {
      final format = GameFormat(
        id: 'commander',
        name: 'Commander',
        startingLife: 40,
        minPlayers: 2,
        maxPlayers: 8,
        maxCommanders: 2,
        enabledCounterIds: ['poison', 'energy', 'commander_tax', 'commander_damage'],
        isBuiltIn: true,
      );

      expect(format.id, 'commander');
      expect(format.name, 'Commander');
      expect(format.startingLife, 40);
      expect(format.minPlayers, 2);
      expect(format.maxPlayers, 8);
      expect(format.maxCommanders, 2);
      expect(format.enabledCounterIds, hasLength(4));
      expect(format.isBuiltIn, true);
    });

    test('copyWith preserves values when not specified', () {
      final format = GameFormat(
        id: 'commander',
        name: 'Commander',
        startingLife: 40,
        minPlayers: 2,
        maxPlayers: 8,
        maxCommanders: 2,
        enabledCounterIds: ['poison'],
        isBuiltIn: true,
      );
      final copied = format.copyWith(startingLife: 30);
      expect(copied.name, 'Commander');
      expect(copied.startingLife, 30);
      expect(copied.maxCommanders, 2);
    });

    test('toJson and fromJson roundtrip', () {
      final format = GameFormat(
        id: 'custom-1',
        name: 'My Format',
        startingLife: 25,
        minPlayers: 2,
        maxPlayers: 6,
        maxCommanders: 3,
        enabledCounterIds: ['poison', 'energy'],
        isBuiltIn: false,
      );
      final json = format.toJson();
      final restored = GameFormat.fromJson(json);
      expect(restored.id, format.id);
      expect(restored.name, format.name);
      expect(restored.startingLife, format.startingLife);
      expect(restored.maxCommanders, format.maxCommanders);
      expect(restored.enabledCounterIds, format.enabledCounterIds);
      expect(restored.isBuiltIn, false);
    });
  });

  group('GameFormat.builtInFormats', () {
    test('contains all 6 presets', () {
      expect(GameFormat.builtInFormats, hasLength(6));
    });

    test('Commander preset has correct values', () {
      final commander = GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');
      expect(commander.startingLife, 40);
      expect(commander.maxPlayers, 8);
      expect(commander.maxCommanders, 2);
      expect(commander.enabledCounterIds, contains('commander_damage'));
    });

    test('Standard preset has 0 commanders', () {
      final standard = GameFormat.builtInFormats.firstWhere((f) => f.id == 'standard');
      expect(standard.startingLife, 20);
      expect(standard.maxCommanders, 0);
      expect(standard.maxPlayers, 2);
    });

    test('Custom preset has unlimited commanders', () {
      final custom = GameFormat.builtInFormats.firstWhere((f) => f.id == 'custom');
      expect(custom.maxCommanders, -1);
      expect(custom.startingLife, 20);
    });

    test('all presets are marked isBuiltIn', () {
      for (final format in GameFormat.builtInFormats) {
        expect(format.isBuiltIn, true, reason: '${format.name} should be built-in');
      }
    });
  });
}
