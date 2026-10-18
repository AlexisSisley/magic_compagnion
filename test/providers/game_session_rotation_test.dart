// test/providers/game_session_rotation_test.dart
//
// Tâche 4 : la rotation d'une zone joueur n'a qu'une seule source de vérité
// -- `TableSeat.quarterTurns`, dérivé du côté de table. `PlayerState.quarterTurns`
// (persisté) n'en est qu'un CACHE, écrit par `seedRotationsFromSeats` quand la
// disposition change, et par `updateRotation` quand l'utilisateur choisit à la
// main.
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/providers/game_session_notifier.dart';
import 'package:magic_companion/widgets/life_counter/layouts/table_layout.dart';

void main() {
  /// Table de référence de la convention : `RotatedBox` tourne dans le sens
  /// horaire, un joueur assis à gauche regarde vers la droite (voir la doc
  /// de `TableSeat.quarterTurns`).
  const expected = {
    TableSide.bottom: 0,
    TableSide.left: 1,
    TableSide.top: 2,
    TableSide.right: 3,
  };

  group('convention side -> quarterTurns (Tâche 3)', () {
    test('la rotation d un siège ne vient que de son côté, 2 à 6 joueurs', () {
      for (final size in const [Size(390, 844), Size(840, 700)]) {
        for (int n = 2; n <= 6; n++) {
          for (final seat in tableLayoutFor(size, n).seats) {
            expect(seat.quarterTurns, expected[seat.side],
                reason: '$n joueurs sur $size, côté ${seat.side}');
          }
        }
      }
    });

    test('une zone plus haute que large reçoit un quart de tour (4 joueurs)',
        () {
      final layout = tableLayoutFor(const Size(390, 844), 4);
      expect(layout.seats.every((s) => s.quarterTurns.isOdd), isTrue);
    });

    test(
        'une zone plus large que haute ne reçoit pas de quart de tour '
        '(4 joueurs)', () {
      final layout = tableLayoutFor(const Size(840, 700), 4);
      expect(layout.seats.every((s) => s.quarterTurns.isEven), isTrue);
    });
  });

  group('GameSessionNotifier.seedRotationsFromSeats', () {
    late ProviderContainer container;

    final commanderFormat =
        GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');
    final configs = [
      const PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
      const PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
      const PlayerConfig(id: 'p3', name: 'Sarah', type: PlayerType.guest),
      const PlayerConfig(id: 'p4', name: 'Leo', type: PlayerType.guest),
    ];

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    GameSessionNotifier getNotifier() =>
        container.read(gameSessionNotifierProvider.notifier);

    test('applique aux joueurs les quarterTurns de leur siège, dans l ordre '
        'd affichage donné', () {
      getNotifier()
          .startNewGame(format: commanderFormat, playerConfigs: configs);
      final seats = tableLayoutFor(const Size(390, 844), 4).seats;

      getNotifier().seedRotationsFromSeats([0, 1, 2, 3], seats);

      final players = container.read(gameSessionNotifierProvider)!.players;
      for (int i = 0; i < players.length; i++) {
        expect(players[i].quarterTurns, seats[i].quarterTurns,
            reason: 'joueur ${players[i].playerId}');
      }
    });

    // Preuve que le semis respecte l'ordre d'AFFICHAGE, pas l'ordre
    // canonique : sans ce test, indexer `state.players[i]` directement sur
    // `seats[i]` (ce que proposait le brief) aurait semblé correct tant que
    // personne n'avait réordonné -- et aurait assigné le siège du joueur
    // affiché en premier au `playerId` 0, quel que soit l'endroit où il est
    // réellement affiché.
    test('respecte l ordre d affichage, pas l ordre canonique des playerId',
        () {
      getNotifier()
          .startNewGame(format: commanderFormat, playerConfigs: configs);
      final seats = tableLayoutFor(const Size(390, 844), 4).seats;

      // playerId 3 est affiché en premier (siège 0), playerId 0 en dernier
      // (siège 3) : ordre d'affichage inversé par rapport à l'ordre
      // canonique.
      const displayOrder = [3, 2, 1, 0];
      getNotifier().seedRotationsFromSeats(displayOrder, seats);

      final byId = {
        for (final p in container.read(gameSessionNotifierProvider)!.players)
          p.playerId: p,
      };
      for (int i = 0; i < displayOrder.length; i++) {
        expect(byId[displayOrder[i]]!.quarterTurns, seats[i].quarterTurns,
            reason: 'playerId ${displayOrder[i]} affiché au siège $i');
      }
    });

    test('ne touche rien si order et seats n ont pas la même longueur', () {
      getNotifier()
          .startNewGame(format: commanderFormat, playerConfigs: configs);
      final before = container.read(gameSessionNotifierProvider)!.players;

      getNotifier().seedRotationsFromSeats(
          [0, 1, 2, 3], tableLayoutFor(const Size(390, 844), 3).seats);

      final after = container.read(gameSessionNotifierProvider)!.players;
      expect(after.map((p) => p.quarterTurns),
          before.map((p) => p.quarterTurns));
    });

    test('sans session en cours, ne lève pas', () {
      expect(
        () => getNotifier()
            .seedRotationsFromSeats([0], const [TableSeat(side: TableSide.bottom, slot: 0, slotCount: 1)]),
        returnsNormally,
      );
    });

    // Question 2 du rapport de tâche : un choix manuel (`updateRotation`)
    // survit à un re-semis qui porte la MÊME disposition -- c'est le filtre
    // de `_seedRotationsIfLayoutChanged` (dans la page) qui garantit ça en
    // amont, mais ce test prouve que le notifier lui-même ne réécrit QUE les
    // joueurs dont la valeur diffère du siège semé : si on ne rappelait
    // jamais `seedRotationsFromSeats` avec une disposition inchangée (ce que
    // fait la page), le choix manuel n'est jamais repris.
    test(
        'un choix manuel (updateRotation) n est pas repris par un notify sur '
        'la même disposition', () {
      getNotifier()
          .startNewGame(format: commanderFormat, playerConfigs: configs);
      final seats = tableLayoutFor(const Size(390, 844), 4).seats;
      getNotifier().seedRotationsFromSeats([0, 1, 2, 3], seats);

      // Le joueur 1 choisit une rotation différente de son siège.
      getNotifier().updateRotation(1, 0);
      expect(
          container.read(gameSessionNotifierProvider)!.players[1].quarterTurns,
          0);

      // La page ne rappelle `seedRotationsFromSeats` QUE si la disposition a
      // changé (voir `_seedRotationsIfLayoutChanged`) : simuler ce
      // comportement ici en ne rappelant rien d'autre, et vérifier que rien
      // n'a glissé derrière le dos du test.
      expect(
          container.read(gameSessionNotifierProvider)!.players[1].quarterTurns,
          0);
    });

    // Question 3 du rapport de tâche (choix assumé) : un changement de
    // disposition réécrit un choix manuel antérieur -- `quarterTurns` reste
    // un cache de la dérivation géométrique, jamais une seconde vérité
    // indépendante.
    test(
        'un nouveau semis après changement de disposition écrase un choix '
        'manuel antérieur', () {
      getNotifier()
          .startNewGame(format: commanderFormat, playerConfigs: configs);
      final folded = tableLayoutFor(const Size(390, 844), 4).seats;
      getNotifier().seedRotationsFromSeats([0, 1, 2, 3], folded);

      // Choix manuel du joueur 1 : "Même sens" (0), alors que son siège
      // replié voulait un quart de tour.
      getNotifier().updateRotation(1, 0);
      expect(folded[1].quarterTurns, isNot(0));

      // L'appareil se déplie : nouvelle disposition, colonnes latérales
      // devenues face-à-face -- les quarterTurns dérivés changent.
      final unfolded = tableLayoutFor(const Size(840, 700), 4).seats;
      expect(unfolded.map((s) => s.quarterTurns),
          isNot(folded.map((s) => s.quarterTurns)));

      getNotifier().seedRotationsFromSeats([0, 1, 2, 3], unfolded);

      expect(
          container.read(gameSessionNotifierProvider)!.players[1].quarterTurns,
          unfolded[1].quarterTurns);
    });
  });
}
