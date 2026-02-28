// Fichier : test/services/wishlist_service_test.dart
// Tests unitaires pour WishlistService

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/services/wishlist_service.dart';
import 'package:magic_companion/models/wishlist_model.dart';
import 'package:magic_companion/models/deck_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WishlistService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = WishlistService();
  });

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────

  /// Seed SharedPreferences avec une liste de wishlists déjà encodée en v2.
  Future<void> seedWishlists(List<Wishlist> wishlists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'user_wishlists_v2',
      json.encode(wishlists.map((w) => w.toJson()).toList()),
    );
  }

  /// Crée une wishlist de test avec des paramètres simples.
  Wishlist makeWishlist({
    String id = 'wl-1',
    String name = 'Test Wishlist',
    List<DeckCard>? cards,
    String? iconScryfallId,
  }) {
    return Wishlist(
      id: id,
      name: name,
      cards: cards ?? [],
      dateCreated: DateTime(2025, 1, 1),
      iconScryfallId: iconScryfallId,
    );
  }

  DeckCard makeCard({
    String scryfallId = 'card-1',
    String name = 'Lightning Bolt',
    int quantity = 1,
    bool isFoil = false,
  }) {
    return DeckCard(
      scryfallId: scryfallId,
      name: name,
      quantity: quantity,
      isFoil: isFoil,
    );
  }

  // ──────────────────────────────────────────────
  // 1. loadWishlists() - wishlist par défaut
  // ──────────────────────────────────────────────
  test('loadWishlists() crée une wishlist par défaut si aucune donnée', () async {
    final result = await service.loadWishlists();

    expect(result, hasLength(1));
    expect(result.first.name, 'Ma Wishlist');
    expect(result.first.cards, isEmpty);
  });

  // ──────────────────────────────────────────────
  // 2. createWishlist()
  // ──────────────────────────────────────────────
  test('createWishlist() ajoute une wishlist', () async {
    // Le premier appel crée la wishlist par défaut
    await service.loadWishlists();
    await service.createWishlist('Trade Binder');

    final result = await service.loadWishlists();

    expect(result, hasLength(2));
    expect(result.last.name, 'Trade Binder');
    expect(result.last.cards, isEmpty);
  });

  // ──────────────────────────────────────────────
  // 3. deleteWishlist()
  // ──────────────────────────────────────────────
  test('deleteWishlist() supprime la bonne wishlist', () async {
    final wl1 = makeWishlist(id: 'wl-1', name: 'A');
    final wl2 = makeWishlist(id: 'wl-2', name: 'B');
    await seedWishlists([wl1, wl2]);

    await service.deleteWishlist('wl-1');

    final result = await service.loadWishlists();
    expect(result, hasLength(1));
    expect(result.first.id, 'wl-2');
    expect(result.first.name, 'B');
  });

  // ──────────────────────────────────────────────
  // 4. renameWishlist()
  // ──────────────────────────────────────────────
  test('renameWishlist() renomme correctement', () async {
    final wl = makeWishlist(id: 'wl-1', name: 'Ancien Nom');
    await seedWishlists([wl]);

    await service.renameWishlist('wl-1', 'Nouveau Nom');

    final result = await service.loadWishlists();
    expect(result.first.name, 'Nouveau Nom');
  });

  // ──────────────────────────────────────────────
  // 5. clearWishlistCards()
  // ──────────────────────────────────────────────
  test('clearWishlistCards() vide les cartes', () async {
    final wl = makeWishlist(
      id: 'wl-1',
      cards: [makeCard(), makeCard(scryfallId: 'card-2', name: 'Counterspell')],
    );
    await seedWishlists([wl]);

    await service.clearWishlistCards('wl-1');

    final result = await service.loadWishlists();
    expect(result.first.cards, isEmpty);
  });

  // ──────────────────────────────────────────────
  // 6. upsertCard() - ajout
  // ──────────────────────────────────────────────
  test('upsertCard() ajoute une carte', () async {
    final wl = makeWishlist(id: 'wl-1');
    await seedWishlists([wl]);

    await service.upsertCard(
      wishlistId: 'wl-1',
      scryfallId: 'bolt-001',
      cardName: 'Lightning Bolt',
      quantityToAdd: 3,
    );

    final result = await service.loadWishlists();
    final cards = result.first.cards;
    expect(cards, hasLength(1));
    expect(cards.first.scryfallId, 'bolt-001');
    expect(cards.first.name, 'Lightning Bolt');
    expect(cards.first.quantity, 3);
  });

  // ──────────────────────────────────────────────
  // 7. upsertCard() - mise à jour quantité
  // ──────────────────────────────────────────────
  test('upsertCard() met à jour la quantité', () async {
    final wl = makeWishlist(
      id: 'wl-1',
      cards: [makeCard(scryfallId: 'bolt-001', name: 'Lightning Bolt', quantity: 2)],
    );
    await seedWishlists([wl]);

    await service.upsertCard(
      wishlistId: 'wl-1',
      scryfallId: 'bolt-001',
      cardName: 'Lightning Bolt',
      quantityToAdd: 2,
    );

    final result = await service.loadWishlists();
    expect(result.first.cards.first.quantity, 4);
  });

  // ──────────────────────────────────────────────
  // 8. upsertCard() - suppression quand qty <= 0
  // ──────────────────────────────────────────────
  test('upsertCard() supprime la carte quand la quantité tombe à 0 ou moins', () async {
    final wl = makeWishlist(
      id: 'wl-1',
      cards: [makeCard(scryfallId: 'bolt-001', name: 'Lightning Bolt', quantity: 2)],
    );
    await seedWishlists([wl]);

    await service.upsertCard(
      wishlistId: 'wl-1',
      scryfallId: 'bolt-001',
      cardName: 'Lightning Bolt',
      quantityToAdd: -2,
    );

    final result = await service.loadWishlists();
    expect(result.first.cards, isEmpty);
  });

  // ──────────────────────────────────────────────
  // 9. upsertCard() - isFoil toggle
  // ──────────────────────────────────────────────
  test('upsertCard() avec isFoil bascule le statut foil', () async {
    final wl = makeWishlist(
      id: 'wl-1',
      cards: [makeCard(scryfallId: 'bolt-001', name: 'Lightning Bolt', quantity: 1, isFoil: false)],
    );
    await seedWishlists([wl]);

    await service.upsertCard(
      wishlistId: 'wl-1',
      scryfallId: 'bolt-001',
      cardName: 'Lightning Bolt',
      isFoil: true,
    );

    final result = await service.loadWishlists();
    expect(result.first.cards.first.isFoil, isTrue);
  });

  // ──────────────────────────────────────────────
  // 10. upsertCard() sans wishlistId -> première liste
  // ──────────────────────────────────────────────
  test('upsertCard() sans wishlistId utilise la première liste', () async {
    final wl1 = makeWishlist(id: 'wl-1', name: 'Première');
    final wl2 = makeWishlist(id: 'wl-2', name: 'Seconde');
    await seedWishlists([wl1, wl2]);

    await service.upsertCard(
      scryfallId: 'sol-ring-001',
      cardName: 'Sol Ring',
      quantityToAdd: 1,
    );

    final result = await service.loadWishlists();
    // La carte doit être dans la première liste (index 0)
    expect(result[0].cards, hasLength(1));
    expect(result[0].cards.first.name, 'Sol Ring');
    // La seconde liste reste vide
    expect(result[1].cards, isEmpty);
  });

  // ──────────────────────────────────────────────
  // 11. setWishlistIcon()
  // ──────────────────────────────────────────────
  test('setWishlistIcon() met à jour l\'icône', () async {
    final wl = makeWishlist(id: 'wl-1');
    await seedWishlists([wl]);

    await service.setWishlistIcon('wl-1', 'icon-scryfall-abc');

    final result = await service.loadWishlists();
    expect(result.first.iconScryfallId, 'icon-scryfall-abc');
  });

  // ──────────────────────────────────────────────
  // 12. Migration v1 -> v2 : données transférées
  // ──────────────────────────────────────────────
  test('Migration v1→v2 : les données legacy sont transférées', () async {
    // Simuler l'ancienne clé v1 avec des cartes
    final legacyCards = [
      DeckCard(scryfallId: 'old-1', name: 'Swords to Plowshares', quantity: 2).toJson(),
      DeckCard(scryfallId: 'old-2', name: 'Path to Exile', quantity: 1).toJson(),
    ];
    SharedPreferences.setMockInitialValues({
      'user_wishlist': json.encode(legacyCards),
    });
    service = WishlistService();

    final result = await service.loadWishlists();

    expect(result, hasLength(1));
    expect(result.first.name, 'Wishlist 1');
    expect(result.first.id, 'legacy_import');
    expect(result.first.cards, hasLength(2));
    expect(result.first.cards[0].name, 'Swords to Plowshares');
    expect(result.first.cards[0].quantity, 2);
    expect(result.first.cards[1].name, 'Path to Exile');
  });

  // ──────────────────────────────────────────────
  // 13. Migration v1 -> v2 : ancienne clé supprimée
  // ──────────────────────────────────────────────
  test('Migration v1→v2 : l\'ancienne clé est supprimée après migration', () async {
    final legacyCards = [
      DeckCard(scryfallId: 'old-1', name: 'Brainstorm', quantity: 4).toJson(),
    ];
    SharedPreferences.setMockInitialValues({
      'user_wishlist': json.encode(legacyCards),
    });
    service = WishlistService();

    // Déclencher la migration via loadWishlists
    await service.loadWishlists();

    final prefs = await SharedPreferences.getInstance();
    // L'ancienne clé ne doit plus exister
    expect(prefs.containsKey('user_wishlist'), isFalse);
    // La nouvelle clé doit exister
    expect(prefs.containsKey('user_wishlists_v2'), isTrue);
  });
}
