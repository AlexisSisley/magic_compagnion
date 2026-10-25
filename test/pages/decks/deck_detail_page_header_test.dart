// Le bandeau sur la page réelle : il est monté, et alimenté par les vraies
// valeurs du contrôleur (compte, CMC moyen, power level, prix). Les tests du
// widget seul prouvent le rendu ; ceux-ci prouvent que la page le branche.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/deck_detail_controller.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/pages/decks/deck_detail_page.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/deck_power_level_service.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/widgets/decks/deck_commander_header.dart';

Map<String, dynamic> _json(
  String id,
  String name,
  String typeLine,
  num cmc, {
  Map<String, dynamic> prices = const {},
}) => {
  'id': id,
  'name': name,
  'type_line': typeLine,
  'cmc': cmc,
  'oracle_text': '',
  'prices': prices,
  'color_identity': ['W'],
};

/// Scryfall qui résout le commandant (créature à 4) et une carte du main
/// (sort à 3, 12,50 €).
class _Api extends ScryfallApiService {
  @override
  Future<Map<String, dynamic>> fetchCollection(
    List<Map<String, dynamic>> identifiers,
  ) async => {
    'data': [
      _json('cmdr', 'Le Chef', 'Legendary Creature — Human', 4),
      _json('spell', 'Un sort', 'Sorcery', 3, prices: {'eur': '12.50'}),
      _json('cheap', 'Un petit sort', 'Instant', 1),
      _json('partner', 'Le Second', 'Legendary Creature — Human', 6),
    ],
  };
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.insertDeck(
      DecksCompanion.insert(
        id: 'd1',
        name: 'Mon deck',
        colors: const Value('[]'),
      ),
    );
    await db.upsertDeckCard(
      deckId: 'd1',
      board: 'main',
      scryfallId: 'spell',
      cardName: 'Un sort',
      quantityToAdd: 2,
    );
  });

  tearDown(() => db.close());

  Future<Deck> load() async => (await DeckService(
    database: db,
  ).loadDecks()).firstWhere((d) => d.id == 'd1');

  Widget app(Deck deck) => ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      scryfallApiServiceProvider.overrideWithValue(_Api()),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: DeckDetailPage(deck: deck),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('sans commandant : le bandeau dit qu\'il n\'y en a pas, à 180', (
    tester,
  ) async {
    await tester.pumpWidget(app(await load()));
    await settle(tester);

    expect(find.byType(DeckCommanderHeader), findsOneWidget);
    expect(find.text('Aucun commandant défini'), findsOneWidget);
    expect(tester.getSize(find.byType(DeckCommanderHeader)).height, 180);
    expect(find.textContaining('Power'), findsNothing);
  });

  testWidgets('avec commandant : le bandeau porte les vraies valeurs', (
    tester,
  ) async {
    await DeckService(database: db).setCommander('d1', 'cmdr');
    final deck = await load();
    await tester.pumpWidget(app(deck));
    await settle(tester);

    Finder inHeader(String t) => find.descendant(
      of: find.byType(DeckCommanderHeader),
      matching: find.text(t),
    );
    expect(inHeader('Mon deck'), findsOneWidget);
    expect(inHeader('2 cartes'), findsOneWidget);
    // Deux exemplaires à 3 : moyenne pondérée de 3, pas de 6 ni de 4.
    expect(inHeader('CMC moyen 3,0'), findsOneWidget);
    // 2 x 12,50 EUR arrondis à l'euro.
    expect(inHeader('25 €'), findsOneWidget);
    final expected = DeckPowerLevelService.estimatePowerLevel(
      deck: deck,
      // Le commandant une fois, le sort deux fois : sa quantité compte.
      fullCardData: [
        ScryfallCard.fromJson(
          _json('cmdr', 'Le Chef', 'Legendary Creature', 4),
        ),
        for (var i = 0; i < 2; i++)
          ScryfallCard.fromJson(
            _json('spell', 'Un sort', 'Sorcery', 3, prices: {'eur': '12.50'}),
          ),
      ],
      commanderScryfallId: 'cmdr',
    )!;
    expect(inHeader('Power ${expected.score}'), findsOneWidget);
  });

  testWidgets('retirer le commandant retire la pilule Power', (tester) async {
    await DeckService(database: db).setCommander('d1', 'cmdr');
    final deck = await load();
    await tester.pumpWidget(app(deck));
    await settle(tester);
    expect(find.textContaining('Power'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeckDetailPage)),
    );
    final ctrl = container.read(deckDetailControllerProvider(deck).notifier);
    await ctrl.unsetCommander(
      DeckCard(scryfallId: 'cmdr', name: 'Le Chef', quantity: 1),
    );
    await settle(tester);

    expect(
      container.read(deckDetailControllerProvider(deck)).powerLevel,
      isNull,
    );
    expect(find.textContaining('Power'), findsNothing);
    expect(find.text('Aucun commandant défini'), findsOneWidget);
  });

  /// Facteur continu : le score arrondi peut rester égal, pas lui.
  double? manaCurve(ProviderContainer c, Deck deck) => c
      .read(deckDetailControllerProvider(deck))
      .powerLevel
      ?.factors['Mana Curve'];

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DeckDetailPage)));

  double expectedCurve(List<(String, num, String, int)> cards) {
    final played = [
      for (final (id, cmc, type, qty) in cards)
        for (var i = 0; i < qty; i++)
          ScryfallCard.fromJson(_json(id, id, type, cmc)),
    ];
    return DeckPowerLevelService.calculateCmcScore(played);
  }

  testWidgets('une carte de wishlist ne change pas le power level', (
    tester,
  ) async {
    await db.upsertDeckCard(
      deckId: 'd1',
      board: 'wishlist',
      scryfallId: 'cheap',
      cardName: 'Un petit sort',
      quantityToAdd: 1,
    );
    await DeckService(database: db).setCommander('d1', 'cmdr');
    final deck = await load();
    await tester.pumpWidget(app(deck));
    await settle(tester);

    // Commandant (4) et deux sorts à 3 : la carte à 1 de la wishlist n'y est pas.
    expect(
      manaCurve(containerOf(tester), deck),
      expectedCurve([
        ('cmdr', 4, 'Legendary Creature', 1),
        ('spell', 3, 'Sorcery', 2),
      ]),
    );
  });

  testWidgets('le power level change quand le main change', (tester) async {
    await db.upsertDeckCard(
      deckId: 'd1',
      board: 'wishlist',
      scryfallId: 'cheap',
      cardName: 'Un petit sort',
      quantityToAdd: 1,
    );
    await DeckService(database: db).setCommander('d1', 'cmdr');
    final deck = await load();
    await tester.pumpWidget(app(deck));
    await settle(tester);
    final container = containerOf(tester);
    final avant = manaCurve(container, deck);

    // Déplacer la carte à 1 vers le main fait baisser la courbe moyenne.
    final cheap = deck.wishlist.single;
    await container
        .read(deckDetailControllerProvider(deck).notifier)
        .moveCard(cheap, DeckBoard.main, DeckBoard.wishlist);

    final apres = manaCurve(container, deck);
    expect(apres, isNot(avant));
    expect(
      apres,
      expectedCurve([
        ('cmdr', 4, 'Legendary Creature', 1),
        ('spell', 3, 'Sorcery', 2),
        ('cheap', 1, 'Instant', 1),
      ]),
    );

    // Une quantité qui baisse compte aussi, et non la seule présence.
    final sort = container
        .read(deckDetailControllerProvider(deck))
        .currentDeck
        .mainboard
        .firstWhere((c) => c.scryfallId == 'spell');
    await container
        .read(deckDetailControllerProvider(deck).notifier)
        .updateQuantity(sort, -1, DeckBoard.main);
    expect(
      manaCurve(container, deck),
      expectedCurve([
        ('cmdr', 4, 'Legendary Creature', 1),
        ('spell', 3, 'Sorcery', 1),
        ('cheap', 1, 'Instant', 1),
      ]),
    );
  });

  testWidgets('après Vider, la pilule Power disparaît', (tester) async {
    await DeckService(database: db).setCommander('d1', 'cmdr');
    final deck = await load();
    await tester.pumpWidget(app(deck));
    await settle(tester);
    expect(find.textContaining('Power'), findsOneWidget);

    await containerOf(tester)
        .read(deckDetailControllerProvider(deck).notifier)
        .clearDeck();
    await settle(tester);

    expect(find.textContaining('Power'), findsNothing);
  });

  testWidgets('un partenaire seul garde la pilule Power', (tester) async {
    await DeckService(database: db).setCommander('d1', 'partner', slot: 2);
    final deck = await load();
    expect(deck.commanderScryfallId, isNull);
    await tester.pumpWidget(app(deck));
    await settle(tester);

    expect(find.textContaining('Power'), findsOneWidget);
  });

  testWidgets('un deck vide ne dit pas de CMC moyen', (tester) async {
    await DeckService(database: db).clearDeck('d1');
    await tester.pumpWidget(app(await load()));
    await settle(tester);

    expect(find.textContaining('CMC moyen'), findsNothing);
    expect(find.text('0 carte'), findsOneWidget);
  });

  testWidgets('switchVersion déduit la catégorie de la nouvelle ligne', (
    tester,
  ) async {
    // La carte d'origine n'est pas résolue par Scryfall : elle reste sans
    // catégorie, donc rien à recopier sur la nouvelle impression.
    await db.upsertDeckCard(
      deckId: 'd1',
      board: 'main',
      scryfallId: 'inconnue',
      cardName: 'Inconnue',
      quantityToAdd: 1,
    );
    final deck = await load();
    await tester.pumpWidget(app(deck));
    await settle(tester);

    // Le rechargement attend 50 ms entre deux lots : l'horloge du test doit
    // avancer pendant l'appel.
    final fin = containerOf(tester)
        .read(deckDetailControllerProvider(deck).notifier)
        .switchVersion(
          deck.mainboard.firstWhere((c) => c.scryfallId == 'inconnue'),
          ScryfallCard.fromJson(_json('cheap', 'Un petit sort', 'Instant', 1)),
          DeckBoard.main,
        );
    await settle(tester);
    await fin;

    final rows = await db.getDeckCardsByDeckId('d1');
    expect(rows.firstWhere((r) => r.scryfallId == 'cheap').category, isNotNull);
  });
}
