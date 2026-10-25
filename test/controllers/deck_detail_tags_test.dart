// Suggestion de tags à l'ouverture d'un deck, correction à la main et
// préférences d'affichage, sur le contrôleur réel et une base Drift en mémoire.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/deck_detail_controller.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/card_tag.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/services/card_tag_catalog.dart';
import 'package:magic_companion/services/collection_service.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/services/deck_view_prefs.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/services/wishlist_service.dart';

/// Scryfall simulé : rend le JSON des cartes demandées, comme
/// `/cards/collection`. [onFetch] s'exécute pendant l'appel, pour simuler ce
/// qui se passe en base pendant l'attente réseau.
class _FakeApi extends ScryfallApiService {
  final Map<String, Map<String, dynamic>> cards;
  Future<void> Function()? onFetch;
  _FakeApi(this.cards);

  @override
  Future<Map<String, dynamic>> fetchCollection(
    List<Map<String, dynamic>> identifiers,
  ) async {
    final f = onFetch;
    onFetch = null;
    if (f != null) await f();
    return {
      'data': [
        for (final i in identifiers)
          if (cards.containsKey(i['id'])) cards[i['id']],
      ],
    };
  }
}

/// Compte les lots de suggestions envoyés à la base.
class _SpyDeckService extends DeckService {
  final List<int> batches = [];
  _SpyDeckService({super.database, super.now});

  @override
  Future<void> applySuggestedTags(
    String deckId,
    List<({DeckBoard board, String scryfallId, List<String> tags})> entries,
  ) {
    batches.add(entries.length);
    return super.applySuggestedTags(deckId, entries);
  }
}

Map<String, dynamic> _card(
  String id,
  String name,
  String type,
  String oracle, {
  List<String> colors = const [],
  String? printed,
}) => {
  'id': id,
  'name': name,
  'type_line': type,
  'oracle_text': oracle,
  if (printed != null) 'printed_text': printed,
  'color_identity': colors,
};

final _scryfall = {
  'swords': _card(
    'swords',
    'Swords to Plowshares',
    'Instant',
    'Exile target creature. Its controller gains life equal to its power.',
    colors: ['W'],
    // Texte imprimé français : la suggestion doit lire l'oracle anglais.
    printed: 'Exilez la créature ciblée.',
  ),
  'harmonize': _card(
    'harmonize',
    'Harmonize',
    'Sorcery',
    'Draw three cards.',
    colors: ['G'],
  ),
  'bears': _card('bears', 'Grizzly Bears', 'Creature — Bear', ''),
  'ephemerate': _card(
    'ephemerate',
    'Ephemerate',
    'Instant',
    "Exile target creature you control, then return it to the battlefield "
        "under its owner's control.\nRebound",
    colors: ['W'],
  ),
  'solring': _card('solring', 'Sol Ring', 'Artifact', '{T}: Add {C}{C}.'),
};

final _t0 = DateTime(2026, 1, 1, 12);
final _t1 = DateTime(2026, 6, 1, 12);

void main() {
  late AppDatabase db;
  late _SpyDeckService deckService;
  late _FakeApi api;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    deckService = _SpyDeckService(database: db, now: () => _t1);
    api = _FakeApi(_scryfall);
    await db.insertDeck(
      DecksCompanion.insert(
        id: 'd1',
        name: 'Deck',
        colors: const Value('[]'),
        updatedAt: Value(_t0),
      ),
    );
  });

  tearDown(() => db.close());

  Future<void> addCard(String id, {String board = 'main'}) => db.upsertDeckCard(
    deckId: 'd1',
    board: board,
    scryfallId: id,
    cardName: id,
    quantityToAdd: 1,
  );

  Future<Deck> loadDeck() async =>
      (await deckService.loadDecks()).firstWhere((d) => d.id == 'd1');

  Future<DbDeckCard> row(String id, {String board = 'main'}) async =>
      (await db.getDeckCardsByDeckId(
        'd1',
      )).firstWhere((c) => c.scryfallId == id && c.board == board);

  Future<List<String>> tagsOf(String id, {String board = 'main'}) async =>
      AppDatabase.decodeTags((await row(id, board: board)).tags);

  DeckCard stateCard(DeckDetailController c, String id) =>
      c.state.currentDeck.mainboard.firstWhere((x) => x.scryfallId == id);

  Future<DeckDetailController> open() async {
    final c = DeckDetailController(
      initialDeck: await loadDeck(),
      deckService: deckService,
      collectionService: CollectionService(database: db),
      wishlistService: WishlistService(database: db),
      apiService: api,
      database: db,
    );
    for (var i = 0; i < 200 && c.state.isLoading; i++) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    expect(c.state.isLoading, isFalse);
    return c;
  }

  test('opening a deck tags Ephemerate Blink and Sol Ring Ramp', () async {
    await addCard('ephemerate');
    await addCard('solring');
    await addCard('harmonize', board: 'side');
    await addCard('bears');

    final c = await open();

    expect(await tagsOf('ephemerate'), ['Blink']);
    expect(await tagsOf('solring'), ['Ramp']);
    expect(await tagsOf('harmonize', board: 'side'), ['Pioche']);
    expect(await tagsOf('bears'), isEmpty);
    expect((await row('ephemerate')).tagsEdited, isFalse);
    // L'état affiché suit la base.
    expect(stateCard(c, 'ephemerate').tags, ['Blink']);
    expect(stateCard(c, 'ephemerate').primaryTag, 'Blink');
    expect(deckService.batches, [3], reason: 'un seul lot pour tout le deck');
    c.dispose();

    final c2 = await open();
    expect(deckService.batches, [
      3,
    ], reason: 'une seconde ouverture ne réécrit rien');
    c2.dispose();
  });

  test('a renamed default tag is suggested under its new name', () async {
    await CardTagCatalog(db).rename('Ramp', 'Accélération');
    await addCard('solring');

    final c = await open();

    expect(await tagsOf('solring'), ['Accélération']);
    c.dispose();
  });

  test('a deleted catalogue tag is not suggested', () async {
    await CardTagCatalog(
      db,
    ).save(kDefaultCardTags.where((t) => t.key != 'blink').toList());
    await addCard('ephemerate');
    await addCard('solring');

    final c = await open();

    expect(await tagsOf('ephemerate'), isEmpty);
    expect(await tagsOf('solring'), ['Ramp']);
    c.dispose();
  });

  test('a card emptied by hand is not re-suggested', () async {
    await addCard('swords');
    final c = await open();
    expect(await tagsOf('swords'), ['Removal']);

    await c.setCardTags(stateCard(c, 'swords'), DeckBoard.main, []);
    expect(await tagsOf('swords'), isEmpty);
    expect((await row('swords')).tagsEdited, isTrue);
    c.dispose();

    final c2 = await open();
    expect(await tagsOf('swords'), isEmpty);
    expect(stateCard(c2, 'swords').tags, isEmpty);
    c2.dispose();
  });

  test('opening does not bump updatedAt', () async {
    await addCard('swords');
    final c = await open();
    expect(await tagsOf('swords'), ['Removal']);
    final deck = (await db.getAllDecksRaw()).single;
    expect(deck.updatedAt, _t0);
    c.dispose();
  });

  test('setCardTags normalise, dédoublonne, marque et date', () async {
    await addCard('swords');
    final c = await open();

    await c.setCardTags(stateCard(c, 'swords'), DeckBoard.main, [
      '  Mon   tag ',
      'removal',
      'mon tag',
      '   ',
    ]);

    expect(await tagsOf('swords'), ['Mon tag', 'Removal']);
    expect((await row('swords')).tagsEdited, isTrue);
    expect(stateCard(c, 'swords').tags, ['Mon tag', 'Removal']);
    expect(stateCard(c, 'swords').tagsEdited, isTrue);
    expect(
      (await db.getAllDecksRaw()).single.updatedAt,
      _t1,
      reason: 'une correction à la main est une modification',
    );
    c.dispose();
  });

  test('resetCardTags restores the suggestion and clears tagsEdited', () async {
    await addCard('swords');
    final c = await open();
    await c.setCardTags(stateCard(c, 'swords'), DeckBoard.main, ['Win-con']);
    expect((await row('swords')).tagsEdited, isTrue);

    await c.resetCardTags(stateCard(c, 'swords'), DeckBoard.main);

    expect(await tagsOf('swords'), ['Removal']);
    expect((await row('swords')).tagsEdited, isFalse);
    expect(stateCard(c, 'swords').tags, ['Removal']);
    expect(stateCard(c, 'swords').tagsEdited, isFalse);
    c.dispose();
  });

  test('resetCardTags vide une carte LOCAL:', () async {
    await addCard('LOCAL:Ma carte');
    final c = await open();
    final card = c.state.currentDeck.mainboard.single;
    await c.setCardTags(card, DeckBoard.main, ['Perso']);

    await c.resetCardTags(c.state.currentDeck.mainboard.single, DeckBoard.main);

    expect(await tagsOf('LOCAL:Ma carte'), isEmpty);
    expect((await row('LOCAL:Ma carte')).tagsEdited, isFalse);
    c.dispose();
  });

  test('une carte déjà taguée garde ses tags à l\'ouverture', () async {
    await addCard('swords');
    await db.setDeckCardTags(
      deckId: 'd1',
      board: 'main',
      scryfallId: 'swords',
      tags: ['Win-con'],
      tagsEdited: true,
    );

    final c = await open();

    expect(await tagsOf('swords'), ['Win-con']);
    expect((await row('swords')).tagsEdited, isTrue);
    c.dispose();
  });

  test('après un chargement complet, tags ET couleurs sont en base, '
      'et une correction faite pendant l\'appel réseau survit', () async {
    await addCard('swords');
    await addCard('harmonize');
    await addCard('bears');
    // Pendant l'attente de Scryfall, l'utilisateur vide les tags d'une carte :
    // le contrôleur tient alors un instantané du deck devenu périmé.
    api.onFetch = () => db.setDeckCardTags(
      deckId: 'd1',
      board: 'main',
      scryfallId: 'harmonize',
      tags: [],
      tagsEdited: true,
    );

    final c = await open();

    final deck = (await db.getAllDecksRaw()).single;
    expect(AppDatabase.decodeTags(deck.colors), ['W', 'G']);
    expect(deck.updatedAt, _t0);
    expect(await tagsOf('swords'), ['Removal']);
    expect(await tagsOf('harmonize'), isEmpty);
    expect((await row('harmonize')).tagsEdited, isTrue);
    c.dispose();
  });

  test('une carte LOCAL: reste sans tag', () async {
    await addCard('LOCAL:Ma carte');
    final c = await open();
    expect(await tagsOf('LOCAL:Ma carte'), isEmpty);
    expect(c.state.currentDeck.mainboard.single.primaryTag, isNull);
    expect(deckService.batches, isEmpty);
    c.dispose();
  });

  test('les préférences d\'affichage se chargent et se mémorisent', () async {
    final c = await open();
    expect(c.state.viewPrefs, const DeckViewPrefs());
    expect(c.state.viewPrefs.grouping, DeckGrouping.type);

    await c.setGrouping(DeckGrouping.tag);
    await c.setLayout(DeckLayout.list);
    expect(c.state.viewPrefs.grouping, DeckGrouping.tag);
    expect(c.state.viewPrefs.layout, DeckLayout.list);
    c.dispose();

    final c2 = await open();
    expect(
      c2.state.viewPrefs,
      const DeckViewPrefs(grouping: DeckGrouping.tag, layout: DeckLayout.list),
    );
    c2.dispose();
  });
}
