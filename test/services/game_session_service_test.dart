// test/services/game_session_service_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/services/game_session_service.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';

void main() {
  final commanderFormat = GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GameSessionService', () {
    test('saveSnapshot and loadSnapshot roundtrip', () async {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
      ];
      final session = GameSession.newGame(format: commanderFormat, playerConfigs: configs);
      final service = GameSessionService();

      await service.saveSnapshot(session);
      final restored = await service.loadSnapshot();

      expect(restored, isNotNull);
      expect(restored!.format.id, 'commander');
      expect(restored.players, hasLength(2));
      expect(restored.players[0].config.name, 'Alex');
      expect(restored.players[0].life, 40);
    });

    test('hasActiveGame returns true after save', () async {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
      ];
      final session = GameSession.newGame(format: commanderFormat, playerConfigs: configs);
      final service = GameSessionService();

      expect(await service.hasActiveGame(), false);
      await service.saveSnapshot(session);
      expect(await service.hasActiveGame(), true);
    });

    test('clearSnapshot removes the snapshot', () async {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
      ];
      final session = GameSession.newGame(format: commanderFormat, playerConfigs: configs);
      final service = GameSessionService();

      await service.saveSnapshot(session);
      expect(await service.hasActiveGame(), true);
      await service.clearSnapshot();
      expect(await service.hasActiveGame(), false);
      expect(await service.loadSnapshot(), isNull);
    });
  });
}
