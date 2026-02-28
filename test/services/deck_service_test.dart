// Fichier : test/services/deck_service_test.dart
//
// Tests unitaires pour DeckService.
// Auteur : Sanji, Lead Developer.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/models/deck_model.dart';
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
  Future<String> _createAndGetDeckId(String name) async {
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
    final deckId = await _createAndGetDeckId('Test Deck');

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
    final deckId = await _createAndGetDeckId('Test Deck');

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
    final deckId = await _createAndGetDeckId('Test Deck');

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
    final deckId = await _createAndGetDeckId('Test Deck');

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
    final deckId = await _createAndGetDeckId('Commander Deck');

    final updated = await service.setCommander(deckId, 'commander-001');

    expect(updated.commanderScryfallId, 'commander-001');
    expect(updated.format, 'Commander');
  });

  // =================================================================
  // 10. setCommander() slot 2 (secondary)
  // =================================================================
  test('setCommander slot 2 definit le commandant secondaire', () async {
    final deckId = await _createAndGetDeckId('Partner Deck');

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
    final deckId = await _createAndGetDeckId('Commander Deck');

    await service.setCommander(deckId, 'commander-001');
    final updated = await service.unsetCommander(deckId);

    expect(updated.commanderScryfallId, isNull);
    expect(updated.format, 'Standard');
  });

  // =================================================================
  // 12. clearDeck() vide tout et reset le format
  // =================================================================
  test('clearDeck vide toutes les zones, reset commandants et format', () async {
    final deckId = await _createAndGetDeckId('Deck Complet');

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
    final deckId = await _createAndGetDeckId('Move Test');

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
    final deckId = await _createAndGetDeckId('Version Test');

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
}
