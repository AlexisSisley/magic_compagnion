// Fichier : lib/models/player_model.dart

import 'package:magic_companion/models/profile_model.dart';

class Player {
  final int id;
  String name;
  int life;
  int colorValue;
  String? backgroundImagePath;
  String? secondaryBackgroundImagePath;

  Map<int, int> commanderDamageReceived;
  int poison;
  int energy;
  int commanderCastCount;
  bool isMonarch;
  int quarterTurns;

  /// Lot 5, tâche 4 (câblage manquant) : collection générique des compteurs
  /// actifs de la session pour ce joueur (id de `CounterType` -> valeur),
  /// AJOUTÉE à côté des trois champs nommés ci-dessus plutôt qu'à leur
  /// place. `PlayerZone` résout désormais le résumé de la poignée
  /// (`CounterSummary`) à partir de CETTE collection, pas des trois champs
  /// ci-dessus (voir son commentaire) : elle porte tout compteur actif de
  /// la session, intégré ou personnalisé, avec sa valeur — y compris zéro.
  ///
  /// Condition VÉRIFIABLE de disparition des trois champs ci-dessus (pas
  /// un simple « hors mandat de ce lot ») : ils restent tant que
  /// `PlayerHistorySnapshot` (lib/models/game_history_model.dart), rempli
  /// par `_finalizeGameSave` (lib/pages/life_counter/life_counter_page.dart),
  /// les lit directement sur `Player` plutôt que sur `counters` ou sur
  /// `PlayerState.counters` en amont. Cette lecture relève du découpage de
  /// `life_counter_page.dart` prévu au lot 7 — c'est cette découpe-là qui
  /// devra faire disparaître `poison`/`energy`/`commanderCastCount`, pas ce
  /// lot-ci.
  ///
  /// `_toLegacyPlayer` (life_counter_page.dart) dérive désormais les trois
  /// champs de CETTE collection (déjà filtrée par
  /// `GameSession.activeCounterIds`), jamais de `PlayerState.counters`
  /// directement — une seule source, un seul filtre, pour que la poignée
  /// et l'historique de fin de partie ne racontent jamais deux parties
  /// différentes pour un même compteur désactivé (ronde de correction 1,
  /// tâche 4 : un compteur retiré des actifs compte 0 pour tous les
  /// consommateurs, y compris l'historique, même si `PlayerState.counters`
  /// conserve sa valeur pour une réactivation ultérieure, décision 1).
  Map<String, int> counters;

  /// Gallery of saved commanders — allows quick artwork switching in-game.
  List<CommanderEntry> commanderGallery;

  Player({
    required this.id,
    this.name = 'Joueur',
    required this.life,
    this.colorValue = 0xFF000000,
    this.backgroundImagePath,
    this.secondaryBackgroundImagePath,
    required this.commanderDamageReceived,
    this.poison = 0,
    this.energy = 0,
    this.commanderCastCount = 0,
    this.counters = const {},
    this.isMonarch = false,
    this.quarterTurns = 0,
    this.commanderGallery = const [],
  });

  int get totalCommanderDamage => commanderDamageReceived.values.fold(0, (sum, element) => sum + element);
}