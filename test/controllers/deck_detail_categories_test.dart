// Catégorisation à l'ouverture d'un deck, correction à la main et préférences
// d'affichage, sur le contrôleur réel et une base Drift en mémoire.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/deck_detail_controller.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/card_category.dart';
import 'package:magic_companion/models/deck_model.dart';
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

/// Compte les lots de déductions envoyés à la base.
class _SpyDeckService extends DeckService {
  final List<int> batches = [];
  _SpyDeckService({super.database, super.now});

  @override
  Future<void> applyDeducedCategories(
    String deckId,
    List<({DeckBoard board, String scryfallId, CardCategory category})> entries,
  ) {
    batches.add(entries.length);
    return super.applyDeducedCategories(deckId, entries);
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
    // Texte imprimé français : la déduction doit lire l'oracle anglais.
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

  test(
    "l'ouverture catégorise les cartes sans catégorie et persiste",
    () async {
      await addCard('swords');
      await addCard('harmonize', board: 'side');
      await addCard('bears');

      final c = await open();

      expect((await row('swords')).category, 'removal');
      expect((await row('harmonize', board: 'side')).category, 'draw');
      expect((await row('bears')).category, 'creatures');
      expect((await row('swords')).categoryLocked, isFalse);
      // L'état affiché suit la base.
      final swords = c.state.currentDeck.mainboard.firstWhere(
        (x) => x.scryfallId == 'swords',
      );
      expect(swords.category, CardCategory.removal);
      expect(deckService.batches, [3], reason: 'un seul lot pour tout le deck');
      c.dispose();

      final c2 = await open();
      expect(deckService.batches, [
        3,
      ], reason: 'une seconde ouverture ne réécrit rien');
      c2.dispose();
    },
  );

  test('ouvrir un deck ne change pas sa date de modification', () async {
    await addCard('swords');
    final c = await open();
    expect((await row('swords')).category, 'removal');
    final deck = (await db.getAllDecksRaw()).single;
    expect(deck.updatedAt, _t0);
    c.dispose();
  });

  test('une carte verrouillée garde sa catégorie à l\'ouverture', () async {
    await addCard('swords');
    await db.setDeckCardCategory(
      deckId: 'd1',
      board: 'main',
      scryfallId: 'swords',
      category: 'wincon',
      categoryLocked: true,
    );

    final c = await open();

    expect((await row('swords')).category, 'wincon');
    expect((await row('swords')).categoryLocked, isTrue);
    c.dispose();
  });

  test('après un chargement complet, catégories ET couleurs sont en base, '
      'et une correction faite pendant l\'appel réseau survit', () async {
    await addCard('swords');
    await addCard('harmonize');
    await addCard('bears');
    // Pendant l'attente de Scryfall, l'utilisateur corrige une carte : le
    // contrôleur tient alors un instantané du deck devenu périmé.
    api.onFetch = () => db.setDeckCardCategory(
      deckId: 'd1',
      board: 'main',
      scryfallId: 'bears',
      category: 'wincon',
      categoryLocked: true,
    );

    final c = await open();

    final deck = (await db.getAllDecksRaw()).single;
    expect(AppDatabase.decodeTags(deck.colors), ['W', 'G']);
    expect(deck.updatedAt, _t0);
    expect((await row('swords')).category, 'removal');
    expect((await row('harmonize')).category, 'draw');
    expect((await row('bears')).category, 'wincon');
    expect((await row('bears')).categoryLocked, isTrue);
    c.dispose();
  });

  test('setCategory verrouille et date ; resetCategory déverrouille et '
      're-déduit', () async {
    await addCard('swords');
    final c = await open();
    final card = c.state.currentDeck.mainboard.firstWhere(
      (x) => x.scryfallId == 'swords',
    );

    await c.setCategory(card, DeckBoard.main, CardCategory.wincon);
    expect((await row('swords')).category, 'wincon');
    expect((await row('swords')).categoryLocked, isTrue);
    expect(
      (await db.getAllDecksRaw()).single.updatedAt,
      _t1,
      reason: 'une correction à la main est une modification',
    );
    final locked = c.state.currentDeck.mainboard.firstWhere(
      (x) => x.scryfallId == 'swords',
    );
    expect(locked.category, CardCategory.wincon);
    expect(locked.categoryLocked, isTrue);

    await c.resetCategory(locked, DeckBoard.main);
    expect((await row('swords')).category, 'removal');
    expect((await row('swords')).categoryLocked, isFalse);
    final reset = c.state.currentDeck.mainboard.firstWhere(
      (x) => x.scryfallId == 'swords',
    );
    expect(reset.category, CardCategory.removal);
    expect(reset.categoryLocked, isFalse);
    c.dispose();
  });

  test(
    'une carte LOCAL: reste sans catégorie et s\'affiche dans Autres',
    () async {
      await addCard('LOCAL:Ma carte');
      final c = await open();
      expect((await row('LOCAL:Ma carte')).category, isNull);
      final card = c.state.currentDeck.mainboard.single;
      expect(c.displayCategory(card), CardCategory.other);
      expect(deckService.batches, isEmpty);
      c.dispose();
    },
  );

  test('les préférences d\'affichage se chargent et se mémorisent', () async {
    final c = await open();
    expect(c.state.viewPrefs, const DeckViewPrefs());
    expect(c.state.viewPrefs.grouping, DeckGrouping.type);

    await c.setGrouping(DeckGrouping.category);
    await c.setLayout(DeckLayout.list);
    expect(c.state.viewPrefs.grouping, DeckGrouping.category);
    expect(c.state.viewPrefs.layout, DeckLayout.list);
    c.dispose();

    final c2 = await open();
    expect(
      c2.state.viewPrefs,
      const DeckViewPrefs(
        grouping: DeckGrouping.category,
        layout: DeckLayout.list,
      ),
    );
    c2.dispose();
  });
}
