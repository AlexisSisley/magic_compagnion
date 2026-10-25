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
import 'package:magic_companion/pages/decks/deck_detail_page.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/services/deck_view_prefs.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/widgets/decks/deck_card_title.dart';

/// Scryfall muet : aucune carte n'est résolue, la page s'ouvre sur ce que la
/// base contient (tags compris).
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
        child: MaterialApp(
          theme: buildAppTheme(),
          home: DeckDetailPage(deck: deck),
        ),
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

  testWidgets('sans préférence, la page groupe par type', (tester) async {
    await openPage(tester);

    // Sans donnée Scryfall, la carte tombe dans la section « Autres » du
    // regroupement par type, pas dans « SANS TAG ».
    expect(find.text('Autres (1)'), findsOneWidget);
    expect(find.text('SANS TAG'), findsNothing);
  });

  testWidgets('l\'interrupteur Tags de la page change et mémorise le '
      'regroupement', (tester) async {
    await openPage(tester);
    expect(find.text('Carte du main'), findsOneWidget);

    await tester.tap(find.text('Tags'));
    await tester.pump(const Duration(milliseconds: 100));

    // Le regroupement par tag remplace les en-têtes de type.
    expect(find.text('SANS TAG'), findsOneWidget);
    expect(find.text('Autres (1)'), findsNothing);
    final saved = await loadDeckViewPrefs(db, 'd1');
    expect(saved.grouping, DeckGrouping.tag);
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

  /// Ouvre « Tags… » sur la vignette affichée, ajoute [tag] et valide.
  Future<void> addTagThroughMenu(WidgetTester tester, String tag) async {
    await tester.longPress(find.byType(DeckCardGridTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tags…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), tag);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byIcon(Icons.add),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  testWidgets('Tags… sur le main marque la carte du main en base', (
    tester,
  ) async {
    // Regroupement par tag mémorisé : la section Pioche doit apparaître.
    await saveDeckViewPrefs(
      db,
      'd1',
      const DeckViewPrefs(grouping: DeckGrouping.tag),
    );
    await openPage(tester);

    // Saisi en minuscules : l'orthographe du catalogue l'emporte.
    await addTagThroughMenu(tester, 'pioche');

    final main = await row('main-card', 'main');
    expect(AppDatabase.decodeTags(main.tags), ['Pioche']);
    expect(main.tagsEdited, isTrue);
    // L'autre board n'a pas bougé.
    expect((await row('side-card', 'side')).tagsEdited, isFalse);
    // Et la page l'affiche : section Pioche, sans cadenas.
    expect(find.text('PIOCHE'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNothing);
  });

  testWidgets('sur le side, la correction vise le board side', (tester) async {
    await openPage(tester);
    await tester.tap(find.textContaining('Side'));
    await tester.pumpAndSettle();

    await addTagThroughMenu(tester, 'Wipe');

    final side = await row('side-card', 'side');
    expect(AppDatabase.decodeTags(side.tags), ['Wipe']);
    expect(side.tagsEdited, isTrue);
    expect((await row('main-card', 'main')).tagsEdited, isFalse);
  });

  testWidgets('Déduire automatiquement rend la carte du main à la suggestion', (
    tester,
  ) async {
    await db.setDeckCardTags(
      deckId: 'd1',
      board: 'main',
      scryfallId: 'main-card',
      tags: ['Win-con'],
      tagsEdited: true,
    );
    await openPage(tester);

    await tester.longPress(find.byType(DeckCardGridTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Déduire automatiquement'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Sans donnée Scryfall, la suggestion est vide.
    final main = await row('main-card', 'main');
    expect(main.tagsEdited, isFalse);
    expect(AppDatabase.decodeTags(main.tags), isEmpty);
  });
}
