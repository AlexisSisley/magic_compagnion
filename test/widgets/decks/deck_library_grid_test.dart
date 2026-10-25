// Tests de la grille de la bibliothèque : colonnes selon la largeur
// disponible, tuile 16:9, états vides et identité stable des tuiles.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/widgets/decks/deck_library_grid.dart';

/// Tuile à état : sert à vérifier que l'état suit le deck et non la position.
class _StatefulTile extends StatefulWidget {
  final String id;
  const _StatefulTile(this.id);

  @override
  State<_StatefulTile> createState() => _StatefulTileState();
}

class _StatefulTileState extends State<_StatefulTile> {
  late final String born = widget.id;

  @override
  Widget build(BuildContext context) => Text('$born/${widget.id}');
}

void main() {
  Deck deck(String id) => Deck(id: id, name: id, format: 'Commander');

  Widget host(
    Widget grid, {
    double width = 840,
    double height = 2000,
  }) =>
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: height,
              child: CustomScrollView(slivers: [grid]),
            ),
          ),
        ),
      );

  DeckLibraryGrid grid(
    List<Deck> decks, {
    int activeFilters = 0,
    VoidCallback? onClear,
    Widget Function(Deck)? tile,
  }) =>
      DeckLibraryGrid(
        decks: decks,
        prices: const {},
        activeFilters: activeFilters,
        onClearFilters: onClear ?? () {},
        tileBuilder: tile ??
            (d) => Container(key: ValueKey('tile-${d.id}'), color: Colors.red),
      );

  group('deckLibraryColumns', () {
    test('seuils 600 et 1000', () {
      expect(deckLibraryColumns(599), 1);
      expect(deckLibraryColumns(600), 2);
      expect(deckLibraryColumns(999), 2);
      expect(deckLibraryColumns(1000), 3);
    });

    test('téléphone et Fold déplié', () {
      expect(deckLibraryColumns(360), 1);
      expect(deckLibraryColumns(841), 2);
    });
  });

  group('DeckLibraryGrid', () {
    // Écran large : seule la largeur donnée à la grille doit compter.
    void wideScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    final decks = [for (var i = 0; i < 6; i++) deck('d$i')];

    int perRow(WidgetTester tester) {
      final first = tester.getTopLeft(find.byKey(const ValueKey('tile-d0'))).dy;
      return [
        for (final d in decks)
          tester.getTopLeft(find.byKey(ValueKey('tile-${d.id}'))).dy,
      ].where((dy) => dy == first).length;
    }

    for (final (width, expected) in [(390.0, 1), (840.0, 2), (1200.0, 3)]) {
      testWidgets('${width.toInt()} de large : $expected tuile(s) par rangée',
          (tester) async {
        wideScreen(tester);
        await tester.pumpWidget(host(grid(decks), width: width));
        expect(perRow(tester), expected);
      });
    }

    testWidgets('la tuile est un 16:9 pur dans les marges de 20',
        (tester) async {
      wideScreen(tester);
      await tester.pumpWidget(host(grid(decks), width: 840));
      final size = tester.getSize(find.byKey(const ValueKey('tile-d0')));
      // (840 - 2 * 20 - 14) / 2 = 393.
      expect(size.width, 393);
      expect(size.width / size.height, closeTo(16 / 9, 0.01));
      expect(tester.getTopLeft(find.byKey(const ValueKey('tile-d0'))).dx, 20);
    });

    testWidgets('la largeur disponible décide, pas celle de l\'écran',
        (tester) async {
      // Écran à 1400 (3 colonnes si l'on mesurait l'écran), grille à 700.
      wideScreen(tester);
      await tester.pumpWidget(host(grid(decks), width: 700));
      expect(perRow(tester), 2);
    });

    testWidgets('supprimer un deck ne laisse pas l\'état d\'une case voisine',
        (tester) async {
      Widget tile(Deck d) => _StatefulTile(d.id);
      final three = [deck('a'), deck('b'), deck('c')];
      await tester.pumpWidget(host(grid(three, tile: tile), width: 390));
      expect(find.text('b/b'), findsOneWidget);

      await tester.pumpWidget(
          host(grid([three[1], three[2]], tile: tile), width: 390));
      // Sans clé par deck, la case 0 garderait l'état « a » : « a/b ».
      expect(find.text('b/b'), findsOneWidget);
      expect(find.text('c/c'), findsOneWidget);
      expect(find.text('a/b'), findsNothing);
    });

    testWidgets('sans deck ni filtre : message simple, pas de bouton',
        (tester) async {
      await tester.pumpWidget(host(grid(const [])));
      expect(find.text('Aucun deck pour l\'instant'), findsOneWidget);
      expect(find.text('Effacer les filtres'), findsNothing);
    });

    testWidgets('filtres actifs et aucun deck : le bouton efface les filtres',
        (tester) async {
      var cleared = 0;
      await tester.pumpWidget(host(grid(
        const [],
        activeFilters: 2,
        onClear: () => cleared++,
      )));
      expect(find.text('Aucun deck ne correspond aux filtres'), findsOneWidget);
      expect(find.text('Aucun deck pour l\'instant'), findsNothing);

      final button = find.text('Effacer les filtres');
      expect(tester.getSize(find.ancestor(
              of: button, matching: find.byType(OutlinedButton))).height,
          greaterThanOrEqualTo(48));
      await tester.tap(button);
      expect(cleared, 1);
    });
  });
}
