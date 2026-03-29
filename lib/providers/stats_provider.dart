import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/models/game_history_model.dart';
import 'package:magic_companion/models/game_stats.dart';
import 'package:magic_companion/providers/game_history_provider.dart';

final ownerStatsProvider = Provider<OwnerStats?>((ref) {
  final historyAsync = ref.watch(gameHistoryProvider);
  return historyAsync.whenOrNull(data: (games) {
    if (games.isEmpty) return null;
    final ownerName = _findOwnerName(games);
    if (ownerName == null) return null;
    return StatsCalculator.computeOwnerStats(ownerName, games);
  });
});

final deckStatsProvider = Provider<List<DeckStats>>((ref) {
  final historyAsync = ref.watch(gameHistoryProvider);
  return historyAsync.whenOrNull(data: (games) {
    final ownerName = _findOwnerName(games);
    if (ownerName == null) return <DeckStats>[];
    return StatsCalculator.computeDeckStats(ownerName, games);
  }) ?? [];
});

final formatStatsProvider = Provider<List<FormatStats>>((ref) {
  final historyAsync = ref.watch(gameHistoryProvider);
  return historyAsync.whenOrNull(data: (games) {
    final ownerName = _findOwnerName(games);
    if (ownerName == null) return <FormatStats>[];
    return StatsCalculator.computeFormatStats(ownerName, games);
  }) ?? [];
});

final opponentStatsProvider = Provider<List<OpponentStats>>((ref) {
  final historyAsync = ref.watch(gameHistoryProvider);
  return historyAsync.whenOrNull(data: (games) {
    final ownerName = _findOwnerName(games);
    if (ownerName == null) return <OpponentStats>[];
    return StatsCalculator.computeOpponentStats(ownerName, games);
  }) ?? [];
});

String? _findOwnerName(List<GameHistoryItem> games) {
  for (final game in games) {
    for (final player in game.playerStates) {
      if (player.type == 'owner') return player.name;
    }
  }
  if (games.isEmpty) return null;
  final winCounts = <String, int>{};
  for (final game in games) {
    winCounts[game.winnerName] = (winCounts[game.winnerName] ?? 0) + 1;
  }
  return winCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}
