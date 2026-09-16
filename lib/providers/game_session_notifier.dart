// lib/providers/game_session_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';

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

  /// Le clamp `0..99` vit ici, pas côté appelant : `updateCounter` est le
  /// seul chemin d'écriture des compteurs (poison/énergie/taxe), et le
  /// tiroir (`showPlayerDrawer`) ne clampe que sa copie locale d'affichage —
  /// sans ce clamp serveur, un delta négatif sous zéro (ex. tap "−" sur un
  /// compteur déjà à 0) écrirait une valeur négative en session.
  void updateCounter(int playerId, String counterId, int value) {
    final session = state;
    if (session == null) return;
    final clamped = value.clamp(0, 99);
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
        cmdDamage[sourcePlayerId] = (cmdDamage[sourcePlayerId] ?? 0) + damage;
        final event = LifeEvent(
          delta: -damage,
          source: 'Commander: $sourceName',
          timestamp: gameDuration,
        );
        return p.copyWith(
          life: p.life - damage,
          commanderDamageReceived: cmdDamage,
          lifeHistory: [...p.lifeHistory, event],
        );
      }
      return p;
    }).toList();
    state = session.copyWith(players: players);
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

  void updateRotation(int playerId, int quarterTurns) {
    final session = state;
    if (session == null) return;
    final players = session.players.map((p) {
      if (p.playerId == playerId) return p.copyWith(quarterTurns: quarterTurns);
      return p;
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
