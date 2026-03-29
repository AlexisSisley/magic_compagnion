// test/controllers/game_session_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/game_session_controller.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/player_config.dart';

void main() {
  late GameSessionController controller;
  final commanderFormat =
      GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');
  final configs = [
    PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
    PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
    PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
    PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
  ];

  setUp(() {
    controller = GameSessionController();
  });

  group('startNewGame', () {
    test('creates session with correct starting life', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      expect(controller.session, isNotNull);
      expect(controller.session!.players, hasLength(4));
      expect(controller.session!.players[0].life, 40);
      expect(controller.session!.format.id, 'commander');
    });
  });

  group('updateLife', () {
    test('increases life and records event', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.updateLife(0, 5, gameDuration: const Duration(minutes: 1));
      expect(controller.session!.players[0].life, 45);
      expect(controller.session!.players[0].lifeHistory, hasLength(1));
      expect(controller.session!.players[0].lifeHistory.first.delta, 5);
    });

    test('decreases life', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.updateLife(0, -3, gameDuration: const Duration(minutes: 2));
      expect(controller.session!.players[0].life, 37);
    });

    test('does not affect other players', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.updateLife(0, -10, gameDuration: Duration.zero);
      expect(controller.session!.players[1].life, 40);
      expect(controller.session!.players[2].life, 40);
    });
  });

  group('updateCounter', () {
    test('sets counter value', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.updateCounter(0, 'poison', 3);
      expect(controller.session!.players[0].counters['poison'], 3);
    });

    test('increments existing counter', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.updateCounter(0, 'poison', 2);
      controller.updateCounter(0, 'poison', 3);
      expect(controller.session!.players[0].counters['poison'], 3);
    });
  });

  group('addCommanderDamage', () {
    test('records commander damage from opponent', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.addCommanderDamage(
        targetPlayerId: 0,
        sourcePlayerId: 1,
        damage: 5,
        gameDuration: const Duration(minutes: 3),
      );
      expect(controller.session!.players[0].commanderDamageReceived[1], 5);
      expect(controller.session!.players[0].life, 35);
      expect(controller.session!.players[0].lifeHistory, hasLength(1));
      expect(
          controller.session!.players[0].lifeHistory.first.source,
          contains('Max'));
    });
  });

  group('eliminatePlayer', () {
    test('marks player as eliminated', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.eliminatePlayer(2, atDuration: const Duration(minutes: 15));
      expect(controller.session!.players[2].isEliminated, true);
      expect(controller.session!.eliminationOrder, [2]);
    });
  });

  group('toggleMonarch', () {
    test('sets monarch and clears from others', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.toggleMonarch(1);
      expect(controller.session!.players[1].isMonarch, true);
      expect(controller.session!.players[0].isMonarch, false);
      controller.toggleMonarch(3);
      expect(controller.session!.players[1].isMonarch, false);
      expect(controller.session!.players[3].isMonarch, true);
    });

    test('toggles off if same player', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.toggleMonarch(1);
      expect(controller.session!.players[1].isMonarch, true);
      controller.toggleMonarch(1);
      expect(controller.session!.players[1].isMonarch, false);
    });
  });

  group('reorderPlayers', () {
    test('updates player order', () {
      controller.startNewGame(format: commanderFormat, playerConfigs: configs);
      controller.reorderPlayers([3, 1, 0, 2]);
      expect(controller.session!.playerOrder, [3, 1, 0, 2]);
    });
  });
}
