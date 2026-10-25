// Fichier : test/services/deck_service_test.dart
//
// Tests unitaires pour DeckService.
// Auteur : Sanji, Lead Developer.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/services/backup_service.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeckService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = DeckService();
  });

  // ---------------------------------------------------------------
  // Helper : cree un deck persiste et retourne son id
  // ---------------------------------------------------------------
  Future<String> createAndGetDeckId(String name) async {
    await service.createNewDeck(name);
    final decks = await service.loadDecks();
    return decks.last.id;
  }

  // ---------------------------------------------------------------
  // Helper : ScryfallCard minimal pour changeCardVersion
  // ---------------------------------------------------------------
  final testScryfallCard = ScryfallCard(
    id: 'new-version-id',
    oracleId: '',
    name: 'Card New Version',
    imageUrl: '',
    rulesText: '',
    typeLine: '',
    legalities: {},
    prices: {},
    lang: 'en',
    colorIdentity: [],
    setName: '',
    setCode: '',
    collectorNumber: '',
    rarity: '',
    purchaseUris: {},
  );

  // =================================================================
  // 1. loadDecks() retourne [] quand vide
  // =================================================================
  test('loadDecks retourne une liste vide quand aucun deck sauvegarde', () async {
    final decks = await service.loadDecks();
    expect(decks, isEmpty);
  });

  // =================================================================
  // 2. createNewDeck() cree un deck avec bons defauts
  // =================================================================
  test('createNewDeck cree un deck avec les valeurs par defaut', () async {
    await service.createNewDeck('Mon Deck');
    final decks = await service.loadDecks();

    expect(decks, hasLength(1));
    final deck = decks.first;
    expect(deck.name, 'Mon Deck');
    expect(deck.format, 'Standard');
    expect(deck.colors, isEmpty);
    expect(deck.mainboard, isEmpty);
    expect(deck.sideboard, isEmpty);
    expect(deck.considering, isEmpty);
    expect(deck.wishlist, isEmpty);
    expect(deck.commanderScryfallId, isNull);
    expect(deck.commanderSecondaryScryfallId, isNull);
  });

  // =================================================================
  // 3. deleteDeck() supprime le bon deck
  // =================================================================
  test('deleteDeck supprime uniquement le deck cible', () async {
    await service.createNewDeck('Deck A');
    // Petit délai pour garantir des IDs différents (basés sur millisecondsSinceEpoch)
    await Future.delayed(const Duration(milliseconds: 10));
    await service.createNewDeck('Deck B');
    final decks = await service.loadDecks();
    expect(decks, hasLength(2));

    final idA = decks.first.id;
    await service.deleteDeck(idA);

    final remaining = await service.loadDecks();
    expect(remaining, hasLength(1));
    expect(remaining.first.name, 'Deck B');
  });

  // =================================================================
  // 4. upsertCardInDeck() ajoute une carte au mainboard
  // =================================================================
  test('upsertCardInDeck ajoute une carte au mainboard', () async {
    final deckId = await createAndGetDeckId('Test Deck');

    final updated = await service.upsertCardInDeck(
      deckId: deckId,
      scryfallId: 'card-001',
      cardName: 'Lightning Bolt',
      quantityToAdd: 4,
      board: DeckBoard.main,
    );

    expect(updated.mainboard, hasLength(1));
    expect(updated.mainboard.first.scryfallId, 'card-001');
    expect(updated.mainboard.first.name, 'Lightning Bolt');
    expect(updated.mainboard.first.quantity, 4);
  });

  // =================================================================
  // 5. upsertCardInDeck() ajoute une carte au sideboard
  // =================================================================
  test('upsertCardInDeck ajoute une carte au sideboard', () async {
    final deckId = await createAndGetDeckId('Test Deck');

    final updated = await service.upsertCardInDeck(
      deckId: deckId,
      scryfallId: 'card-002',
      cardName: 'Negate',
      quantityToAdd: 2,
      board: DeckBoard.side,
    );

    expect(updated.sideboard, hasLength(1));
    expect(updated.sideboard.first.scryfallId, 'card-002');
    expect(updated.sideboard.first.name, 'Negate');
    expect(updated.sideboard.first.quantity, 2);
    // Le mainboard ne doit pas etre touche
    expect(updated.mainboard, isEmpty);
  });

  // =================================================================
  // 6. upsertCardInDeck() met a jour la quantite existante
  // =================================================================
  test('upsertCardInDeck incremente la quantite d une carte existante', () async {
    final deckId = await createAndGetDeckId('Test Deck');

    await service.upsertCardInDeck(
      deckId: deckId,
      scryfallId: 'card-001',
      cardName: 'Lightning Bolt',
      quantityToAdd: 2,
    );

    final updated = await service.upsertCardInDeck(
      deckId: deckId,
      scryfallId: 'card-001',
      cardName: 'Lightning Bolt',
      quantityToAdd: 2,
    );

    expect(updated.mainboard, hasLength(1));
    expect(updated.mainboard.first.quantity, 4);
  });

  // =================================================================
  // 7. upsertCardInDeck() supprime quand qty <= 0
  // =================================================================
  test('upsertCardInDeck supprime la carte quand la quantite tombe a zero', () async {
    final deckId = await createAndGetDeckId('Test Deck');

    await service.upsertCardInDeck(
      deckId: deckId,
      scryfallId: 'card-001',
      cardName: 'Lightning Bolt',
      quantityToAdd: 2,
    );

    final updated = await service.upsertCardInDeck(
      deckId: deckId,
      scryfallId: 'card-001',
      cardName: 'Lightning Bolt',
      absoluteQuantity: 0,
    );

    expect(updated.mainboard, isEmpty);
  });

  // =================================================================
  // 8. upsertCardInDeck() sur deck inexistant -> StateError
  // =================================================================
  test('upsertCardInDeck lance StateError si le deck n existe pas', () async {
    expect(
      () => service.upsertCardInDeck(
        deckId: 'deck-inexistant',
        scryfallId: 'card-001',
        cardName: 'Lightning Bolt',
        quantityToAdd: 1,
      ),
      throwsA(isA<StateError>()),
    );
  });

  // =================================================================
  // 9. setCommander() met le format a 'Commander'
  // =================================================================
  test('setCommander definit le commandant et passe le format en Commander', () async {
    final deckId = await createAndGetDeckId('Commander Deck');

    final updated = await service.setCommander(deckId, 'commander-001');

    expect(updated.commanderScryfallId, 'commander-001');
    expect(updated.format, 'Commander');
  });

  // =================================================================
  // 10. setCommander() slot 2 (secondary)
  // =================================================================
  test('setCommander slot 2 definit le commandant secondaire', () async {
    final deckId = await createAndGetDeckId('Partner Deck');

    await service.setCommander(deckId, 'commander-001', slot: 1);
    final updated = await service.setCommander(deckId, 'commander-002', slot: 2);

    expect(updated.commanderScryfallId, 'commander-001');
    expect(updated.commanderSecondaryScryfallId, 'commander-002');
    expect(updated.format, 'Commander');
  });

  // =================================================================
  // 11. unsetCommander() remet format Standard quand plus aucun commandant
  // =================================================================
  test('unsetCommander remet le format Standard quand il n y a plus de commandant', () async {
    final deckId = await createAndGetDeckId('Commander Deck');

    await service.setCommander(deckId, 'commander-001');
    final updated = await service.unsetCommander(deckId);

    expect(updated.commanderScryfallId, isNull);
    expect(updated.format, 'Standard');
  });

  // =================================================================
  // 12. clearDeck() vide tout et reset le format
  // =================================================================
  test('clearDeck vide toutes les zones, reset commandants et format', () async {
    final deckId = await createAndGetDeckId('Deck Complet');

    // On remplit le deck
    await service.upsertCardInDeck(
      deckId: deckId,
      scryfallId: 'card-001',
      cardName: 'Lightning Bolt',
      quantityToAdd: 4,
      board: DeckBoard.main,
    );
    await service.upsertCardInDeck(
      deckId: deckId,
      scryfallId: 'card-002',
      cardName: 'Negate',
      quantityToAdd: 2,
      board: DeckBoard.side,
    );
    await service.upsertCardInDeck(
      deckId: deckId,
      scryfallId: 'card-003',
      cardName: 'Consider This',
      quantityToAdd: 1,
      board: DeckBoard.considering,
    );
    await service.upsertCardInDeck(
      deckId: deckId,
      scryfallId: 'card-004',
      cardName: 'Expensive Card',
      quantityToAdd: 1,
      board: DeckBoard.wishlist,
    );
    await service.setCommander(deckId, 'commander-001');

    // On clear
    final cleared = await service.clearDeck(deckId);

    expect(cleared.mainboard, isEmpty);
    expect(cleared.sideboard, isEmpty);
    expect(cleared.considering, isEmpty);
    expect(cleared.wishlist, isEmpty);
    expect(cleared.commanderScryfallId, isNull);
    expect(cleared.commanderSecondaryScryfallId, isNull);
    expect(cleared.format, 'Standard');
  });

  // =================================================================
  // 13. moveCard() deplace une carte entre zones
  // =================================================================
  test('moveCard deplace une carte du mainboard vers le sideboard', () async {
    final deckId = await createAndGetDeckId('Move Test');

    await service.upsertCardInDeck(
      deckId: deckId,
      scryfallId: 'card-001',
      cardName: 'Lightning Bolt',
      quantityToAdd: 3,
      board: DeckBoard.main,
    );

    final cardToMove = DeckCard(
      scryfallId: 'card-001',
      name: 'Lightning Bolt',
      quantity: 3,
      tags: ['Burn'],
    );

    final updated = await service.moveCard(
      deckId: deckId,
      card: cardToMove,
      fromBoard: DeckBoard.main,
      toBoard: DeckBoard.side,
    );

    expect(updated.mainboard, isEmpty);
    expect(updated.sideboard, hasLength(1));
    expect(updated.sideboard.first.scryfallId, 'card-001');
    expect(updated.sideboard.first.quantity, 3);
  });

  // =================================================================
  // 14. changeCardVersion() remplace une version de carte
  // =================================================================
  test('changeCardVersion remplace l ancienne version par la nouvelle', () async {
    final deckId = await createAndGetDeckId('Version Test');

    await service.upsertCardInDeck(
      deckId: deckId,
      scryfallId: 'old-version-id',
      cardName: 'Card Old Version',
      quantityToAdd: 3,
      board: DeckBoard.main,
      newTags: ['Staple'],
      isFoil: true,
    );

    final oldCard = DeckCard(
      scryfallId: 'old-version-id',
      name: 'Card Old Version',
      quantity: 3,
      tags: ['Staple'],
      isFoil: true,
    );

    final updated = await service.changeCardVersion(
      deckId: deckId,
      oldCard: oldCard,
      newVersion: testScryfallCard,
      board: DeckBoard.main,
    );

    // L'ancienne version ne doit plus etre presente
    expect(
      updated.mainboard.any((c) => c.scryfallId == 'old-version-id'),
      isFalse,
    );
    // La nouvelle version doit etre presente avec les memes proprietes
    expect(updated.mainboard, hasLength(1));
    final newCard = updated.mainboard.first;
    expect(newCard.scryfallId, 'new-version-id');
    expect(newCard.name, 'Card New Version');
    expect(newCard.quantity, 3);
    expect(newCard.tags, ['Staple']);
    expect(newCard.isFoil, isTrue);
  });

  test('repli SharedPreferences : moveCard fusionne proxys et foil', () async {
    final id = await createAndGetDeckId('Prefs');
    final deck = (await service.loadDecks()).single;
    deck.mainboard.add(DeckCard(
        scryfallId: 'c1', name: 'Sol Ring', quantity: 2, proxyQuantity: 1, isFoil: true));
    deck.sideboard.add(DeckCard(
        scryfallId: 'c1', name: 'Sol Ring', quantity: 1, proxyQuantity: 1));
    await service.updateDeck(deck);

    await service.moveCard(
      deckId: id,
      card: (await service.loadDecks()).single.mainboard.single,
      fromBoard: DeckBoard.main,
      toBoard: DeckBoard.side,
    );

    final c = (await service.loadDecks()).single.sideboard.single;
    expect(c.quantity, 3);
    expect(c.proxyQuantity, 2);
    expect(c.isFoil, isTrue);
  });

  // ---------------------------------------------------------------
  // Chemins d'ecriture sur base Drift : proxys, foils, tags, horodatage
  // ---------------------------------------------------------------
  group('ecritures Drift', () {
    late AppDatabase db;
    late DateTime horloge;
    late DeckService svc;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      horloge = DateTime(2026, 1, 1);
      svc = DeckService(database: db, now: () => horloge);
      await db.insertDeck(DecksCompanion.insert(id: 'd1', name: 'Test'));
    });

    tearDown(() async => db.close());

    DeckCard cartePrecieuse() => DeckCard(
          scryfallId: 'c1',
          name: 'Sol Ring',
          quantity: 3,
          proxyQuantity: 2,
          isFoil: true,
          tags: ['Ramp'],
        );

    Future<Deck> relire() async =>
        (await svc.loadDecks()).firstWhere((d) => d.id == 'd1');

    void expectCartePrecieuse(DeckCard c) {
      expect(c.quantity, 3);
      expect(c.proxyQuantity, 2);
      expect(c.isFoil, isTrue);
      expect(c.tags, ['Ramp']);
    }

    test('updateDeck conserve proxyQuantity, isFoil et tags des cartes', () async {
      final deck = await relire();
      deck.mainboard.add(cartePrecieuse());
      await svc.updateDeck(deck);

      expectCartePrecieuse((await relire()).mainboard.single);
    });

    test('moveCard main vers side rend la carte identique', () async {
      final deck = await relire();
      deck.mainboard.add(cartePrecieuse());
      await svc.updateDeck(deck);

      await svc.moveCard(
        deckId: 'd1',
        card: (await relire()).mainboard.single,
        fromBoard: DeckBoard.main,
        toBoard: DeckBoard.side,
      );

      final relu = await relire();
      expect(relu.mainboard, isEmpty);
      expectCartePrecieuse(relu.sideboard.single);
    });

    test('changeCardVersion conserve les proxys', () async {
      final deck = await relire();
      deck.mainboard.add(cartePrecieuse());
      await svc.updateDeck(deck);

      final nouvelle = ScryfallCard(
        id: 'c2',
        oracleId: '',
        name: 'Sol Ring',
        imageUrl: '',
        rulesText: '',
        typeLine: '',
        legalities: {},
        prices: {},
        lang: 'en',
        colorIdentity: [],
        setName: '',
        setCode: '',
        collectorNumber: '',
        rarity: '',
        purchaseUris: {},
      );
      await svc.changeCardVersion(
        deckId: 'd1',
        oldCard: (await relire()).mainboard.single,
        newVersion: nouvelle,
        board: DeckBoard.main,
      );

      final c = (await relire()).mainboard.single;
      expect(c.scryfallId, 'c2');
      expect(c.proxyQuantity, 2);
    });

    test('moveCard fusionne avec la carte deja presente sur la cible', () async {
      final deck = await relire();
      deck.mainboard.add(DeckCard(
          scryfallId: 'c1', name: 'Sol Ring', quantity: 2, proxyQuantity: 1));
      deck.sideboard.add(DeckCard(
          scryfallId: 'c1', name: 'Sol Ring', quantity: 1, proxyQuantity: 1));
      await svc.updateDeck(deck);

      await svc.moveCard(
        deckId: 'd1',
        card: (await relire()).mainboard.single,
        fromBoard: DeckBoard.main,
        toBoard: DeckBoard.side,
      );

      final c = (await relire()).sideboard.single;
      expect(c.quantity, 3);
      expect(c.proxyQuantity, 2);
    });

    test('moveCard fusionne le foil : l un OU l autre', () async {
      final deck = await relire();
      deck.mainboard.add(DeckCard(scryfallId: 'c1', name: 'Sol Ring', quantity: 1));
      deck.sideboard.add(DeckCard(
          scryfallId: 'c1', name: 'Sol Ring', quantity: 1, isFoil: true));
      await svc.updateDeck(deck);

      await svc.moveCard(
        deckId: 'd1',
        card: (await relire()).mainboard.single,
        fromBoard: DeckBoard.main,
        toBoard: DeckBoard.side,
      );

      expect((await relire()).sideboard.single.isFoil, isTrue);
    });

    test('changeCardVersion fusionne avec la version deja presente', () async {
      final deck = await relire();
      deck.mainboard.add(DeckCard(
          scryfallId: 'c1', name: 'Sol Ring', quantity: 2, proxyQuantity: 1));
      deck.mainboard.add(DeckCard(
          scryfallId: 'c2', name: 'Sol Ring', quantity: 2, proxyQuantity: 1,
          isFoil: true));
      await svc.updateDeck(deck);

      final nouvelle = ScryfallCard(
        id: 'c2', oracleId: '', name: 'Sol Ring', imageUrl: '', rulesText: '',
        typeLine: '', legalities: {}, prices: {}, lang: 'en',
        colorIdentity: [], setName: '', setCode: '', collectorNumber: '',
        rarity: '', purchaseUris: {},
      );
      await svc.changeCardVersion(
        deckId: 'd1',
        oldCard: (await relire()).mainboard.firstWhere((c) => c.scryfallId == 'c1'),
        newVersion: nouvelle,
        board: DeckBoard.main,
      );

      final c = (await relire()).mainboard.single;
      expect(c.scryfallId, 'c2');
      // 2 exemplaires deplaces + 2 deja presents : aucune copie perdue.
      expect(c.quantity, 4);
      expect(c.proxyQuantity, 2);
      expect(c.isFoil, isTrue);
    });

    test('updateDeck avec un Deck perime ne retire pas les tags', () async {
      await svc.updateDeckTags('d1', ['Casual']);
      final perime = Deck(id: 'd1', name: 'Test', colors: [], format: 'Standard');
      await svc.updateDeck(perime);
      expect((await relire()).tags, ['Casual']);
    });

    test('updateDeckTags remplace les tags du deck', () async {
      await svc.updateDeckTags('d1', ['Casual']);
      expect((await relire()).tags, ['Casual']);
    });

    test('un deck neuf a des tags vides et la date de creation', () async {
      final id = await svc.createNewDeck('Neuf');
      final deck = (await svc.loadDecks()).firstWhere((d) => d.id == id);
      expect(deck.tags, isEmpty);
      expect(deck.updatedAt, horloge);
    });

    Future<void> expectAvance(String nom, Future<void> Function() ecrire) async {
      final avant = horloge = horloge.add(const Duration(days: 1));
      await ecrire();
      expect((await relire()).updatedAt, avant, reason: nom);
    }

    test('chaque ecriture fait avancer updatedAt', () async {
      await expectAvance('updateDeck', () async => svc.updateDeck(await relire()));
      await expectAvance(
          'upsertCardInDeck',
          () => svc.upsertCardInDeck(
              deckId: 'd1', scryfallId: 'c1', cardName: 'Sol Ring', quantityToAdd: 1));
      await expectAvance(
          'moveCard',
          () async => svc.moveCard(
              deckId: 'd1',
              card: (await relire()).mainboard.single,
              fromBoard: DeckBoard.main,
              toBoard: DeckBoard.side));
      await expectAvance('setCommander', () => svc.setCommander('d1', 'cmd-1'));
      await expectAvance('unsetCommander', () => svc.unsetCommander('d1'));
      await expectAvance('clearDeck', () => svc.clearDeck('d1'));
      await expectAvance('updateDeckTags', () => svc.updateDeckTags('d1', ['x']));
    });
  });

  // ---------------------------------------------------------------
  // Tags stockes sur la carte et leur drapeau : meme contrat sur Drift et sur
  // le repli SharedPreferences.
  // ---------------------------------------------------------------
  for (final backend in ['Drift', 'SharedPreferences']) {
    group('tags stockes ($backend)', () {
      AppDatabase? db;
      late DeckService svc;
      late String deckId;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        db = backend == 'Drift' ? AppDatabase(NativeDatabase.memory()) : null;
        svc = DeckService(database: db);
        deckId = await svc.createNewDeck('Test');
      });

      tearDown(() async => db?.close());

      Future<Deck> relire() async =>
          (await svc.loadDecks()).firstWhere((d) => d.id == deckId);

      DeckCard editee() => DeckCard(
            scryfallId: 'c1',
            name: 'Swords',
            quantity: 1,
            tags: ['Removal', 'Perso'],
            tagsEdited: true,
          );

      void expectRemovalEditee(DeckCard c) {
        expect(c.tags, ['Removal', 'Perso']);
        expect(c.tagsEdited, isTrue);
      }

      ScryfallCard version(String id) => ScryfallCard(
            id: id, oracleId: '', name: 'Swords', imageUrl: '', rulesText: '',
            typeLine: '', legalities: {}, prices: {}, lang: 'en',
            colorIdentity: [], setName: '', setCode: '', collectorNumber: '',
            rarity: '', purchaseUris: {},
          );

      test('updateDeck conserve tags et drapeau', () async {
        final deck = await relire();
        deck.mainboard.add(editee());
        await svc.updateDeck(deck);
        expectRemovalEditee((await relire()).mainboard.single);
      });

      test('moveCard main vers side conserve tags et drapeau', () async {
        final deck = await relire();
        deck.mainboard.add(editee());
        await svc.updateDeck(deck);
        await svc.moveCard(
          deckId: deckId,
          card: (await relire()).mainboard.single,
          fromBoard: DeckBoard.main,
          toBoard: DeckBoard.side,
        );
        expectRemovalEditee((await relire()).sideboard.single);
      });

      test('moveCard fusionne : la ligne cible garde ses tags et son drapeau',
          () async {
        final deck = await relire();
        deck.mainboard.add(editee());
        deck.sideboard.add(DeckCard(
            scryfallId: 'c1', name: 'Swords', quantity: 1,
            tags: ['Protection'], tagsEdited: true));
        await svc.updateDeck(deck);
        await svc.moveCard(
          deckId: deckId,
          card: (await relire()).mainboard.single,
          fromBoard: DeckBoard.main,
          toBoard: DeckBoard.side,
        );
        final c = (await relire()).sideboard.single;
        expect(c.quantity, 2);
        expect(c.tags, ['Protection']);
        expect(c.tagsEdited, isTrue);
      });

      test('moveCard fusionne : une cible sans tag ne prend pas ceux de la carte',
          () async {
        final deck = await relire();
        deck.mainboard.add(editee());
        deck.sideboard.add(DeckCard(scryfallId: 'c1', name: 'Swords', quantity: 1));
        await svc.updateDeck(deck);
        await svc.moveCard(
          deckId: deckId,
          card: (await relire()).mainboard.single,
          fromBoard: DeckBoard.main,
          toBoard: DeckBoard.side,
        );
        final c = (await relire()).sideboard.single;
        expect(c.tags, isEmpty);
        expect(c.tagsEdited, isFalse);
      });

      test('changeCardVersion vers une impression absente recopie tags et drapeau',
          () async {
        final deck = await relire();
        deck.mainboard.add(editee());
        await svc.updateDeck(deck);
        await svc.changeCardVersion(
          deckId: deckId,
          oldCard: (await relire()).mainboard.single,
          newVersion: version('c2'),
          board: DeckBoard.main,
        );
        final c = (await relire()).mainboard.single;
        expect(c.scryfallId, 'c2');
        expectRemovalEditee(c);
      });

      test('changeCardVersion vers une impression deja presente garde celle de la cible',
          () async {
        final deck = await relire();
        deck.mainboard.add(editee());
        deck.mainboard.add(DeckCard(
            scryfallId: 'c2', name: 'Swords', quantity: 1,
            tags: ['Wipe'], tagsEdited: true));
        await svc.updateDeck(deck);
        await svc.changeCardVersion(
          deckId: deckId,
          oldCard: (await relire()).mainboard.firstWhere((c) => c.scryfallId == 'c1'),
          newVersion: version('c2'),
          board: DeckBoard.main,
        );
        final c = (await relire()).mainboard.single;
        expect(c.quantity, 2);
        expect(c.tags, ['Wipe']);
        expect(c.tagsEdited, isTrue);
      });

      test('upsertCardInDeck(quantityToAdd: 1) conserve tags et drapeau',
          () async {
        final deck = await relire();
        deck.mainboard.add(editee());
        await svc.updateDeck(deck);
        await svc.upsertCardInDeck(
            deckId: deckId, scryfallId: 'c1', cardName: 'Swords', quantityToAdd: 1);
        final c = (await relire()).mainboard.single;
        expect(c.quantity, 2);
        expectRemovalEditee(c);
      });

      test('upsertCardInDeck ecrit tags et drapeau fournis a l insertion', () async {
        await svc.upsertCardInDeck(
            deckId: deckId, scryfallId: 'c1', cardName: 'Swords',
            quantityToAdd: 1, newTags: ['Tuteur'], tagsEdited: true);
        final c = (await relire()).mainboard.single;
        expect(c.tags, ['Tuteur']);
        expect(c.tagsEdited, isTrue);
      });

      test('setCardTags ecrit dans l ordre, puis vide', () async {
        final deck = await relire();
        deck.mainboard.add(DeckCard(scryfallId: 'c1', name: 'Swords', quantity: 1));
        await svc.updateDeck(deck);

        await svc.setCardTags(
            deckId, DeckBoard.main, 'c1', ['Pioche', 'Ramp'], edited: true);
        var c = (await relire()).mainboard.single;
        expect(c.tags, ['Pioche', 'Ramp']);
        expect(c.tagsEdited, isTrue);

        await svc.setCardTags(deckId, DeckBoard.main, 'c1', [], edited: false);
        c = (await relire()).mainboard.single;
        expect(c.tags, isEmpty);
        expect(c.tagsEdited, isFalse);
      });

      test('applySuggestedTags n ecrit que sur une carte vide et non editee',
          () async {
        final deck = await relire();
        deck.mainboard.add(DeckCard(scryfallId: 'vide', name: 'A', quantity: 1));
        deck.mainboard.add(DeckCard(
            scryfallId: 'videe', name: 'B', quantity: 1, tagsEdited: true));
        deck.mainboard.add(
            DeckCard(scryfallId: 'taguee', name: 'C', quantity: 1, tags: ['X']));
        await svc.updateDeck(deck);

        await svc.applySuggestedTags(deckId, [
          for (final id in ['vide', 'videe', 'taguee'])
            (board: DeckBoard.main, scryfallId: id, tags: ['Ramp']),
        ]);

        final main = (await relire()).mainboard;
        DeckCard of(String id) => main.firstWhere((c) => c.scryfallId == id);
        expect(of('vide').tags, ['Ramp']);
        expect(of('vide').tagsEdited, isFalse);
        expect(of('videe').tags, isEmpty);
        expect(of('taguee').tags, ['X']);
      });
    });
  }

  test('sauvegarde : export puis import conservent tags et drapeau', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final svc = DeckService(database: db);
    final id = await svc.createNewDeck('Test');
    final deck = (await svc.loadDecks()).single;
    deck.mainboard.add(DeckCard(
        scryfallId: 'c1', name: 'Swords', quantity: 1,
        tags: ['Removal'], tagsEdited: true));
    deck.mainboard.add(DeckCard(scryfallId: 'c2', name: 'Island', quantity: 1));
    await svc.updateDeck(deck);

    final backup = BackupService(database: db);
    final exporte = await backup.generateBackupJson();
    await backup.restoreFromJson(exporte);

    final relu = (await svc.loadDecks()).firstWhere((d) => d.id == id);
    final c1 = relu.mainboard.firstWhere((c) => c.scryfallId == 'c1');
    expect(c1.tags, ['Removal']);
    expect(c1.tagsEdited, isTrue);
    final c2 = relu.mainboard.firstWhere((c) => c.scryfallId == 'c2');
    expect(c2.tags, isEmpty);
    expect(c2.tagsEdited, isFalse);
  });
}
