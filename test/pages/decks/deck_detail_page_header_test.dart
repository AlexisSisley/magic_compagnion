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
      fullCardData: [
        ScryfallCard.fromJson(
          _json('cmdr', 'Le Chef', 'Legendary Creature', 4),
        ),
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
}
