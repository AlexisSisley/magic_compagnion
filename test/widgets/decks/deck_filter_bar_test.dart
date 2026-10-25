// Tests de la barre de filtres : compteur, puces actives, croix et tri.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/deck_list_filters.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/widgets/decks/deck_filter_bar.dart';

void main() {
  Widget bar({
    DeckFilterCriteria criteria = const DeckFilterCriteria(),
    int activeCount = 0,
    double width = 700,
    VoidCallback? onOpen,
    ValueChanged<DeckSort>? onSort,
    void Function(DeckFilterKind)? onClear,
  }) => MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: DeckFilterBar(
            criteria: criteria,
            activeCount: activeCount,
            onOpenFilters: onOpen ?? () {},
            onSort: onSort ?? (_) {},
            onClear: onClear ?? (_) {},
          ),
        ),
      ),
    ),
  );

  const badge = ValueKey('deck-filter-badge');

  group('compteur', () {
    testWidgets('badge absent à 0', (tester) async {
      await tester.pumpWidget(bar());
      expect(find.text('Filtres'), findsOneWidget);
      expect(find.byKey(badge), findsNothing);
    });

    testWidgets('badge « 2 » avec deux filtres', (tester) async {
      await tester.pumpWidget(
        bar(
          criteria: const DeckFilterCriteria(
            format: 'Commander',
            priceRange: (0, 300),
          ),
          activeCount: 2,
        ),
      );
      expect(
        find.descendant(of: find.byKey(badge), matching: find.text('2')),
        findsOneWidget,
      );
    });

    testWidgets('la pilule ouvre la feuille', (tester) async {
      var opened = 0;
      await tester.pumpWidget(bar(onOpen: () => opened++));
      await tester.tap(find.text('Filtres'));
      expect(opened, 1);
    });
  });

  group('libellés de puces', () {
    Future<void> showPrice(WidgetTester tester, (double, double) range) =>
        tester.pumpWidget(
          bar(criteria: DeckFilterCriteria(priceRange: range), activeCount: 1),
        );

    testWidgets('min à 0 : « Sous 300 € »', (tester) async {
      await showPrice(tester, (0, 300));
      expect(find.text('Sous 300 €'), findsOneWidget);
    });

    testWidgets('sans plafond : « Dès 50 € »', (tester) async {
      await showPrice(tester, (50, double.infinity));
      expect(find.text('Dès 50 €'), findsOneWidget);
    });

    testWidgets('fourchette : « 50–300 € »', (tester) async {
      await showPrice(tester, (50, 300));
      expect(find.text('50–300 €'), findsOneWidget);
    });

    testWidgets('format tel quel', (tester) async {
      await tester.pumpWidget(
        bar(
          criteria: const DeckFilterCriteria(format: 'Commander'),
          activeCount: 1,
        ),
      );
      expect(find.text('Commander'), findsOneWidget);
    });

    testWidgets('identité : le nom de la famille, « Incolore » pour vide', (
      tester,
    ) async {
      await tester.pumpWidget(
        bar(
          criteria: const DeckFilterCriteria(identityColors: ['U', 'W']),
          activeCount: 1,
        ),
      );
      expect(find.text('Azorius'), findsOneWidget);

      await tester.pumpWidget(
        bar(
          criteria: const DeckFilterCriteria(identityColors: []),
          activeCount: 1,
        ),
      );
      expect(find.text('Incolore'), findsOneWidget);
    });

    testWidgets('un tag : son nom ; plusieurs : « 3 tags »', (tester) async {
      await tester.pumpWidget(
        bar(
          criteria: const DeckFilterCriteria(tags: ['Combo']),
          activeCount: 1,
        ),
      );
      expect(find.text('Combo'), findsOneWidget);

      await tester.pumpWidget(
        bar(
          criteria: const DeckFilterCriteria(tags: ['A', 'B', 'C']),
          activeCount: 1,
        ),
      );
      expect(find.text('3 tags'), findsOneWidget);
    });

    testWidgets('aucune puce sans filtre', (tester) async {
      await tester.pumpWidget(bar());
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });

  group('croix', () {
    testWidgets('chaque croix appelle onClear avec son genre', (tester) async {
      final cleared = <DeckFilterKind>[];
      // L'écran de test fait 800 de large : trop étroit pour les quatre puces.
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        bar(
          criteria: const DeckFilterCriteria(
            format: 'Commander',
            identityColors: ['W'],
            tags: ['Combo'],
            priceRange: (0, 300),
          ),
          activeCount: 4,
          // Assez large pour que les quatre puces soient visibles : en
          // dessous, elles défilent et la dernière sort de l'écran.
          width: 1100,
          onClear: cleared.add,
        ),
      );
      for (final kind in DeckFilterKind.values) {
        await tester.tap(
          find.byKey(ValueKey('deck-filter-clear-${kind.name}')),
        );
      }
      expect(cleared, DeckFilterKind.values);
    });

    testWidgets('la cible de la croix fait au moins 48 x 48', (tester) async {
      await tester.pumpWidget(
        bar(
          criteria: const DeckFilterCriteria(format: 'Commander'),
          activeCount: 1,
        ),
      );
      final size = tester.getSize(
        find.byKey(const ValueKey('deck-filter-clear-format')),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('tri', () {
    testWidgets('le menu liste les cinq libellés et rend le choix', (
      tester,
    ) async {
      DeckSort? chosen;
      await tester.pumpWidget(bar(onSort: (s) => chosen = s));
      // Le libellé courant est dans la pilule, avant l'ouverture du menu.
      expect(find.text('Nom (A-Z)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('deck-filter-sort')));
      await tester.pumpAndSettle();
      for (final s in DeckSort.values) {
        expect(find.text(deckSortLabel(s)), findsWidgets);
      }
      // « Nom (A-Z) » apparait deux fois : pilule et entrée du menu.
      expect(find.text('Nom (A-Z)'), findsNWidgets(2));

      await tester.tap(find.text('Prix décroissant'));
      await tester.pumpAndSettle();
      expect(chosen, DeckSort.priceDesc);
    });

    testWidgets('la pilule affiche le tri courant', (tester) async {
      await tester.pumpWidget(
        bar(criteria: const DeckFilterCriteria(sort: DeckSort.cardCount)),
      );
      expect(find.text('Nombre de cartes'), findsOneWidget);
    });
  });

  group('petit écran', () {
    for (final w in [360.0, 390.0]) {
      testWidgets(
        'quatre filtres actifs à $w : toutes les puces sont visibles',
        (tester) async {
          tester.view.physicalSize = Size(w, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          await tester.pumpWidget(
            bar(
              width: w,
              criteria: const DeckFilterCriteria(
                format: 'Commander',
                identityColors: ['W', 'U'],
                tags: ['Casual', 'cEDH'],
                priceRange: (0, 300),
              ),
              activeCount: 4,
            ),
          );
          for (final kind in DeckFilterKind.values) {
            final clear = find.byKey(
              ValueKey('deck-filter-clear-${kind.name}'),
            );
            expect(clear, findsOneWidget);
            final rect = tester.getRect(clear);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(w));
            expect(rect.bottom, lessThanOrEqualTo(800));
            // Atteignable : le point central tombe bien sur la croix.
            expect(clear.hitTestable(), findsOneWidget);
          }
          // Filtres à gauche, tri à droite, sur la première ligne.
          final filters = tester.getRect(
            find.byKey(const ValueKey('deck-filter-open')),
          );
          final sort = tester.getRect(
            find.byKey(const ValueKey('deck-filter-sort')),
          );
          expect(filters.top, sort.top);
          expect(filters.left, lessThan(sort.left));
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
