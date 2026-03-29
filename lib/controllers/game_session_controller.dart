// lib/controllers/game_session_controller.dart
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/models/player_config.dart';

class GameSessionController {
  GameSession? _session;
  GameSession? get session => _session;

  void startNewGame({
    required GameFormat format,
    required List<PlayerConfig> playerConfigs,
    List<String>? extraCounterIds,
    String? tag,
  }) {
    _session = GameSession.newGame(
      format: format,
      playerConfigs: playerConfigs,
      extraCounterIds: extraCounterIds,
      tag: tag,
    );
  }

  void updateLife(int playerId, int delta, {required Duration gameDuration}) {
    if (_session == null) return;
    final players = _session!.players.map((p) {
      if (p.playerId == playerId) {
        final event = LifeEvent(delta: delta, timestamp: gameDuration);
        return p.copyWith(
          life: p.life + delta,
          lifeHistory: [...p.lifeHistory, event],
        );
      }
      return p;
    }).toList();
    _session = _session!.copyWith(players: players);
  }

  void updateCounter(int playerId, String counterId, int value) {
    if (_session == null) return;
    final players = _session!.players.map((p) {
      if (p.playerId == playerId) {
        final counters = Map<String, int>.from(p.counters);
        counters[counterId] = value;
        return p.copyWith(counters: counters);
      }
      return p;
    }).toList();
    _session = _session!.copyWith(players: players);
  }

  void addCommanderDamage({
    required int targetPlayerId,
    required int sourcePlayerId,
    required int damage,
    required Duration gameDuration,
  }) {
    if (_session == null) return;
    final sourcePlayer = _session!.players
        .where((p) => p.playerId == sourcePlayerId)
        .firstOrNull;
    if (sourcePlayer == null) return;
    final sourceName = sourcePlayer.config.name;
    final players = _session!.players.map((p) {
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
    _session = _session!.copyWith(players: players);
  }

  void eliminatePlayer(int playerId, {required Duration atDuration}) {
    if (_session == null) return;
    _session = _session!.eliminatePlayer(playerId, atDuration: atDuration);
  }

  void toggleMonarch(int playerId) {
    if (_session == null) return;
    final currentMonarch =
        _session!.players.any((p) => p.playerId == playerId && p.isMonarch);
    final players = _session!.players.map((p) {
      if (p.playerId == playerId) return p.copyWith(isMonarch: !currentMonarch);
      return p.copyWith(isMonarch: false);
    }).toList();
    _session = _session!.copyWith(players: players);
  }

  void reorderPlayers(List<int> newOrder) {
    if (_session == null) return;
    _session = _session!.reorderPlayers(newOrder);
  }

  void updateRotation(int playerId, int quarterTurns) {
    if (_session == null) return;
    final players = _session!.players.map((p) {
      if (p.playerId == playerId) return p.copyWith(quarterTurns: quarterTurns);
      return p;
    }).toList();
    _session = _session!.copyWith(players: players);
  }

  void endGame() {
    if (_session == null) return;
    _session = _session!.copyWith(isActive: false);
  }

  void clear() {
    _session = null;
  }
}
