// Reprise de l'existant : met en cache le tirage de chaque carte deja stockee,
// pour que la projection d'affichage dispose d'un oracleId.
//
// Ne modifie AUCUNE ligne de deck ni de collection : le scryfallId possede est
// la verite, et ce service ne fait que remplir le cache a cote.
//
// Voir docs/superpowers/specs/2026-09-17-identite-tirage-langue-design.md

import '../data/database/app_database.dart';
import '../models/card_print.dart';
import 'card_resolver.dart';

class PrintBackfillService {
  final AppDatabase _db;
  final CardResolver _resolver;

  PrintBackfillService({required AppDatabase db, required CardResolver resolver})
      : _db = db,
        _resolver = resolver;

  /// Rend le nombre de tirages nouvellement mis en cache.
  Future<int> run() async {
    final deckRows = await _db.select(_db.deckCards).get();
    final collectionRows = await _db.select(_db.collectionCards).get();

    final ids = <String, String>{}; // scryfallId -> nom
    for (final row in deckRows) {
      ids[row.scryfallId] = row.name;
    }
    for (final row in collectionRows) {
      ids[row.scryfallId] = row.name;
    }

    final missing = <PrintRequest>[];
    for (final entry in ids.entries) {
      if (await _db.getCardPrint(entry.key) == null) {
        missing.add(PrintRequest(name: entry.value, scryfallId: entry.key));
      }
    }

    final resolution = await _resolver.resolveEditions(missing);
    return resolution.resolved.length;
  }
}
