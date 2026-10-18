// lib/providers/game_session_notifier.dart
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/providers/counter_catalog_provider.dart';

/// Source de vérité unique de la partie en cours.
///
/// Remplace GameSessionController, que la page instanciait à la main tout en
/// gardant une copie locale resynchronisée manuellement. Ici l'état vit dans
/// le notifier et nulle part ailleurs.
class GameSessionNotifier extends Notifier<GameSession?> {
  @override
  GameSession? build() => null;

  void startNewGame({
    required GameFormat format,
    required List<PlayerConfig> playerConfigs,
    List<String>? extraCounterIds,
    String? tag,
  }) {
    state = GameSession.newGame(
      format: format,
      playerConfigs: playerConfigs,
      extraCounterIds: extraCounterIds,
      tag: tag,
    );
  }

  void updateLife(int playerId, int delta, {required Duration gameDuration}) {
    final session = state;
    if (session == null) return;
    final players = session.players.map((p) {
      if (p.playerId == playerId) {
        final event = LifeEvent(delta: delta, timestamp: gameDuration);
        return p.copyWith(
          life: p.life + delta,
          lifeHistory: [...p.lifeHistory, event],
        );
      }
      return p;
    }).toList();
    state = session.copyWith(players: players);
  }

  /// Le clamp vit ici, pas côté appelant : `updateCounter` est le seul
  /// chemin d'écriture des compteurs, et le tiroir (`showPlayerDrawer`) ne
  /// clampe que sa copie locale d'affichage — sans ce clamp serveur, un
  /// delta négatif sous zéro (ex. tap "−" sur un compteur déjà à 0)
  /// écrirait une valeur négative en session.
  ///
  /// Le plafond vient de `CounterType.maxValue` (lot 5, tâche 3) — résolu
  /// via `counterTypeByIdProvider`, donc y compris pour un compteur
  /// personnalisé chargé dans le catalogue — et non plus d'une constante
  /// écrite ici : `poison` (`maxValue: 10`) sature désormais à 10, pas à
  /// 99. Un `counterId` sans `CounterType` connu (catalogue pas encore
  /// chargé, id obsolète) ou dont `maxValue` est `null` (illimité, ex.
  /// `energy`) retombe sur 99, le plafond historique.
  void updateCounter(int playerId, String counterId, int value) {
    final session = state;
    if (session == null) return;
    final maxValue =
        ref.read(counterTypeByIdProvider(counterId))?.maxValue ?? 99;
    final clamped = value.clamp(0, maxValue);
    final players = session.players.map((p) {
      if (p.playerId == playerId) {
        final counters = Map<String, int>.from(p.counters);
        counters[counterId] = clamped;
        return p.copyWith(counters: counters);
      }
      return p;
    }).toList();
    state = session.copyWith(players: players);
  }

  /// Le plancher `0` (comme `updateCounter` ci-dessus) vit ici, pas côté
  /// appelant : c'est le seul chemin d'écriture de `commanderDamageReceived`,
  /// et sans ce plancher serveur, un delta négatif sous zéro (ex. tap "−"
  /// sur une source déjà à 0 dans la grille du tiroir) écrirait une valeur
  /// négative en session.
  ///
  /// Le point de vie ne suit que le delta RÉELLEMENT appliqué à la carte des
  /// dégâts, pas le `damage` brut demandé : si le plancher absorbe tout ou
  /// partie du décrément (ex. total déjà à 0), retirer `damage` complet de
  /// la vie rendrait un point de vie gratuit qui ne correspond à aucun
  /// dégât annulé.
  void addCommanderDamage({
    required int targetPlayerId,
    required int sourcePlayerId,
    required int damage,
    required Duration gameDuration,
  }) {
    final session = state;
    if (session == null) return;
    final sourcePlayer =
        session.players.where((p) => p.playerId == sourcePlayerId).firstOrNull;
    if (sourcePlayer == null) return;
    final sourceName = sourcePlayer.config.name;
    final players = session.players.map((p) {
      if (p.playerId == targetPlayerId) {
        final cmdDamage = Map<int, int>.from(p.commanderDamageReceived);
        final current = cmdDamage[sourcePlayerId] ?? 0;
        // Plancher à 0 uniquement : aucun plafond n'existe pour un total de
        // dégâts de commandant (contrairement aux compteurs, plafonnés à 99
        // dans updateCounter).
        final updated = max(0, current + damage);
        final appliedDelta = updated - current;
        if (appliedDelta == 0) return p; // rien à appliquer (plancher atteint)
        cmdDamage[sourcePlayerId] = updated;
        final event = LifeEvent(
          delta: -appliedDelta,
          source: 'Commander: $sourceName',
          timestamp: gameDuration,
        );
        return p.copyWith(
          life: p.life - appliedDelta,
          commanderDamageReceived: cmdDamage,
          lifeHistory: [...p.lifeHistory, event],
        );
      }
      return p;
    }).toList();
    state = session.copyWith(players: players);
  }

  /// Active [id] dans la partie en cours (lot 5, tâche 4) : l'ajoute à
  /// `activeCounterIds` -- idempotent, un id déjà actif n'est pas dupliqué.
  ///
  /// [isCustom] ajoute aussi [id] à `customCounterIds` : c'est le chemin
  /// emprunté par la création depuis le tiroir (décision 2 du rapport de
  /// tâche : créer un compteur l'active immédiatement dans la partie en
  /// cours), PAS par la réactivation d'un compteur intégré déjà membre du
  /// catalogue -- son défaut `false` évite qu'une réactivation banale
  /// (`commander_tax` retiré puis remis) ne le fasse passer pour
  /// personnalisé.
  void activateCounter(String id, {bool isCustom = false}) {
    final session = state;
    if (session == null) return;
    if (session.activeCounterIds.contains(id)) return;
    state = session.copyWith(
      activeCounterIds: [...session.activeCounterIds, id],
      customCounterIds:
          isCustom ? [...session.customCounterIds, id] : session.customCounterIds,
    );
  }

  /// Retire [id] des compteurs actifs de la partie en cours (lot 5, tâche
  /// 4) -- et de `customCounterIds` s'il y était, pour que ce dernier reste
  /// un sous-ensemble cohérent du premier.
  ///
  /// Décision 1 du rapport de tâche (préférence du brief) : NE TOUCHE PAS
  /// à `PlayerState.counters` -- la valeur de chaque joueur pour ce
  /// compteur est conservée, pas effacée, pour être retrouvée intacte si le
  /// même id est réactivé plus tard dans la même partie. L'effacement
  /// serait destructif et irréversible en cours de partie ; la conservation
  /// ne coûte que quelques octets dans le snapshot.
  ///
  /// Ne lève pas si [id] est absent (no-op) -- même contrat que
  /// `CounterTypeService.deleteCustomType`.
  void deactivateCounter(String id) {
    final session = state;
    if (session == null) return;
    state = session.copyWith(
      activeCounterIds:
          session.activeCounterIds.where((c) => c != id).toList(),
      customCounterIds:
          session.customCounterIds.where((c) => c != id).toList(),
    );
  }

  void eliminatePlayer(int playerId, {required Duration atDuration}) {
    final session = state;
    if (session == null) return;
    state = session.eliminatePlayer(playerId, atDuration: atDuration);
  }

  void toggleMonarch(int playerId) {
    final session = state;
    if (session == null) return;
    final currentMonarch =
        session.players.any((p) => p.playerId == playerId && p.isMonarch);
    final players = session.players.map((p) {
      if (p.playerId == playerId) return p.copyWith(isMonarch: !currentMonarch);
      return p.copyWith(isMonarch: false);
    }).toList();
    state = session.copyWith(players: players);
  }

  void reorderPlayers(List<int> newOrder) {
    final session = state;
    if (session == null) return;
    state = session.reorderPlayers(newOrder);
  }

  /// Pose une rotation pour [playerId].
  ///
  /// Ruling 28 : par défaut, [manual] marque `PlayerState.manualRotation`,
  /// qui protège désormais la valeur contre tout semis automatique ultérieur
  /// (`seedRotationsFromSeats`), quelle que soit la disposition à venir --
  /// pliage, dépliage, rotation de l'appareil.
  ///
  /// Ruling 29 : [manual] a un paramètre, parce que tous les appels ne
  /// décrivent pas un choix d'ANGLE. `_onReorderPlayers` (glisser-déposer
  /// qui change un joueur de place) appelle cette méthode avec
  /// `manual: false` pour les deux zones déplacées : la rotation qu'il pose
  /// alors n'est que le défaut du nouveau siège -- exactement ce qu'un
  /// semis aurait calculé -- et PAS un angle que l'utilisateur a choisi.
  /// `manual: false` EFFACE le marqueur plutôt que de simplement s'abstenir
  /// d'en poser un : un joueur qui change de place autour de la table perd
  /// la pertinence de son éventuel ancien réglage (il décrivait son
  /// ANCIENNE place), donc la zone redevient sensible au prochain semis
  /// (ex. un pliage qui suit le reorder).
  ///
  /// Défaut à `true`, DÉLIBÉRÉMENT : si un futur appelant (tâche 8 : les
  /// quatre flèches par zone, les presets d'orientation déjà en place dans
  /// `_applyOrientationPreset`) omet ce paramètre -- ce qu'ils doivent
  /// faire, ce sont de vrais choix d'angle -- le pire résultat est qu'une
  /// zone garde un angle qu'elle n'a pas besoin de garder. L'erreur dans
  /// l'autre sens (un `true` oublié qui devient `false` par défaut) ferait
  /// PERDRE à l'utilisateur un réglage qu'il a posé consciemment --
  /// nettement plus désagréable. `_onReorderPlayers` est donc le seul
  /// appelant à passer `manual: false` explicitement ; tous les autres
  /// gardent le défaut sans jamais connaître ce paramètre.
  void updateRotation(int playerId, int quarterTurns, {bool manual = true}) {
    final session = state;
    if (session == null) return;
    final players = session.players.map((p) {
      if (p.playerId == playerId) {
        return p.copyWith(quarterTurns: quarterTurns, manualRotation: manual);
      }
      return p;
    }).toList();
    state = session.copyWith(players: players);
  }

  /// Applique aux joueurs NON MARQUÉS les rotations que leur donne la
  /// disposition actuellement rendue.
  ///
  /// La rotation n'a qu'un seul propriétaire (spec §1.4, et §2.1 de la spec
  /// table multijoueur v2) : `TableSeat.quarterTurns`, dérivé du côté de
  /// table par `tableLayoutFor`/`seatsForArrangement` (Tâche 3). Ce point
  /// d'entrée existe pour que `PlayerState.quarterTurns` reste un CACHE de
  /// cette dérivation pour tout joueur qui n'a jamais choisi la sienne à la
  /// main : `life_counter_page.dart` le rappelle chaque fois que la
  /// disposition RÉELLEMENT rendue change (démarrage de partie, rotation de
  /// l'appareil, pliage/dépliage, changement d'effectif) -- jamais à chaque
  /// frame, voir `_seedRotationsIfLayoutChanged` côté page.
  ///
  /// [order] donne les `playerId` dans l'ordre d'AFFICHAGE -- celui utilisé
  /// pour construire les zones passées à `AdaptiveGrid`
  /// (`_orderedPlayers.playerId`), PAS celui de `state.players`, qui reste
  /// trié par `playerId` canonique. [seats] doit être indexé pareil :
  /// `seats[i]` est le siège du joueur `order[i]`. Semer par position
  /// canonique au lieu de l'ordre d'affichage assignerait la rotation du
  /// siège 0 au joueur `playerId == 0` même quand un glisser-déposer l'a
  /// affiché ailleurs -- exactement la dérive que `_onReorderPlayers` (dans
  /// la page) évite déjà en passant par `order[displayIndex]`.
  ///
  /// Ruling 28 (revient sur la décision de la tâche 4, qui faisait l'inverse
  /// -- voir git blame si besoin d'archéologie) : un joueur dont
  /// `manualRotation == true` (posé par `updateRotation(..., manual: true)`,
  /// son défaut) n'est JAMAIS touché ici, quelle que soit la disposition
  /// reçue. Il garde la rotation qu'il a choisie jusqu'à ce que ce marqueur
  /// se réinitialise -- deux chemins, pas un seul : une nouvelle partie
  /// (`GameSession.newGame` reconstruit des `PlayerState` neufs) ou un
  /// changement de PLACE à la table (ruling 29 : `_onReorderPlayers` appelle
  /// `updateRotation(..., manual: false)` pour les deux zones déplacées,
  /// précisément pour les rendre de nouveau sensibles à cette méthode). Un
  /// joueur non marqué continue, lui, de suivre la dérivation géométrique à
  /// chaque disposition différente.
  void seedRotationsFromSeats(List<int> order, List<TableSeat> seats) {
    final session = state;
    if (session == null) return;
    if (order.isEmpty || order.length != seats.length) return;
    final rotationByPlayerId = {
      for (int i = 0; i < order.length; i++) order[i]: seats[i].quarterTurns,
    };
    final players = session.players.map((p) {
      if (p.manualRotation) return p; // Ruling 28 : jamais écrasé.
      final quarterTurns = rotationByPlayerId[p.playerId];
      if (quarterTurns == null || quarterTurns == p.quarterTurns) return p;
      return p.copyWith(quarterTurns: quarterTurns);
    }).toList();
    state = session.copyWith(players: players);
  }

  /// Démarre le chronomètre de la partie. La durée est portée par la session
  /// pour survivre à un redémarrage de l'application (elle vivait auparavant
  /// dans le State de la page et était perdue).
  void startTimer() {
    final session = state;
    if (session == null) return;
    state = session.copyWith(
      startedAt: DateTime.now(),
      duration: Duration.zero,
      isActive: true,
    );
  }

  /// Avance le chronomètre d'une seconde.
  void tick() {
    final session = state;
    if (session == null || !session.isActive) return;
    state = session.copyWith(
      duration: session.duration + const Duration(seconds: 1),
    );
  }

  void stopTimer() {
    final session = state;
    if (session == null) return;
    state = session.copyWith(isActive: false);
  }

  void endGame() {
    final session = state;
    if (session == null) return;
    state = session.copyWith(isActive: false);
  }

  /// Remplace la session courante (reprise après crash, chargement de snapshot).
  void restoreSession(GameSession session) {
    state = session;
  }

  void clear() {
    state = null;
  }
}

final gameSessionNotifierProvider =
    NotifierProvider<GameSessionNotifier, GameSession?>(
  GameSessionNotifier.new,
);
