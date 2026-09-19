// Correspondance entre la structure de deck Moxfield et le modele de l'app.
//
// Structure relevee sur un deck reel le 2026-09-19 :
//   boards { commanders, mainboard, sideboard, maybeboard, attractions, ... }
//   chaque entree : { quantity, isFoil, isProxy, finish, card { scryfall_id,
//                     name, set, cn, lang } }
//
// Voir docs/superpowers/specs/2026-09-19-import-moxfield-design.md
//
// Robustesse: une reponse inattendue (API non documentee) ne doit pas casser l'import.
// Politique de degradation : une structure inattendue produit zero ligne pour ce board ;
// une entree inattendue est ignoree ; jamais d'exception.
//
// Notes de conception :
// - Une carte presente a la fois dans mainboard et maybeboard produit DEUX lignes
//   (les deux boards sont semantiquement distincts).
// - L'ordre des commandants s'appuie sur l'ordre d'iteration de la Map JSON, qui est
//   deterministe avec dart:convert (LinkedHashMap, ordre d'insertion).

/// Une ligne de deck telle que Moxfield la decrit.
class MoxfieldCardLine {
  final String scryfallId;
  final String name;
  final int quantity;
  final bool isFoil;
  final bool isProxy;

  /// 'mainboard', 'sideboard' ou 'considering'.
  final String board;

  const MoxfieldCardLine({
    required this.scryfallId,
    required this.name,
    required this.quantity,
    required this.board,
    this.isFoil = false,
    this.isProxy = false,
  });
}

class MoxfieldDeckData {
  final String name;
  final String format;
  final List<MoxfieldCardLine> lines;
  final String? commanderScryfallId;
  final String? partnerScryfallId;

  const MoxfieldDeckData({
    required this.name,
    required this.format,
    this.lines = const [],
    this.commanderScryfallId,
    this.partnerScryfallId,
  });
}

class MoxfieldDeckMapper {
  /// Boards Moxfield retenus, et leur equivalent dans le modele Deck.
  /// Les boards absents de cette table (attractions, stickers, planes...) sont
  /// ignores : ils n'ont pas d'equivalent et ne concernent pas les formats geres.
  static const Map<String, String> _boards = {
    'mainboard': 'mainboard',
    'sideboard': 'sideboard',
    'maybeboard': 'considering',
  };

  static MoxfieldDeckData fromJson(Map<String, dynamic> json) {
    // Garde l'accès à boards: si ce n'est pas une Map, on ignore silencieusement.
    final boardsRaw = json['boards'];
    final boards = (boardsRaw is Map<String, dynamic>)
        ? boardsRaw
        : <String, dynamic>{};
    final lines = <MoxfieldCardLine>[];

    for (final entry in _boards.entries) {
      final cardBoard = boards[entry.key];
      if (cardBoard is! Map) continue;
      final cardsRaw = cardBoard['cards'];
      if (cardsRaw is! Map) continue;
      final cards = cardsRaw.cast<String, dynamic>();
      for (final raw in cards.values) {
        final line = _line(raw, entry.value);
        if (line != null) lines.add(line);
      }
    }

    final ids = <String>[];
    final commandersBoard = boards['commanders'];
    if (commandersBoard is Map) {
      final cardsRaw = commandersBoard['cards'];
      if (cardsRaw is Map<String, dynamic>) {
        for (final raw in cardsRaw.values) {
          if (raw is! Map) continue;
          final card = raw['card'];
          if (card is! Map) continue;
          final idRaw = card['scryfall_id'];
          // Accepte seulement String pour scryfall_id, pas int ou autre.
          final id = idRaw is String ? idRaw : null;
          if (id != null && id.isNotEmpty) {
            ids.add(id);
          }
        }
      }
    }

    // Normalise la casse du format pour l'affichage utilisateur.
    // Capitalise chaque mot séparé par espace, préservant les formats multi-mots.
    String normalizeFormat(dynamic raw) {
      if (raw is! String || raw.isEmpty) return 'Commander';
      final words = raw.split(' ');
      return words
          .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase())
          .join(' ');
    }

    // Garde l'accès à name et format: accepte seulement String.
    final nameRaw = json['name'];
    final name = (nameRaw is String) ? nameRaw : 'Deck importé';
    final formatRaw = json['format'];
    final format = normalizeFormat(formatRaw);

    return MoxfieldDeckData(
      name: name,
      format: format,
      lines: lines,
      commanderScryfallId: ids.isNotEmpty ? ids.first : null,
      partnerScryfallId: ids.length > 1 ? ids[1] : null,
    );
  }

  static MoxfieldCardLine? _line(dynamic raw, String board) {
    if (raw is! Map) return null;
    final card = raw['card'];
    if (card is! Map) return null;

    // Accepte seulement String pour scryfall_id.
    final idRaw = card['scryfall_id'];
    final id = idRaw is String ? idRaw : null;
    if (id == null || id.isEmpty) return null;

    // Valide que quantity est un nombre (pas une chaîne, par ex).
    final qty = raw['quantity'];
    final quantity = (qty is num) ? qty.toInt() : (qty is int) ? qty : null;
    if (quantity == null || quantity < 1) return null;

    // Accepte seulement String pour name, accepte seulement bool pour isFoil/isProxy.
    final nameRaw = card['name'];
    final name = (nameRaw is String) ? nameRaw : '';

    final isFoilRaw = raw['isFoil'];
    final isFoil = (isFoilRaw is bool) ? isFoilRaw : false;

    final isProxyRaw = raw['isProxy'];
    final isProxy = (isProxyRaw is bool) ? isProxyRaw : false;

    return MoxfieldCardLine(
      scryfallId: id,
      name: name,
      quantity: quantity,
      isFoil: isFoil,
      isProxy: isProxy,
      board: board,
    );
  }
}
