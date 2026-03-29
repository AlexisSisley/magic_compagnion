// test/models/game_stats_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_history_model.dart';
import 'package:magic_companion/models/game_stats.dart';

void main() {
  group('Enriched PlayerHistorySnapshot', () {
    test('toJson and fromJson with new fields', () {
      final snapshot = PlayerHistorySnapshot(
        name: 'Alex', life: 32, poison: 3, commanderDamageTaken: 12,
        type: 'owner', deckName: 'Atraxa Superfriends',
        commanderNames: ['Atraxa', 'Thrasios'], energy: 5, commanderTax: 4, isEliminated: false,
      );
      final json = snapshot.toJson();
      final restored = PlayerHistorySnapshot.fromJson(json);
      expect(restored.type, 'owner');
      expect(restored.deckName, 'Atraxa Superfriends');
      expect(restored.commanderNames, hasLength(2));
      expect(restored.energy, 5);
      expect(restored.commanderTax, 4);
      expect(restored.isEliminated, false);
    });

    test('toJson includes all new fields', () {
      final snapshot = PlayerHistorySnapshot(
        name: 'Alex', life: 20, poison: 0, commanderDamageTaken: 0,
        type: 'owner', deckName: 'Korvold', commanderNames: ['Korvold'],
        energy: 2, commanderTax: 2, isEliminated: true,
        eliminatedAtSeconds: 600, eliminationRank: 3,
      );
      final json = snapshot.toJson();
      expect(json['type'], 'owner');
      expect(json['deckName'], 'Korvold');
      expect(json['commanderNames'], ['Korvold']);
      expect(json['energy'], 2);
      expect(json['commanderTax'], 2);
      expect(json['isEliminated'], true);
      expect(json['eliminatedAtSeconds'], 600);
      expect(json['eliminationRank'], 3);
    });

    test('fromJson roundtrip preserves eliminatedAtSeconds and eliminationRank', () {
      final snapshot = PlayerHistorySnapshot(
        name: 'Bob', life: 0, poison: 0, commanderDamageTaken: 0,
        isEliminated: true, eliminatedAtSeconds: 1234, eliminationRank: 2,
      );
      final restored = PlayerHistorySnapshot.fromJson(snapshot.toJson());
      expect(restored.isEliminated, true);
      expect(restored.eliminatedAtSeconds, 1234);
      expect(restored.eliminationRank, 2);
    });

    test('backward compatible with old snapshots missing new fields', () {
      final oldJson = {'name': 'Max', 'life': 0, 'poison': 10, 'commanderDamageTaken': 0};
      final restored = PlayerHistorySnapshot.fromJson(oldJson);
      expect(restored.name, 'Max');
      expect(restored.type, isNull);
      expect(restored.deckName, isNull);
      expect(restored.commanderNames, isEmpty);
      expect(restored.energy, 0);
      expect(restored.isEliminated, false);
    });

    test('backward compatible with old snapshots — eliminatedAtSeconds defaults to null', () {
      final oldJson = {'name': 'Sara', 'life': 20, 'poison': 0, 'commanderDamageTaken': 0};
      final restored = PlayerHistorySnapshot.fromJson(oldJson);
      expect(restored.eliminatedAtSeconds, isNull);
      expect(restored.eliminationRank, isNull);
      expect(restored.commanderTax, 0);
    });

    test('default commanderNames is empty list', () {
      final snapshot = PlayerHistorySnapshot(
        name: 'Test', life: 20, poison: 0, commanderDamageTaken: 0,
      );
      expect(snapshot.commanderNames, isEmpty);
      expect(snapshot.commanderNames, isA<List<String>>());
    });
  });

  group('StatsCalculator', () {
    final games = [
      _makeGame(winner: 'Alex', deckName: 'Atraxa', format: 'Commander', players: ['Alex', 'Max', 'Sarah']),
      _makeGame(winner: 'Max', format: 'Commander', players: ['Alex', 'Max', 'Sarah']),
      _makeGame(winner: 'Alex', deckName: 'Korvold', format: 'Commander', players: ['Alex', 'Max']),
      _makeGame(winner: 'Alex', deckName: 'Atraxa', format: 'Standard', players: ['Alex', 'Sarah']),
      _makeGame(winner: 'Sarah', format: 'Commander', players: ['Alex', 'Sarah', 'Leo']),
    ];

    test('calculates global winrate for owner', () {
      final stats = StatsCalculator.computeOwnerStats('Alex', games);
      expect(stats.totalGames, 5);
      expect(stats.wins, 3);
      expect(stats.winrate, closeTo(0.6, 0.01));
    });

    test('computeOwnerStats totalGames is 0 when player has no games', () {
      final stats = StatsCalculator.computeOwnerStats('Unknown', games);
      expect(stats.totalGames, 0);
      expect(stats.wins, 0);
      expect(stats.winrate, 0.0);
    });

    test('calculates bestStreak and currentStreak', () {
      final stats = StatsCalculator.computeOwnerStats('Alex', games);
      expect(stats.bestStreak, greaterThanOrEqualTo(1));
      expect(stats.currentStreak, greaterThanOrEqualTo(0));
    });

    test('calculates winrate by deck', () {
      final deckStats = StatsCalculator.computeDeckStats('Alex', games);
      final atraxa = deckStats.firstWhere((d) => d.deckName == 'Atraxa');
      expect(atraxa.games, 2);
      expect(atraxa.wins, 2);
      expect(atraxa.winrate, 1.0);
      final korvold = deckStats.firstWhere((d) => d.deckName == 'Korvold');
      expect(korvold.games, 1);
      expect(korvold.wins, 1);
    });

    test('computeDeckStats excludes games without deckName', () {
      final deckStats = StatsCalculator.computeDeckStats('Alex', games);
      // The game where Max wins and Alex has no deck should not appear as empty-name deck
      expect(deckStats.any((d) => d.deckName.isEmpty), isFalse);
    });

    test('computeDeckStats returns empty list for unknown player', () {
      final deckStats = StatsCalculator.computeDeckStats('Unknown', games);
      expect(deckStats, isEmpty);
    });

    test('calculates winrate by format', () {
      final formatStats = StatsCalculator.computeFormatStats('Alex', games);
      final commander = formatStats.firstWhere((f) => f.format == 'Commander');
      expect(commander.games, 4);
      expect(commander.wins, 2);
    });

    test('computeFormatStats winrate is correct for Standard', () {
      final formatStats = StatsCalculator.computeFormatStats('Alex', games);
      final standard = formatStats.firstWhere((f) => f.format == 'Standard');
      expect(standard.games, 1);
      expect(standard.wins, 1);
      expect(standard.winrate, 1.0);
    });

    test('computeFormatStats avgDurationSeconds is positive', () {
      final formatStats = StatsCalculator.computeFormatStats('Alex', games);
      for (final f in formatStats) {
        expect(f.avgDurationSeconds, greaterThan(0));
      }
    });

    test('calculates opponent stats', () {
      final oppStats = StatsCalculator.computeOpponentStats('Alex', games);
      final max = oppStats.firstWhere((o) => o.opponentName == 'Max');
      expect(max.gamesAgainst, 3);
      expect(max.winsAgainst, 2);
    });

    test('computeOpponentStats winrateAgainst is correct', () {
      final oppStats = StatsCalculator.computeOpponentStats('Alex', games);
      final max = oppStats.firstWhere((o) => o.opponentName == 'Max');
      expect(max.winrateAgainst, closeTo(2 / 3, 0.01));
    });

    test('computeOpponentStats lastPlayed is not null', () {
      final oppStats = StatsCalculator.computeOpponentStats('Alex', games);
      for (final o in oppStats) {
        expect(o.lastPlayed, isNotNull);
      }
    });

    test('computeOpponentStats does not include owner as opponent', () {
      final oppStats = StatsCalculator.computeOpponentStats('Alex', games);
      expect(oppStats.any((o) => o.opponentName == 'Alex'), isFalse);
    });
  });
}

GameHistoryItem _makeGame({
  required String winner,
  String? deckName,
  required String format,
  required List<String> players,
}) {
  return GameHistoryItem(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    date: DateTime.now(),
    durationSeconds: 1800,
    winnerName: winner,
    format: format,
    winMethod: 'normal',
    playerStates: players.map((name) => PlayerHistorySnapshot(
      name: name, life: 20, poison: 0, commanderDamageTaken: 0,
      deckName: name == 'Alex' ? deckName : null,
      type: name == 'Alex' ? 'owner' : 'guest',
    )).toList(),
  );
}
