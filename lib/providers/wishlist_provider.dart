// Fichier : lib/providers/wishlist_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scryfall_card_model.dart';
import '../models/wishlist_model.dart';
import 'service_providers.dart';

class WishlistNotifier extends AsyncNotifier<List<Wishlist>> {
  @override
  Future<List<Wishlist>> build() async {
    final service = ref.read(wishlistServiceProvider);
    return service.loadWishlists();
  }

  Future<void> createWishlist(String name) async {
    final service = ref.read(wishlistServiceProvider);
    await service.createWishlist(name);
    ref.invalidateSelf();
  }

  Future<void> deleteWishlist(String id) async {
    final service = ref.read(wishlistServiceProvider);
    await service.deleteWishlist(id);
    ref.invalidateSelf();
  }

  Future<void> renameWishlist(String id, String newName) async {
    final service = ref.read(wishlistServiceProvider);
    await service.renameWishlist(id, newName);
    ref.invalidateSelf();
  }

  Future<void> clearWishlistCards(String wishlistId) async {
    final service = ref.read(wishlistServiceProvider);
    await service.clearWishlistCards(wishlistId);
    ref.invalidateSelf();
  }

  Future<void> upsertCard({
    String? wishlistId,
    required String scryfallId,
    required String cardName,
    int? quantityToAdd,
    int? absoluteQuantity,
    bool? isFoil,
  }) async {
    final service = ref.read(wishlistServiceProvider);
    await service.upsertCard(
      wishlistId: wishlistId,
      scryfallId: scryfallId,
      cardName: cardName,
      quantityToAdd: quantityToAdd,
      absoluteQuantity: absoluteQuantity,
      isFoil: isFoil,
    );
    ref.invalidateSelf();
  }

  Future<void> addCard(ScryfallCard card, int quantity, {String? targetWishlistId}) async {
    final service = ref.read(wishlistServiceProvider);
    await service.addCard(card, quantity, targetWishlistId: targetWishlistId);
    ref.invalidateSelf();
  }

  Future<void> setWishlistIcon(String wishlistId, String? scryfallId) async {
    final service = ref.read(wishlistServiceProvider);
    await service.setWishlistIcon(wishlistId, scryfallId);
    ref.invalidateSelf();
  }

  Future<void> reload() async {
    ref.invalidateSelf();
  }
}

final wishlistProvider = AsyncNotifierProvider<WishlistNotifier, List<Wishlist>>(
  WishlistNotifier.new,
);
