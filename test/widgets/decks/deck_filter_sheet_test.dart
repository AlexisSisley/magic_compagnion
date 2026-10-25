// Tests de la feuille de filtres, branchée sur un vrai contrôleur : chaque
// geste doit atteindre l'état, et la feuille doit refléter l'état en retour.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/deck_list_controller.dart';
import 'package:magic_companion/controllers/deck_list_filters.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/services/card_resolver.dart';
import 'package:magic_companion/services/collection_service.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/services/local_card_service.dart';
import 'package:magic_companion/services/moxfield_deck_client.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/services/translation_worker.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/widgets/decks/deck_filter_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Contrôleur réel (DeckService en repli SharedPreferences, base en mémoire)
  /// chargé avec des decks (nom, format, tags).
  Future<DeckListController> build(
    WidgetTester tester,
    List<(String, String, List<String>)> specs,
  ) async {
    late DeckListController controller;
    await tester.runAsync(() async {
      final service = DeckService();
      for (final (name, format, tags) in specs) {
        final id = await service.createNewDeck(name);
        final deck = (await service.loadDecks()).firstWhere((d) => d.id == id);
        deck.format = format;
        await service.updateDeck(deck);
        await service.updateDeckTags(id, tags);
      }
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final dio = Dio(BaseOptions(baseUrl: ScryfallApiService.baseUrl));
      final resolver = CardResolver(
        api: ScryfallApiService(dio: dio),
        db: db,
      );
      controller = DeckListController(
        deckService: service,
        localCardService: LocalCardService(),
        collectionService: CollectionService(database: db, resolver: resolver),
        translationWorker: TranslationWorker(resolver: resolver, db: db),
        cardResolver: resolver,
        moxfieldClient: MoxfieldDeckClient(),
        db: db,
      );
      await controller.loadDecks();
    });
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> openSheet(
    WidgetTester tester,
    DeckListController c, {
    double maxPrice = 280,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDeckFilterSheet(
                context,
                state: c.state,
                controller: c,
                formats: c.availableFormats,
                tags: c.availableTags,
                maxPrice: maxPrice,
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  test('plafond du curseur : multiple de 50 supérieur, 50 sans prix', () {
    expect(deckPriceCeiling(0), 50);
    expect(deckPriceCeiling(-3), 50);
    expect(deckPriceCeiling(1), 50);
    expect(deckPriceCeiling(50), 50);
    expect(deckPriceCeiling(51), 100);
    expect(deckPriceCeiling(289), 300);
  });

  testWidgets(
    'sélectionner un tag appelle updateTags, le retire au second appui',
    (tester) async {
      final c = await build(tester, [
        ('A', 'Standard', ['X']),
        ('B', 'Standard', ['Y']),
      ]);
      await openSheet(tester, c);

      await tester.tap(find.widgetWithText(FilterChip, 'X'));
      await tester.pumpAndSettle();
      expect(c.state.selectedTags, ['X']);
      // La feuille reste ouverte et reflète l'état.
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'X'))
            .selected,
        isTrue,
      );

      await tester.tap(find.widgetWithText(FilterChip, 'Y'));
      await tester.pumpAndSettle();
      expect(c.state.selectedTags, ['X', 'Y']);

      await tester.tap(find.widgetWithText(FilterChip, 'X'));
      await tester.pumpAndSettle();
      expect(c.state.selectedTags, ['Y']);
    },
  );

  testWidgets('sans tag : le texte d\'aide, aucune puce', (tester) async {
    final c = await build(tester, [('A', 'Standard', [])]);
    await openSheet(tester, c);
    expect(
      find.text('Aucun tag : appui long sur un deck pour en poser'),
      findsOneWidget,
    );
    expect(find.byType(FilterChip), findsNothing);
  });

  testWidgets('format : « Tous » + formats présents, choix unique', (
    tester,
  ) async {
    final c = await build(tester, [
      ('A', 'Standard', []),
      ('B', 'Commander', []),
    ]);
    await openSheet(tester, c);
    expect(find.widgetWithText(ChoiceChip, 'Tous'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Commander'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Standard'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Commander'));
    await tester.pumpAndSettle();
    expect(c.state.selectedFormat, 'Commander');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Standard'));
    await tester.pumpAndSettle();
    expect(c.state.selectedFormat, 'Standard');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tous'));
    await tester.pumpAndSettle();
    expect(c.state.selectedFormat, isNull);
  });

  testWidgets('« Tout effacer » appelle clearAllFilters et garde le tri', (
    tester,
  ) async {
    final c = await build(tester, [
      ('A', 'Commander', ['X']),
    ]);
    c.updateFormat('Commander');
    c.updateTags(['X']);
    c.updatePriceRange((0, 100));
    c.updateIdentityFilter('Blanc', ['W']);
    c.updateSort(DeckSort.priceDesc);
    await openSheet(tester, c);
    expect(activeFilterCount(c.state.criteria), 4);

    await tester.tap(find.text('Tout effacer'));
    await tester.pumpAndSettle();
    expect(activeFilterCount(c.state.criteria), 0);
    expect(c.state.selectedSort, DeckSort.priceDesc);
  });

  group('prix', () {
    RangeSlider slider(WidgetTester tester) => tester.widget<RangeSlider>(
      find.byKey(const ValueKey('deck-filter-price')),
    );

    testWidgets('curseur de 0 au multiple de 50 supérieur, pas de 10', (
      tester,
    ) async {
      final c = await build(tester, [('A', 'Standard', [])]);
      await openSheet(tester, c, maxPrice: 289);
      final s = slider(tester);
      expect(s.min, 0);
      expect(s.max, 300);
      expect(s.divisions, 30);
      expect(find.text('Tous les prix'), findsOneWidget);
    });

    testWidgets('sans prix connu, le curseur reste valide à 50', (
      tester,
    ) async {
      final c = await build(tester, [('A', 'Standard', [])]);
      await openSheet(tester, c, maxPrice: 0);
      expect(slider(tester).max, 50);
    });

    testWidgets('relâcher le curseur pose la fourchette', (tester) async {
      final c = await build(tester, [('A', 'Standard', [])]);
      await openSheet(tester, c);
      slider(tester).onChangeEnd!(const RangeValues(0, 100));
      await tester.pumpAndSettle();
      expect(c.state.priceRange, (0.0, 100.0));
    });

    testWidgets('butée droite : sans plafond ; plage entière : filtre retiré', (
      tester,
    ) async {
      final c = await build(tester, [('A', 'Standard', [])]);
      await openSheet(tester, c); // plafond 300
      slider(tester).onChangeEnd!(const RangeValues(50, 300));
      await tester.pumpAndSettle();
      expect(c.state.priceRange, (50.0, double.infinity));
      // La butée droite reste affichée au plafond, pas à l'infini.
      expect(slider(tester).values, const RangeValues(50, 300));

      slider(tester).onChangeEnd!(const RangeValues(0, 300));
      await tester.pumpAndSettle();
      expect(c.state.priceRange, isNull);
    });
  });

  testWidgets('identité : le bouton ouvre la modale existante', (tester) async {
    final c = await build(tester, [('A', 'Standard', [])]);
    await openSheet(tester, c);
    expect(find.text('Toutes les identités'), findsOneWidget);

    // La modale charge ses symboles de mana sur le réseau, indisponible en
    // test : l'échec de décodage remonte comme erreur de zone. On l'isole
    // dans une zone dédiée pour ne juger que ce qui nous concerne.
    Future<void> inIsolatedZone(Future<void> Function() body) async {
      await runZonedGuarded(body, (error, stack) {
        if (!error.toString().contains('Invalid SVG data')) {
          Zone.root.handleUncaughtError(error, stack);
        }
      });
    }

    final button = find.byKey(const ValueKey('deck-filter-identity'));
    expect(button, findsOneWidget);
    await inIsolatedZone(() async {
      await tester.tap(button);
      await tester.pumpAndSettle();
    });
    expect(find.text('Identite Couleur'), findsOneWidget);

    // Première entrée de la liste : visible sans défilement.
    expect(find.text('Blanc'), findsOneWidget);
    await inIsolatedZone(() async {
      await tester.tap(find.text('Blanc'));
      await tester.pumpAndSettle();
    });
    expect(c.state.selectedIdentityName, 'Blanc');
    // De retour sur la feuille, le bouton reflète le choix.
    expect(find.text('Blanc'), findsOneWidget);
  });
}
