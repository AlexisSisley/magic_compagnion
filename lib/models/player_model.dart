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
  /// place — voir `_toLegacyPlayer` (lib/pages/life_counter/life_counter_page.dart)
  /// et `PlayerHistorySnapshot` (lib/models/game_history_model.dart, via
  /// `_finalizeGameSave`) qui lisent encore `poison`/`energy`/
  /// `commanderCastCount` directement ; ce lot n'a pas mandat de démonter
  /// le modèle `Player` legacy, seulement de le faire passer les compteurs
  /// personnalisés. `PlayerZone` résout désormais le résumé de la poignée
  /// (`CounterSummary`) à partir de CETTE collection, pas des trois champs
  /// ci-dessus (voir son commentaire) : elle porte tout compteur actif de
  /// la session, intégré ou personnalisé, avec sa valeur — y compris zéro.
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