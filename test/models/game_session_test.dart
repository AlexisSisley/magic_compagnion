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

    test('un snapshot écrit par ce code porte le marqueur de migration', () {
      final session = GameSession.newGame(
        format: GameFormat.builtInFormats.first,
        playerConfigs: List.generate(
          4,
          (i) => PlayerConfig(
            id: 'p$i',
            name: 'Joueur $i',
            type: i == 0 ? PlayerType.owner : PlayerType.guest,
          ),
        ),
      );
      expect(session.toJson()['rotationsMigrated'], isTrue);
    });

    test('un « Même sens » délibéré survit à un aller-retour JSON', () {
      final session = GameSession.newGame(
        format: GameFormat.builtInFormats.first,
        playerConfigs: List.generate(
          4,
          (i) => PlayerConfig(
            id: 'p$i',
            name: 'Joueur $i',
            type: i == 0 ? PlayerType.owner : PlayerType.guest,
          ),
        ),
      );
      final allZero = session.copyWith(
        players: session.players.map((p) => p.copyWith(quarterTurns: 0)).toList(),
      );
      final round = GameSession.fromJson(allZero.toJson());
      expect(round.players.map((p) => p.quarterTurns).toList(), [0, 0, 0, 0],
          reason: 'sans le marqueur, l\'heuristique prendrait ce choix délibéré '
              'pour un ancien snapshot et le réécrirait à chaque rechargement');
    });

    test(
        'un ancien snapshot SANS marqueur NI playerOrder reçoit les '
        'rotations de siège en ordre canonique', () {
      final session = GameSession.newGame(
        format: GameFormat.builtInFormats.first,
        playerConfigs: List.generate(
          4,
          (i) => PlayerConfig(
            id: 'p$i',
            name: 'Joueur $i',
            type: i == 0 ? PlayerType.owner : PlayerType.guest,
          ),
        ),
      );
      // Un vrai snapshot antérieur au champ `playerOrder` ne le porte PAS du
      // tout dans son JSON (le champ n'existait pas encore) : le retirer
      // entièrement, pas seulement laisser `[0,1,2,3]`, est ce qui fait
      // vraiment emprunter la retombée de `_migrateLegacyRotation`
      // (`playerOrder.length != players.length`, ici 0 != 4). Un
      // `playerOrder` laissé à `[0,1,2,3]` prend la branche normale
      // (`effectiveOrder = playerOrder`), qui donne par coïncidence le même
      // résultat que la retombée ici — ce qui masquait totalement la
      // retombée avant ce correctif (ronde de correction 3).
      final legacy = Map<String, dynamic>.from(session.toJson())
        ..remove('rotationsMigrated')
        ..remove('playerOrder');
      legacy['players'] = (legacy['players'] as List)
          .map((p) => Map<String, dynamic>.from(p as Map)..['quarterTurns'] = 0)
          .toList();
      final migrated = GameSession.fromJson(legacy);
      expect(migrated.players.map((p) => p.quarterTurns).toList(), [2, 3, 0, 1],
          reason: 'playerOrder absent -> effectiveOrder retombe sur l\'ordre '
              'canonique des playerId ([0,1,2,3]) -> seatsFor(4) '
              '(top,right,bottom,left) donne [2,3,0,1]');
    });

    test(
        'un ancien snapshot SANS marqueur MAIS avec un playerOrder déjà '
        'posé migre dans l\'ordre d\'AFFICHAGE, pas dans l\'ordre canonique',
        () {
      // Version transitoire plausible : `playerOrder` existait déjà (M-3,
      // tâche antérieure à celle-ci) mais `rotationsMigrated` n'existait pas
      // encore. Ce cas doit emprunter la branche NORMALE de
      // `_migrateLegacyRotation` (`effectiveOrder = playerOrder`), pas la
      // retombée canonique -- et le résultat doit donc différer de celui
      // qu'on obtiendrait en ordre canonique, sans quoi les deux chemins
      // seraient indiscernables (voir la contrainte du brief : aucune
      // fixture ne part d'un playerOrder identité quand le test porte sur
      // l'ordre).
      final session = GameSession.newGame(
        format: GameFormat.builtInFormats.first,
        playerConfigs: List.generate(
          4,
          (i) => PlayerConfig(
            id: 'p$i',
            name: 'Joueur $i',
            type: i == 0 ? PlayerType.owner : PlayerType.guest,
          ),
        ),
      );
      final legacy = Map<String, dynamic>.from(session.toJson())
        ..remove('rotationsMigrated');
      legacy['playerOrder'] = [3, 1, 2, 0];
      legacy['players'] = (legacy['players'] as List)
          .map((p) => Map<String, dynamic>.from(p as Map)..['quarterTurns'] = 0)
          .toList();
      final migrated = GameSession.fromJson(legacy);
      // seatsFor(4) : [top,right,bottom,left] -> quarterTurns [2,3,0,1].
      // effectiveOrder = playerOrder = [3,1,2,0] : position0(joueur3)->2,
      // position1(joueur1)->3, position2(joueur2)->0, position3(joueur0)->1.
      // Résultat en ordre canonique playerId [0,1,2,3] : [1,3,0,2] --
      // différent du [2,3,0,1] qu'aurait donné un calcul en ordre canonique
      // (le résultat du test précédent), preuve que ce chemin lit bien
      // `playerOrder`.
      expect(migrated.players.map((p) => p.quarterTurns).toList(), [1, 3, 0, 2]);
    });
  });
}
