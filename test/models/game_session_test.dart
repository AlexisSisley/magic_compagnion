// test/models/game_session_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/table_seat.dart';

/// Configs de test génériques, une par joueur (id/nom uniques, reste par
/// défaut) — évite de retaper la même liste littérale dans chaque test.
List<PlayerConfig> _configs(int count) => List.generate(
      count,
      (i) => PlayerConfig(id: 'p${i + 1}', name: 'Joueur ${i + 1}', type: PlayerType.guest),
    );

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

    test(
        'fromJson migre un snapshot hérité (players permutés, playerOrder '
        'resté à l\'identité) sans perdre la disposition (M-3)', () {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
        PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
        PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
      ];
      final base = GameSession.newGame(format: commanderFormat, playerConfigs: configs);
      expect(base.playerOrder, [0, 1, 2, 3]); // identité de départ

      // Reproduit le comportement de l'ancienne version installée : la liste
      // `players` est physiquement permutée pour représenter la disposition
      // voulue par le joueur, `playerOrder` n'est jamais touché (identité).
      final legacyJson = base
          .copyWith(players: [
            base.players[3],
            base.players[1],
            base.players[2],
            base.players[0],
          ])
          .toJson();

      final restored = GameSession.fromJson(legacyJson);

      expect(
        restored.players.map((p) => p.playerId).toList(),
        [0, 1, 2, 3],
        reason: 'players doit être retrié en ordre canonique après migration',
      );
      expect(
        restored.playerOrder,
        [3, 1, 2, 0],
        reason: 'playerOrder doit hériter de la disposition physique '
            'observée, pas rester à l\'identité',
      );
    });

    test(
        'fromJson ne migre pas un snapshot déjà écrit par le code actuel '
        '(playerOrder porte un vrai reorder)', () {
      final configs = [
        PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
        PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
        PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
        PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
      ];
      final base = GameSession.newGame(format: commanderFormat, playerConfigs: configs);
      // players reste canonique, seul playerOrder change (comportement actuel).
      final reordered = base.reorderPlayers([3, 1, 2, 0]);

      final restored = GameSession.fromJson(reordered.toJson());

      expect(restored.players.map((p) => p.playerId).toList(), [0, 1, 2, 3]);
      expect(restored.playerOrder, [3, 1, 2, 0]);
    });
  });

  group('GameSession.newGame — rotations initiales (lot 6 §2)', () {
    test('4 joueurs : haut/droite/bas/gauche -> [2, 3, 0, 1]', () {
      final session = GameSession.newGame(
        format: commanderFormat,
        playerConfigs: _configs(4),
      );
      expect(session.players.map((p) => p.quarterTurns).toList(), [2, 3, 0, 1]);
    });

    test('2 joueurs : face-a-face historique preserve -> [2, 0]', () {
      final session = GameSession.newGame(
        format: commanderFormat,
        playerConfigs: _configs(2),
      );
      expect(session.players.map((p) => p.quarterTurns).toList(), [2, 0]);
    });

    test(
        '8 joueurs : aucune rotation laterale, quarterTurns suit exactement '
        'les defauts de seatsFor(8)', () {
      // Ronde de correction 1 (MINOR) : `anyOf(0, 2)` seul passait par
      // construction (le defaut 0 de PlayerState appartient deja a cet
      // ensemble), donc retirer le cablage de seatsFor dans `newGame` ne
      // faisait pas echouer ce test. On compare desormais a la sortie REELLE
      // de `seatsFor(8)` (pas a une liste recopiee a la main), ce qui exige
      // que `newGame` l'utilise vraiment ; l'assertion `anyOf` est conservee
      // en plus, pour documenter explicitement l'absence de siege lateral.
      final session = GameSession.newGame(
        format: commanderFormat,
        playerConfigs: _configs(8),
      );
      final expectedQuarterTurns =
          seatsFor(8).map((seat) => seat.quarterTurns).toList();

      expect(
        session.players.map((p) => p.quarterTurns).toList(),
        expectedQuarterTurns,
      );
      for (final p in session.players) {
        expect(p.quarterTurns, anyOf(0, 2), reason: 'joueur ${p.playerId}');
      }
    });
  });

  group('GameSession.fromJson — migration de rotation heritee (lot 6)', () {
    test(
        'ancien snapshot, 4 joueurs tous a 0, recoit les defauts de siege '
        '[2, 3, 0, 1]', () {
      final base = GameSession.newGame(
        format: commanderFormat,
        playerConfigs: _configs(4),
      );
      // Reproduit un snapshot ecrit avant ce lot : la grille compensait alors
      // pour la moitie haute, donc `quarterTurns` valait 0 pour tout le monde.
      final legacy = base.copyWith(
        players: base.players.map((p) => p.copyWith(quarterTurns: 0)).toList(),
      );

      final restored = GameSession.fromJson(legacy.toJson());

      expect(restored.players.map((p) => p.quarterTurns).toList(), [2, 3, 0, 1]);
    });

    test(
        'ronde de correction 1 (CRITICAL) : snapshot sans champ playerOrder '
        'du tout (ecrit avant le lot 1), 4 joueurs tous a 0, recoit quand '
        'meme les defauts de siege [2, 3, 0, 1]', () {
      final base = GameSession.newGame(
        format: commanderFormat,
        playerConfigs: _configs(4),
      );
      final legacy = base.copyWith(
        players: base.players.map((p) => p.copyWith(quarterTurns: 0)).toList(),
      );

      // `playerOrder` n'existait pas avant le lot 1 : simule un snapshot ou
      // le champ est totalement absent du JSON, pas seulement egal a
      // l'identite. `fromJson` doit alors retomber sur l'ordre canonique de
      // `players` pour la migration, exactement comme `_orderedPlayers` le
      // fait deja pour l'affichage.
      final json = legacy.toJson();
      json.remove('playerOrder');

      final restored = GameSession.fromJson(json);

      expect(restored.players.map((p) => p.quarterTurns).toList(), [2, 3, 0, 1]);
    });

    test(
        'un joueur qui a deja tourne sa zone bloque toute la migration, meme '
        'les zeros des autres', () {
      final base = GameSession.newGame(
        format: commanderFormat,
        playerConfigs: _configs(4),
      );
      final withOneRotated = base.copyWith(
        players: [
          base.players[0].copyWith(quarterTurns: 0),
          base.players[1].copyWith(quarterTurns: 0),
          base.players[2].copyWith(quarterTurns: 1),
          base.players[3].copyWith(quarterTurns: 0),
        ],
      );

      final restored = GameSession.fromJson(withOneRotated.toJson());

      expect(
        restored.players.map((p) => p.quarterTurns).toList(),
        [0, 0, 1, 0],
        reason: 'des qu un joueur a tourne, aucune valeur ne doit bouger, y '
            'compris les zeros des autres',
      );
    });

    test('snapshot a un seul joueur : pas de migration, pas de crash', () {
      final single = GameSession.newGame(
        format: commanderFormat,
        playerConfigs: _configs(1),
      );

      final restored = GameSession.fromJson(single.toJson());

      expect(restored.players, hasLength(1));
      expect(restored.players.single.quarterTurns, 0);
    });
  });
}
