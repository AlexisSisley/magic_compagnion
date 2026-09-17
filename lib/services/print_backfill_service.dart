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
  /// Cle AppSettings memorisant que la reprise a deja aboutit une fois.
  /// Posee uniquement en cas de succes (voir [runOnce]) : un echec ne doit
  /// jamais etre pris pour un succes silencieux, sous peine de perdre la
  /// reprise pour toujours pour l'utilisateur concerne.
  static const String backfillCompletedSettingKey = 'print_backfill_completed';

  final AppDatabase _db;
  final CardResolver _resolver;

  PrintBackfillService({required AppDatabase db, required CardResolver resolver})
      : _db = db,
        _resolver = resolver;

  /// Lance [run] une seule fois au total, memorise via [AppSettings]
  /// (drapeau [backfillCompletedSettingKey]).
  ///
  /// Pensee pour etre appelee sans `await` au demarrage (voir `main.dart`) :
  /// - une panne (reseau absent au premier lancement, etc.) ne pose PAS le
  ///   drapeau -- la reprise sera retentee au prochain lancement plutot que
  ///   perdue silencieusement ;
  /// - aucune exception ne s'echappe de cette methode : le demarrage de
  ///   l'application ne doit jamais dependre de la reprise de l'existant.
  Future<void> runOnce() async {
    final alreadyDone = await _db.getSetting(backfillCompletedSettingKey);
    if (alreadyDone == 'true') return;

    try {
      await run();
      await _db.setSetting(backfillCompletedSettingKey, 'true');
    } catch (_) {
      // Echec (reseau, base, etc.) : le drapeau reste absent expres, pour
      // que le prochain lancement retente la reprise plutot que de la
      // considerer terminee a tort.
    }
  }

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
