// Fichier : lib/models/game_stats.dart

import 'package:magic_companion/models/game_history_model.dart';

/// Global statistics for the owner player.
class OwnerStats {
  final int totalGames;
  final int wins;
  final double winrate;
  final int currentStreak;
  final int bestStreak;

  const OwnerStats({
    required this.totalGames,
    required this.wins,
    required this.winrate,
    required this.currentStreak,
    required this.bestStreak,
  });
}

/// Statistics grouped by deck name.
class DeckStats {
  final String deckName;
  final int games;
  final int wins;
  final double winrate;

  const DeckStats({
    required this.deckName,
    required this.games,
    required this.wins,
    required this.winrate,
  });
}

/// Statistics grouped by game format.
class FormatStats {
  final String format;
  final int games;
  final int wins;
  final double winrate;
  final double avgDurationSeconds;

  const FormatStats({
    required this.format,
    required this.games,
    required this.wins,
    required this.winrate,
    required this.avgDurationSeconds,
  });
}

/// Statistics against a specific opponent.
class OpponentStats {
  final String opponentName;
  final int gamesAgainst;
  final int winsAgainst;
  final double winrateAgainst;
  final DateTime? lastPlayed;

  const OpponentStats({
    required this.opponentName,
    required this.gamesAgainst,
    required this.winsAgainst,
    required this.winrateAgainst,
    this.lastPlayed,
  });
}

/// Utility class with static methods to compute stats from a list of [GameHistoryItem].
class StatsCalculator {
  StatsCalculator._();

  /// Returns global [OwnerStats] for [ownerName] across all [games].
  static OwnerStats computeOwnerStats(
    String ownerName,
    List<GameHistoryItem> games,
  ) {
    final ownerGames = games.where(_participates(ownerName)).toList();
    final totalGames = ownerGames.length;
    final wins = ownerGames.where((g) => g.winnerName == ownerName).length;
    final winrate = totalGames == 0 ? 0.0 : wins / totalGames;

    // Streaks — walk games in chronological order (oldest first)
    final sorted = [...ownerGames]..sort((a, b) => a.date.compareTo(b.date));
    int currentStreak = 0;
    int bestStreak = 0;
    int streak = 0;
    for (final game in sorted) {
      if (game.winnerName == ownerName) {
        streak++;
        if (streak > bestStreak) bestStreak = streak;
      } else {
        streak = 0;
      }
    }
    // currentStreak = trailing wins from end of sorted list
    for (final game in sorted.reversed) {
      if (game.winnerName == ownerName) {
        currentStreak++;
      } else {
        break;
      }
    }

    return OwnerStats(
      totalGames: totalGames,
      wins: wins,
      winrate: winrate,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
    );
  }

  /// Returns [DeckStats] for each deck played by [ownerName].
  /// Games without a deckName for the owner are excluded.
  static List<DeckStats> computeDeckStats(
    String ownerName,
    List<GameHistoryItem> games,
  ) {
    final Map<String, ({int games, int wins})> byDeck = {};

    for (final game in games) {
      final ownerSnapshot = _ownerSnapshot(ownerName, game);
      if (ownerSnapshot == null) continue;
      final deckName = ownerSnapshot.deckName;
      if (deckName == null || deckName.isEmpty) continue;

      final prev = byDeck[deckName] ?? (games: 0, wins: 0);
      final isWin = game.winnerName == ownerName ? 1 : 0;
      byDeck[deckName] = (games: prev.games + 1, wins: prev.wins + isWin);
    }

    return byDeck.entries.map((e) {
      final g = e.value.games;
      final w = e.value.wins;
      return DeckStats(
        deckName: e.key,
        games: g,
        wins: w,
        winrate: g == 0 ? 0.0 : w / g,
      );
    }).toList();
  }

  /// Returns [FormatStats] for each format in which [ownerName] participated.
  static List<FormatStats> computeFormatStats(
    String ownerName,
    List<GameHistoryItem> games,
  ) {
    final Map<String, ({int games, int wins, int totalDuration})> byFormat = {};

    for (final game in games) {
      if (!_participates(ownerName)(game)) continue;
      final format = game.format;
      final prev = byFormat[format] ?? (games: 0, wins: 0, totalDuration: 0);
      final isWin = game.winnerName == ownerName ? 1 : 0;
      byFormat[format] = (
        games: prev.games + 1,
        wins: prev.wins + isWin,
        totalDuration: prev.totalDuration + game.durationSeconds,
      );
    }

    return byFormat.entries.map((e) {
      final g = e.value.games;
      final w = e.value.wins;
      final dur = e.value.totalDuration;
      return FormatStats(
        format: e.key,
        games: g,
        wins: w,
        winrate: g == 0 ? 0.0 : w / g,
        avgDurationSeconds: g == 0 ? 0.0 : dur / g,
      );
    }).toList();
  }

  /// Returns [OpponentStats] for every opponent [ownerName] has faced.
  static List<OpponentStats> computeOpponentStats(
    String ownerName,
    List<GameHistoryItem> games,
  ) {
    final Map<String, ({int games, int wins, DateTime? lastPlayed})> byOpponent =
        {};

    for (final game in games) {
      if (!_participates(ownerName)(game)) continue;
      final isWin = game.winnerName == ownerName;

      for (final player in game.playerStates) {
        if (player.name == ownerName) continue;
        final opponent = player.name;
        final prev = byOpponent[opponent] ??
            (games: 0, wins: 0, lastPlayed: null);
        final lastPlayed = prev.lastPlayed == null ||
                game.date.isAfter(prev.lastPlayed!)
            ? game.date
            : prev.lastPlayed;
        byOpponent[opponent] = (
          games: prev.games + 1,
          wins: prev.wins + (isWin ? 1 : 0),
          lastPlayed: lastPlayed,
        );
      }
    }

    return byOpponent.entries.map((e) {
      final g = e.value.games;
      final w = e.value.wins;
      return OpponentStats(
        opponentName: e.key,
        gamesAgainst: g,
        winsAgainst: w,
        winrateAgainst: g == 0 ? 0.0 : w / g,
        lastPlayed: e.value.lastPlayed,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static bool Function(GameHistoryItem) _participates(String name) =>
      (game) => game.playerStates.any((p) => p.name == name);

  static PlayerHistorySnapshot? _ownerSnapshot(
    String ownerName,
    GameHistoryItem game,
  ) {
    try {
      return game.playerStates.firstWhere((p) => p.name == ownerName);
    } catch (_) {
      return null;
    }
  }
}
