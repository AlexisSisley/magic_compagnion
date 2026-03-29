// test/models/player_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/player_config.dart';

void main() {
  group('CommanderInfo', () {
    test('creates with name only', () {
      final info = CommanderInfo(name: 'Atraxa');
      expect(info.name, 'Atraxa');
      expect(info.scryfallId, isNull);
      expect(info.artCropUrl, isNull);
    });

    test('toJson and fromJson roundtrip', () {
      final info = CommanderInfo(
        name: 'Korvold',
        scryfallId: 'abc-123',
        artCropUrl: 'https://example.com/art.jpg',
      );
      final json = info.toJson();
      final restored = CommanderInfo.fromJson(json);
      expect(restored.name, 'Korvold');
      expect(restored.scryfallId, 'abc-123');
      expect(restored.artCropUrl, 'https://example.com/art.jpg');
    });
  });

  group('PlayerConfig', () {
    test('creates owner config with linked deck', () {
      final config = PlayerConfig(
        id: 'owner-1',
        name: 'Alex',
        type: PlayerType.owner,
        colorValue: 0xFF0D47A1,
        linkedDeckId: 'deck-atraxa',
        commanders: [],
      );

      expect(config.type, PlayerType.owner);
      expect(config.linkedDeckId, 'deck-atraxa');
      expect(config.isOwner, true);
      expect(config.isGuest, false);
    });

    test('creates guest config with manual commanders', () {
      final config = PlayerConfig(
        id: 'guest-1',
        name: 'Max',
        type: PlayerType.guest,
        colorValue: 0xFFB71C1C,
        commanders: [
          CommanderInfo(name: 'Prossh', scryfallId: 'prossh-123'),
        ],
      );

      expect(config.type, PlayerType.guest);
      expect(config.linkedDeckId, isNull);
      expect(config.commanders, hasLength(1));
      expect(config.isOwner, false);
      expect(config.isGuest, true);
    });

    test('copyWith preserves values', () {
      final config = PlayerConfig(
        id: 'guest-1',
        name: 'Max',
        type: PlayerType.guest,
        colorValue: 0xFFB71C1C,
        commanders: [CommanderInfo(name: 'Prossh')],
      );
      final copied = config.copyWith(name: 'Maxime');
      expect(copied.id, 'guest-1');
      expect(copied.name, 'Maxime');
      expect(copied.commanders, hasLength(1));
    });

    test('toJson and fromJson roundtrip', () {
      final config = PlayerConfig(
        id: 'guest-2',
        name: 'Sarah',
        type: PlayerType.guest,
        colorValue: 0xFF4A148C,
        avatarPath: '/path/to/avatar.png',
        commanders: [
          CommanderInfo(name: 'Atraxa', scryfallId: 'atraxa-456'),
          CommanderInfo(name: 'Thrasios'),
        ],
      );
      final json = config.toJson();
      final restored = PlayerConfig.fromJson(json);
      expect(restored.id, 'guest-2');
      expect(restored.name, 'Sarah');
      expect(restored.type, PlayerType.guest);
      expect(restored.avatarPath, '/path/to/avatar.png');
      expect(restored.commanders, hasLength(2));
      expect(restored.commanders[0].name, 'Atraxa');
      expect(restored.commanders[1].name, 'Thrasios');
    });
  });
}
