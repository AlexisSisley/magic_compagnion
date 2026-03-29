// test/models/game_session_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/models/game_session.dart';

void main() {
  final commanderFormat = GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');

  group('LifeEvent', () {
    test('creates with all fields', () {
      final event = LifeEvent(
        delta: -5,
        source: 'Commander: Atraxa',
        timestamp: const Duration(minutes: 3, seconds: 22),
      );
      expect(event.delta, -5);
      expect(event.source, 'Commander: Atraxa');
      expect(event.timestamp.inSeconds, 202);
    });

    test('toJson and fromJson roundtrip', () {
      final event = LifeEvent(
        delta: 3,
        timestamp: const Duration(seconds: 120),
      );
      final json = event.toJson();
      final restored = LifeEvent.fromJson(json);
      expect(restored.delta, 3);
      expect(restored.source, isNull);
      expect(restored.timestamp.inSeconds, 120);
    });
  });

  group('PlayerState', () {
    test('creates with default values', () {
      final config = PlayerConfig(
        id: 'p1',
        name: 'Alex',
        type: PlayerType.owner,
      );
      final state = PlayerState(
        playerId: 0,
        config: config,
        life: 40,
      );

      expect(state.life, 40);
      expect(state.counters, isEmpty);
      expect(state.commanderDamageReceived, isEmpty);
      expect(state.isEliminated, false);
      expect(state.isMonarch, false);
      expect(state.lifeHistory, isEmpty);
    });

    test('copyWith updates life and preserves rest', () {
      final config = PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner);
      final state = PlayerState(playerId: 0, config: config, life: 40);
      final updated = state.copyWith(life: 35);
      expect(updated.life, 35);
      expect(updated.config.name, 'Alex');
      expect(updated.playerId, 0);
    });

    test('addLifeEvent appends to history', () {
      final config = PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner);
      final state = PlayerState(playerId: 0, config: config, life: 40);
      final event = LifeEvent(delta: -3, timestamp: const Duration(seconds: 60));
      final updated = state.copyWith(
        life: 37,
        lifeHistory: [...state.lifeHistory, event],
      );
      expect(updated.lifeHistory, hasLength(1));
      expect(updated.lifeHistory.first.delta, -3);
    });
  });

  group('GameSession', () {
    test('creates a new session from format', () {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
        PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
        PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
      ];

      final session = GameSession.newGame(
        format: commanderFormat,
        playerConfigs: configs,
      );

      expect(session.format.id, 'commander');
      expect(session.players, hasLength(4));
      expect(session.players[0].life, 40);
      expect(session.players[0].config.name, 'Alex');
      expect(session.isActive, false);
      expect(session.eliminationOrder, isEmpty);
      expect(session.playerOrder, [0, 1, 2, 3]);
    });

    test('toJson and fromJson roundtrip', () {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
      ];
      final session = GameSession.newGame(
        format: commanderFormat,
        playerConfigs: configs,
      );

      final json = session.toJson();
      final restored = GameSession.fromJson(json);

      expect(restored.id, session.id);
      expect(restored.format.id, 'commander');
      expect(restored.players, hasLength(2));
      expect(restored.players[0].config.name, 'Alex');
      expect(restored.players[1].life, 40);
    });

    test('eliminatePlayer marks player and records order', () {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
      ];
      final session = GameSession.newGame(format: commanderFormat, playerConfigs: configs);
      final updated = session.eliminatePlayer(1, atDuration: const Duration(minutes: 10));

      expect(updated.players[1].isEliminated, true);
      expect(updated.players[1].eliminatedAt, const Duration(minutes: 10));
      expect(updated.eliminationOrder, [1]);
      expect(updated.players[0].isEliminated, false);
    });

    test('reorderPlayers updates playerOrder', () {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
        PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
        PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
      ];
      final session = GameSession.newGame(format: commanderFormat, playerConfigs: configs);
      final reordered = session.reorderPlayers([2, 0, 3, 1]);
      expect(reordered.playerOrder, [2, 0, 3, 1]);
    });
  });
}
