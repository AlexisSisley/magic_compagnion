// Câblage de la liste sur la page réelle : un tap dans DeckCardListTab doit
// aboutir à un changement dans la base, en passant par la page et le
// contrôleur. Les tests de l'onglet seul prouvent que le callback est appelé ;
// ceux-ci prouvent que la page le branche, et sur le bon board.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/card_category.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/pages/decks/deck_detail_page.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/services/deck_view_prefs.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/widgets/decks/deck_card_title.dart';

/// Scryfall muet : aucune carte n'est résolue, la page s'ouvre sur ce que la
/// base contient (catégories comprises).
class _SilentApi extends ScryfallApiService {
  @override
  Future<Map<String, dynamic>> fetchCollection(
    List<Map<String, dynamic>> identifiers,
  ) async => {'data': <dynamic>[]};
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.insertDeck(
      DecksCompanion.insert(id: 'd1', name: 'Deck', colors: const Value('[]')),
    );
    await db.upsertDeckCard(
      deckId: 'd1',
      board: 'main',
      scryfallId: 'main-card',
      cardName: 'Carte du main',
      quantityToAdd: 1,
    );
    await db.upsertDeckCard(
      deckId: 'd1',
      board: 'side',
      scryfallId: 'side-card',
      cardName: 'Carte du side',
      quantityToAdd: 1,
    );
  });

  tearDown(() => db.close());

  Future<void> openPage(WidgetTester tester) async {
    final deck = (await DeckService(
      database: db,
    ).loadDecks()).firstWhere((d) => d.id == 'd1');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          scryfallApiServiceProvider.overrideWithValue(_SilentApi()),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: DeckDetailPage(deck: deck)),
      ),
    );
    // Laisse le contrôleur finir son chargement (base en mémoire).
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<DbDeckCard> row(String id, String board) async =>
      (await db.getDeckCardsByDeckId(
        'd1',
      )).firstWhere((c) => c.scryfallId == id && c.board == board);

  testWidgets('l\'interrupteur Type de la page change et mémorise le '
      'regroupement', (tester) async {
    await openPage(tester);
    expect(find.text('Carte du main'), findsOneWidget);

    await tester.tap(find.text('Type'));
    await tester.pump(const Duration(milliseconds: 100));

    // Le regroupement par type remplace les en-têtes de catégorie.
    expect(find.text('AUTRES'), findsNothing);
    expect(find.textContaining('(1)'), findsWidgets);
    final saved = await loadDeckViewPrefs(db, 'd1');
    expect(saved.grouping, DeckGrouping.type);
  });

  testWidgets('l\'icône liste de la page bascule en DeckCardTile', (
    tester,
  ) async {
    await openPage(tester);
    expect(find.byType(DeckCardGridTile), findsOneWidget);

    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DeckCardTile), findsOneWidget);
    expect((await loadDeckViewPrefs(db, 'd1')).layout, DeckLayout.list);
  });

  testWidgets('Catégorie… sur le main verrouille la carte du main en base', (
    tester,
  ) async {
    await openPage(tester);

    await tester.longPress(find.byType(DeckCardGridTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catégorie…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pioche'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final main = await row('main-card', 'main');
    expect(main.category, 'draw');
    expect(main.categoryLocked, isTrue);
    // L'autre board n'a pas bougé.
    expect((await row('side-card', 'side')).categoryLocked, isFalse);
    // Et la page l'affiche : section Pioche, cadenas sur la vignette.
    expect(find.text('PIOCHE'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });

  testWidgets('sur le side, la correction vise le board side', (tester) async {
    await openPage(tester);
    await tester.tap(find.textContaining('Side'));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(DeckCardGridTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catégorie…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wipe'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final side = await row('side-card', 'side');
    expect(side.category, CardCategory.wipe.name);
    expect(side.categoryLocked, isTrue);
    expect((await row('main-card', 'main')).categoryLocked, isFalse);
  });

  testWidgets('Déduire automatiquement rend la carte du main à la déduction', (
    tester,
  ) async {
    await db.setDeckCardCategory(
      deckId: 'd1',
      board: 'main',
      scryfallId: 'main-card',
      category: 'wincon',
      categoryLocked: true,
    );
    await openPage(tester);
    expect(find.byIcon(Icons.lock), findsOneWidget);

    await tester.longPress(find.byType(DeckCardGridTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Déduire automatiquement'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect((await row('main-card', 'main')).categoryLocked, isFalse);
    expect(find.byIcon(Icons.lock), findsNothing);
  });
}
