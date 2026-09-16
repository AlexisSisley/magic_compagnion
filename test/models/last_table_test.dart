// test/models/last_table_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/last_table.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/services/game_session_service.dart';

void main() {
  final commanderFormat = GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');

  group('LastTable', () {
    test('toJson/fromJson roundtrip preserves format, overridden thresholds, players and timer', () {
      final format = commanderFormat.copyWith(maxCommanderDamage: 15);
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner, colorValue: 0xFFAA0011),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest, colorValue: 0xFF00BB22),
      ];
      final table = LastTable(
        format: format,
        playerConfigs: configs,
        timerEnabled: true,
      );

      final restored = LastTable.fromJson(table.toJson());

      expect(restored.format.id, 'commander');
      expect(restored.format.maxCommanderDamage, 15);
      expect(restored.playerConfigs, hasLength(2));
      expect(restored.playerConfigs[0].id, 'p1');
      expect(restored.playerConfigs[0].name, 'Alex');
      expect(restored.playerConfigs[0].type, PlayerType.owner);
      expect(restored.playerConfigs[0].colorValue, 0xFFAA0011);
      expect(restored.playerConfigs[1].id, 'p2');
      expect(restored.playerConfigs[1].name, 'Max');
      expect(restored.playerConfigs[1].type, PlayerType.guest);
      expect(restored.playerConfigs[1].colorValue, 0xFF00BB22);
      expect(restored.timerEnabled, true);
    });
  });

  group('GameSessionService last table', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadLastTable returns null when no key is stored', () async {
      final service = GameSessionService();
      expect(await service.loadLastTable(), isNull);
    });

    test('saveLastTable then loadLastTable roundtrips', () async {
      final service = GameSessionService();
      final table = LastTable(
        format: commanderFormat,
        playerConfigs: [
          PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        ],
        timerEnabled: false,
      );

      await service.saveLastTable(table);
      final restored = await service.loadLastTable();

      expect(restored, isNotNull);
      expect(restored!.format.id, 'commander');
      expect(restored.playerConfigs, hasLength(1));
      expect(restored.timerEnabled, false);
    });

    test('loadLastTable returns null (does not throw) on invalid JSON', () async {
      SharedPreferences.setMockInitialValues({'last_table': 'not valid json {{{'});
      final service = GameSessionService();
      expect(await service.loadLastTable(), isNull);
    });

    test('loadLastTable returns null (does not throw) when a required field like format is missing', () async {
      SharedPreferences.setMockInitialValues({
        'last_table': '{"playerConfigs": [], "timerEnabled": true}',
      });
      final service = GameSessionService();
      expect(await service.loadLastTable(), isNull);
    });

    test('clearLastTable makes loadLastTable return null', () async {
      final service = GameSessionService();
      final table = LastTable(
        format: commanderFormat,
        playerConfigs: [
          PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        ],
        timerEnabled: true,
      );

      await service.saveLastTable(table);
      expect(await service.loadLastTable(), isNotNull);

      await service.clearLastTable();
      expect(await service.loadLastTable(), isNull);
    });
  });
}
