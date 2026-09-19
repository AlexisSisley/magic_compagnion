// Fichier : test/support/test_game_session.dart
// Fabrique de GameSession pour les tests. Partagee entre le provider de
// partie en cours et l'Accueil, qui en ont besoin des deux cotes : le
// dupliquer les laisserait deriver l'un de l'autre.

import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';

/// Une partie de Commander a deux joueurs, conforme au modele du depot.
///
/// Passe par `GameSession.newGame` plutot que par le constructeur : c'est le
/// chemin que prend une vraie partie, donc les champs derives (vies de
/// depart, etats de joueur) valent ce qu'ils vaudraient en usage reel.
GameSession buildTestSession({String tag = 'test'}) {
  final commander =
      GameFormat.builtInFormats.firstWhere((f) => f.id == 'commander');

  return GameSession.newGame(
    format: commander,
    playerConfigs: const [
      PlayerConfig(id: 'p1', name: 'Alex', type: PlayerType.owner),
      PlayerConfig(id: 'p2', name: 'Max', type: PlayerType.guest),
    ],
    tag: tag,
  );
}
