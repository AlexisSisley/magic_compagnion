// Correspondance entre la structure de deck Moxfield et le modele de l'app.
//
// Structure relevee sur un deck reel le 2026-09-19 :
//   boards { commanders, mainboard, sideboard, maybeboard, attractions, ... }
//   chaque entree : { quantity, isFoil, isProxy, finish, card { scryfall_id,
//                     name, set, cn, lang } }
//
// Voir docs/superpowers/specs/2026-09-19-import-moxfield-design.md

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
    final boards = (json['boards'] as Map?)?.cast<String, dynamic>() ?? {};
    final lines = <MoxfieldCardLine>[];

    for (final entry in _boards.entries) {
      final cards = ((boards[entry.key] as Map?)?['cards'] as Map?) ?? {};
      for (final raw in cards.values) {
        final line = _line(raw, entry.value);
        if (line != null) lines.add(line);
      }
    }

    final commandants = ((boards['commanders'] as Map?)?['cards'] as Map?)?.values.toList() ?? [];
    final ids = commandants
        .map((c) => ((c as Map)['card'] as Map?)?['scryfall_id'] as String?)
        .whereType<String>()
        .toList();

    return MoxfieldDeckData(
      name: json['name'] as String? ?? 'Deck importé',
      format: json['format'] as String? ?? 'Commander',
      lines: lines,
      commanderScryfallId: ids.isNotEmpty ? ids.first : null,
      partnerScryfallId: ids.length > 1 ? ids[1] : null,
    );
  }

  static MoxfieldCardLine? _line(dynamic raw, String board) {
    if (raw is! Map) return null;
    final card = raw['card'];
    if (card is! Map) return null;

    final id = card['scryfall_id'] as String?;
    if (id == null || id.isEmpty) return null;

    return MoxfieldCardLine(
      scryfallId: id,
      name: card['name'] as String? ?? '',
      quantity: (raw['quantity'] as num?)?.toInt() ?? 1,
      isFoil: raw['isFoil'] as bool? ?? false,
      isProxy: raw['isProxy'] as bool? ?? false,
      board: board,
    );
  }
}
