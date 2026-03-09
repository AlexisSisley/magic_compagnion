// Fichier : lib/services/deck_export_service.dart
// Service de generation de texte pour le partage de decks.
// Extrait de DeckDetailController.
// Fonctions pures sans etat, testables en isolation.

import '../models/deck_model.dart';
import '../models/scryfall_card_model.dart';

/// Service statique pour la generation de texte d'export/partage de decks.
class DeckExportService {
  /// Genere le texte complet du deck (Commander + Mainboard + Sideboard).
  /// [fullCardData] est utilise pour resoudre les noms des commandants par ID.
  static String generateFullDeckText({
    required Deck deck,
    required List<ScryfallCard> fullCardData,
  }) {
    StringBuffer sb = StringBuffer();
    sb.writeln('Deck: ${deck.name}');
    sb.writeln('Format: ${deck.format}');
    sb.writeln('');

    if (deck.commanderScryfallId != null) {
      final cmd = _findCardOrUnknown(deck.commanderScryfallId!, fullCardData);
      sb.writeln('COMMANDER:');
      sb.writeln('1 ${cmd.name}');
    }
    if (deck.commanderSecondaryScryfallId != null) {
      final partner = _findCardOrUnknown(deck.commanderSecondaryScryfallId!, fullCardData);
      sb.writeln('1 ${partner.name}');
    }
    if (deck.commanderScryfallId != null) sb.writeln('');

    sb.writeln('MAINBOARD:');
    for (var c in deck.mainboard) {
      if (c.scryfallId != deck.commanderScryfallId && c.scryfallId != deck.commanderSecondaryScryfallId) {
        sb.writeln('${c.quantity} ${c.name}');
      }
    }
    sb.writeln('');

    if (deck.sideboard.isNotEmpty) {
      sb.writeln('SIDEBOARD:');
      for (var c in deck.sideboard) {
        sb.writeln('${c.quantity} ${c.name}');
      }
    }

    return sb.toString();
  }

  /// Genere le texte de la liste "Considering".
  /// Retourne null si la liste considering est vide.
  static String? generateConsideringText(Deck deck) {
    if (deck.considering.isEmpty) return null;

    StringBuffer sb = StringBuffer();
    sb.writeln('Considering for: ${deck.name}');
    sb.writeln('');
    for (var c in deck.considering) {
      sb.writeln('${c.quantity} ${c.name}');
    }
    return sb.toString();
  }

  /// Genere le texte de la wishlist.
  /// Retourne null si la wishlist est vide.
  static String? generateWishlistText(Deck deck) {
    if (deck.wishlist.isEmpty) return null;

    StringBuffer sb = StringBuffer();
    sb.writeln('Wishlist for: ${deck.name}');
    sb.writeln('');
    for (var c in deck.wishlist) {
      sb.writeln('${c.quantity} ${c.name}');
    }
    return sb.toString();
  }

  // --- PRIVATE HELPERS ---

  static ScryfallCard _findCardOrUnknown(String scryfallId, List<ScryfallCard> fullCardData) {
    return fullCardData.where((c) => c.id == scryfallId).firstOrNull ??
        ScryfallCard(
          id: '',
          oracleId: '',
          name: 'Inconnu',
          imageUrl: '',
          rulesText: '',
          typeLine: '',
          legalities: {},
          prices: {},
          lang: '',
          colorIdentity: [],
          setName: '',
          setCode: '',
          collectorNumber: '',
          rarity: '',
          purchaseUris: {},
        );
  }
}
