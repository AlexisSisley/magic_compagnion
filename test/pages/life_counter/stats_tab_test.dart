// Test : lib/pages/life_counter/stats_tab.dart (Life Counter v2 - Task 19)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/models/game_stats.dart';
import 'package:magic_companion/pages/life_counter/stats_tab.dart';
import 'package:magic_companion/providers/stats_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildWidget({
  OwnerStats? ownerStats,
  List<DeckStats> deckStats = const [],
  List<OpponentStats> opponentStats = const [],
  List<FormatStats> formatStats = const [],
}) {
  return ProviderScope(
    overrides: [
      ownerStatsProvider.overrideWithValue(ownerStats),
      deckStatsProvider.overrideWithValue(deckStats),
      opponentStatsProvider.overrideWithValue(opponentStats),
      formatStatsProvider.overrideWithValue(formatStats),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: StatsTab(),
      ),
    ),
  );
}

const _ownerWith10Games = OwnerStats(
  totalGames: 10,
  wins: 6,
  winrate: 0.6,
  currentStreak: 2,
  bestStreak: 4,
);

final _deckStatsList = [
  const DeckStats(deckName: 'Atraxa', games: 5, wins: 3, winrate: 0.6),
  const DeckStats(deckName: 'Korvold', games: 5, wins: 3, winrate: 0.6),
];

final _opponentStatsList = [
  const OpponentStats(
    opponentName: 'Alice',
    gamesAgainst: 4,
    winsAgainst: 3,
    winrateAgainst: 0.75,
  ),
  const OpponentStats(
    opponentName: 'Bob',
    gamesAgainst: 3,
    winsAgainst: 1,
    winrateAgainst: 0.33,
  ),
];

final _formatStatsList = [
  const FormatStats(
    format: 'Commander',
    games: 7,
    wins: 4,
    winrate: 0.57,
    avgDurationSeconds: 1800,
  ),
  const FormatStats(
    format: 'Standard',
    games: 3,
    wins: 2,
    winrate: 0.67,
    avgDurationSeconds: 900,
  ),
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('StatsTab - empty state', () {
    testWidgets('affiche le message vide quand aucune stat disponible',
        (tester) async {
      await tester.pumpWidget(_buildWidget());
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Pas encore de statistiques. Jouez des parties pour commencer !'),
        findsOneWidget,
      );
    });

    testWidgets('n\'affiche pas les sections quand les stats sont nulles',
        (tester) async {
      await tester.pumpWidget(_buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Résumé'), findsNothing);
      expect(find.text('Par Deck'), findsNothing);
      expect(find.text('Par Adversaire'), findsNothing);
      expect(find.text('Par Format'), findsNothing);
    });
  });

  group('StatsTab - section Résumé', () {
    testWidgets('affiche le titre de section Résumé', (tester) async {
      await tester.pumpWidget(_buildWidget(ownerStats: _ownerWith10Games));
      await tester.pumpAndSettle();

      expect(find.text('Résumé'), findsOneWidget);
    });

    testWidgets('affiche le nombre total de parties', (tester) async {
      await tester.pumpWidget(_buildWidget(ownerStats: _ownerWith10Games));
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('affiche le winrate en pourcentage', (tester) async {
      await tester.pumpWidget(_buildWidget(ownerStats: _ownerWith10Games));
      await tester.pumpAndSettle();

      expect(find.text('60%'), findsWidgets);
    });

    testWidgets('affiche le nombre de victoires', (tester) async {
      await tester.pumpWidget(_buildWidget(ownerStats: _ownerWith10Games));
      await tester.pumpAndSettle();

      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('affiche une LinearProgressIndicator', (tester) async {
      await tester.pumpWidget(_buildWidget(ownerStats: _ownerWith10Games));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsAtLeastNWidgets(1));
    });
  });

  group('StatsTab - section Par Deck', () {
    testWidgets('affiche le titre de section Par Deck', (tester) async {
      await tester.pumpWidget(_buildWidget(
        ownerStats: _ownerWith10Games,
        deckStats: _deckStatsList,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Par Deck'), findsOneWidget);
    });

    testWidgets('affiche les noms de decks', (tester) async {
      await tester.pumpWidget(_buildWidget(
        ownerStats: _ownerWith10Games,
        deckStats: _deckStatsList,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Atraxa'), findsOneWidget);
      expect(find.text('Korvold'), findsOneWidget);
    });

    testWidgets('n\'affiche pas la section Par Deck si la liste est vide',
        (tester) async {
      await tester.pumpWidget(_buildWidget(ownerStats: _ownerWith10Games));
      await tester.pumpAndSettle();

      expect(find.text('Par Deck'), findsNothing);
    });
  });

  group('StatsTab - section Par Adversaire', () {
    testWidgets('affiche le titre de section Par Adversaire', (tester) async {
      await tester.pumpWidget(_buildWidget(
        ownerStats: _ownerWith10Games,
        opponentStats: _opponentStatsList,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Par Adversaire'), findsOneWidget);
    });

    testWidgets('affiche les noms des adversaires', (tester) async {
      await tester.pumpWidget(_buildWidget(
        ownerStats: _ownerWith10Games,
        opponentStats: _opponentStatsList,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets(
        'n\'affiche pas la section Par Adversaire si la liste est vide',
        (tester) async {
      await tester.pumpWidget(_buildWidget(ownerStats: _ownerWith10Games));
      await tester.pumpAndSettle();

      expect(find.text('Par Adversaire'), findsNothing);
    });
  });

  group('StatsTab - section Par Format', () {
    testWidgets('affiche le titre de section Par Format', (tester) async {
      await tester.pumpWidget(_buildWidget(
        ownerStats: _ownerWith10Games,
        formatStats: _formatStatsList,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Par Format'), findsOneWidget);
    });

    testWidgets('affiche les noms de formats', (tester) async {
      await tester.pumpWidget(_buildWidget(
        ownerStats: _ownerWith10Games,
        formatStats: _formatStatsList,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Commander'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
    });

    testWidgets('n\'affiche pas la section Par Format si la liste est vide',
        (tester) async {
      await tester.pumpWidget(_buildWidget(ownerStats: _ownerWith10Games));
      await tester.pumpAndSettle();

      expect(find.text('Par Format'), findsNothing);
    });
  });

  group('StatsTab - interactivité', () {
    testWidgets('les lignes de deck sont tappables sans crash', (tester) async {
      await tester.pumpWidget(_buildWidget(
        ownerStats: _ownerWith10Games,
        deckStats: _deckStatsList,
      ));
      await tester.pumpAndSettle();

      // Tap on a deck row - should not crash
      await tester.tap(find.text('Atraxa'));
      await tester.pumpAndSettle();
      // If we reach here without exception, the test passes
    });

    testWidgets('les lignes d\'adversaire sont tappables sans crash',
        (tester) async {
      await tester.pumpWidget(_buildWidget(
        ownerStats: _ownerWith10Games,
        opponentStats: _opponentStatsList,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
    });
  });
}
