// Fichier : lib/services/scryfall_api.dart
// Constantes et helpers pour l'API Scryfall

class ScryfallApi {
  static const String baseUrl = 'https://api.scryfall.com';
  static const String setsUrl = '$baseUrl/sets';
  static const String cardsSearchUrl = '$baseUrl/cards/search';
  static const String cardsCollectionUrl = '$baseUrl/cards/collection';
  static const String svgBaseUrl = 'https://svgs.scryfall.io/card-symbols';

  /// Construit l'URL d'image art_crop via l'endpoint redirect Scryfall.
  /// Attention : certaines cartes ne supportent pas art_crop (tokens, digitales...).
  /// Préférer l'URL directe depuis image_uris quand disponible.
  static String artCropRedirectUrl(String scryfallId) =>
      '$baseUrl/cards/$scryfallId?format=image&version=art_crop';

  /// Extrait l'URL art_crop depuis les image_uris du JSON Scryfall.
  /// Retourne null si non disponible.
  static String? extractArtCropUrl(Map<String, dynamic>? imageUris) {
    if (imageUris == null) return null;
    return imageUris['art_crop'] as String?;
  }

  /// Extrait l'URL art_crop en gérant les cartes double-face.
  static String? extractArtCropFromCard(Map<String, dynamic> cardJson) {
    // D'abord essayer image_uris au niveau racine
    if (cardJson['image_uris'] != null) {
      return extractArtCropUrl(cardJson['image_uris'] as Map<String, dynamic>);
    }
    // Sinon essayer la première face
    if (cardJson['card_faces'] != null &&
        (cardJson['card_faces'] as List).isNotEmpty) {
      final face = cardJson['card_faces'][0] as Map<String, dynamic>;
      if (face['image_uris'] != null) {
        return extractArtCropUrl(face['image_uris'] as Map<String, dynamic>);
      }
    }
    return null;
  }
}
