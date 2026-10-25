// Fichier : lib/utils/deck_metrics.dart
// Mesures de deck partagées : une seule règle, pour que l'onglet Stats et les
// en-têtes de la liste ne donnent jamais deux CMC moyens différents.

import '../models/deck_model.dart';
import '../models/scryfall_card_model.dart';

/// CMC moyen pondéré par la quantité. Les terrains n'ont pas de coût et
/// tireraient la moyenne vers zéro : ils sont exclus. Une carte `LOCAL:` ou
/// sans données Scryfall n'a pas de CMC connu : elle est ignorée plutôt que
/// comptée pour zéro. Rend 0,0 quand aucune carte n'est comptée.
double averageManaValue(
  Iterable<DeckCard> cards,
  List<ScryfallCard> fullCardData,
) {
  final byId = {for (final c in fullCardData) c.id: c};
  double total = 0;
  int count = 0;
  for (final deckCard in cards) {
    if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
    final sc = byId[deckCard.scryfallId];
    if (sc == null) continue;
    if (sc.typeLine.toLowerCase().contains('land')) continue;
    total += (sc.cmc ?? 0) * deckCard.quantity;
    count += deckCard.quantity;
  }
  return count > 0 ? total / count : 0.0;
}

/// Nombre de colonnes de la grille d'artworks selon la largeur disponible :
/// des vignettes d'environ 130 px, entre 3 (téléphone) et 8 (grand écran).
int deckCardGridColumns(double width) => (width / 130).floor().clamp(3, 8);
